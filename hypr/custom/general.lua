-- Blur: size 14 / passes 3 was very expensive at 2560x1440@170 (every blurred
-- surface re-samples the background dozens of times per pixel, 170x a second).
-- size 7 / passes 2 looks almost the same and costs a fraction of it.
hl.config({ decoration = { blur = { size = 7, passes = 2 } } })

hl.config({
  render = {
    cm_auto_hdr = 0,
    -- 2: only fullscreen windows that declare themselves as games.
    direct_scanout = 2,
    -- Trial: meant for weaker GPUs, like the Iris Xe at 1440p@170. Experimental.
    new_render_scheduling = true,
  },
})

-- VRR in fullscreen only. Takes effect once FreeSync is on in the M27Q's menu.
hl.config({ misc = { vrr = 2 } })

-- BEGIN keyboard-layouts (managed by Settings)
hl.config({ input = { kb_layout = "br", kb_variant = "" } })
-- END keyboard-layouts
