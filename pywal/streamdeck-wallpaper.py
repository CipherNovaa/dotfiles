#!/usr/bin/env python3
# Run with the venv that has python-elgato-streamdeck + Pillow, e.g.
#   ~/.local/share/streamdeck-venv/bin/python streamdeck-wallpaper.py
"""
streamdeck-wallpaper.py — render the current wallpaper split across all keys of
an Elgato Stream Deck, as a desk piece. Animated GIFs/WEBMs loop; static images
are pushed once. Single-instance: starting a new one replaces the running one.

Usage:
    streamdeck-wallpaper.py [IMAGE]
    # no arg -> reads the path stored in ~/.cache/wal/current-main

Supports: png, jpg, jpeg, webp, gif (PIL), webm/mp4/avi (ffmpeg pipe → PIL).
Uses a dedicated venv (python-elgato-streamdeck + Pillow). OpenDeck must not be
holding the device (it isn't, unless you launch it).
"""
import fcntl
import io
import os
import subprocess
import sys
import signal
import time
from pathlib import Path

from PIL import Image, ImageSequence
from StreamDeck.DeviceManager import DeviceManager
from StreamDeck.ImageHelpers import PILHelper

# Gap (in px) the image "spans" between adjacent keys, so the picture lines up
# across the physical bezels. Tune to taste if the image looks too spread/tight.
KEY_SPACING = 28
# Don't hammer USB faster than this (seconds per full-deck frame). The original
# deck can't do much better than a few fps across all 15 keys anyway.
MIN_FRAME_TIME = 0.18
PIDFILE = Path("/tmp/streamdeck-wallpaper.pid")
LOCKFILE = Path("/tmp/streamdeck-wallpaper.lock")
VIDEO_EXTS = {".webm", ".mp4", ".avi", ".mov", ".mkv"}


def resolve_image() -> str:
    if len(sys.argv) > 1 and sys.argv[1].strip():
        return os.path.expanduser(sys.argv[1].strip())
    pointer = Path.home() / ".cache/wal/current-main"
    return pointer.read_text().strip()


def _pid_alive(pid: int) -> bool:
    try:
        os.kill(pid, 0)
    except ProcessLookupError:
        return False
    except PermissionError:
        return True
    return True


def kill_previous():
    """Stop any already-running instance and WAIT for it to fully exit so the
    kernel releases the USB HID handle before we open the device.

    Must be called while holding the launch lock (see main): that, plus actually
    waiting for the old PID to die, is what prevents two processes from opening
    the same deck at once — the race that froze the device on rapid switches."""
    if PIDFILE.exists():
        try:
            old = int(PIDFILE.read_text().strip())
        except ValueError:
            old = None
        if old and old != os.getpid() and _pid_alive(old):
            try:
                os.kill(old, signal.SIGTERM)
            except ProcessLookupError:
                old = None
            # Wait for graceful shutdown, then escalate to SIGKILL.
            deadline = time.time() + 1.5
            while old and _pid_alive(old) and time.time() < deadline:
                time.sleep(0.05)
            if old and _pid_alive(old):
                try:
                    os.kill(old, signal.SIGKILL)
                except ProcessLookupError:
                    pass
                deadline = time.time() + 1.0
                while _pid_alive(old) and time.time() < deadline:
                    time.sleep(0.05)
            # Brief settle so the kernel finishes releasing the HID handle.
            time.sleep(0.2)
    PIDFILE.write_text(str(os.getpid()))


def load_frames_ffmpeg(path: str):
    """Extract all frames from a video file using ffmpeg, return list of PIL Images."""
    cmd = [
        "ffmpeg", "-i", path,
        "-vf", "fps=15,scale=iw:ih",
        "-f", "image2pipe",
        "-vcodec", "png",
        "pipe:1",
    ]
    try:
        proc = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
    except FileNotFoundError:
        print("streamdeck-wallpaper: ffmpeg not found, cannot decode video", file=sys.stderr)
        return []

    # ffmpeg outputs concatenated PNG files; split on PNG magic bytes
    data = proc.stdout
    magic = b"\x89PNG"
    frames = []
    start = 0
    while True:
        pos = data.find(magic, start + 1)
        if pos == -1:
            chunk = data[start:]
            if len(chunk) > 8:
                try:
                    frames.append(Image.open(io.BytesIO(chunk)).copy())
                except Exception:
                    pass
            break
        chunk = data[start:pos]
        if len(chunk) > 8:
            try:
                frames.append(Image.open(io.BytesIO(chunk)).copy())
            except Exception:
                pass
        start = pos
    return frames


