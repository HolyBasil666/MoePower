-- Paladin Class Module for MoePower

local _, MoePower = ...

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
        activeAlpha = 1.0,       -- Alpha when holy power is active
        transitionTime = 0.15,   -- Fade transition time in seconds (150ms)
        backgroundAtlas = nil,   -- No background texture
        -- foregroundAtlas = "uf-holypower-rune1-ready"  -- Foreground fill texture
    }
}

-- Create holy power display in arc formation
function PaladinModule:CreateOrbs(frame, layoutConfig)
    local holyPower = {}
    local maxPower = 5  -- Paladin holy power is always 5

    local cfg = self.config
    local arcRadius = layoutConfig.arcRadius
    local arcSpan = layoutConfig.arcSpan
    local startAngle = 90 + (arcSpan / 2)  -- Start from top-left

    -- Rune texture mapping for positions 1-5
    local runeMap = {4, 2, 1, 3, 5}

    for i = 1, maxPower do
        -- Calculate position in arc
        local angle = startAngle - ((i - 1) * (arcSpan / (maxPower - 1)))
        local radian = math.rad(angle)
        local x = arcRadius * math.cos(radian)
        local y = arcRadius * math.sin(radian)

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

        -- Fade in animation
        local fadeInGroup = powerFrame:CreateAnimationGroup()
        local fadeIn = fadeInGroup:CreateAnimation("Alpha")
        fadeIn:SetFromAlpha(0)
        fadeIn:SetToAlpha(cfg.activeAlpha)
        fadeIn:SetDuration(cfg.transitionTime)
        fadeIn:SetSmoothing("IN")

        fadeInGroup:SetScript("OnFinished", function()
            powerFrame:SetAlpha(cfg.activeAlpha)
        end)

        -- Fade out animation
        local fadeOutGroup = powerFrame:CreateAnimationGroup()
        local fadeOut = fadeOutGroup:CreateAnimation("Alpha")
        fadeOut:SetFromAlpha(cfg.activeAlpha)
        fadeOut:SetToAlpha(0)
        fadeOut:SetDuration(cfg.transitionTime)
        fadeOut:SetSmoothing("OUT")

        fadeOutGroup:SetScript("OnFinished", function()
            powerFrame:SetAlpha(0)
        end)

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
    local startIndex = math.floor((maxPower - currentPower) / 2) + 1
    local endIndex = startIndex + currentPower - 1

    -- Determine texture variant based on power level
    local textureVariant = (currentPower <= 2) and "active" or "ready"

    for i = 1, maxPower do
        if i >= startIndex and i <= endIndex then
            -- Visible on load
            holyPower[i].frame:SetAlpha(cfg.activeAlpha)
            holyPower[i].active = true
            -- Update texture based on power level
            local runeNumber = runeMap[i]
            local runeAtlas = "uf-holypower-rune" .. runeNumber .. "-" .. textureVariant
            pcall(holyPower[i].foreground.SetAtlas, holyPower[i].foreground, runeAtlas)
        else
            -- Hidden on load
            holyPower[i].frame:SetAlpha(0)
            holyPower[i].active = false
        end
    end

    return holyPower
end

-- Update holy power display based on current power
function PaladinModule:UpdatePower(orbs)
    local currentPower = UnitPower("player", self.powerType)
    local maxPower = #orbs

    -- Calculate centered range of holy power to show
    local startIndex = math.floor((maxPower - currentPower) / 2) + 1
    local endIndex = startIndex + currentPower - 1

    -- Determine texture variant based on power level
    local textureVariant = (currentPower <= 2) and "active" or "ready"

    -- Rune texture mapping for positions 1-5
    local runeMap = {4, 2, 1, 3, 5}

    for i = 1, maxPower do
        if i >= startIndex and i <= endIndex then
            if not orbs[i].active then
                orbs[i].fadeOut:Stop()
                orbs[i].fadeIn:Play()
                orbs[i].active = true
            end
            -- Update texture based on power level
            local runeNumber = runeMap[i]
            local runeAtlas = "uf-holypower-rune" .. runeNumber .. "-" .. textureVariant
            pcall(orbs[i].foreground.SetAtlas, orbs[i].foreground, runeAtlas)
        else
            if orbs[i].active then
                orbs[i].fadeIn:Stop()
                orbs[i].fadeOut:Play()
                orbs[i].active = false
            end
        end
    end
end

-- Register this module with the framework
MoePower:RegisterClassModule(PaladinModule)
