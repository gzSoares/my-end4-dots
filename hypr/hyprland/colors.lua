hl.config({
    general = {
        col = {
            active_border   = "rgba(d8c0ccEE)",
            inactive_border = "rgba(49464755)",
        },
    },
    decoration = {
        shadow = {
            enabled      = true,
            color        = "rgba(d8c0cc66)",
            range        = 8,
            render_power = 3,
        },
    },
    misc = {
        background_color = "rgba(151314FF)",
    },
})

hl.window_rule({
    match        = { pin = 1 },
    border_color = "rgba(d8c0ccFF) rgba(d3c2c9FF) rgba(debeceFF) rgba(d8c0ccFF)",
})
