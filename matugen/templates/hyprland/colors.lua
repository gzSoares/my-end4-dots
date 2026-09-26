hl.config({
    general = {
        col = {
            active_border   = "rgba({{colors.primary.default.hex_stripped}}EE)",
            inactive_border = "rgba({{colors.outline_variant.default.hex_stripped}}55)",
        },
    },
    decoration = {
        shadow = {
            enabled      = true,
            color        = "rgba({{colors.primary.default.hex_stripped}}66)",
            range        = 8,
            render_power = 3,
        },
    },
    misc = {
        background_color = "rgba({{colors.surface.dark.hex_stripped}}FF)",
    },
})

hl.window_rule({
    match        = { pin = 1 },
    border_color = "rgba({{colors.primary.default.hex_stripped}}FF) rgba({{colors.secondary.default.hex_stripped}}FF) rgba({{colors.tertiary.default.hex_stripped}}FF) rgba({{colors.primary.default.hex_stripped}}FF)",
})
