-- Preserve Num Lock across both compositor handoffs and full reboots. Keep
-- the existing enabled default until the user has made a saved choice: on a
-- cold boot the hardware LEDs initially read off before anything sets them.
local function inheritedNumlockState()
    local statePath = (os.getenv("HOME") or "") .. "/.local/state/mainstream/numlock"
    local saved = io.open(statePath, "r")
    if saved then
        local value = saved:read("*l")
        saved:close()
        if value == "1" then
            return true
        elseif value == "0" then
            return false
        end
    end

    return true
end

-- Cache numlock state - only re-read when file changes
local cachedNumlockState = nil
local cachedNumlockMtime = 0
local function getCachedNumlockState()
    local statePath = (os.getenv("HOME") or "") .. "/.local/state/mainstream/numlock"
    local attr = io.open(statePath, "r")
    if attr then
        attr:close()
        -- Check mtime via stat equivalent - use file size as proxy
        local f = io.open(statePath, "r")
        if f then
            local content = f:read("*a")
            f:close()
            if content ~= cachedNumlockState then
                cachedNumlockState = content
                return content == "1"
            end
            return cachedNumlockState == "1"
        end
    end
    return true
end

-- The layout the machine was set up with, read from the same file the login
-- screen reads: systemd-localed's X11 config, which the installer's keyboard
-- page writes, then the console keymap. Read at every start rather than copied
-- in once, so an update that refreshes this file cannot send the desktop back
-- to QWERTY. Settings → Keyboard writes its own list into custom/general.lua,
-- which is sourced after this file and wins.
local function systemKeyboardLayout()
    local conf = io.open("/etc/X11/xorg.conf.d/00-keyboard.conf", "r")
    if conf then
        local layout, variant
        for line in conf:lines() do
            layout = layout or line:match('Option%s+"XkbLayout"%s+"([^"]*)"')
            variant = variant or line:match('Option%s+"XkbVariant"%s+"([^"]*)"')
        end
        conf:close()
        -- localed writes XKB names here, one or a comma-separated list.
        if layout and layout:match("^[%a,]+$") then
            if not (variant and variant:match("^[%w_,%-]*$")) then
                variant = ""
            end
            return layout, variant
        end
    end

    local vconsole = io.open("/etc/vconsole.conf", "r")
    if vconsole then
        local keymap
        for line in vconsole:lines() do
            keymap = keymap or line:match("^KEYMAP=(.-)%s*$")
        end
        vconsole:close()
        if keymap then
            keymap = keymap:gsub('"', "")
            -- Console keymaps carry a variant after a dash and a hardware
            -- number at the end (fr-latin1, jp106); XKB knows neither.
            keymap = keymap:match("^([^-]+)") or keymap
            keymap = keymap:gsub("%d+$", "")
            if keymap:match("^%a%a+$") then
                return keymap, ""
            end
        end
    end

    return "us", ""
end

-- Cache keyboard layout - only re-read when files change
local cachedKbLayout, cachedKbVariant = nil, nil
local function getCachedKeyboardLayout()
    if cachedKbLayout then return cachedKbLayout, cachedKbVariant end
    cachedKbLayout, cachedKbVariant = systemKeyboardLayout()
    return cachedKbLayout, cachedKbVariant
end

local kbLayout, kbVariant = getCachedKeyboardLayout()

-- MONITOR CONFIG
hl.monitor({
    output = "",
    mode = "preferred",
    position = "auto",
    scale = 1
})

-- BEGIN gestures — rewritten by Settings → Mouse; change them there
hl.gesture({
    fingers = 3,
    direction = "horizontal",
    action = "workspace"
})
hl.gesture({
    fingers = 3,
    direction = "pinch",
    action = "float"
})
hl.gesture({
    fingers = 3,
    direction = "vertical",
    action = function()
        hl.dispatch(hl.dsp.global("quickshell:overviewWorkspacesToggle"))
    end
})
hl.gesture({
    fingers = 4,
    direction = "up",
    action = (function()
        local scrolloverview_open = false
        return function()
            local f = hl.plugin.scrolloverview.overview(scrolloverview_open and "off" or "on")
            if type(f) == "function" then
                f()
                scrolloverview_open = not scrolloverview_open
            end
        end
    end)()
})
hl.gesture({
    fingers = 4,
    direction = "down",
    action = function()
        hl.dispatch(hl.dsp.workspace.toggle_special("special"))
    end
})
-- END gestures

