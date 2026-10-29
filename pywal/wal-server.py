#!/usr/bin/env python3
# wal-server.py — serves ~/.cache/wal/colors.json on localhost:7799
#
# The keybr Chromium extension fetches from here to get the current
# pywal palette. Much simpler than native messaging for read-only color access.
#
# Install: cp wal-server.py ~/.local/bin/wal-server && chmod +x ~/.local/bin/wal-server
# Autostart: add  hl.exec_cmd(home .. "/.local/bin/wal-server")  to hyprland.lua

import http.server
import os

COLORS_PATH = os.path.expanduser("~/.cache/wal/colors.json")
PORT        = 7799

class WalHandler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        try:
            # read fresh from disk on every request
            # so pywal changes are picked up automatically
            with open(COLORS_PATH, "rb") as f:
                data = f.read()
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            # CORS header lets the Chromium extension fetch from localhost
            self.send_header("Access-Control-Allow-Origin", "*")
            self.end_headers()
            self.wfile.write(data)
        except FileNotFoundError:
            self.send_response(404)
            self.end_headers()
        except Exception:
            self.send_response(500)
            self.end_headers()

    # suppress the default per-request log lines
    def log_message(self, *args):
        pass

if __name__ == "__main__":
    server = http.server.HTTPServer(("127.0.0.1", PORT), WalHandler)
    server.serve_forever()
