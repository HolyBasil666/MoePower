-- Paladin Class Module for MoePower

local _, MoePower = ...

-- Rune texture mapping for positions 1-5 (hoisted to avoid table creation in hot path)
local runeMap = {4, 2, 1, 3, 5}
local ACTIVE_VARIANT_ALPHA = MoePower.ACTIVE_ALPHA * 2 / 3  -- Alpha for "active" variant (<=2 HP)

-- Paladin-specific configuration
local PaladinModule = {
    className = "PALADIN",
    powerType = Enum.PowerType.HolyPower,
    powerTypeName = "HOLY_POWER",

    -- Visual settings
    config = {
        orbSize = 26,            -- Orb frame size (container)
        backgroundScale = 1.0,   -- Background texture scale (multiplier of orbSize)
        foregroundScale = 1.0,   -- Foreground texture scale (multiplier of orbSize)
        backgroundAtlas = nil,   -- No background texture
    }
}

-- Create holy power display in arc formation
function PaladinModule:CreateOrbs(frame, layoutConfig)
    local holyPower = {}
    local maxPower = 5  -- Paladin holy power is always 5

    local cfg        = self.config
    local layout     = layoutConfig.layout or "arc"
    local arcRadius  = layoutConfig.arcRadius
    local arcSpan    = layoutConfig.arcSpan
    local startAngle = 90 + (arcSpan / 2)
    local arcStep    = maxPower > 1 and arcSpan / (maxPower - 1) or 0
    local horizStep  = cfg.orbSize + 4

    for i = 1, maxPower do
        -- Calculate orb position
        local x, y
        if layout == "horizontal" then
            x = -(horizStep * (maxPower - 1) / 2) + (i - 1) * horizStep
            y = arcRadius
        else
            local angle = startAngle - (i - 1) * arcStep
            local radian = math.rad(angle)
            x = arcRadius * math.cos(radian)
            y = arcRadius * math.sin(radian)
        end

        -- Create holy power container frame
        local powerFrame = CreateFrame("Frame", nil, frame)
        powerFrame:SetSize(cfg.orbSize, cfg.orbSize)
        powerFrame:SetPoint("CENTER", frame, "CENTER", x, y)

        -- Background texture (optional)
        local background
        if cfg.backgroundAtlas then
            background = powerFrame:CreateTexture(nil, "BACKGROUND")
            local bgSize = cfg.orbSize * cfg.backgroundScale
            background:SetSize(bgSize, bgSize)
            background:SetPoint("CENTER", powerFrame, "CENTER", 0, 0)
            local bgSuccess = pcall(background.SetAtlas, background, cfg.backgroundAtlas)
            if not bgSuccess then
                background:SetColorTexture(0.2, 0.2, 0.2, 0.75)
            end
        end

        -- Foreground fill texture (shows when active)
        local foreground = powerFrame:CreateTexture(nil, "ARTWORK")
        local fgSize = cfg.orbSize * cfg.foregroundScale
        foreground:SetSize(fgSize, fgSize)
        foreground:SetPoint("CENTER", powerFrame, "CENTER", 0, 0)
        -- Use mapped rune texture for each position
        local runeNumber = runeMap[i]
        local runeAtlas = "uf-holypower-rune" .. runeNumber .. "-active"
        local fgSuccess = pcall(foreground.SetAtlas, foreground, runeAtlas)
        if not fgSuccess then
            foreground:SetColorTexture(1, 0.9, 0.2, 1)  -- Golden color for holy power
        end

        -- Add fade animations
        local fadeInGroup, fadeOutGroup = MoePower:AddOrbAnimations(powerFrame)

        -- Store references
        holyPower[i] = {
            frame = powerFrame,
            background = background,
            foreground = foreground,
            fadeIn = fadeInGroup,
            fadeOut = fadeOutGroup,
            active = false
        }

        powerFrame:Show()
    end

    -- Initialize visibility based on current power
    local currentPower = UnitPower("player", self.powerType)
    local startIndex, endIndex = MoePower:GetVisibleRange(currentPower, maxPower)

    -- Determine texture variant based on power level
    local textureVariant = (currentPower <= 2) and "active" or "ready"

    for i = 1, maxPower do
        if i >= startIndex and i <= endIndex then
            -- Visible on load
            holyPower[i].frame:SetAlpha(MoePower.ACTIVE_ALPHA)
            holyPower[i].active = true
            -- Update texture and alpha based on power level
            local runeNumber = runeMap[i]
            local runeAtlas = "uf-holypower-rune" .. runeNumber .. "-" .. textureVariant
            pcall(holyPower[i].foreground.SetAtlas, holyPower[i].foreground, runeAtlas)
            holyPower[i].foreground:SetAlpha(textureVariant == "active" and ACTIVE_VARIANT_ALPHA or MoePower.ACTIVE_ALPHA)
        else
            -- Hidden on load
            holyPower[i].frame:SetAlpha(0)
            holyPower[i].active = false
        end
    end

    self.lastTextureVariant = textureVariant
    return holyPower
end

-- Update holy power display based on current power
function PaladinModule:UpdatePower(orbs)
    local currentPower = UnitPower("player", self.powerType)
    local maxPower = #orbs

    -- Calculate visible range of holy power to show
    local startIndex, endIndex = MoePower:GetVisibleRange(currentPower, maxPower)

    -- Determine texture variant based on power level
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
            -- Only update texture/alpha when variant changed or orb just activated
            if variantChanged or not wasActive then
                local runeAtlas = "uf-holypower-rune" .. runeMap[i] .. "-" .. textureVariant
                pcall(orbs[i].foreground.SetAtlas, orbs[i].foreground, runeAtlas)
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
        if not UnitAffectingCombat("player") and currentPower >= maxPower then
            MoePower:ScheduleHideOrbs(orbs, 1)
        else
            MoePower:CancelHideOrbs()
        end
    end
end

-- Register this module with the framework
MoePower:RegisterClassModule(PaladinModule)
