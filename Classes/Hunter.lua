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

local SURVIVAL_SPEC = 3  -- GetSpecialization() index for Survival

local HunterModule = {
    className   = "HUNTER",
    specKeys    = { [3] = "SURVIVAL" },
    maxPower    = TIP_MAX_STACKS,
    tracksAura  = true,  -- Opt-in: UNIT_AURA → UpdatePower (out-of-combat aura sync)
    config = {
        orbSize              = 20,
        foregroundScale      = 1.0,
        foregroundAtlas      = "ClassOverlay-ComboPoint",
        foregroundFallbackColor = {1.0, 0.65, 0.0, 1.0},  -- amber
    }
}

-- Internal state
local tipStacks        = 0
local seenCastGUID     = {}
local suppressNextSync = false  -- Suppresses SyncFromAura for one GetCurrentPower call after OnSpellCast
local hasPrimalSurge = false
local hasTwinFangs   = false
local isSurvival     = false  -- Cached spec check; set in CreateOrbs on every Initialize/spec change

-- Wipe cast-dedup table when leaving combat (MoePower.inCombat tracks the flag itself)
local combatFrame = CreateFrame("Frame")
combatFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
combatFrame:SetScript("OnEvent", function()
    wipe(seenCastGUID)
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

-- CreateOrbs: spec check + pre-init, then delegate to generic frame builder
function HunterModule:CreateOrbs(frame, layoutConfig)
    isSurvival = GetSpecialization() == SURVIVAL_SPEC
    -- Only Survival needs UNIT_AURA routing (OOC aura sync).
    self.tracksAura = isSurvival
    if not isSurvival then return {} end

    SyncFromAura()
    UpdateTalents()
    return MoePower:BuildOrbFrames(frame, layoutConfig, self)
end

-- Read internal stack counter; sync from aura when safe (out of combat).
-- Skips one sync after OnSpellCast to avoid overwriting a freshly-incremented
-- tipStacks before the Tip of the Spear buff has actually been applied.
function HunterModule:GetCurrentPower()
    if not MoePower.inCombat then
        if suppressNextSync then
            suppressNextSync = false
        else
            SyncFromAura()
        end
    end
    return tipStacks
end

-- Hide after 1s when out of combat with no stacks
function HunterModule:ShouldHideOOC(currentPower, maxPower)
    return currentPower == 0
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
        suppressNextSync = true
    elseif spellID == TAKEDOWN_ID then
        if hasTwinFangs then
            tipStacks = math.min(tipStacks + 3, TIP_MAX_STACKS)
        else
            tipStacks = math.max(tipStacks - 1, 0)
        end
        suppressNextSync = true
    elseif SPENDER_IDS[spellID] then
        tipStacks = math.max(tipStacks - 1, 0)
        suppressNextSync = true
    end
end

MoePower:RegisterClassModule(HunterModule)
