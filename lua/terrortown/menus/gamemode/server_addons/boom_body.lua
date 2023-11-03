CLGAMEMODESUBMENU.base = "base_gamemodesubmenu"

CLGAMEMODESUBMENU.priority = 0
CLGAMEMODESUBMENU.title = "Boom Body"

function CLGAMEMODESUBMENU:Populate(parent)
    local form = vgui.CreateTTT2Form(parent, "General Settings")

    form:MakeCheckBox({
        serverConvar = "ttt2_boom_body_allow_pickup",
        label = "label_boom_body_allow_pickup"
    })

    form:MakeCheckBox({
        serverConvar = "ttt2_boom_body_spawn_blood",
        label = "label_boom_body_spawn_blood"
    })

    form:MakeCheckBox({
        serverConvar = "ttt2_boom_body_pain_sound",
        label = "label_boom_body_pain_sound"
    })

    form:MakeSlider({
        serverConvar = "ttt2_boom_body_explosion_delay",
        label = "label_boom_body_explosion_delay",
        min = 0,
        max = 5,
        decimal = 1,
        default = 0
    })

    form:MakeSlider({
        serverConvar = "ttt2_boom_body_explosion_delay_policing",
        label = "label_boom_body_explosion_delay_policing",
        min = 0,
        max = 5,
        decimal = 1,
        default = 0
    })
end