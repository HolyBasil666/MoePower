-- Monk Class Module for MoePower
-- Windwalker:  tracks Chi via UNIT_POWER_FREQUENT (5–6 orbs, talent-dependent)
-- Mistweaver:  tracks Teachings of the Monastery internally via spell cast events;
--              aura is read ONLY out of combat (TWW 12.0 blocks aura data in combat).
-- Brewmaster:  no secondary resource tracked; module is inactive.

local _, MoePower = ...

local WINDWALKER_SPEC      = 3      -- GetSpecialization() index for Windwalker
local MISTWEAVER_SPEC      = 2      -- GetSpecialization() index for Mistweaver
local TEACHINGS_MAX_STACKS = 4
local TEACHINGS_SPELL_ID   = 202090 -- Teachings of the Monastery aura (MW; for OOC sync)
local TIGER_PALM_ID        = 100780 -- Grants 1 Teachings stack
local BLACKOUT_KICK_ID     = 100784 -- Consumes all Teachings stacks

-- Per-orb foreground offsets (pixels); indices 1–6 cover up to max WW chi.
local FG_X_OFFSET = {0, -0.4, -0.3, 0.15, 0.2, -0.9}
local FG_Y_OFFSET = {2.7, 2.6, 2.4, 2.4, 2.6, 2.7}

local MonkModule = {
    className     = "MONK",
    specKeys      = { [2] = "MISTWEAVER", [3] = "WINDWALKER" },
    powerType     = Enum.PowerType.Chi,   -- GetModuleMaxPower: 5–6 for WW, 0→falls back to maxPower for MW/BM
    powerTypeName = "CHI",                 -- Routes UNIT_POWER_FREQUENT + UNIT_MAXPOWER (WW only)
    tracksAura    = true,                  -- Routes UNIT_AURA → UpdatePower (MW OOC sync; harmless for WW)
    maxPower      = TEACHINGS_MAX_STACKS,  -- Fallback for GetModuleMaxPower when UnitPowerMax(Chi) = 0

    config = {
        orbSize              = 25,
        backgroundScale      = 1,
        foregroundScale      = 0.57,
        backgroundAtlas      = "UF-Chi-BG-Active",
        foregroundAtlas      = "UF-Chi-Icon",
        foregroundFallbackColor = {0.2, 0.9, 0.2, 1.0},
    }
}

-- Internal state
local isWindwalker    = false  -- Cached in CreateOrbs; reset on every spec change / Initialize
local isMistweaver    = false  -- Cached in CreateOrbs; only MW tracks Teachings
local teachingsStacks = 0      -- Internal counter for MW (not read from aura during combat)
local seenCastGUID    = {}     -- Deduplication: prevents double-counting multi-hit spells

-- Wipe cast-dedup table when leaving combat (MoePower.inCombat tracks the flag itself)
local combatFrame = CreateFrame("Frame")
combatFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
combatFrame:SetScript("OnEvent", function()
    wipe(seenCastGUID)
end)

-- Sync Teachings stack count from aura data.
-- ONLY call this out of combat; aura fields are blocked in TWW 12.0 during combat.
local function SyncTeachingsFromAura()
    local auraData = C_UnitAuras.GetPlayerAuraBySpellID(TEACHINGS_SPELL_ID)
    teachingsStacks = auraData and (auraData.applications or 0) or 0
end

-- CreateOrbs: spec check + pre-init, then delegate to generic frame builder
function MonkModule:CreateOrbs(frame, layoutConfig)
    local spec = GetSpecialization()
    isWindwalker = (spec == WINDWALKER_SPEC)
    isMistweaver = (spec == MISTWEAVER_SPEC)

    -- Brewmaster has no secondary resource to track
    if not isWindwalker and not isMistweaver then return {} end

    -- Only Mistweaver needs UNIT_AURA routing (OOC aura sync).
    self.tracksAura = isMistweaver

    if isMistweaver then SyncTeachingsFromAura() end
    return MoePower:BuildOrbFrames(frame, layoutConfig, self)
end

-- Read power from chi (WW) or internal Teachings counter (MW); sync aura OOC for MW
function MonkModule:GetCurrentPower()
    if isWindwalker then
        return UnitPower("player", Enum.PowerType.Chi)
    else
        if not MoePower.inCombat then SyncTeachingsFromAura() end
        return teachingsStacks
    end
end

-- Per-orb static offsets to align UF-Chi-Icon within each UF-Chi-BG-Active slot
function MonkModule:GetForegroundOffset(i)
    return FG_X_OFFSET[i] or 0, FG_Y_OFFSET[i] or 0
end

-- Chi doesn't auto-regen; always hide after leaving combat regardless of current amount
function MonkModule:ShouldHideOOC(currentPower, maxPower)
    return true
end

-- Called by framework on UNIT_SPELLCAST_SUCCEEDED for the player
function MonkModule:OnSpellCast(spellID, castGUID)
    if not isMistweaver then return end
    -- Deduplicate: ignore if we've already processed this cast
    if castGUID then
        if seenCastGUID[castGUID] then return end
        seenCastGUID[castGUID] = true
    end

    if spellID == TIGER_PALM_ID then
        teachingsStacks = math.min(teachingsStacks + 1, TEACHINGS_MAX_STACKS)
    elseif spellID == BLACKOUT_KICK_ID then
        teachingsStacks = 0
    end
end

MoePower:RegisterClassModule(MonkModule)
