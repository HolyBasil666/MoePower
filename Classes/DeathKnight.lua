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
    specKeys  = { [1] = "BLOOD", [2] = "FROST", [3] = "UNHOLY" },
    powerType = Enum.PowerType.Runes,  -- Used by GetModuleMaxPower to size the orb array
    -- No powerTypeName: UNIT_POWER_FREQUENT is unreliable for runes; RUNE_POWER_UPDATE is used instead

    config = {
        orbSize              = 22,
        backgroundScale      = 1.5,
        foregroundScale      = 0.8,
        backgroundAtlas      = "UF-DKRunes-BGActive",
        backgroundFallbackColor = {0.2, 0.2, 0.2, 0.75},
        -- Per-spec foreground atlases and fallback colors (resolved in CreateOrbs)
        foregroundAtlases = {
            [1] = "UF-DKRunes-Blood-SkullActive",
            [2] = "UF-DKRunes-Frost-SkullActive",
            [3] = "UF-DKRunes-Unholy-SkullActive",
        },
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

-- Returns the number of runes that are currently ready (not on cooldown)
local function GetReadyRuneCount()
    local count = 0
    for i = 1, DK_MAX_RUNES do
        local _, _, ready = GetRuneCooldown(i)
        if ready then count = count + 1 end
    end
    return count
end

-- CreateOrbs: resolve spec-specific values, cache them, then delegate to generic frame builder
function DeathKnightModule:CreateOrbs(frame, layoutConfig)
    local spec       = GetSpecialization() or 1
    self._fgAtlas    = self.config.foregroundAtlases[spec]
    self._fgColor    = self.config.colors[spec] or self.config.colors[1]
    self._fgXOffset  = FG_X_OFFSET[spec] or FG_X_OFFSET[1]
    self._fgYOffset  = FG_Y_OFFSET[spec] or FG_Y_OFFSET[1]
    self._useFgAtlas = nil  -- reset so GetForegroundAtlas re-validates on next call
    return MoePower:BuildOrbFrames(frame, layoutConfig, self)
end

-- Custom power source: GetRuneCooldown is authoritative; UnitPower(Runes) is unreliable in TWW 12.0
function DeathKnightModule:GetCurrentPower()
    return GetReadyRuneCount()
end

-- Per-spec atlas (same for all 6 runes; validated once via self._useFgAtlas cache)
function DeathKnightModule:GetForegroundAtlas(i, currentPower)
    if self._useFgAtlas == nil then
        self._useFgAtlas = self._fgAtlas and C_Texture.GetAtlasInfo(self._fgAtlas) ~= nil
    end
    return self._useFgAtlas and self._fgAtlas or nil
end

-- Per-rune, per-spec pixel offsets to align skull texture
function DeathKnightModule:GetForegroundOffset(i)
    return self._fgXOffset[i], self._fgYOffset[i]
end

-- Per-spec fallback color (used when atlas is unavailable)
function DeathKnightModule:GetForegroundFallbackColor()
    return self._fgColor
end

-- Hide 1s after leaving combat with all runes ready
function DeathKnightModule:ShouldHideOOC(currentPower, maxPower)
    return currentPower >= maxPower
end

MoePower:RegisterClassModule(DeathKnightModule)
