hl.config({ input = { kb_layout = "br", kb_variant = "" } })

-- Blur: size 14 / passes 3 was very expensive at 2560x1440@170 (every blurred
-- surface re-samples the background dozens of times per pixel, 170x a second).
-- size 7 / passes 2 looks almost the same and costs a fraction of it.
hl.config({ decoration = { blur = { size = 7, passes = 2 } } })

hl.config({
  render = {
    cm_auto_hdr = 0,
  },
})
