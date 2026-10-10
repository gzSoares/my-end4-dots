-- ######## Window rules ########

-- Disable blur for xwayland context menus
hl.window_rule({match = {class = ".*", title = ".*"}, no_blur = true })

--spotlight-blur
hl.layer_rule({
    name = "spotlight-blur",
    match = { namespace = "macos:spotlight" },
    blur = true,
    ignore_alpha = 0.6,
})

-- Floating dialogs (consolidated: center + float + size where applicable)
hl.window_rule({match = {title = "^(Open File)(.*)$" },                      center = true, float = true})
hl.window_rule({match = {title = "^(Select a File)(.*)$" },                  center = true, float = true})
hl.window_rule({match = {title = "^(Choose wallpaper)(.*)$" },               center = true, float = true, size = {"(monitor_w*0.60)", "(monitor_h*0.65)"} })
hl.window_rule({match = {title = "^(Open Folder)(.*)$" },                    center = true, float = true})
hl.window_rule({match = {title = "^(Save As)(.*)$" },                        center = true, float = true})
hl.window_rule({match = {title = "^(Library)(.*)$" },                        center = true, float = true})
hl.window_rule({match = {title = "^(File Upload)(.*)$" },                    center = true, float = true})
hl.window_rule({match = {title = "^(.*)(wants to save)$" },                  center = true, float = true})
hl.window_rule({match = {title = "^(.*)(wants to open)$" },                  center = true, float = true})
hl.window_rule({match = {title = "^(Choose Files)(.*)$" },                   center = true})

-- Keep hidden games rendering — alt-tabbing must not freeze multiplayer
-- ticks or starve OBS game capture (rate: misc:render_unfocused_fps).
hl.window_rule({match = {class = "^(steam_app_.*)$" },                       render_unfocused = true})

-- Floating apps with size/center (consolidated per class)
hl.window_rule({match = {class = "^(blueberry\\.py)$" },                     float = true})
hl.window_rule({match = {class = "^(guifetch)$" },                           float = true}) -- FlafyDev/guifetch
hl.window_rule({match = {class = "^(pavucontrol|org.pulseaudio.pavucontrol)$" }, float = true, size = {"(monitor_w*0.45)", "(monitor_h*0.45)"}, center = true})
hl.window_rule({match = {class = "^(nm-connection-editor)$" },               float = true, size = {"(monitor_w*0.45)", "(monitor_h*0.45)"}, center = true})
hl.window_rule({match = {class = ".*plasmawindowed.*" },                     float = true})
hl.window_rule({match = {class = "kcm_.*" },                                  float = true})
hl.window_rule({match = {class = ".*bluedevilwizard" },                      float = true})
hl.window_rule({match = {title = ".*Welcome" },                              float = true})
hl.window_rule({match = {title = "^(Mainstream Settings)$" },               float = true})
hl.window_rule({match = {class = "org.freedesktop.impl.portal.desktop.kde" }, float = true, size = {"(monitor_w*0.60)", "(monitor_h*0.65)"} })
hl.window_rule({match = {class = "^(Zotero)$" },                             float = true, size = {"(monitor_w*0.45)", "(monitor_h*0.45)"} })
hl.window_rule({match = {class = "^(io.github.diegopvlk.Cine)$" },           float = true, size = {"(monitor_w*0.45)", "(monitor_h*0.45)"}, center = true})
hl.window_rule({match = {class = "^(org.kde.gwenview)$" },                   float = true, size = {"(monitor_w*0.25)", "(monitor_h*0.50)"}, center = true})
hl.window_rule({match = {class = "^(scrcpy)$" },                             float = true, size = {"(monitor_w*0.18)", "(monitor_h*0.45)"}, move = {"(monitor_w*0.81)", "(monitor_h*0.54)"} })
hl.window_rule({match = {class = "^(mpv)$" },                                float = true, size = {"(monitor_w*0.25)", "(monitor_h*0.50)"}, center = true})
hl.window_rule({match = {class = "^(org.gnome.Calculator)$" },               float = true, size = {"(monitor_w*0.18)", "(monitor_h*0.45)"}, move = {"(monitor_w*0.81)", "(monitor_h*0.54)"}, pin = true})
hl.window_rule({match = {class = "^(org.quickshell)$" },                     float = true})
hl.window_rule({match = {class = "^(.*)(com.interversehq.qView)$" },        float = true, center = true, size = {"(monitor_w*0.45)", "(monitor_h*0.45)"} })

