-- =============================================================================
-- Hyprland config — desktop (Lua)
-- Converted from hyprland.conf. Two outputs: DP-3 (main, 2560x1440) and
-- HDMI-A-1 (a 5:4 CRT at 1280x1024). Rename outputs to match your machine.
-- =============================================================================
--
-- SECTION MAP (search the ---- HEADER ---- lines to jump):
--   MONITORS ............ output modes/positions (DP-3 main, HDMI-A-1 CRT)
--   PROGRAMS ............ terminal / file-manager / menu / mainMod aliases
--   AUTOSTART ........... hyprland.start exec list + one-shot services
--   ENVIRONMENT ......... env vars (Nvidia, Electron/Qt platform hints)
--   LOOK AND FEEL ....... general/decoration/blur/animations/layer rules
--   INPUT ............... keyboard/touchpad/gestures/devices
--   WORKSPACES .......... workspace→monitor rules (1–10 DP-3, 11–20 CRT pool)
--   KEYBINDINGS ......... Core · Focus · Move · Monitor · Workspaces · Numpad
--                         · Keyboard workflow · Screenshot · Power · Audio
--                         · Utilities · Mouse · Gamemode
--                         F-key layout: SUPER+F8 gamemode, F9 network,
--                         F10 calendar, F11 focustime, F12 media widgets
--   WINDOW RULES ........ float rules + per-app workspace/monitor assignments
--                         (grouped: general → main-monitor → CRT/retro apps)
--
-- Scripts are expected under ~/scripts/... (see the repo README's install table).
-- A few binds call tools that live outside this repo — drop them if you don't
-- have them: keybr (github.com/CipherNovaa/keybr-ws: keybr-toggle), ~/scripts/godot/gamedev.sh,
-- hyprule-snapd.py (github.com/CipherNovaa/hyprule), codec, and the MGS4 / AC6
-- window rules (github.com/CipherNovaa/mgs4-crt, .../ac6-crt-5to4).
-- =============================================================================

--------------------
---- MONITORS ------
--------------------

hl.monitor({ output = "DP-3", mode = "2560x1440@170", position = "1280x0", scale = 1 })
hl.monitor({ output = "HDMI-A-1", mode = "1280x1024@75", position = "0x0", scale = 1 })

-----------------------
---- PROGRAMS ------
-----------------------

local terminal = "kitty"
local fileManager = "kitty --class yazi -e sh -c 'cat ~/.cache/wal/sequences && yazi'"
local menu = "rofi -show drun -show-icons"
local mainMod = "SUPER"
local home = os.getenv("HOME")

-------------------
---- AUTOSTART ----
-------------------

hl.on("hyprland.start", function()
	hl.exec_cmd("systemctl --user start hyprpolkitagent")
	-- Keep Dolphin's app/mime index (ksycoca) fresh so "Open With" is never empty
	hl.exec_cmd("kbuildsycoca6")
	hl.exec_cmd("waybar")
	hl.exec_cmd("awww-daemon")
	hl.exec_cmd(home .. "/scripts/system/launch-wallpaper.sh")
	hl.exec_cmd("nm-applet")
	-- dunst replaced by quickshell's NotificationServer (Main.qml) as of 2026-06-11
	-- hl.exec_cmd("dunst")
	-- DeaDBeeF no longer auto-starts (2026-07-13); launch it on demand instead.
	-- hl.exec_cmd(home .. "/scripts/system/launch-deadbeef.sh")
	hl.exec_cmd("wal -R -n -q")
	hl.exec_cmd("wl-paste --type text --watch cliphist store")
	hl.exec_cmd("wl-paste --type image --watch cliphist store")
	hl.exec_cmd(home .. "/scripts/bar/art-daemon.sh")
	hl.exec_cmd("openrgb --server")
	hl.exec_cmd(home .. "/scripts/bar/resize-art.sh")
	hl.exec_cmd(home .. "/scripts/system/audio-loopback.sh")
	-- KDE Connect: shared clipboard with the phone + laptop over Tailscale (2026-09-13).
	-- Hyprland doesn't run XDG autostart, and kdeconnectd needs the Wayland session env
	-- for clipboard access, so it's launched from here.
	hl.exec_cmd("kdeconnectd")
	-- hyprule snap daemon: re-homes emulator/media windows to their CRT category
	-- workspace (ws11 Emulator / ws12 Media) when they land on the CRT. Only ever
	-- acts on the CRT monitor, so main-display rules are untouched. Config +
	-- on/off in ~/.config/hyprule/snap.json (hot-reloaded); managed by the hyprule app.
	hl.exec_cmd("python3 " .. home .. "/scripts/system/hyprule-snapd.py")
	-- trackball-mode: the TB550's wheel button is hold-to-scroll (below) EXCEPT
	-- while Aseprite / Blender / Godot / a game is focused — there it's a real
	-- middle button (pan, orbit, in-game binds). List in the script.
	hl.exec_cmd("python3 " .. home .. "/scripts/system/trackball-mode.py")
	-- Make DP-3 the XWayland primary so Wine/Proton games fullscreen on it and read
	-- its 144Hz refresh (otherwise the CRT at 0x0 is treated as primary).
	hl.exec_cmd("sh -c 'sleep 3; xrandr --output DP-3 --primary'")
end)

-- keybr is no longer auto-started: ws7 is now Blender. The typing dashboard
-- lives in the `special:keybr` scratchpad, launched on demand via SUPER+SHIFT+T
-- (see keybr-toggle). wal-server still starts here (keybr-launch used to start it).
hl.exec_cmd(home .. "/.local/bin/wal-server")
-- Quickshell widget layer (media popup + power menu) — managed by quickshell.service
-- (systemd-user, Restart=on-failure) so it auto-respawns if it ever dies.
hl.exec_cmd("systemctl --user restart quickshell.service")
-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------

hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("LIBVA_DRIVER_NAME", "nvidia")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("GBM_BACKEND", "nvidia-drm")
hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
hl.env("WLR_NO_HARDWARE_CURSORS", "1")
-- Electron apps (Vesktop, Obsidian, etc.): force XWayland. Native Wayland Electron
-- renders a blank/transparent window on this Nvidia setup, so x11 is the safe default.
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "x11")
-- Qt apps (Dolphin, PCSX2, DuckStation): read the full palette from qt6ct so the
-- pywal colors actually apply. update-qt-colors.sh regenerates the qt6ct scheme.
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
-- NVIDIA shader cache: the 1GB default was full (~/.cache/nvidia/GLCache), so the driver
-- evicted old shaders and games/emulators recompiled them = stutter. 12GB (2026-09-13).
hl.env("__GL_SHADER_DISK_CACHE_SIZE", "12000000000")
-- Zen/Firefox hardware video decode on the 3070 (nvidia-vaapi-driver). Without these the
-- RDD sandbox can't open the driver and YouTube silently decodes on the CPU.
hl.env("MOZ_DISABLE_RDD_SANDBOX", "1")
hl.env("NVD_BACKEND", "direct")
-----------------------
---- LOOK AND FEEL ----
-----------------------