def load_frames(img_path: str):
    """Load all frames from image or video file."""
    ext = Path(img_path).suffix.lower()
    if ext in VIDEO_EXTS:
        return load_frames_ffmpeg(img_path), True
    src = Image.open(img_path)
    frames = [f.copy() for f in ImageSequence.Iterator(src)]
    # Preserve frame durations for GIFs
    durations = [max(f.info.get("duration", 100) / 1000.0, MIN_FRAME_TIME) for f in frames]
    return frames, durations


def slice_frame(deck, frame: Image.Image):
    """Split one RGB frame into native per-key images covering the whole deck."""
    rows, cols = deck.key_layout()
    kw, kh = deck.key_image_format()["size"]
    full_w = cols * kw + (cols - 1) * KEY_SPACING
    full_h = rows * kh + (rows - 1) * KEY_SPACING
    canvas = frame.convert("RGB").resize((full_w, full_h), Image.LANCZOS)

    images = {}
    for r in range(rows):
        for c in range(cols):
            x = c * (kw + KEY_SPACING)
            y = r * (kh + KEY_SPACING)
            tile = canvas.crop((x, y, x + kw, y + kh))
            key = r * cols + c
            images[key] = PILHelper.to_native_format(deck, tile)
    return images


def push(deck, images):
    with deck:
        for key, img in images.items():
            deck.set_key_image(key, img)


def main():
    img_path = resolve_image()
    if not img_path or not os.path.isfile(img_path):
        print(f"streamdeck-wallpaper: no image at {img_path!r}", file=sys.stderr)
        return 1

    # Serialize the whole device handoff (kill previous → wait → open) with an
    # exclusive lock. Without this, two launchers started in quick succession
    # (rapid GIF switching) could both reach deck.open() and freeze the device.
    lock_fd = os.open(str(LOCKFILE), os.O_CREAT | os.O_RDWR, 0o644)
    fcntl.flock(lock_fd, fcntl.LOCK_EX)
    try:
        # Kill any running instance and wait for it to release the USB handle.
        kill_previous()

        decks = DeviceManager().enumerate()
        if not decks:
            print("streamdeck-wallpaper: no Stream Deck found", file=sys.stderr)
            return 1

        deck = decks[0]
        # The previous owner should be gone, but retry briefly in case the HID
        # handle is still being torn down.
        last_err = None
        for _ in range(6):
            try:
                deck.open()
                last_err = None
                break
            except Exception as e:  # USBError / HID busy
                last_err = e
                time.sleep(0.3)
        if last_err is not None:
            print(f"streamdeck-wallpaper: could not open deck: {last_err}", file=sys.stderr)
            return 1
        deck.reset()
        deck.set_brightness(100)
    finally:
        fcntl.flock(lock_fd, fcntl.LOCK_UN)
        os.close(lock_fd)

    def cleanup(*_):
        try:
            deck.close()
        except Exception:
            pass
        finally:
            if PIDFILE.exists():
                try:
                    if PIDFILE.read_text().strip() == str(os.getpid()):
                        PIDFILE.unlink(missing_ok=True)
                except Exception:
                    pass
        os._exit(0)

    signal.signal(signal.SIGTERM, cleanup)
    signal.signal(signal.SIGINT, cleanup)

    result = load_frames(img_path)

    # Video files return (frames_list, is_video=True)
    # Image files return (frames_list, durations_list)
    if result[1] is True:
        frames = result[0]
        durations = [MIN_FRAME_TIME] * len(frames)
    else:
        frames, durations = result

    if not frames:
        print(f"streamdeck-wallpaper: could not load frames from {img_path!r}", file=sys.stderr)
        deck.close()
        PIDFILE.unlink(missing_ok=True)
        return 1

    if len(frames) <= 1:
        # Static image — push once; the deck retains it after we exit.
        push(deck, slice_frame(deck, frames[0]))
        deck.close()
        PIDFILE.unlink(missing_ok=True)
        return 0

    # Animated — precompute every frame's key images, then loop forever.
    rendered = [slice_frame(deck, f) for f in frames]

    while True:
        for images, delay in zip(rendered, durations):
            push(deck, images)
            time.sleep(delay)


if __name__ == "__main__":
    sys.exit(main())