-- Move
-- kde-material-you-colors spawns a window when changing dark/light theme. This is to make sure it doesn't interfere at all.
hl.window_rule({match = {class = "^(plasma-changeicons)$" }, float = true, no_initial_focus = true, move = {999999, 999999}})
-- stupid dolphin copy
hl.window_rule({match = {title = "^(Copying — Dolphin)$" }, move = {40, 80}})

-- Tiling
hl.window_rule({match = {class = "^dev\\.warp\\.Warp$" }, tile = true})

-- Picture-in-Picture
hl.window_rule({match = {title = "^([Pp]icture[-\\s]?[Ii]n[-\\s]?[Pp]icture)(.*)$" }, float = true, keep_aspect_ratio = true, move = {"(monitor_w*0.73)", "(monitor_h*0.72)"}, size = {"(monitor_w*0.25)", "(monitor_h*0.25)"}, pin = true})

-- Screen sharing
hl.window_rule({match = {title = ".*is sharing (a window|your screen).*" }, float = true, pin = true, move = {"(monitor_w*.5-window_w*.5)", "(monitor_h-window_h-12)"} })

-- --- Tearing ---
hl.window_rule({match = {title = ".*\\.exe" }, immediate = true})
hl.window_rule({match = {title = ".*minecraft.*" }, immediate = true})
hl.window_rule({match = {class = "^(steam_app).*" }, immediate = true})

-- No shadow for tiled windows
hl.window_rule({match = {float = 0 }, no_shadow = true})

-- ######## Workspace rules ########
hl.workspace_rule({ workspace = "special:special", gaps_out = 30 })

-- ######## Layer rules ########
hl.layer_rule({ match = { namespace = ".*" }, xray = true})
hl.layer_rule({ match = { namespace = "(walker|selection|overview|anyrun|indicator.*|osk|hyprpicker|noanim)" }, no_anim = true})
hl.layer_rule({ match = { namespace = "gtk-layer-shell" }, blur = true, ignore_alpha = 0})
hl.layer_rule({ match = { namespace = "launcher" }, blur = true, ignore_alpha = 0.5})
hl.layer_rule({ match = { namespace = "notifications" }, blur = true, ignore_alpha = 0.69})
hl.layer_rule({ match = { namespace = "logout_dialog" }, blur = true}) -- wlogout

-- ags
hl.layer_rule({ match = { namespace = "sideleft.*" }, animation = "slide left", blur = true, ignore_alpha = 0.6})
hl.layer_rule({ match = { namespace = "sideright.*" }, animation = "slide right", blur = true, ignore_alpha = 0.6})
hl.layer_rule({ match = { namespace = "(session|bar|barcorner|dock|indicator|overview|cheatsheet|sideright|sideleft|osk)[0-9]*" }, blur = true, ignore_alpha = 0.6})