hl.config({
	general = {
		gaps_in = 6,
		gaps_out = 10,
		border_size = 2,
		col = {
			-- Kept transparent; pywal sets active_border via hyprctl keyword at runtime
			active_border = "rgba(00000000)",
			inactive_border = "rgba(1e1a1400)",
		},
		resize_on_border = true,
		allow_tearing = false,
		layout = "dwindle",
	},
})

-- pywal active border (color3 → color2, 45deg), read straight from the palette at
-- config load. This replaced the `hyprctl keyword` call in wallpaper-picker.sh, which
-- is dead on the Lua build — and doing it here means every `hyprctl reload` (wallpaper
-- change, game mode off) re-applies the current colors instead of wiping them.
do
	local f = io.open(home .. "/.cache/wal/colors.json", "r")
	if f then
		local palette = f:read("a")
		f:close()
		local c3 = palette:match('"color3"%s*:%s*"#(%x%x%x%x%x%x)"')
		local c2 = palette:match('"color2"%s*:%s*"#(%x%x%x%x%x%x)"')
		if c3 and c2 then
			hl.config({
				general = { col = { active_border = { colors = { "rgba(" .. c3 .. "ee)", "rgba(" .. c2 .. "ee)" }, angle = 45 } } },
			})
		end
	end
end

hl.config({
	decoration = {
		rounding = 7,
		rounding_power = 2.0,
		active_opacity = 0.9,
		inactive_opacity = 0.8,
		shadow = {
			enabled = true,
			range = 8,
			render_power = 3,
			color = "rgba(0d0f12ee)",
		},
		blur = {
			enabled = true,
			size = 4,
			passes = 2,
			vibrancy = 0.1696,
		},
	},
})

hl.config({
	animations = { enabled = true },
})

-- Direct scanout for fullscreen GAMES only (2): the game's frames go straight to DP-3
-- without compositing = lower input lag, pairs with G-Sync. If a game flickers or shows
-- black frames, set this back to 0.
hl.config({
	render = { direct_scanout = 2 },
})

-- Blur the rofi layer surface so it matches the translucency of normal windows
-- (rofi draws on a layer-shell surface, which is not blurred by the global window
-- blur unless an explicit layer rule opts it in). Pairs with the alpha baked into
-- ~/.config/wal/templates/colors-rofi-dark.rasi.
hl.layer_rule({ name = "rofi-blur", match = { namespace = "^rofi$" }, blur = true, ignore_alpha = 0.2 })
-- Quickshell widget layers get blur too. All dispatcher widgets (media, power,
-- music, calendar, focustime, battery) share the qs-master overlay namespace;
-- the volume OSD is its own surface.
hl.layer_rule({ name = "qs-master-blur", match = { namespace = "^qs-master$" }, blur = true, ignore_alpha = 0.2 })
hl.layer_rule({ name = "qs-osd-blur", match = { namespace = "^qs-volume-osd$" }, blur = true, ignore_alpha = 0.1 })

hl.curve("easeOutQuint", { type = "bezier", points = { { 0.23, 1 }, { 0.32, 1 } } })
hl.curve("macos_pop", { type = "bezier", points = { { 0.175, 0.885 }, { 0.32, 1.275 } } })
hl.curve("linear", { type = "bezier", points = { { 0, 0 }, { 1, 1 } } })
hl.curve("quick", { type = "bezier", points = { { 0.15, 0 }, { 0.1, 1 } } })

hl.animation({ leaf = "global", enabled = true, speed = 10, bezier = "default" })
hl.animation({ leaf = "border", enabled = true, speed = 5.39, bezier = "easeOutQuint" })
hl.animation({ leaf = "borderangle", enabled = true, speed = 15, bezier = "linear", style = "loop" })

