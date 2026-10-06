-- Put extra environment variables here
-- https://wiki.hypr.land/Configuring/Environment-variables/

-- Input method (uncomment as needed)
-- See https://fcitx-im.org/wiki/Using_Fcitx_5_on_Wayland
-- hl.env("QT_IM_MODULE", "fcitx")
-- hl.env("XMODIFIERS", "@im=fcitx")
-- hl.env("SDL_IM_MODULE", "fcitx")
-- hl.env("GLFW_IM_MODULE", "ibus")
-- hl.env("INPUT_METHOD", "fcitx")

-- Wayland
-- Tearing
-- hl.env("WLR_DRM_NO_ATOMIC", "1")
-- hl.env("WLR_NO_HARDWARE_CURSORS", "1")

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

hl.env("LIBVA_DRIVER_NAME", "nvidia")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
hl.env("WLR_NO_HARDWARE_CURSORS", "1")
hl.env("GEMINI_API_KEY", "AQ.Ab8RN6IObVo6AcZYxvdHu4aFZUiWOPctQl0AcLVOKMwmpvNdqw")
hl.env("DEEPSEEK_API_KEY", "sk-595760eb6f2b4f64b0227cdf5866de8e")
hl.env("OPENROUTER_API_KEY", "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")
hl.env("HERMES_API_KEY", "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")
hl.env("HERMES_URL", "http://127.0.0.1:8642")
hl.env("HERMES_MODEL", "hermes-agent")
