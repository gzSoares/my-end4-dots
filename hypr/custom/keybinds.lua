-- Add your own keybinds here.
-- https://wiki.hypr.land/Configuring/Binds/

-- Examples — uncomment and tweak as needed. The fork's defaults are in
-- hyprland/keybinds.lua and these run after, so anything here overrides.
--
-- hl.bind("SUPER + Return", hl.dsp.exec_cmd(terminal), {description = "Terminal"})
-- hl.bind("SUPER + T", hl.dsp.exec_cmd(terminal))
-- hl.bind("CTRL + ALT + T", hl.dsp.exec_cmd(terminal))
-- hl.bind("SUPER + E", hl.dsp.exec_cmd(fileManager), {description = "File manager"})
-- hl.bind("SUPER + B", hl.dsp.exec_cmd(browser), {description = "Browser"})
-- hl.bind("SUPER + C", hl.dsp.exec_cmd(codeEditor), {description = "Code editor"})
-- hl.bind("SUPER + X", hl.dsp.exec_cmd(textEditor), {description = "Text editor"})
-- hl.bind("CTRL + SUPER + V", hl.dsp.exec_cmd(volumeMixer), {description = "Volume mixer"})
-- hl.bind("SUPER + I", hl.dsp.exec_cmd(settingsApp), {description = "Settings app"})
-- hl.bind("CTRL + SHIFT + Escape", hl.dsp.exec_cmd(taskManager), {description = "Task manager"})

-- qs_keybind_capture — capture submap used by the settings keybinds editor; do not remove
hl.define_submap("qs_keybind_capture", function()
    hl.bind("Escape", hl.dsp.submap("reset"))
end)

--#/# bind = CTRL + SUPER + Scroll ↑/↓,, -- Focus window left/right
hl.bind("SUPER + CTRL + t", hl.dsp.global("quickshell:wallpaperSelectorToggle"))

hl.bind("SUPER + V", hl.dsp.exec_cmd("qs -c ii ipc call spotlightMode openMode clipboard"))
hl.bind("SUPER + Z", hl.dsp.exec_cmd("qs -c ii ipc call spotlightMode openMode apps"))

-- qs_keybind_capture — capture submap used by the settings keybinds editor; do not remove
hl.define_submap("qs_keybind_capture", function()
    hl.bind("Escape", hl.dsp.submap("reset"))
end)
