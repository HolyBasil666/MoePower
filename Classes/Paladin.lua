-- Paladin Class Module for MoePower

local _, MoePower = ...

-- Rune texture mapping for positions 1-5, keyed by grow direction
local runeMaps = {
    center = {4, 2, 1, 3, 5},  -- center-outward: rune 1 at middle, 4/5 at edges
    left   = {1, 2, 3, 4, 5},  -- left→right: rune 1 at leftmost orb
    right  = {5, 4, 3, 2, 1},  -- right→left: rune 5 at leftmost orb
}
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

-- Per-orb dynamic atlas: different rune graphic per position.
-- Runes 4 and 5 always use "ready" (no "active" atlas variant exists for them).
function PaladinModule:GetForegroundAtlas(i, currentPower)
    if useRuneAtlas == nil then
        useRuneAtlas = C_Texture.GetAtlasInfo("uf-holypower-rune1-active") ~= nil
    end
    if not useRuneAtlas then return nil end
    local dir = (MoePower.settings and MoePower.settings.growDirection) or "center"
    local rmap = runeMaps[dir] or runeMaps.center
    local runeNum = rmap[i]
    local variant = (currentPower <= 2 and runeNum ~= 4 and runeNum ~= 5) and "active" or "ready"
    return "uf-holypower-rune" .. runeNum .. "-" .. variant
end

-- Override CreateOrbs to patch each orb's fadeIn OnFinished callback.
-- The framework's default OnFinished hardcodes ACTIVE_ALPHA; we replace it with
-- a per-orb targetAlpha so that the dim (≤2 HP) is preserved after the animation ends.
-- Paladin has no background texture, so using frame alpha for dimming is safe.
function PaladinModule:CreateOrbs(frame, layoutConfig)
    local orbs = MoePower:BuildOrbFrames(frame, layoutConfig, self)
    for i = 1, #orbs do
        local orb = orbs[i]
        orb.targetAlpha = MoePower.ACTIVE_ALPHA  -- updated each UpdatePower
        orb.fadeIn:SetScript("OnFinished", function()
            orb.frame:SetAlpha(orb.targetAlpha)
        end)
    end
    return orbs
end

-- Hide OOC when the "paladinHideWhenFull" setting is enabled
function PaladinModule:ShouldHideOOC(currentPower, maxPower)
    return MoePower.settings and MoePower.settings.paladinHideWhenFull
end

-- Sync atlas and frame alpha for every active orb after visibility updates.
-- Dimming is applied to the orb frame (not foreground texture) so it survives
-- the fadeIn OnFinished callback.
function PaladinModule:OnAfterUpdatePower(orbs, currentPower)
    local alpha = (currentPower <= 2) and ACTIVE_VARIANT_ALPHA or MoePower.ACTIVE_ALPHA
    for i = 1, #orbs do
        if orbs[i].active then
            local atlas = self:GetForegroundAtlas(i, currentPower)
            if atlas then orbs[i].foreground:SetAtlas(atlas) end
            orbs[i].targetAlpha = alpha
            orbs[i].frame:SetAlpha(alpha)
        end
    end
end

MoePower:RegisterClassModule(PaladinModule)
