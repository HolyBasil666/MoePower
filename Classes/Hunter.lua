-- Hunter Class Module for MoePower (Survival Spec)
-- Tracks Tip of the Spear buff stacks internally via spell cast events.
-- Aura data is NOT read during combat (blocked in TWW 12.0 Secret Values system).

local _, MoePower = ...

-- Spell IDs (sourced from TIPS addon reference)
local KILL_COMMAND_ID = 259489
local TAKEDOWN_ID     = 1253859
local SPENDER_IDS = {
    [186270]  = true, -- Raptor Strike
    [1262293] = true, -- Raptor Swipe
    [1261193] = true, -- Boomstick
    [1253859] = true, -- Takedown (also checked above for Twin Fangs case)
    [259495]  = true, -- Wildfire Bomb
    [193265]  = true, -- Hatchet Toss
    [1264949] = true, -- Chakram
    [1262343] = true, -- Ranged Raptor Swipe
    [265189]  = true, -- Ranged Raptor Strike
    [1251592] = true, -- Flamefang Pitch
}

local PRIMAL_SURGE_ID = 1272154  -- Talent: Kill Command grants 2 stacks
local TWIN_FANGS_ID   = 1272139  -- Talent: Takedown grants 3 stacks
local TIP_SPELL_ID    = 260286   -- Tip of the Spear buff (for out-of-combat aura sync)
local TIP_MAX_STACKS  = 3
local FILL_ORDER      = {2, 1, 3}  -- center first, then left, then right

local SURVIVAL_SPEC = 3  -- GetSpecialization() index for Survival

local HunterModule = {
    className   = "HUNTER",
    maxPower    = TIP_MAX_STACKS,
    tracksAura  = true,  -- Opt-in: UNIT_AURA → UpdatePower (out-of-combat aura sync)
    -- No powerType / powerTypeName: framework uses maxPower and routes UNIT_SPELLCAST_SUCCEEDED
    config = {
        orbSize         = 20,
        foregroundScale = 1.0,
        foregroundAtlas = "ClassOverlay-ComboPoint",
    }
}

-- Internal state
local tipStacks      = 0
local seenCastGUID   = {}
local hasPrimalSurge = false
local hasTwinFangs   = false
local isSurvival     = false  -- Cached spec check; set in CreateOrbs on every Initialize/spec change
-- Event-driven combat flag: avoids the brief window where UnitAffectingCombat()
-- returns false right after PLAYER_REGEN_DISABLED fires (TWW 12.0 timing issue).
local moduleInCombat = false

local combatFrame = CreateFrame("Frame")
combatFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
combatFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
combatFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_REGEN_DISABLED" then
        moduleInCombat = true
    else  -- PLAYER_REGEN_ENABLED
        moduleInCombat = false
        wipe(seenCastGUID)
    end
end)

-- Refresh talent flags (call after any talent/spec change)
local function UpdateTalents()
    hasPrimalSurge = IsPlayerSpell(PRIMAL_SURGE_ID)
    hasTwinFangs   = IsPlayerSpell(TWIN_FANGS_ID)
end

-- Sync stack count from aura data.
-- ONLY call this out of combat; aura fields are blocked in TWW 12.0 during combat.
local function SyncFromAura()
    local auraData = C_UnitAuras.GetPlayerAuraBySpellID(TIP_SPELL_ID)
    tipStacks = auraData and (auraData.applications or 0) or 0
end

-- Called by framework on UNIT_SPELLCAST_SUCCEEDED for the player
function HunterModule:OnSpellCast(spellID, castGUID)
    if not isSurvival then return end
    -- Deduplicate: ignore if we've already processed this cast
    if castGUID then
        if seenCastGUID[castGUID] then return end
        seenCastGUID[castGUID] = true
    end

    if spellID == KILL_COMMAND_ID then
        tipStacks = math.min(tipStacks + (hasPrimalSurge and 2 or 1), TIP_MAX_STACKS)
    elseif spellID == TAKEDOWN_ID then
        if hasTwinFangs then
            tipStacks = math.min(tipStacks + 3, TIP_MAX_STACKS)
        else
            tipStacks = math.max(tipStacks - 1, 0)
        end
    elseif SPENDER_IDS[spellID] then
        tipStacks = math.max(tipStacks - 1, 0)
    end
end

-- Create orb frames in arc formation
function HunterModule:CreateOrbs(frame, layoutConfig)
    isSurvival = GetSpecialization() == SURVIVAL_SPEC
    if not isSurvival then return {} end

    local orbs = {}
    local cfg        = self.config
    local orbSize    = cfg.orbSize
    local fgSize     = orbSize * cfg.foregroundScale
    local arcRadius  = layoutConfig.arcRadius
    local arcSpan    = layoutConfig.arcSpan
    local startAngle = 90 + (arcSpan / 2)
    local angleStep  = arcSpan / (TIP_MAX_STACKS - 1)

    -- Atlas check hoisted: result is identical for every orb
    local atlasName = cfg.foregroundAtlas
    local useAtlas  = C_Texture.GetAtlasInfo(atlasName) ~= nil

    for i = 1, TIP_MAX_STACKS do
        local radian = math.rad(startAngle - (i - 1) * angleStep)
        local x = arcRadius * math.cos(radian)
        local y = arcRadius * math.sin(radian)

        local orbFrame = CreateFrame("Frame", nil, frame)
        orbFrame:SetSize(orbSize, orbSize)
        orbFrame:SetPoint("CENTER", frame, "CENTER", x, y)

        -- Foreground (active fill)
        local foreground = orbFrame:CreateTexture(nil, "ARTWORK")
        foreground:SetSize(fgSize, fgSize)
        foreground:SetPoint("CENTER", orbFrame, "CENTER", 0, 0)
        if useAtlas then
            foreground:SetAtlas(atlasName)
        else
            foreground:SetColorTexture(1.0, 0.65, 0.0, 1.0)  -- amber fallback
        end

        local fadeIn, fadeOut = MoePower:AddOrbAnimations(orbFrame)

        -- foreground not stored: texture is set once and never changed
        orbs[i] = {
            frame   = orbFrame,
            fadeIn  = fadeIn,
            fadeOut = fadeOut,
            active  = false,
        }

        orbFrame:SetAlpha(0)
        orbFrame:Show()
    end

    -- Sync initial state and talent flags (safe: CreateOrbs is never called mid-combat)
    SyncFromAura()
    UpdateTalents()

    return orbs
end

-- Update orb display from internal stack counter
function HunterModule:UpdatePower(orbs)
    local n = #orbs
    if n == 0 then return end  -- non-Survival spec: no orbs to update
    -- Out of combat: sync from aura (safe; event-driven flag is never briefly wrong)
    if not moduleInCombat then
        SyncFromAura()
    end

    local currentStacks = tipStacks

    -- Light up orbs from center outward (fill order: 2, 1, 3)
    for i = 1, n do
        local orb = orbs[FILL_ORDER[i]]
        if i <= currentStacks then
            if not orb.active then
                orb.fadeOut:Stop()
                orb.fadeIn:Play()
                orb.active = true
            end
        else
            if orb.active then
                orb.fadeIn:Stop()
                orb.fadeOut:Play()
                orb.active = false
            end
        end
    end

    -- Hide after 1s when out of combat with no stacks
    if not moduleInCombat and currentStacks == 0 then
        MoePower:ScheduleHideOrbs(orbs, 1)
    else
        MoePower:CancelHideOrbs()
    end
end

MoePower:RegisterClassModule(HunterModule)
