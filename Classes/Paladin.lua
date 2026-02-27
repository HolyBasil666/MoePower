-- Paladin Class Module for MoePower

local _, MoePower = ...

-- Rune texture mapping for positions 1-5
local runeMap = {4, 2, 1, 3, 5}
local ACTIVE_VARIANT_ALPHA = MoePower.ACTIVE_ALPHA * 2 / 3  -- Alpha for "active" variant (<=2 HP)

-- Atlas validation (checked once; atlas availability doesn't change at runtime)
local useRuneAtlas

local PaladinModule = {
    className     = "PALADIN",
    specKeys      = { [1] = "HOLY", [2] = "PROTECTION", [3] = "RETRIBUTION" },
    powerType     = Enum.PowerType.HolyPower,
    powerTypeName = "HOLY_POWER",
    maxPower      = 5,  -- Holy power is always 5; explicit so BuildOrbFrames skips UnitPowerMax

    config = {
        orbSize         = 26,
        backgroundScale = 1.0,
        foregroundScale = 1.0,
        backgroundAtlas = nil,  -- No background texture for Paladin
    }
}

-- Per-orb dynamic atlas: different rune graphic per position, dimmed variant at <= 2 HP
function PaladinModule:GetForegroundAtlas(i, currentPower)
    if useRuneAtlas == nil then
        useRuneAtlas = C_Texture.GetAtlasInfo("uf-holypower-rune1-active") ~= nil
    end
    if not useRuneAtlas then return nil end
    local variant = (currentPower <= 2) and "active" or "ready"
    return "uf-holypower-rune" .. runeMap[i] .. "-" .. variant
end

-- Hide OOC when the "paladinHideWhenFull" setting is enabled
function PaladinModule:ShouldHideOOC(currentPower, maxPower)
    return MoePower.settings and MoePower.settings.paladinHideWhenFull
end

-- After the standard fade loop, update foreground alpha when the texture variant changes.
-- "active" variant (1-2 HP) is dimmed; "ready" variant (3-5 HP) is full alpha.
function PaladinModule:OnAfterUpdatePower(orbs, currentPower)
    local variant = (currentPower <= 2) and "active" or "ready"
    if variant == self.lastTextureVariant then return end
    self.lastTextureVariant = variant

    local alpha = variant == "active" and ACTIVE_VARIANT_ALPHA or MoePower.ACTIVE_ALPHA
    for i = 1, #orbs do
        if orbs[i].active then
            local atlas = self:GetForegroundAtlas(i, currentPower)
            if atlas then orbs[i].foreground:SetAtlas(atlas) end
            orbs[i].foreground:SetAlpha(alpha)
        end
    end
end

MoePower:RegisterClassModule(PaladinModule)
