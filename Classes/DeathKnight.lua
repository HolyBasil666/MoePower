-- Death Knight Class Module for MoePower
-- Tracks 6 Runes via RUNE_POWER_UPDATE + GetRuneCooldown().
-- UnitPower(Enum.PowerType.Runes) does not update correctly in TWW 12.0;
-- GetRuneCooldown(i) is the authoritative source for individual rune ready states.
-- Spec-specific colours: Blood (red), Frost (ice blue), Unholy (green).
-- Background: UF-DKRunes-BGActive  Foreground: UF-DKRunes-{spec}-SkullActive

local _, MoePower = ...

local DK_MAX_RUNES = 6

local DeathKnightModule = {
    className = "DEATHKNIGHT",
    powerType = Enum.PowerType.Runes,  -- Used by GetModuleMaxPower to size the orb array
    -- No powerTypeName: UNIT_POWER_FREQUENT is unreliable for runes; RUNE_POWER_UPDATE is used instead

    config = {
        orbSize         = 22,
        backgroundScale = 1.5,
        foregroundScale = 0.8,
        backgroundAtlas = "UF-DKRunes-BGActive",
        foregroundAtlases = {
            [1] = "UF-DKRunes-Blood-SkullActive",
            [2] = "UF-DKRunes-Frost-SkullActive",
            [3] = "UF-DKRunes-Unholy-SkullActive",
        },
        -- Colour fallbacks per spec index (RGBA)
        colors = {
            [1] = {0.9, 0.1, 0.1, 1.0},  -- Blood: red
            [2] = {0.5, 0.8, 1.0, 1.0},  -- Frost: ice blue
            [3] = {0.2, 0.9, 0.2, 1.0},  -- Unholy: green
        },
    }
}

-- Per-spec, per-rune foreground offsets (pixels) indexed by [spec][rune]
local FG_X_OFFSET = {
    [1] = {0.35, -0.2, 0,  0.5, 0.7, 0.1},  -- Blood
    [2] = {0, -0.5, -0.25,  0.25, 0.5, 0},  -- Frost
    [3] = {0, -0.5, -0.25,  0.25, 0.5, 0},  -- Unholy
}
local FG_Y_OFFSET = {
    [1] = {0.2, 0.3, 0, 0, 0.3, 0.2},  -- Blood
    [2] = {0.2, 0.3, 0, 0, 0.3, 0.2},  -- Frost
    [3] = {0.2, 0.3, 0, 0, 0.3, 0.2},  -- Unholy
}

-- Event-driven combat flag: avoids UnitAffectingCombat() API call in the RUNE_POWER_UPDATE hot path
local moduleInCombat = false
local combatFrame = CreateFrame("Frame")
combatFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
combatFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
combatFrame:SetScript("OnEvent", function(self, event)
    moduleInCombat = event == "PLAYER_REGEN_DISABLED"
end)

-- Returns the number of runes that are currently ready (not on cooldown)
local function GetReadyRuneCount()
    local count = 0
    for i = 1, DK_MAX_RUNES do
        local _, _, ready = GetRuneCooldown(i)
        if ready then count = count + 1 end
    end
    return count
end

-- Create rune orb frames in arc formation
function DeathKnightModule:CreateOrbs(frame, layoutConfig)
    local orbs = {}
    local cfg        = self.config
    local orbSize    = cfg.orbSize
    local bgSize     = orbSize * cfg.backgroundScale
    local fgSize     = orbSize * cfg.foregroundScale
    local layout     = layoutConfig.layout or "arc"
    local arcRadius  = layoutConfig.arcRadius
    local arcSpan    = layoutConfig.arcSpan
    local startAngle = 90 + (arcSpan / 2)
    local arcStep    = arcSpan / (DK_MAX_RUNES - 1)
    local horizStep  = cfg.orbSize + 4

    -- Resolve per-spec values (hoisted: same for all 6 orbs)
    local spec       = GetSpecialization() or 1
    local fgAtlas    = cfg.foregroundAtlases[spec]
    local useFgAtlas = fgAtlas and C_Texture.GetAtlasInfo(fgAtlas) ~= nil
    local color      = cfg.colors[spec] or cfg.colors[1]
    local xOffsets   = FG_X_OFFSET[spec] or FG_X_OFFSET[1]
    local yOffsets   = FG_Y_OFFSET[spec] or FG_Y_OFFSET[1]
    -- Background atlas (same for all specs, hoisted)
    local bgAtlas    = cfg.backgroundAtlas
    local useBgAtlas = bgAtlas and C_Texture.GetAtlasInfo(bgAtlas) ~= nil
    -- Hoist initial power query: same value for every orb
    local currentPower = GetReadyRuneCount()
    local startIndex, endIndex = MoePower:GetVisibleRange(currentPower, DK_MAX_RUNES)

    for i = 1, DK_MAX_RUNES do
        local x, y
        if layout == "horizontal" then
            x = -(horizStep * (DK_MAX_RUNES - 1) / 2) + (i - 1) * horizStep
            y = arcRadius
        else
            local radian = math.rad(startAngle - (i - 1) * arcStep)
            x = arcRadius * math.cos(radian)
            y = arcRadius * math.sin(radian)
        end

        local orbFrame = CreateFrame("Frame", nil, frame)
        orbFrame:SetSize(orbSize, orbSize)
        orbFrame:SetPoint("CENTER", frame, "CENTER", x, y)

        -- Background (fades with orb)
        local background = orbFrame:CreateTexture(nil, "BACKGROUND")
        background:SetSize(bgSize, bgSize)
        background:SetPoint("CENTER", orbFrame, "CENTER", 0, 0)
        if useBgAtlas then
            background:SetAtlas(bgAtlas)
        else
            background:SetColorTexture(0.2, 0.2, 0.2, 0.75)
        end

        -- Foreground (fades with orb)
        local foreground = orbFrame:CreateTexture(nil, "ARTWORK")
        foreground:SetSize(fgSize, fgSize)
        foreground:SetPoint("CENTER", orbFrame, "CENTER", xOffsets[i], yOffsets[i])
        if useFgAtlas then
            foreground:SetAtlas(fgAtlas)
        else
            foreground:SetColorTexture(color[1], color[2], color[3], color[4])
        end

        local fadeIn, fadeOut = MoePower:AddOrbAnimations(orbFrame)

        orbs[i] = {
            frame   = orbFrame,
            fadeIn  = fadeIn,
            fadeOut = fadeOut,
            active  = false,
        }

        if i >= startIndex and i <= endIndex then
            orbFrame:SetAlpha(MoePower.ACTIVE_ALPHA)
            orbs[i].active = true
        else
            orbFrame:SetAlpha(0)
        end

        orbFrame:Show()
    end

    return orbs
end

-- Update rune display based on current ready rune count
function DeathKnightModule:UpdatePower(orbs)
    local n            = #orbs
    local currentPower = GetReadyRuneCount()
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

    -- Hide 1s after leaving combat with all runes ready (matches Evoker pattern)
    if not moduleInCombat and currentPower >= n then
        MoePower:ScheduleHideOrbs(orbs, 1)
    else
        MoePower:CancelHideOrbs()
    end
end

MoePower:RegisterClassModule(DeathKnightModule)
