-- Custom window / layer / workspace rules.
-- Window: https://wiki.hypr.land/Configuring/Window-Rules/
-- Workspace: https://wiki.hypr.land/Configuring/Workspace-Rules/

-- ######## Layer rules ########

-- ######## Window rules ########

-- GTK file picker / portal chooser
hl.window_rule({ match = { class = "xdg-desktop-portal-gtk" }, float = true, center = true, size = "900 600" })

-- Login image picker (kdialog)
hl.window_rule({ match = { title = "^Choose login image$" }, float = true, center = true, pin = true, size = "900 600" })

-- Common file dialog titles
hl.window_rule({ match = { title = "^Open File$" }, float = true })
hl.window_rule({ match = { title = "^Open Folder$" }, float = true })
hl.window_rule({ match = { title = "^Save File$" }, float = true })
hl.window_rule({ match = { title = "^Save As$" }, float = true })

-- Satty screenshot annotator
hl.window_rule({ match = { class = "^(com\\.gabm\\.satty)$" }, float = true, center = true })
hl.window_rule({ match = { class = "^(satty)$" }, float = true, center = true })

-- Nautilus when its title still reads the bare app id (early-load state)
hl.window_rule({ match = { class = "^(org\\.gnome\\.Nautilus)$", title = "^(org\\.gnome\\.Nautilus)$" }, float = true, center = true })

-- Calamares installer
hl.window_rule({
    name = "calamares-by-class",
    match = { class = "^(io.calamares.calamares)$" },
    float = true,
    suppress_event = "fullscreen maximize",
    size = "1500 800",
    center = true,
})

--spotlight-blur
hl.layer_rule({
    name = "spotlight-blur",
    match = { namespace = "macos:spotlight" },
    blur = true,
    ignore_alpha = 0.6,
})

hl.layer_rule({
    name = "overview-dim-blur",
    match = { namespace = "quickshell:overviewDim" },
    blur = true,
    ignore_alpha = 0.6,
})

hl.layer_rule({
    name = "quickshell-blur-threshold",
    match = { namespace = "quickshell:.*" },
    ignore_alpha = 0.3,
})

-- Phone tab (scrcpy windows the left sidebar embeds or opens)
hl.window_rule({match = {title = "^(ii-phone-unlock)$" },                    float = true})
-- Apps opened from the Phone tab (Android Apps): one scrcpy window per app,
-- floating at the the same size as the phone mirror (373x808 px).
hl.window_rule({match = {title = "^(ii-phone-app-)(.*)$" },                  float = true})
hl.window_rule({match = {title = "^(ii-phone-app-)(.*)$" },                  size = {"373", "808"}})
-- Phone mirror opened as its own window (when the sidebar mirror is off).
hl.window_rule({match = {title = "^(ii-phone-mirror-)(.*)$" },               float = true})
hl.window_rule({match = {title = "^(ii-phone-mirror-)(.*)$" },               size = {"373", "808"}})
-- The scrcpy window the Phone sidebar embeds. It is a real window kept exactly
-- under a cut-out in the panel's input region, which is what makes touches and
-- the keyboard reach the phone natively; the panel paints the captured picture
-- over it, so it is never actually seen and every decoration below would be
-- work thrown away. It opens on a hidden special workspace and the shell moves
-- it into place, so it never flashes through the tiling layout on the way in.
-- Off the monitor rather than on a special workspace: `silent` is not read in
-- any spelling the Lua parser accepts without complaint, so parking it there
-- pulled an empty scratchpad into view — overlay and all — on every start. The
-- offset is relative to the monitor and is not clamped, so nothing is ever seen
-- until the shell moves it under the panel's cut-out.
hl.window_rule({match = {title = "^(ii-phone-embed-)(.*)$" },               move = "9000 9000"})
hl.window_rule({match = {title = "^(ii-phone-embed-)(.*)$" },               float = true})
hl.window_rule({match = {title = "^(ii-phone-embed-)(.*)$" },               no_initial_focus = true})
hl.window_rule({match = {title = "^(ii-phone-embed-)(.*)$" },               no_anim = true})
hl.window_rule({match = {title = "^(ii-phone-embed-)(.*)$" },               no_blur = true})
hl.window_rule({match = {title = "^(ii-phone-embed-)(.*)$" },               no_shadow = true})

-- The screenshot editor is a translucent window: let the compositor blur behind it like the shell's panels (the rule above turns blur off for every window)
hl.window_rule({match = {class = "^(org.quickshell)$", title = "^(Screenshot editor)$" },  no_blur = false})
hl.window_rule({match = {class = "^(org.quickshell)$", title = "^(Screen recorder)$" },    no_blur = false})
hl.window_rule({match = {class = "^(org.quickshell)$", title = "^(Video editor)$" },       no_blur = false})