hl.animation({ leaf = "windowsIn", enabled = true, speed = 4.1, bezier = "macos_pop", style = "popin 87%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 1.5, bezier = "easeOutQuint", style = "popin 87%" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 4, bezier = "easeOutQuint" })

hl.animation({ leaf = "fadeIn", enabled = true, speed = 2, bezier = "easeOutQuint" })
hl.animation({ leaf = "fadeOut", enabled = true, speed = 1.5, bezier = "quick" })
hl.animation({ leaf = "fade", enabled = true, speed = 3, bezier = "quick" })

hl.animation({ leaf = "layersIn", enabled = true, speed = 3, bezier = "macos_pop", style = "slide" })
hl.animation({ leaf = "layersOut", enabled = true, speed = 1.5, bezier = "quick", style = "slide" })
hl.animation({ leaf = "fadeLayersIn", enabled = true, speed = 1.8, bezier = "easeOutQuint" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 1.4, bezier = "quick" })

hl.animation({ leaf = "workspaces", enabled = true, speed = 4, bezier = "easeOutQuint", style = "slidefade" })
hl.animation({ leaf = "workspacesIn", enabled = true, speed = 4, bezier = "easeOutQuint", style = "slidefade" })
hl.animation({ leaf = "workspacesOut", enabled = true, speed = 4, bezier = "easeOutQuint", style = "slidefade" })

hl.config({
	dwindle = {
		preserve_split = true,
	},
})

hl.config({ master = { new_status = "slave", mfact = 0.43 } })
hl.config({
	misc = {
		force_default_wallpaper = 0,
		disable_hyprland_logo = true,
		focus_on_activate = true,
		mouse_move_focuses_monitor = true,
		-- VRR (monitor's FreeSync Premium, 48-170Hz on DP-3) for fullscreen windows only;
		-- always-on (1) can flicker/stutter the desktop on NVIDIA. 0 = off.
		vrr = 2,
	},
})

---------------
---- INPUT ----
---------------

hl.config({
	input = {
		kb_layout = "us",
		kb_options = "caps:swapescape",
		-- follow_mouse = 2 tried 2026-07-19, reverted the same day
		-- (too easy to lose focus). Hover-follows stays between tiled windows.
		follow_mouse = 1,
		-- Crossing between floating and tiled windows doesn't move focus, so the
		-- roaming cursor can't hover-steal it from a popup; a click still does.
		-- (2026-10-16: replaced a stay_focused rule on ALL floats, which froze
		-- input whenever a Steam toast or any other floating window was up.)
		float_switch_override_focus = 0,
		sensitivity = 0,
		numlock_by_default = true,
		touchpad = {
			natural_scroll = false,
		},
	},
})

-- Three-finger horizontal swipe → switch workspace. (The master-layout options
-- are configured above via hl.config({ master = ... }); an old stray `Master`
-- global table here did nothing and was removed 2026-07-13.)
hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })

hl.device({
	name = "sony-interactive-entertainment-dualsense-edge-wireless-controller-touchpad",
	enabled = false,
})

-- Kensington Pro Fit Ergo TB550 trackball (2026-09-17). Its own block so the
-- Dark Core keeps its settings — a global change would hit both.
--   accel_profile "flat": pointer acceleration assumes a mouse you pick up and
--     reposition. A ball never moves, so accel just makes fine work slippery.
--   on_button_down + BTN_MIDDLE(274): hold the wheel button and roll the ball
--     to scroll — better than the wheel for anything long. Moved off BTN_SIDE
--     (275) on 2026-10-04: that is the BACK thumb button, and libinput swallows
--     a scroll button, so back never reached any app. 275 back / 276 forward
--     are now free for codec (and browsers). Cost: no plain middle-click —
--     libinput owns a scroll button (a hold becomes scroll, a click arrives
--     only on release), so ~/scripts/system/trackball-mode.py switches this to
--     "no_scroll" while an app that needs the middle button is focused
--     (2026-10-16: Aseprite's middle-drag pan, Valheim's in-game middle).
--     If you change this block, change DEVICE in that script to match.
--   Buttons this device exposes: 272 left · 273 right · 274 middle · 275 side ·
--     276 extra (decoded from /sys/class/input/.../capabilities/key = 1f0000).
hl.device({
	name = "cx-tb550-2.4ghz-receiver-mouse",
	accel_profile = "flat",
	sensitivity = 0,
	scroll_method = "on_button_down",
	scroll_button = 274,
	natural_scroll = false,
})

----------------------
---- WORKSPACES ------
----------------------

hl.workspace_rule({ workspace = "1", monitor = "DP-3", default_name = "1:   Terminal", default = true })
hl.workspace_rule({ workspace = "2", monitor = "DP-3", default_name = "2:   Browser" })
hl.workspace_rule({ workspace = "3", monitor = "DP-3", default_name = "3:   Files" })
hl.workspace_rule({ workspace = "4", monitor = "DP-3", default_name = "4: 󰽉  Aseprite" })
hl.workspace_rule({ workspace = "5", monitor = "DP-3", default_name = "5:   Media" })
hl.workspace_rule({ workspace = "6", monitor = "DP-3", default_name = "6: 󰺯 NeoVim" })
hl.workspace_rule({ workspace = "7", monitor = "DP-3", default_name = "7:   Blender" })
hl.workspace_rule({ workspace = "8", monitor = "DP-3", default_name = "8: 󰓓  Steam" })
hl.workspace_rule({ workspace = "9", monitor = "DP-3", default_name = "9: 󰙯  Discord" })
hl.workspace_rule({ workspace = "10", monitor = "DP-3", default_name = "10: 󰠮  Notes" })
hl.workspace_rule({ workspace = "11", monitor = "HDMI-A-1", default_name = " 󰊴  Emulator", default = true })
-- CRT workspace pool: ws12–15 are also pinned to the CRT (HDMI-A-1), created on demand
-- (non-persistent, so empty slots don't clutter). This gives the CRT its own independent
-- pool — each emulator/game can get its own slot and be flipped between without touching
-- DP-3's 1–10. Switch: SUPER+ALT+1..5 · move window: SUPER+ALT+SHIFT+1..5 (see KEYBINDINGS).
-- Native monitor-pinning — no split-monitor-workspaces plugin (nothing to recompile on updates).
-- ws11 = Emulator, ws12 = Media are the two "category" screens the hyprule snap daemon
-- targets (see ~/.config/hyprule/snap.json); 13–20 are spare CRT screens — the CRT gets
-- a full 10-workspace pool (11–20), mirroring DP-3's 1–10, switched on SUPER+ALT+1..0.
hl.workspace_rule({ workspace = "12", monitor = "HDMI-A-1", default_name = " 󰝚  Media" })
hl.workspace_rule({ workspace = "13", monitor = "HDMI-A-1", default_name = " 󰡀  CRT 3" })
hl.workspace_rule({ workspace = "14", monitor = "HDMI-A-1", default_name = " 󰡀  CRT 4" })
hl.workspace_rule({ workspace = "15", monitor = "HDMI-A-1", default_name = " 󰡀  CRT 5" })
hl.workspace_rule({ workspace = "16", monitor = "HDMI-A-1", default_name = " 󰡀  CRT 6" })
hl.workspace_rule({ workspace = "17", monitor = "HDMI-A-1", default_name = " 󰡀  CRT 7" })
hl.workspace_rule({ workspace = "18", monitor = "HDMI-A-1", default_name = " 󰡀  CRT 8" })
hl.workspace_rule({ workspace = "19", monitor = "HDMI-A-1", default_name = " 󰡀  CRT 9" })
hl.workspace_rule({ workspace = "20", monitor = "HDMI-A-1", default_name = " 󰡀  CRT 10" })

-- ── Gamedev workspace (ws4 "Godot") ───────────────────────────────────────────
-- The gamedev Kitty (Neovim) and the Godot editor both live on workspace 4.

---------------------
---- KEYBINDINGS ----
---------------------

-- ── Core ──────────────────────────────────────────────────────────────────────
hl.bind(mainMod .. " + C", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + Q", hl.dsp.window.close())
hl.bind(mainMod .. " + SHIFT + Q", function()
	local w = hl.get_active_window()
	if w ~= nil then
		hl.dispatch(hl.dsp.exec_cmd("kill -9 " .. w.pid))
	end
end)
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen())
hl.bind(mainMod .. " + SHIFT + space", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + space", hl.dsp.exec_cmd(menu))
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + T", hl.dsp.layout("togglesplit"))
hl.bind(mainMod .. " + G", hl.dsp.exec_cmd(home .. "/scripts/godot/gamedev.sh"))
-- codec: the media player (github.com/CipherNovaa/codec)
hl.bind(mainMod .. " + M", hl.dsp.exec_cmd("codec"))
-- Config reload / exit
hl.bind(mainMod .. " + SHIFT + C", hl.dsp.exec_cmd("hyprctl reload"))
hl.bind(mainMod .. " + SHIFT + E", hl.dsp.exec_cmd("qs ipc call power toggle"))
-- Quickshell dispatcher widgets on SUPER+F9–F12 (media/power use the compat shims above).
-- Desktop has no battery, so its slot is dropped; F8 is free for the gamemode toggle
-- (below). On the laptop, F7=wallpaper, F8=battery, F9–F12 match this block.
hl.bind(mainMod .. " + F9", hl.dsp.exec_cmd("qs ipc call main handleCommand toggle network ''"))
hl.bind(mainMod .. " + F10", hl.dsp.exec_cmd("qs ipc call main handleCommand toggle calendar ''"))
hl.bind(mainMod .. " + F11", hl.dsp.exec_cmd("qs ipc call main handleCommand toggle focustime ''"))
hl.bind(mainMod .. " + F12", hl.dsp.exec_cmd("qs ipc call main handleCommand toggle music ''"))

-- ── Focus ─────────────────────────────────────────────────────────────────────
hl.bind(mainMod .. " + left", hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up", hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down", hl.dsp.focus({ direction = "down" }))
-- vim-style focus (hjkl)
hl.bind(mainMod .. " + H", hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + J", hl.dsp.focus({ direction = "down" }))
hl.bind(mainMod .. " + K", hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + L", hl.dsp.focus({ direction = "right" }))

-- ── Move windows ──────────────────────────────────────────────────────────────
hl.bind(mainMod .. " + SHIFT + left", hl.dsp.window.move({ direction = "left" }))
hl.bind(mainMod .. " + SHIFT + right", hl.dsp.window.move({ direction = "right" }))
hl.bind(mainMod .. " + SHIFT + up", hl.dsp.window.move({ direction = "up" }))
hl.bind(mainMod .. " + SHIFT + down", hl.dsp.window.move({ direction = "down" }))
-- vim-style move (hjkl)
hl.bind(mainMod .. " + SHIFT + H", hl.dsp.window.move({ direction = "left" }))
hl.bind(mainMod .. " + SHIFT + J", hl.dsp.window.move({ direction = "down" }))
hl.bind(mainMod .. " + SHIFT + K", hl.dsp.window.move({ direction = "up" }))
hl.bind(mainMod .. " + SHIFT + L", hl.dsp.window.move({ direction = "right" }))

-- ── Monitor focus ─────────────────────────────────────────────────────────────
hl.bind(mainMod .. " + comma", hl.dsp.focus({ monitor = "l" }))
hl.bind(mainMod .. " + period", hl.dsp.focus({ monitor = "r" }))
hl.bind(mainMod .. " + SHIFT + comma", hl.dsp.window.move({ monitor = "l" }))
hl.bind(mainMod .. " + SHIFT + period", hl.dsp.window.move({ monitor = "r" }))

-- ── Workspaces 1–10 + CRT ─────────────────────────────────────────────────────
for i = 1, 10 do
	local key = i % 10 -- 10 maps to key 0
	hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = i }))
	hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end
-- SUPER+grave is now the window selector (see Keyboard workflow). Moving a window to
-- the CRT (ws11) stays on SUPER+SHIFT+grave; the CRT is also reachable via SUPER+period.
hl.bind(mainMod .. " + SHIFT + grave", hl.dsp.window.move({ workspace = 11 }))

-- ── CRT workspace pool (ws11–20 on HDMI-A-1) ──────────────────────────────────
-- SUPER+ALT+1..0 focuses CRT ws11..20 (0 = ws20; focus follows onto the CRT; SUPER+comma
-- bounces back to DP-3). SUPER+ALT+SHIFT+1..0 throws the active window onto that CRT ws.
-- Bound on BOTH the number row AND the numpad (workspaces get switched on the numpad here),
-- mirroring the main SUPER+KP_* ws1–10 binds. The number row (SUPER+1..0) stays DP-3.
-- The CRT thus has a full 10-workspace pool, same as DP-3.
local crt_numpad = { "KP_End", "KP_Down", "KP_Next", "KP_Left", "KP_Begin",
                     "KP_Right", "KP_Home", "KP_Up", "KP_Prior", "KP_Insert" } -- numpad 1..0 (NumLock off)
for i = 1, 10 do
	local ws  = 10 + i
	local key = i % 10  -- 10 maps to number-row key "0"
	hl.bind(mainMod .. " + ALT + " .. key, hl.dsp.focus({ workspace = ws }))
	hl.bind(mainMod .. " + ALT + SHIFT + " .. key, hl.dsp.window.move({ workspace = ws }))
	hl.bind(mainMod .. " + ALT + " .. crt_numpad[i], hl.dsp.focus({ workspace = ws }))
	hl.bind(mainMod .. " + ALT + SHIFT + " .. crt_numpad[i], hl.dsp.window.move({ workspace = ws }))
end

-- ── Numpad workspace switching ────────────────────────────────────────────────
local numpad_keys = {
	"KP_End",
	"KP_Down",
	"KP_Next",
	"KP_Left",
	"KP_Begin",
	"KP_Right",
	"KP_Home",
	"KP_Up",
	"KP_Prior",
	"KP_Insert",
}
for i, key in ipairs(numpad_keys) do
	hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = i }))
	hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

