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
-- Tune these to align UF-Chi-Icon within each UF-Chi-BG-Active slot.
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
        orbSize         = 25,
        backgroundScale = 1,
        foregroundScale = 0.57,
        backgroundAtlas = "UF-Chi-BG-Active",
        foregroundAtlas = "UF-Chi-Icon",
    }
}

-- Internal state
local isWindwalker    = false  -- Cached in CreateOrbs; reset on every spec change / Initialize
local isMistweaver    = false  -- Cached in CreateOrbs; only MW tracks Teachings
local teachingsStacks = 0      -- Internal counter for MW (not read from aura during combat)
local seenCastGUID    = {}     -- Deduplication: prevents double-counting multi-hit spells
-- Event-driven combat flag: avoids the brief window where UnitAffectingCombat()
-- returns false right after PLAYER_REGEN_DISABLED fires (TWW 12.0 timing issue).
local moduleInCombat  = false

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

-- Sync Teachings stack count from aura data.
-- ONLY call this out of combat; aura fields are blocked in TWW 12.0 during combat.
local function SyncTeachingsFromAura()
    local auraData = C_UnitAuras.GetPlayerAuraBySpellID(TEACHINGS_SPELL_ID)
    teachingsStacks = auraData and (auraData.applications or 0) or 0
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

-- Create orb frames for the current spec
function MonkModule:CreateOrbs(frame, layoutConfig)
    local spec = GetSpecialization()
    isWindwalker = (spec == WINDWALKER_SPEC)
    isMistweaver = (spec == MISTWEAVER_SPEC)

    -- Brewmaster has no secondary resource to track
    if not isWindwalker and not isMistweaver then return {} end

    -- Only Mistweaver needs UNIT_AURA routing (OOC aura sync).
    -- Windwalker is driven by UNIT_POWER_FREQUENT; enabling tracksAura for WW
    -- would fire UpdatePower on every buff/debuff change unnecessarily.
    self.tracksAura = isMistweaver

    local orbs     = {}
    local cfg      = self.config
    local maxPower = isWindwalker
        and (UnitPowerMax("player", Enum.PowerType.Chi) or TEACHINGS_MAX_STACKS)
        or  TEACHINGS_MAX_STACKS

    local layout     = layoutConfig.layout or "arc"
    local arcRadius  = layoutConfig.arcRadius
    local arcSpan    = layoutConfig.arcSpan
    local startAngle = 90 + (arcSpan / 2)
    local arcStep    = maxPower > 1 and arcSpan / (maxPower - 1) or 0
    local horizStep  = cfg.orbSize + 4

    -- Hoist atlas checks outside loop: result is identical for every orb
    local useBgAtlas = C_Texture.GetAtlasInfo(cfg.backgroundAtlas) ~= nil
    local useFgAtlas = C_Texture.GetAtlasInfo(cfg.foregroundAtlas) ~= nil

    -- Sync initial state (safe: CreateOrbs is never called mid-combat)
    if isMistweaver then
        SyncTeachingsFromAura()
    end
    local currentPower = isWindwalker
        and UnitPower("player", Enum.PowerType.Chi)
        or  teachingsStacks
    local startIndex, endIndex = MoePower:GetVisibleRange(currentPower, maxPower)

    for i = 1, maxPower do
        local x, y
        if layout == "horizontal" then
            x = -(horizStep * (maxPower - 1) / 2) + (i - 1) * horizStep
            y = arcRadius
        else
            local radian = math.rad(startAngle - (i - 1) * arcStep)
            x = arcRadius * math.cos(radian)
            y = arcRadius * math.sin(radian)
        end

        local orbFrame = CreateFrame("Frame", nil, frame)
        orbFrame:SetSize(cfg.orbSize, cfg.orbSize)
        orbFrame:SetPoint("CENTER", frame, "CENTER", x, y)

        -- Background texture (inactive slot / orb glow)
        local bg = orbFrame:CreateTexture(nil, "BACKGROUND")
        local bgSize = cfg.orbSize * cfg.backgroundScale
        bg:SetSize(bgSize, bgSize)
        bg:SetPoint("CENTER", orbFrame, "CENTER", 0, 0)
        if useBgAtlas then
            bg:SetAtlas(cfg.backgroundAtlas)
        else
            bg:SetColorTexture(0.1, 0.1, 0.1, 0.6)
        end

        -- Foreground texture (chi orb / teachings stack fill)
        local fg = orbFrame:CreateTexture(nil, "ARTWORK")
        local fgSize = cfg.orbSize * cfg.foregroundScale
        fg:SetSize(fgSize, fgSize)
        fg:SetPoint("CENTER", orbFrame, "CENTER", FG_X_OFFSET[i] or 0, FG_Y_OFFSET[i] or 0)
        if useFgAtlas then
            fg:SetAtlas(cfg.foregroundAtlas)
        else
            fg:SetColorTexture(0.2, 0.9, 0.2, 1.0)
        end

        local fadeIn, fadeOut = MoePower:AddOrbAnimations(orbFrame)

        local active = (i >= startIndex and i <= endIndex)
        orbFrame:SetAlpha(active and MoePower.ACTIVE_ALPHA or 0)

        orbs[i] = {
            frame      = orbFrame,
            background = bg,
            foreground = fg,
            fadeIn     = fadeIn,
            fadeOut    = fadeOut,
            active     = active,
        }
        orbFrame:Show()
    end

    return orbs
end

-- Update orb display from current power / teachings stack counter
function MonkModule:UpdatePower(orbs)
    local n = #orbs
    if n == 0 then return end

    local currentPower
    if isWindwalker then
        currentPower = UnitPower("player", Enum.PowerType.Chi)
    else
        -- Out of combat: sync from aura (safe; event-driven flag is never briefly wrong)
        if not moduleInCombat then
            SyncTeachingsFromAura()
        end
        currentPower = teachingsStacks
    end

    local startIndex, endIndex = MoePower:GetVisibleRange(currentPower, n)

    for i = 1, n do
        if i >= startIndex and i <= endIndex then
            if not orbs[i].active then
                orbs[i].fadeOut:Stop()
                orbs[i].fadeIn:Play()
                orbs[i].active = true
            end
        else
            if orbs[i].active then
                orbs[i].fadeIn:Stop()
                orbs[i].fadeOut:Play()
                orbs[i].active = false
            end
        end
    end

    -- Hide 1 s after leaving combat (chi doesn't auto-regen, so hide regardless of current amount)
    if not moduleInCombat then
        MoePower:ScheduleHideOrbs(orbs, 1)
    else
        MoePower:CancelHideOrbs()
    end
end

MoePower:RegisterClassModule(MonkModule)
