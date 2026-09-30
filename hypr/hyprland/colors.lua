hl.config({
    general = {
        col = {
            active_border   = "rgba(bdc2ffEE)",
            inactive_border = "rgba(46464f55)",
        },
    },
    decoration = {
        shadow = {
            enabled      = true,
            color        = "rgba(bdc2ff66)",
            range        = 8,
            render_power = 3,
        },
    },
    misc = {
        background_color = "rgba(131318FF)",
    },
})

hl.window_rule({
    match        = { pin = 1 },
    border_color = "rgba(bdc2ffFF) rgba(c4c4ddFF) rgba(e7b9d6FF) rgba(bdc2ffFF)",
})