-- ── Keyboard workflow ─────────────────────────────────────────────────────────
-- Window selector on SUPER+grave (backtick); SUPER+Tab is now the clipboard.
hl.bind(mainMod .. " + grave", hl.dsp.exec_cmd("rofi -show window -show-icons"))
-- Clipboard history (cliphist → rofi). Dual-bound to SUPER+Tab and SUPER+Menu (the
-- menu key right of R-Alt) so it works on both the laptop and the Unicomp Model M.
hl.bind(mainMod .. " + Tab", hl.dsp.exec_cmd("cliphist list | rofi -dmenu | cliphist decode | wl-copy"))
hl.bind(mainMod .. " + Menu", hl.dsp.exec_cmd("cliphist list | rofi -dmenu | cliphist decode | wl-copy"))
-- Open Spotify (spicetify watch + spotify-launcher).
hl.bind(mainMod .. " + S", hl.dsp.exec_cmd(home .. "/scripts/system/launch-spotify.sh"))
-- Obsidian (point this at your AppImage if you don't use the packaged one).
hl.bind(mainMod .. " + N", hl.dsp.exec_cmd("obsidian --ozone-platform=x11 --ozone-platform-hint=auto"))
-- Zen Browser (Firefox fork). Installed from the zen-browser-bin package on both
-- machines, so call its /usr/bin/zen-browser: Hyprland's PATH has no ~/.local/bin
-- on the laptop (greetd launches it directly, not via a login shell), which is why
-- a bare "zen" pointing at ~/.local/bin worked in a terminal but not from this bind.
-- Pressing this repeatedly opens an extra window each time (the running instance
-- handles the re-launch) — that's intended, same as any other app here.
-- App_id is "zen" (only the first-run import window reports "firefox"); the
-- ws-browser rule matches both and routes it to ws2.
hl.bind(mainMod .. " + B", hl.dsp.exec_cmd("zen-browser"))
-- Toggle the keybr typing scratchpad (special:keybr). Launches the dashboard +
-- practice browser on first use, then shows/hides them as an overlay. ws7 is
-- Blender now, so keybr no longer occupies a numbered workspace.
hl.bind(mainMod .. " + SHIFT + T", hl.dsp.exec_cmd(home .. "/scripts/keybr-toggle"))

-- Mouse workspace scroll
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))

