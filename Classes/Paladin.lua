-- Paladin Class Module for MoePower

local _, MoePower = ...

-- Rune texture mapping for positions 1-5 (hoisted to avoid table creation in hot path)
local runeMap = {4, 2, 1, 3, 5}
local ACTIVE_VARIANT_ALPHA = MoePower.ACTIVE_ALPHA * 2 / 3  -- Alpha for "active" variant (<=2 HP)

-- Paladin-specific configuration
local PaladinModule = {
    className     = "PALADIN",
    specKeys      = { [1] = "HOLY", [2] = "PROTECTION", [3] = "RETRIBUTION" },
    powerType     = Enum.PowerType.HolyPower,
    powerTypeName = "HOLY_POWER",

    config = {
        orbSize         = 26,
        backgroundScale = 1.0,
        foregroundScale = 1.0,
        backgroundAtlas = nil,  -- No background texture
    }
}

-- Event-driven combat flag (avoids UnitAffectingCombat() in the UpdatePower hot path)
local moduleInCombat = false
local combatFrame = CreateFrame("Frame")
combatFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
combatFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
combatFrame:SetScript("OnEvent", function(self, event)
    moduleInCombat = event == "PLAYER_REGEN_DISABLED"
end)

-- Create holy power display in arc or horizontal formation
function PaladinModule:CreateOrbs(frame, layoutConfig)
    local holyPower = {}
    local maxPower  = 5  -- Paladin holy power is always 5

    local cfg        = self.config
    local layout     = layoutConfig.layout or "arc"
    local arcRadius  = layoutConfig.arcRadius
    local arcSpan    = layoutConfig.arcSpan
    local startAngle = 90 + (arcSpan / 2)
    local arcStep    = maxPower > 1 and arcSpan / (maxPower - 1) or 0
    local horizStep  = cfg.orbSize + 4

    -- Hoist atlas validation: all rune atlas names share the same naming pattern;
    -- check one representative entry — if it exists, all variants do too.
    local useRuneAtlas = C_Texture.GetAtlasInfo("uf-holypower-rune1-active") ~= nil
    self.useRuneAtlas  = useRuneAtlas  -- cache for UpdatePower

    -- Hoist initial power query (same value for every orb)
    local currentPower   = UnitPower("player", self.powerType)
    local textureVariant = (currentPower <= 2) and "active" or "ready"
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

        local powerFrame = CreateFrame("Frame", nil, frame)
        powerFrame:SetSize(cfg.orbSize, cfg.orbSize)
        powerFrame:SetPoint("CENTER", frame, "CENTER", x, y)

        -- Background texture (optional; Paladin has none by default)
        local background
        if cfg.backgroundAtlas then
            background = powerFrame:CreateTexture(nil, "BACKGROUND")
            background:SetSize(cfg.orbSize * cfg.backgroundScale, cfg.orbSize * cfg.backgroundScale)
            background:SetPoint("CENTER", powerFrame, "CENTER", 0, 0)
            if C_Texture.GetAtlasInfo(cfg.backgroundAtlas) then
                background:SetAtlas(cfg.backgroundAtlas)
            else
                background:SetColorTexture(0.2, 0.2, 0.2, 0.75)
            end
        end

        local foreground = powerFrame:CreateTexture(nil, "ARTWORK")
        foreground:SetSize(cfg.orbSize * cfg.foregroundScale, cfg.orbSize * cfg.foregroundScale)
        foreground:SetPoint("CENTER", powerFrame, "CENTER", 0, 0)
        local runeAtlas = "uf-holypower-rune" .. runeMap[i] .. "-" .. textureVariant
        if useRuneAtlas then
            foreground:SetAtlas(runeAtlas)
        else
            foreground:SetColorTexture(1, 0.9, 0.2, 1)
        end

        local fadeInGroup, fadeOutGroup = MoePower:AddOrbAnimations(powerFrame)

        local active = (i >= startIndex and i <= endIndex)
        powerFrame:SetAlpha(active and MoePower.ACTIVE_ALPHA or 0)
        if active then
            foreground:SetAlpha(textureVariant == "active" and ACTIVE_VARIANT_ALPHA or MoePower.ACTIVE_ALPHA)
        end

        holyPower[i] = {
            frame      = powerFrame,
            background = background,
            foreground = foreground,
            fadeIn     = fadeInGroup,
            fadeOut    = fadeOutGroup,
            active     = active,
        }

        powerFrame:Show()
    end

    self.lastTextureVariant = textureVariant
    return holyPower
end

-- Update holy power display based on current power
function PaladinModule:UpdatePower(orbs)
    local currentPower = UnitPower("player", self.powerType)
    local maxPower     = #orbs
    local startIndex, endIndex = MoePower:GetVisibleRange(currentPower, maxPower)

    local textureVariant = (currentPower <= 2) and "active" or "ready"
    local variantChanged = textureVariant ~= self.lastTextureVariant
    self.lastTextureVariant = textureVariant

    for i = 1, maxPower do
        if i >= startIndex and i <= endIndex then
            local wasActive = orbs[i].active
            if not wasActive then
                orbs[i].fadeOut:Stop()
                orbs[i].fadeIn:Play()
                orbs[i].active = true
            end
            if variantChanged or not wasActive then
                local runeAtlas = "uf-holypower-rune" .. runeMap[i] .. "-" .. textureVariant
                if self.useRuneAtlas then
                    orbs[i].foreground:SetAtlas(runeAtlas)
                end
                orbs[i].foreground:SetAlpha(textureVariant == "active" and ACTIVE_VARIANT_ALPHA or MoePower.ACTIVE_ALPHA)
            end
        else
            if orbs[i].active then
                orbs[i].fadeIn:Stop()
                orbs[i].fadeOut:Play()
                orbs[i].active = false
            end
        end
    end

    -- Respect paladinHideWhenFull setting (default: always show)
    if MoePower.settings and MoePower.settings.paladinHideWhenFull then
        if not moduleInCombat and currentPower >= maxPower then
            MoePower:ScheduleHideOrbs(orbs, 1)
        else
            MoePower:CancelHideOrbs()
        end
    end
end

-- Register this module with the framework
MoePower:RegisterClassModule(PaladinModule)
