#!/usr/bin/env python3
# GameCube adapter (Wii U mode) probe: per-port status + measured polling Hz.
# Close Dolphin first (it holds the USB interface). Usage: gc_adapter_check.py [seconds]
import ctypes as C, time, sys
L = C.CDLL("libusb-1.0.so.0")
L.libusb_open_device_with_vid_pid.restype = C.c_void_p
L.libusb_open_device_with_vid_pid.argtypes = [C.c_void_p, C.c_uint16, C.c_uint16]
L.libusb_interrupt_transfer.argtypes = [C.c_void_p, C.c_ubyte, C.c_void_p, C.c_int, C.POINTER(C.c_int), C.c_uint]
for f in ("libusb_claim_interface", "libusb_release_interface", "libusb_kernel_driver_active", "libusb_detach_kernel_driver"):
    getattr(L, f).argtypes = [C.c_void_p, C.c_int]
L.libusb_close.argtypes = [C.c_void_p]
L.libusb_init(None)
h = L.libusb_open_device_with_vid_pid(None, 0x057e, 0x0337)
if not h: sys.exit("open failed (permissions?)")
if L.libusb_kernel_driver_active(h, 0) == 1: L.libusb_detach_kernel_driver(h, 0)
r = L.libusb_claim_interface(h, 0); print("claim:", r, "(0 = ok, -6 = busy)")
if r != 0: sys.exit("adapter is claimed by another process (Dolphin open?) - close it first")
n = C.c_int(); cmd = (C.c_ubyte * 1)(0x13)
print("init write:", L.libusb_interrupt_transfer(h, 0x02, cmd, 1, C.byref(n), 100))
buf = (C.c_ubyte * 37)(); cnt = 0; t0 = time.time(); last = None
dur = float(sys.argv[1]) if len(sys.argv) > 1 else 2
while time.time() - t0 < dur:
    if L.libusb_interrupt_transfer(h, 0x81, buf, 37, C.byref(n), 100) == 0 and buf[0] == 0x21:
        cnt += 1; last = bytes(buf)
el = time.time() - t0
print(f"reports: {cnt} in {el:.2f}s = {cnt/el:.0f} Hz")
if last:
    for p in range(4):
        s = last[1 + 9*p:10 + 9*p]
        kind = {0x10: "wired controller", 0x20: "wireless controller"}.get(s[0] & 0x30, "empty")
        print(f"port {p+1}: {kind:20s} status=0x{s[0]:02x} stick=({s[3]},{s[4]}) c=({s[5]},{s[6]}) L={s[7]} R={s[8]}")
L.libusb_release_interface(h, 0); L.libusb_close(h)
