-- Tema custom snappy para Quickshell/IllogicalImpulse
-- Salva em ~/.config/quickshell/ii/assets/custom/theme.lua

return {
    -- Cores base (geradas pelo matugen do wallpaper, mas com overrides)
    colors = {
        -- Surface containers (camadas)
        surfaceContainer = "#1E1E2E",
        surfaceContainerLow = "#181825",
        surfaceContainerHigh = "#313244",
        surfaceContainerHighest = "#45475A",
        
        -- Outline/bordas
        outline = "#6C7086",
        outlineVariant = "#585B70",
        
        -- Shadow/sombra
        shadow = "#00000080",
        scrim = "#000000CC",
        
        -- Primary/Accent
        primary = "#89B4FA",
        onPrimary = "#1E1E2E",
        primaryContainer = "#1E66F5",
        onPrimaryContainer = "#DCE0E8",
        
        -- Secondary
        secondary = "#F5C2E7",
        onSecondary = "#1E1E2E",
        secondaryContainer = "#E879F9",
        onSecondaryContainer = "#1E1E2E",
        
        -- Tertiary
        tertiary = "#F9E2AF",
        onTertiary = "#1E1E2E",
        tertiaryContainer = "#F5C2E7",
        onTertiaryContainer = "#1E1E2E",
        
        -- Error
        error = "#F38BA8",
        onError = "#1E1E2E",
        errorContainer = "#F38BA8",
        onErrorContainer = "#1E1E2E",
        
        -- Background
        background = "#11111B",
        onBackground = "#CDD6F4",
        
        -- Surface
        surface = "#1E1E2E",
        onSurface = "#CDD6F4",
        
        -- Inverse
        inverseSurface = "#CDD6F4",
        inverseOnSurface = "#1E1E2E",
        inversePrimary = "#1E66F5",
    },
    
    -- Tokens de arredondamento (consistentes)
    rounding = {
        none = 0,
        xs = 4,
        sm = 8,
        md = 12,      -- padrão para cards/widgets
        lg = 16,
        xl = 24,
        full = 9999,
        screenRounding = 12,
        windowRounding = 16,
        normal = 12,
        full = 9999,
        elevationMargin = 8,
    },
    
    -- Elevação/sombras (Material 3)
    elevation = {
        level0 = { shadow = "none", color = "#00000000" },
        level1 = { 
            shadow = "0 1px 2px #00000030, 0 1px 3px #0000001A", 
            color = "#00000030" 
        },
        level2 = { 
            shadow = "0 3px 6px #00000030, 0 2px 4px #0000001A", 
            color = "#00000040" 
        },
        level3 = { 
            shadow = "0 6px 12px #00000030, 0 4px 8px #0000001A", 
            color = "#00000050" 
        },
        level4 = { 
            shadow = "0 12px 24px #00000030, 0 8px 16px #0000001A", 
            color = "#00000060" 
        },
        level5 = { 
            shadow = "0 24px 48px #00000030, 0 16px 32px #0000001A", 
            color = "#00000070" 
        },
    },
    
    -- Tamanhos base
    sizes = {
        baseBarHeight = 40,
        barHeight = 40,
        elevationMargin = 8,
        hyprlandGapsOut = 5,
        hyprlandGapsIn = 4,
        osdWidth = 320,
        mediaControlsWidth = 360,
        mediaControlsHeight = 120,
        widgetWidth = 280,
        widgetHeight = 140,
    },
    
    -- Animações snappy (curvas easeOutCubic, duração curta)
    animation = {
        curves = {
            default = "easeOutCubic",
            snappy = "easeOutCubic",
            smooth = "easeInOutCubic",
            spring = "spring(1, 0.8, 0.1)",
        },
        targets = {
            opacity = { duration = 120, curve = "easeOutCubic" },
            position = { duration = 150, curve = "easeOutCubic" },  -- x, y
            size = { duration = 150, curve = "easeOutCubic" },       -- width, height
            scale = { duration = 100, curve = "easeOutCubic" },
            rotation = { duration = 150, curve = "easeOutCubic" },
            color = { duration = 120, curve = "easeOutCubic" },
            blur = { duration = 200, curve = "easeOutCubic" },
        },
        -- Perfis nomeados
        profiles = {
            snappy = {
                curves = { default = "easeOutCubic" },
                targets = {
                    opacity = { duration = 100 },
                    position = { duration = 120 },
                    size = { duration = 120 },
                    scale = { duration = 80 },
                    color = { duration = 100 },
                }
            },
            expressive = {
                curves = { default = "easeInOutCubic" },
                targets = {
                    opacity = { duration = 200 },
                    position = { duration = 300 },
                    size = { duration = 300 },
                    scale = { duration = 200 },
                    color = { duration = 200 },
                }
            },
            minimal = {
                curves = { default = "easeOutQuart" },
                targets = {
                    opacity = { duration = 80 },
                    position = { duration = 100 },
                    size = { duration = 100 },
                    scale = { duration = 60 },
                    color = { duration = 80 },
                }
            },
        },
    },
    
    -- Blur/Glass
    blur = {
        radius = 20,
        strength = 0.8,
        noise = 0.02,
        contrast = 1.1,
        vibrancy = 0.3,
        glassBg = "#FFFFFF10",      -- vidro sutil
        glassBorder = "#FFFFFF1A",   -- borda do vidro
    },
    
    -- Fontes
    font = {
        family = {
            title = "Google Sans Flex",
            body = "Google Sans Flex",
            mono = "JetBrains Mono",
            icon = "Material Symbols Rounded",
        },
        pixelSize = {
            xs = 10,
            sm = 12,
            normal = 14,
            md = 14,
            lg = 16,
            xl = 20,
            title = 28,
            large = 90,   -- clock
        },
        weight = {
            light = 300,
            normal = 400,
            medium = 500,
            semiBold = 600,
            bold = 700,
        },
    },
    
    -- Espaçamento
    spacing = {
        xs = 4,
        sm = 8,
        md = 12,
        lg = 16,
        xl = 24,
        xxl = 32,
    },
}