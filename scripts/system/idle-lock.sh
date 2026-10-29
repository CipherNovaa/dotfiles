#!/bin/bash
# idle-lock.sh — lock the session on idle, UNLESS a video is actively playing.
# Wired to hypridle's lock timeout. The actual lock (and CRT-sleep) is performed
# by lock_cmd = lock-crt-sleep.sh, triggered via loginctl lock-session.

~/scripts/system/idle-media-active.sh && exit 0   # watching something -> don't lock
loginctl lock-session