-- ── Screenshot ────────────────────────────────────────────────────────────────
-- grim+slurp region -> clipboard (grim/slurp share the compositor coordinate space,
-- so region geometry is correct across HDMI-A-1 + DP-3). SUPER+Print annotates in satty.
hl.bind("+ Print", hl.dsp.exec_cmd("sh -c 'grim -g \"$(slurp)\" - | wl-copy'"))
hl.bind(mainMod .. " + Print", hl.dsp.exec_cmd("sh -c 'grim -g \"$(slurp)\" - | satty -f -'"))

-- ── Power / lock ──────────────────────────────────────────────────────────────
hl.bind("+ Pause", hl.dsp.exec_cmd(home .. "/scripts/system/lock-crt-sleep.sh"))
hl.bind(mainMod .. " + Pause", hl.dsp.exec_cmd("qs ipc call power toggle"))
hl.bind(mainMod .. " + SHIFT + X", hl.dsp.exec_cmd(home .. "/scripts/system/lock-crt-sleep.sh"))

-- ── Audio ─────────────────────────────────────────────────────────────────────
hl.bind("ALT + F1", hl.dsp.exec_cmd("pactl set-sink-volume @DEFAULT_SINK@ -5%"))
hl.bind("ALT + F2", hl.dsp.exec_cmd(home .. "/scripts/bar/vol-up.sh"))
hl.bind("ALT + F3", hl.dsp.exec_cmd("bash -c 'playerctl previous; ~/scripts/media/now-playing-notif.sh'"))
hl.bind("ALT + F4", hl.dsp.exec_cmd("bash -c 'playerctl next; ~/scripts/media/now-playing-notif.sh'"))

