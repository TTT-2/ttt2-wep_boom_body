if SERVER then
    AddCSLuaFile()

    resource.AddFile("materials/vgui/ttt/icon_boom_body.vmt")
end

SWEP.Base = "weapon_tttbase"

SWEP.Spawnable = true
SWEP.AutoSpawnable = false
SWEP.AdminSpawnable = true

SWEP.HoldType = "slam"

if CLIENT then
    SWEP.Author = "Mineotopia"

    SWEP.ViewModelFOV = 54
    SWEP.ViewModelFlip = false

    SWEP.Category = "Explosive"
    SWEP.Icon = "vgui/ttt/icon_boom_body"
    SWEP.EquipMenuData = {
        type = "item_weapon",
        name = "ttt2_weapon_boom_body",
        desc = "ttt2_weapon_boom_body_desc",
    }
end

SWEP.Kind = WEAPON_EXTRA
SWEP.CanBuy = { ROLE_TRAITOR }

SWEP.UseHands = true
SWEP.ViewModelFlip = false
SWEP.ViewModelFOV = 54

SWEP.NoSights = true

SWEP.DrawCrosshair = false
SWEP.ViewModelFlip = false
SWEP.Primary.ClipSize = 1
SWEP.Primary.DefaultClip = 1
SWEP.Primary.Automatic = true
SWEP.Primary.Ammo = "none"
SWEP.Primary.Delay = 5.0

SWEP.ViewModel = Model("models/weapons/cstrike/c_c4.mdl")
SWEP.WorldModel = Model("models/weapons/w_c4.mdl")
SWEP.Weight = 5

game.AddDecal("chalk_outline", "decals/decal_chalk_outline")

local cvAllowPickup = CreateConVar(
    "ttt2_boom_body_allow_pickup",
    "1",
    { FCVAR_NOTIFY, FCVAR_ARCHIVE, FCVAR_REPLICATED }
)
local cvPainSound = CreateConVar(
    "ttt2_boom_body_pain_sound",
    "1",
    { FCVAR_NOTIFY, FCVAR_ARCHIVE, FCVAR_REPLICATED }
)
local cvExplosionDelay = CreateConVar(
    "ttt2_boom_body_explosion_delay",
    "0",
    { FCVAR_NOTIFY, FCVAR_ARCHIVE, FCVAR_REPLICATED }
)
local cvExplosionDelayPolicing = CreateConVar(
    "ttt2_boom_body_explosion_delay_policing",
    "0",
    { FCVAR_NOTIFY, FCVAR_ARCHIVE, FCVAR_REPLICATED }
)