-- Quickshell: illogical-impulse
hl.layer_rule({ match = { namespace = "quickshell:.*" }, blur_popups = true, blur = true, ignore_alpha = 0.79})
-- Blur stops at a fixed alpha, so with the shared 0.79 the bar loses its blur
-- between two neighboring steps of its own transparency slider, and where that
-- lands moves with the interface's transparency setting — around 7% of the
-- slider on a wallpaper the automatic setting reads as fairly vibrant. Held low
-- enough that the slider is smooth through the range anyone uses, and above the
-- shadow these surfaces cast. Their layer is larger than the shape drawn on it:
-- the rest is the room the shadow falls in, and a floor under the shadow's own
-- alpha sends the blur through that too, ringing every surface in a frosted
-- halo. The dock and sidebars ride the same floor, because the shared threshold
-- above sits inside the reach of their stock alpha — the automatic transparency
-- can land them a hair under it on a dark wallpaper, and a surface should not
-- lose its blur to settings nobody touched.
hl.layer_rule({ match = { namespace = "quickshell:(bar|verticalBar|dock[A-Za-z]*|sidebarLeft|sidebarRight)" }, ignore_alpha = 0.35})
-- The dock is lifted above the overview's dim while the overview is open, so
-- it is the one blurred surface here whose blur edge is ever seen against
-- anything but the wallpaper. Blurring the wallpaper alone punches a bright,
-- stepped outline through the dim, because that edge is decided per pixel with
-- nothing in between. Reading what is actually behind it puts the dim on both
-- sides of the line, and the line has nothing left to show.
hl.layer_rule({ match = { namespace = "quickshell:dock[A-Za-z]*" }, xray = false})
hl.layer_rule({ match = { namespace = "quickshell:bar" }, animation = "slide", order = 10 })
hl.layer_rule({ match = { namespace = "quickshell:verticalBar" }, animation = "slide", order = 10 })
hl.layer_rule({ match = { namespace = "quickshell:actionCenter" }, no_anim = true})
hl.layer_rule({ match = { namespace = "quickshell:cheatsheet" }, animation = "slide bottom"})
hl.layer_rule({ match = { namespace = "quickshell:dock" }, animation = "slide bottom"})
hl.layer_rule({ match = { namespace = "quickshell:dockTop" }, animation = "slide top"})
hl.layer_rule({ match = { namespace = "quickshell:dockLeft" }, animation = "slide left"})
hl.layer_rule({ match = { namespace = "quickshell:dockRight" }, animation = "slide right"})
hl.layer_rule({ match = { namespace = "quickshell:screenCorners" }, animation = "popin 120%"})
hl.layer_rule({ match = { namespace = "quickshell:lockWindowPusher" }, no_anim = true})
hl.layer_rule({ match = { namespace = "quickshell:notificationPopup" }, animation = "fade"})
hl.layer_rule({ match = { namespace = "quickshell:overlay" }, no_anim = true, ignore_alpha = 1})
hl.layer_rule({ match = { namespace = "quickshell:overview" }, no_anim = true})
hl.layer_rule({ match = { namespace = "quickshell:osk" }, animation = "slide bottom", order = -1})
hl.layer_rule({ match = { namespace = "quickshell:polkit" }, no_anim = true})
hl.layer_rule({ match = { namespace = "quickshell:popup" }, xray = false, ignore_alpha = 1}) -- No weird color for bar tooltips
hl.layer_rule({ match = { namespace = "quickshell:mediaControls" }, ignore_alpha = 1}) -- Same as above
hl.layer_rule({ match = { namespace = "quickshell:reloadPopup" }, animation = "slide"})
hl.layer_rule({ match = { namespace = "quickshell:regionSelector" }, no_anim = true})
hl.layer_rule({ match = { namespace = "quickshell:screenshot" }, no_anim = true})
hl.layer_rule({ match = { namespace = "quickshell:session" }, blur = true, no_anim = true, ignore_alpha = 0})
-- Unnamed direction so the slide follows whichever edge the panel anchored to,
-- the way the vertical bar below is served on either side by one rule.
hl.layer_rule({ match = { namespace = "quickshell:sidebarRight" }, animation = "slide"})
hl.layer_rule({ match = { namespace = "quickshell:sidebarLeft" }, animation = "slide"})

-- Quickshell: waffles
hl.layer_rule({ match = { namespace = "quickshell:wallpaperSelector" }, animation = "slide top"})
hl.layer_rule({ match = { namespace = "quickshell:(wNotificationCenter|wOnScreenDisplay|wStartMenu)" }, no_anim = true})
hl.layer_rule({ match = { namespace = "quickshell:wTaskView" }, ignore_alpha = 0, no_anim = true})

-- Launchers need to be FAST
hl.layer_rule({ match = { namespace = "gtk4-layer-shell" }, no_anim = true})

-- The settings page keeps its window rules in a file of its own, loaded after
-- everything above so a rule made there outranks a shipped one for the same
-- window. Absent or broken, nothing happens.
pcall(dofile, os.getenv("HOME") .. "/.config/hypr/hyprland/userrules.lua")