-- ──Laptop only Media Binds ─────────────────────────────────────────────────────────────────────
hl.bind("+ XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("+ XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("+ XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("+ XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })
hl.bind(
	"+ XF86AudioRaiseVolume",
	hl.dsp.exec_cmd(home .. "/scripts/bar/vol-up.sh"),
	{ locked = true, repeating = true }
)
hl.bind(
	"+ XF86AudioLowerVolume",
	hl.dsp.exec_cmd("pactl set-sink-volume @DEFAULT_SINK@ -5%"),
	{ locked = true, repeating = true }
)
hl.bind(
	"+ XF86AudioMute",
	hl.dsp.exec_cmd("pactl set-sink-mute @DEFAULT_SINK@ toggle"),
	{ locked = true, repeating = true }
)
hl.bind(
	"+ XF86AudioMicMute",
	hl.dsp.exec_cmd("pactl set-source-mute @DEFAULT_SOURCE@ toggle"),
	{ locked = true, repeating = true }
)

-- ── Utilities ─────────────────────────────────────────────────────────────────
hl.bind("+ XF86Calculator", hl.dsp.exec_cmd("qalculate-gtk"))
hl.bind(mainMod .. " + Home", hl.dsp.exec_cmd(home .. "/scripts/system/wallpaper-picker.sh"))
hl.bind(mainMod .. " + I", hl.dsp.exec_cmd("python3 " .. home .. "/scripts/keybinds/keybind_manager.py --rofi"))

-- ── Mouse drag / resize ───────────────────────────────────────────────────────
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- ── Gamemode toggle ───────────────────────────────────────────────────────────
-- Moved off SUPER+F10 (now the calendar widget) to SUPER+F8 (free on desktop).
hl.bind(mainMod .. " + F8", hl.dsp.exec_cmd(home .. "/scripts/system/gamemode-toggle.sh"))

-- ── Resize submap ─────────────────────────────────────────────────────────────
-- TODO: hl.dsp.submap() not yet in Lua API

---------------------------------
---- WINDOWS AND WORKSPACES -----
---------------------------------

-- Suppress maximize requests globally
hl.window_rule({
	name = "suppress-maximize-events",
	match = { class = ".*" },
	suppress_event = "maximize",
})

-- Bugfix
hl.window_rule({
	name = "fix-xwayland-drags",
	match = { class = "^$", title = "^$", xwayland = true, float = true, fullscreen = false, pin = false },
	no_focus = true,
})

-- Steam's notification toasts never take focus (they'd eat keystrokes mid-typing).
hl.window_rule({
	name = "steam-toasts-no-focus",
	match = { class = "^(steam)$", title = "^(notificationtoasts_.*)$" },
	no_focus = true,
})