if SERVER then
    util.AddNetworkString("BoomBodyUpdateRadar")

    local soundThrow = Sound("Weapon_SLAM.SatchelThrow")
    local soundThrow1 = Sound("vo/npc/male01/pain07.wav")
    local soundPreExplosion = Sound("weapons/c4/c4_beep1.wav")

    local cvSpawnBlood = CreateConVar(
        "ttt2_boom_body_spawn_blood",
        "1",
        { FCVAR_NOTIFY, FCVAR_ARCHIVE, FCVAR_REPLICATED }
    )

    local function UpdateRadar(state, rag)
        if not IsValid(rag) then
            return
        end

        net.Start("BoomBodyUpdateRadar")

        net.WriteUInt(rag:EntIndex(), 16)
        net.WriteBool(state)

        if state then
            net.WriteVector(rag:GetPos())
            net.WriteString(rag:GetNWEntity("boom_body_owner"):GetTeam())
        end

        net.Broadcast()
    end

    local function RemoveBoomBody(rag)
        local owner = rag:GetNWEntity("boom_body_owner")

        owner.boomBodyCache[rag] = nil

        UpdateRadar(false, rag)

        rag:Remove()
    end

    local function ExplodeBoomBody(rag)
        local posRag = rag:GetPos() + rag:OBBCenter()
        local radius = 160

        local tr = util.TraceLine({
            start = posRag,
            endpos = posRag + Vector(0, 0, -32),
            mask = MASK_SHOT_HULL,
            filter = { rag },
        })

        local effect = EffectData()

        effect:SetStart(posRag)
        effect:SetOrigin(posRag)
        effect:SetScale(radius * 0.3)
        effect:SetRadius(radius)
        effect:SetMagnitude(500)

        if tr.Fraction ~= 1.0 then
            effect:SetNormal(tr.HitNormal)
        end

        util.Effect("Explosion", effect, true, true)
        util.BlastDamage(
            ents.Create("weapon_ttt_boom_body"),
            rag:GetNWEntity("boom_body_owner"),
            posRag,
            radius,
            350
        )

        util.DecalRemovable(
            "boom_body_chalk_outline_" .. CORPSE.GetPlayerNick(rag, "undefined"),
            "chalk_outline",
            tr.HitPos + 5 * tr.HitNormal,
            tr.HitPos - 5 * tr.HitNormal,
            { rag }
        )

        util.DecalRemovable(
            "boom_body_scorch_" .. CORPSE.GetPlayerNick(rag, "undefined"),
            "Scorch",
            tr.HitPos + 5 * tr.HitNormal,
            tr.HitPos - 5 * tr.HitNormal,
            { rag }
        )

        RemoveBoomBody(rag)
    end

    function SWEP:SelectBoomBodyPlayer()
        local plys = player.GetAll()

        return plys[math.random(#plys)]
    end

    function SWEP:SpawnBoomBody()
        local ply = self:SelectBoomBodyPlayer()
        local owner = self:GetOwner()

        local dmg = DamageInfo()

        dmg:SetAttacker(owner)
        dmg:SetInflictor(self)
        dmg:SetDamage(10)
        dmg:SetDamageType(DMG_BULLET)

        local rag = CORPSE.Create(owner, ply, dmg)

        rag:SetNWEntity("boom_body_owner", owner)
        rag.killer_sample = nil
        rag.isBoomBody = true

        CORPSE.SetCredits(rag, 0)

        rag:EmitSound(soundThrow)
        if cvPainSound:GetBool() then
            rag:EmitSound(soundThrow1)
        end
        self:SendWeaponAnim(ACT_VM_SECONDARYATTACK)

        -- spawn blood decals
        if cvSpawnBlood:GetBool() then
            timer.Create("ragdoll_blood_decals_" .. rag:EntIndex(), 0.15, 15, function()
                if not IsValid(rag) then
                    return
                end

                local jitter = VectorRand() * 25

                jitter.z = 10

                util.PaintDown(rag:GetPos() + rag:OBBCenter() + jitter, "Blood", rag)
            end)
        end

        -- cache ragdolls on owner
        owner.boomBodyCache = owner.boomBodyCache or {}
        owner.boomBodyCache[rag] = true

        -- update the bomb radar for the team mates
        UpdateRadar(true, rag)

        -- remove the weapon from the inventory
        self:Remove()
    end

    hook.Add("TTTCanSearchCorpse", "BoomBodySearchCorpse", function(ply, rag, isCovert)
        if not rag.isBoomBody then
            return
        end

        if ply:IsSpec() then
            LANG.Msg(ply, "boom_body_no_search", nil, MSG_MSTACK_PLAIN)

            return false
        end

        if ply == rag:GetNWEntity("boom_body_owner") and isCovert and cvAllowPickup:GetBool() then
            ply:SafePickupWeaponClass("weapon_ttt_boom_body", true)

            RemoveBoomBody(rag)

            return false
        end

        local delay = cvExplosionDelay:GetFloat()
        if ply:GetSubRoleData().isPolicingRole then
            delay = delay + cvExplosionDelayPolicing:GetFloat()
        end

        if delay > 0 then
            rag:EmitSound(soundPreExplosion)
            timer.Simple(delay, function()
                if not IsValid(rag) then
                    return
                end
                ExplodeBoomBody(rag)
            end)
        else
            ExplodeBoomBody(rag)
        end

        return false
    end)

    hook.Add("TTT2UpdateTeam", "BoomBodyOwnerChangesTeam", function(ply)
        if not ply.boomBodyCache then
            return
        end

        for rag in pairs(ply.boomBodyCache) do
            UpdateRadar(true, rag)
        end
    end)

    hook.Add("TTTPrepareRound", "BoomBodyCacheReset", function()
        local plys = player.GetAll()

        for i = 1, #plys do
            plys[i].boomBodyCache = nil
        end
    end)
else --CLIENT
    local key_params = {
        usekey = Key("+use", "USE"),
        walkkey = Key("+walk", "WALK"),
    }

    net.Receive("BoomBodyUpdateRadar", function()
        local idx = net.ReadUInt(16)

        if net.ReadBool() then
            RADAR.bombs[idx] = {
                pos = net.ReadVector(),
                team = net.ReadString(),
                nick = LANG.TryTranslation("ttt2_weapon_boom_body"),
            }
        else
            RADAR.bombs[idx] = nil
        end

        RADAR.bombs_count = table.Count(RADAR.bombs)
    end)

    hook.Add("TTTRenderEntityInfo", "BoomBodyTargetID", function(tData)
        local client = LocalPlayer()
        local ent = tData:GetEntity()

        -- has to be a ragdoll
        if not IsValid(ent) or ent:GetClass() ~= "prop_ragdoll" then
            return
        end

        -- only show this if the ragdoll has a nick, else it could be a mattress
        if not CORPSE.GetPlayerNick(ent, false) then
            return
        end

        local bbRadar = RADAR.bombs[ent:EntIndex()]

        if client == ent:GetNWEntity("boom_body_owner") and cvAllowPickup:GetBool() then
            tData:AddDescriptionLine(
                LANG.GetParamTranslation("boom_body_own_ragdoll", key_params),
                COLOR_ORANGE
            )
        elseif bbRadar and bbRadar.team == client:GetTeam() then
            tData:AddDescriptionLine(LANG.GetTranslation("boom_body_warn_ragdoll"), COLOR_ORANGE)
        end
    end)

    function SWEP:Initialize()
        self:AddTTT2HUDHelp("boom_body_help_msb1")

        return self.BaseClass.Initialize(self)
    end

    function SWEP:AddToSettingsMenu(parent)
        local form = vgui.CreateTTT2Form(parent, "header_equipment_additional")

        form:MakeCheckBox({
            serverConvar = "ttt2_boom_body_allow_pickup",
            label = "label_boom_body_allow_pickup",
        })

        form:MakeCheckBox({
            serverConvar = "ttt2_boom_body_spawn_blood",
            label = "label_boom_body_spawn_blood",
        })

        form:MakeCheckBox({
            serverConvar = "ttt2_boom_body_pain_sound",
            label = "label_boom_body_pain_sound",
        })

        form:MakeSlider({
            serverConvar = "ttt2_boom_body_explosion_delay",
            label = "label_boom_body_explosion_delay",
            min = 0,
            max = 5,
            decimal = 1,
            default = 0,
        })

        form:MakeSlider({
            serverConvar = "ttt2_boom_body_explosion_delay_policing",
            label = "label_boom_body_explosion_delay_policing",
            min = 0,
            max = 5,
            decimal = 1,
            default = 0,
        })
    end
end

function SWEP:PrimaryAttack()
    if CLIENT or not self:CanPrimaryAttack() then
        return
    end

    self:SpawnBoomBody()
end

function SWEP:SecondaryAttack() end
