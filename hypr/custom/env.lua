-- Put extra environment variables here
-- https://wiki.hypr.land/Configuring/Environment-variables/

-- Input method (uncomment as needed)
-- See https://fcitx-im.org/wiki/Using_Fcitx_5_on_Wayland
-- hl.env("QT_IM_MODULE", "fcitx")
-- hl.env("XMODIFIERS", "@im=fcitx")
-- hl.env("SDL_IM_MODULE", "fcitx")
-- hl.env("GLFW_IM_MODULE", "ibus")
-- hl.env("INPUT_METHOD", "fcitx")

-- Editor
-- hl.env("EDITOR", "vim")

-- Input / mouse / touchpad
-- Settings → Mouse panel rewrites these via Python regex; keep the shape
-- (one key per line, touchpad as a nested table).
hl.config({
    input = {
        sensitivity = 0.0,
        left_handed = false,
        accel_profile = "adaptive",
        natural_scroll = false,
        touchpad = {
            natural_scroll = true,
        },
    },
})

hl.env("XDG_SESSION_TYPE", "wayland")

-- Removed (hybrid Intel + MX450 laptop):
--   LIBVA_DRIVER_NAME=nvidia and __GLX_VENDOR_LIBRARY_NAME=nvidia forced every
--   app to render/decode video on the MX450 while the screen is driven by the
--   Intel GPU, so each frame had to be copied between GPUs (and the dGPU never
--   slept). Use `prime-run <app>` for the apps that should run on the NVIDIA.
--   WLR_NO_HARDWARE_CURSORS is a wlroots variable; Hyprland ignores it.

-- Hermes (non-secret settings)
hl.env("HERMES_URL", "http://127.0.0.1:8642")
hl.env("HERMES_MODEL", "hermes-agent")

-- API keys live in custom/secrets.lua, which is NOT committed (see .gitignore).
local ok, err = pcall(require, "custom.secrets")
if not ok and not tostring(err):match("module .- not found") then
    print("[custom/env.lua] custom/secrets.lua errored: " .. tostring(err))
end