-- ── Float rules ───────────────────────────────────────────────────────────────
hl.window_rule({ name = "float-calc", match = { class = "^(Qalculate-gtk|qalculate-gtk)$" }, float = true })
hl.window_rule({ name = "float-calculator", match = { title = "^(Calculator)$" }, float = true })
-- riptide bandwidth/speed monitor popup (opened by right-clicking the waybar network module)
hl.window_rule({ name = "float-riptide", match = { class = "^(riptide)$" }, float = true })
hl.window_rule({ name = "size-riptide", match = { class = "^(riptide)$" }, size = "900 600" })
hl.window_rule({ name = "center-riptide", match = { class = "^(riptide)$" }, center = true })

-- ── Workspace assignments ─────────────────────────────────────────────────────
-- Browser = Zen (Firefox fork). Normal launches report app_id "zen"; the
-- first-run/import window reports "firefox" (and vanilla Firefox, if ever run,
-- is "firefox"/"Firefox") — match all so the browser always lands on ws2.
hl.window_rule({ name = "ws-browser", match = { class = "^(zen|firefox|Firefox)$" }, workspace = 2 })
hl.window_rule({ name = "ws-files", match = { class = "^(Nemo|nemo|org.gnome.Nautilus)$" }, workspace = 3 })
hl.window_rule({ name = "ws-text", match = { class = "^(Xed|xed|gedit|mousepad)$" }, workspace = 4 })
hl.window_rule({ name = "ws-nvim", match = { class = "^(kitty-nvim)$" }, workspace = 6 })
hl.window_rule({ name = "ws-dolphin", match = { class = "^(org.kde.dolphin)$" }, workspace = 3 })
hl.window_rule({ name = "ws-steam", match = { class = "^(Steam|steam)$" }, workspace = 8 })
hl.window_rule({ name = "ws-discord", match = { class = "^(discord|Discord)$" }, workspace = 9 })
hl.window_rule({ name = "ws-yazi", match = { class = "^(yazi)$" }, workspace = 3 })
hl.window_rule({ match = { class = "gamescope", title = "The Typing of The Dead" }, monitor = "HDMI-A-1" })
hl.window_rule({ match = { class = "gamescope", title = "The Typing of The Dead" }, workspace = "11" })
hl.window_rule({ match = { class = "gamescope", title = "The Typing of The Dead" }, fullscreen = true })
hl.window_rule({ name = "ws-gamedev", match = { class = "^(gamedev)$" }, workspace = 4 })
hl.window_rule({ name = "ws-godot", match = { class = "^([Gg]odot)$" }, workspace = 4 })
hl.window_rule({ name = "ws-spotify", match = { class = "^(Spotify)$" }, workspace = 12 })
hl.window_rule({ name = "ws-spotify-mon", match = { class = "^(Spotify)$" }, monitor = "HDMI-A-1" })
hl.window_rule({ name = "ws-obsidian", match = { class = "^(obsidian)$" }, workspace = 10 })
hl.window_rule({ name = "ws-vesktop", match = { class = "^(vesktop)$" }, workspace = 9 })
hl.window_rule({ name = "ws-blender", match = { class = "^(blender)$" }, workspace = 7 })
hl.window_rule({ name = "ws-rpcs3", match = { class = "^(rpcs3)$" }, workspace = 11 })
-- CRT workspace
hl.window_rule({ name = "ws-rpcs3-mon", match = { class = "^(rpcs3)$" }, monitor = "HDMI-A-1" })
hl.window_rule({ name = "ws-crt-deadbeef", match = { class = "^(deadbeef|DeaDBeeF)$" }, workspace = 12 })
hl.window_rule({ name = "ws-crt-duckstation", match = { class = "^(org.duckstation.DuckStation|duckstation-qt|DuckStation)$" }, workspace = 11 })
hl.window_rule({ name = "ws-crt-pcsx2", match = { class = "^(pcsx2-qt|pcsx2|PCSX2)$" }, workspace = 11 })
hl.window_rule({ match = { class = "flycast" }, workspace = "11" })
hl.window_rule({ match = { class = "redream" }, workspace = "11" })
hl.window_rule({ name = "ws-crt-gzdoom", match = { class = "^([Gg]zdoom)$" }, workspace = 11 })
hl.window_rule({ name = "ws-crt-gzdoom-mon", match = { class = "^([Gg]zdoom)$" }, monitor = "HDMI-A-1" })
hl.window_rule({ name = "ws-crt-gzdoom-fs", match = { class = "^([Gg]zdoom)$" }, fullscreen = true })
hl.window_rule({ name = "ws-crt-zandronum", match = { class = "^([Zz]andronum)$" }, workspace = 11 })
hl.window_rule({ name = "ws-crt-zandronum-mon", match = { class = "^([Zz]andronum)$" }, monitor = "HDMI-A-1" })
hl.window_rule({ name = "ws-crt-zandronum-fs", match = { class = "^([Zz]andronum)$" }, fullscreen = true })
-- Armored Core 6 — CRT mode (class steam_app_1888160, fullscreen, NO gamescope):
-- pin to the CRT at MAP time so the game's exclusive-fullscreen buffer is created
-- at 1280x1024 (5:4) instead of grabbing the main monitor's 16:9 (moving it after
-- launch is too late — the buffer is already 16:9). Main/online mode runs under
-- gamescope (class "gamescope"), so these rules don't touch it.
hl.window_rule({ name = "ws-crt-ac6", match = { class = "^(steam_app_1888160)$" }, workspace = 11 })
hl.window_rule({ name = "ws-crt-ac6-mon", match = { class = "^(steam_app_1888160)$" }, monitor = "HDMI-A-1" })
hl.window_rule({ name = "ws-crt-ac6-fs", match = { class = "^(steam_app_1888160)$" }, fullscreen = true })
-- HELLDIVERS 2 (class steam_app_553850) — pin to the MAIN monitor DP-3 at MAP time.
-- Opposite of AC6: HD2 is a main-monitor game (2560x1440@141) but it opens on
-- whatever monitor is focused and grabs exclusive fullscreen there. When that's
-- the 1280x1024 CRT, the panel can't sync 2560x1440 → black screen. Force DP-3 at
-- map time so the fullscreen buffer is created at the right res on the main display.
hl.window_rule({ name = "hd2-mon", match = { class = "^(steam_app_553850)$" }, monitor = "DP-3" })
hl.window_rule({ name = "hd2-fs", match = { class = "^(steam_app_553850)$" }, fullscreen = true })
-- MGS4 (non-Steam shortcut steam_app_4070345827; steam_proton when started via proton
-- directly). Runs borderless (Sunny Side Up's RenderScale only works there), which maps
-- as a tiled window — force fullscreen at map time. Also covers the launcher.
-- Target display follows ~/.cache/mgs4-display ("crt" → CRT ws11, else DP-3), written by
-- ~/scripts/gaming/mgs4.sh (rofi CRT/Main picker) and reset to main when the game exits.
-- The title match also covers the Act 4 MGS1 flashback: mgs4.exe hands over to a separate
-- mgs1.exe ("METAL GEAR SOLID" window, same Proton app class), which restarts mgs4.exe when
-- it ends; both land on the same screen, fullscreen.
local mgs4_match = { class = "^(steam_app_4070345827|steam_proton)$", title = "^(METAL GEAR SOLID.*)$" }
local mgs4_crt = false
do
	local f = io.open(home .. "/.cache/mgs4-display", "r")
	if f then
		mgs4_crt = (f:read("l") or "") == "crt"
		f:close()
	end
end
if mgs4_crt then
	hl.window_rule({ name = "mgs4-ws", match = mgs4_match, workspace = 11 })
	hl.window_rule({ name = "mgs4-mon", match = mgs4_match, monitor = "HDMI-A-1" })
else
	hl.window_rule({ name = "mgs4-mon", match = mgs4_match, monitor = "DP-3" })
end
hl.window_rule({ name = "mgs4-fs", match = mgs4_match, fullscreen = true })
-- MGS4 keeps requesting activation; with focus_on_activate that yanks focus back from
-- whatever the mouse is over (e.g. the terminal on the other monitor). Ignore its requests.
hl.window_rule({ name = "mgs4-noactivate", match = mgs4_match, suppress_event = "activate activatefocus" })
-- ─── NEC Test Pattern - fullscreen on CRT ───────────────────────────────────────────────────────────────
hl.window_rule({ match = { class = "nec_test.exe", title = "NEC Monitor Test Window" }, workspace = "11" })
hl.window_rule({ match = { class = "nec_test.exe", title = "NEC Monitor Test Window" }, fullscreen = true })
-- ─── NEC Control Panel - floating on CRT ───────────────────────────────────────────────────────────────
hl.window_rule({ match = { class = "nec_test.exe", title = "NEC Monitor Test Control Panel" }, workspace = "11" })
hl.window_rule({ match = { class = "nec_test.exe", title = "NEC Monitor Test Control Panel" }, float = true })
hl.window_rule({ match = { class = "nec_test.exe", title = "NEC Monitor Test Control Panel" }, move = "512 426" })
-- ─── Crt apps ───────────────────────────────────────────────────────────────
-- Risk of Rain Returns
hl.window_rule({ match = { class = "steam_app_1337520" }, workspace = "11" })
hl.window_rule({ name = "ws-duckstation", match = { class = "^(org.duckstation.DuckStation)$" }, workspace = 11 })
hl.window_rule({
	name = "ws-duckstation-mon",
	match = { class = "^(org.duckstation.DuckStation)$" },
	monitor = "HDMI-A-1",
})
hl.window_rule({ name = "ws-pcsx2-qt", match = { class = "^(pcsx2-qt)$" }, workspace = 11 })
hl.window_rule({ name = "ws-pcsx2-qt-mon", match = { class = "^(pcsx2-qt)$" }, monitor = "HDMI-A-1" })
hl.window_rule({ name = "ws-aseprite", match = { class = "^(Aseprite)$" }, workspace = 4 })

-- ── keybr scratchpad (special:keybr) ──────────────────────────
-- master layout so the stats dashboard claims the top slot and the practice
-- browser fills the rest. ws7 is Blender now and uses the default layout.
hl.workspace_rule({
	workspace = "special:keybr",
	layout = "master",
	layout_opts = { orientation = "top" },
})

-- CRT: stacking layout so multiple apps can coexist and be selected by click
hl.workspace_rule({
	workspace = "11",
	layout = "master",
	layout_opts = { orientation = "left", mfact = 0.5 },
})

hl.window_rule({
	name = "keybr-dash",
	match = { class = "^(keybr-dash)$" },
	workspace = "special:keybr",
	monitor = "DP-3",
})
hl.window_rule({
	name = "keybr-practice",
	match = { class = "^(keybr-practice)$" },
	workspace = "special:keybr",
	monitor = "DP-3",
	tile = true,
})
