#!/bin/bash
# Switch CRT to 1024x768 (4:3) for Flycast, restore 1280x1024 on exit

wlr-randr --output HDMI-A-1 --mode 1024x768@75
sleep 0.5

flycast

wlr-randr --output HDMI-A-1 --mode 1280x1024@75