hl.config({
    gestures = {
        workspace_swipe_distance = 700,
        workspace_swipe_cancel_ratio = 0.2,
        workspace_swipe_min_speed_to_force = 5,
        workspace_swipe_direction_lock = true,
        workspace_swipe_direction_lock_threshold = 10,
        workspace_swipe_create_new = true
    },
    general = {
        -- Settings → Layouts panel rewrites this line via regex.
        layout = "dwindle",

        -- Gaps and border
        gaps_in = 4,
        gaps_out = 5,
        gaps_workspaces = 50,

        border_size = 4,

        col = {
            active_border = "rgba(0DB7D455)",
            inactive_border = "rgba(31313600)"
        },
        resize_on_border = true,

        no_focus_fallback = true,
        allow_tearing = true, -- This just allows the `immediate` window rule to work
        snap = {
            enabled = true,
            window_gap = 4,
            monitor_gap = 5,
            respect_gaps = true
        }
    },
    decoration = {
        -- 2 = circle, higher = squircle, 4 = very obvious squircle
        -- We use a slightly higher power here to make the rounding feel more continuous
        rounding_power = 2,
        rounding = 10,

        blur = {
            enabled = true,
            xray = true,
            special = false,
            new_optimizations = true,
            size = 10,
            passes = 3,
            noise = 0,
            contrast = 0.89,
            vibrancy = 0.5,
            vibrancy_darkness = 0.5,
            popups = true,
            popups_ignorealpha = 0.6,
            input_methods = true,
            input_methods_ignorealpha = 0.8
        },
        shadow = {
            enabled = true,
            range = 20,
            offset = {0, 2},
            render_power = 4,
            color = "rgba(00000024)"
        },
        -- Dim
        dim_inactive = true,
        dim_strength = 0.05,
        dim_special = 0.2
    },
    animations = {
        enabled = true
    },
    dwindle = {
        preserve_split = true,
        smart_split = false,
        smart_resizing = false
        -- precise_mouse_move = true,
    },
})
-- Animations live in a profile file so the set can be swapped whole: curves
-- and targets belong together, and half of one profile over half of another
-- is a window easing against a curve tuned for something else. The name in
-- animations/active picks the file; anything missing or unreadable falls
-- back to the stock profile. Read from disk on every reload rather than
-- required, so a change shows without restarting.
local animationsDir = os.getenv("HOME") .. "/.config/hypr/hyprland/animations/"
local animationProfile = "expressive"
local activeFile = io.open(animationsDir .. "active", "r")
if activeFile then
    local line = activeFile:read("*l")
    activeFile:close()
    if line then
        line = line:match("^%s*([%w_%-]+)%s*$")
        if line then animationProfile = line end
    end
end

-- A profile is meant to be data: a set of curves and the targets they drive.
-- It can arrive inside a theme file downloaded from anywhere, and dofile would
-- run it with the whole standard library within reach — os.execute included.
-- It is loaded into an environment holding only the two calls a profile has
-- any business making, and only as source, never as bytecode. A profile that
-- reaches for anything else finds nil and fails, which is the fallback's cue.
local function loadAnimationProfile(file)
    local fh = io.open(file, "r")
    if not fh then return false end
    local src = fh:read("*a")
    fh:close()
    if not src then return false end
    local chunk = load(src, "@" .. file, "t",
        { hl = { curve = hl.curve, animation = hl.animation } })
    if not chunk then return false end
    return (pcall(chunk))
end

-- Lazy-load animation profile: only reload when active file changes
local lastLoadedProfile = ""
local function maybeReloadAnimationProfile()
    local activeFile = io.open(animationsDir .. "active", "r")
    local currentProfile = animationProfile
    if activeFile then
        local line = activeFile:read("*l")
        activeFile:close()
        if line then
            line = line:match("^%s*([%w_%-]+)%s*$")
            if line then currentProfile = line end
        end
    end
    if currentProfile ~= lastLoadedProfile then
        if not loadAnimationProfile(animationsDir .. currentProfile .. ".lua") then
            loadAnimationProfile(animationsDir .. "expressive.lua")
        end
        lastLoadedProfile = currentProfile
    end
end

-- Initial load
maybeReloadAnimationProfile()

-- Reload only when animations/active file changes
hl.on("config.reloaded", maybeReloadAnimationProfile)

hl.config({
    input = {
        kb_layout = kbLayout,
        kb_variant = kbVariant,
        numlock_by_default = getCachedNumlockState(),
        repeat_delay = 250,
        repeat_rate = 35,

        follow_mouse = 1,
        off_window_axis_events = 2,

        touchpad = {
            -- natural_scroll and disable_while_typing live in custom/env.lua
            -- (Settings → Mouse writes them there); a duplicate here would win
            -- on every hyprctl reload.
            clickfinger_behavior = true,
            scroll_factor = 0.7
        }
    },

    misc = {
        disable_hyprland_logo = true,
        disable_splash_rendering = true,
        vrr = 0,
        mouse_move_enables_dpms = true,
        key_press_enables_dpms = true,
        animate_manual_resizes = false,
        animate_mouse_windowdragging = false,
        enable_swallow = false,
        swallow_regex = "(foot|kitty|allacritty|Alacritty)",
        on_focus_under_fullscreen = 2,
        allow_session_lock_restore = true,
        session_lock_xray = true,
        initial_workspace_tracking = false,
        focus_on_activate = false,
        render_unfocused_fps = 60
    },

    binds = {
        scroll_event_delay = 0,
        hide_special_on_workspace_change = true
    },

    cursor = {
        default_monitor = "DP-1",
        zoom_factor = 1,
        zoom_rigid = false,
        zoom_disable_aa = true,
        hotspot_padding = 1
    },

    -- 10-bit (bitdepth=10 in monitors.lua): the old layer-surface modeset
    -- flicker was fixed upstream in 0.55.1 (#14397, "don't modeset on reserved changes").

    xwayland = {
        force_zero_scaling = true
    }
})