hl.config({
    general = {
        col = {
            active_border   = "rgba(83d2e4EE)",
            inactive_border = "rgba(3f484b55)",
        },
    },
    decoration = {
        shadow = {
            enabled      = true,
            color        = "rgba(83d2e466)",
            range        = 8,
            render_power = 3,
        },
    },
    misc = {
        background_color = "rgba(0e1416FF)",
    },
})

hl.window_rule({
    match        = { pin = 1 },
    border_color = "rgba(83d2e4FF) rgba(b2cbd1FF) rgba(bdc5ebFF) rgba(83d2e4FF)",
})
