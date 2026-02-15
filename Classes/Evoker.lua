-- Evoker Class Module for MoePower

local _, MoePower = ...

-- Evoker-specific configuration
local EvokerModule = {
    className = "EVOKER",
    powerType = Enum.PowerType.Essence,
    powerTypeName = "ESSENCE",

    -- Visual settings
    config = {
        orbSize = 25,            -- Orb frame size (container)
        backgroundScale = 1.0,   -- Background texture scale (multiplier of orbSize)
        foregroundScale = 1.0,   -- Foreground texture scale (multiplier of orbSize)
        activeAlpha = 1.0,       -- Alpha when essence is active
        transitionTime = 0.15,   -- Fade transition time in seconds (150ms)
        backgroundAtlas = "uf-essence-bg-active",  -- Background texture
        foregroundAtlas = "uf-essence-icon"        -- Foreground fill texture
    }
}

-- Create essence display in arc formation
function EvokerModule:CreateOrbs(frame, layoutConfig)
    local essence = {}
    local maxPower = UnitPowerMax("player", self.powerType)
    if maxPower == 0 then
        maxPower = 6  -- Default fallback
    end

    local cfg = self.config
    local arcRadius = layoutConfig.arcRadius
    local arcSpan = layoutConfig.arcSpan
    local startAngle = 90 + (arcSpan / 2)  -- Start from top-left

    for i = 1, maxPower do
        -- Calculate position in arc
        local angle = startAngle - ((i - 1) * (arcSpan / (maxPower - 1)))
        local radian = math.rad(angle)
        local x = arcRadius * math.cos(radian)
        local y = arcRadius * math.sin(radian)

        -- Create essence container frame
        local essenceFrame = CreateFrame("Frame", nil, frame)
        essenceFrame:SetSize(cfg.orbSize, cfg.orbSize)
        essenceFrame:SetPoint("CENTER", frame, "CENTER", x, y)

        -- Background essence texture (always visible)
        local background = essenceFrame:CreateTexture(nil, "BACKGROUND")
        local bgSize = cfg.orbSize * cfg.backgroundScale
        background:SetSize(bgSize, bgSize)
        background:SetPoint("CENTER", essenceFrame, "CENTER", 0, 0)
        local bgSuccess = pcall(background.SetAtlas, background, cfg.backgroundAtlas)
        if not bgSuccess then
            background:SetColorTexture(0.2, 0.2, 0.2, 0.75)
        end

        -- Foreground essence fill texture (shows when active)
        local foreground = essenceFrame:CreateTexture(nil, "ARTWORK")
        local fgSize = cfg.orbSize * cfg.foregroundScale
        foreground:SetSize(fgSize, fgSize)
        foreground:SetPoint("CENTER", essenceFrame, "CENTER", 0, 0)
        local fgSuccess = pcall(foreground.SetAtlas, foreground, cfg.foregroundAtlas)
        if not fgSuccess then
            foreground:SetColorTexture(1, 1, 1, 1)
        end

        -- Fade in animation
        local fadeInGroup = essenceFrame:CreateAnimationGroup()
        local fadeIn = fadeInGroup:CreateAnimation("Alpha")
        fadeIn:SetFromAlpha(0)
        fadeIn:SetToAlpha(cfg.activeAlpha)
        fadeIn:SetDuration(cfg.transitionTime)
        fadeIn:SetSmoothing("IN")

        fadeInGroup:SetScript("OnFinished", function()
            essenceFrame:SetAlpha(cfg.activeAlpha)
        end)

        -- Fade out animation
        local fadeOutGroup = essenceFrame:CreateAnimationGroup()
        local fadeOut = fadeOutGroup:CreateAnimation("Alpha")
        fadeOut:SetFromAlpha(cfg.activeAlpha)
        fadeOut:SetToAlpha(0)
        fadeOut:SetDuration(cfg.transitionTime)
        fadeOut:SetSmoothing("OUT")

        fadeOutGroup:SetScript("OnFinished", function()
            essenceFrame:SetAlpha(0)
        end)

        -- Store references
        essence[i] = {
            frame = essenceFrame,
            background = background,
            foreground = foreground,
            fadeIn = fadeInGroup,
            fadeOut = fadeOutGroup,
            active = false
        }

        essenceFrame:Show()
    end

    -- Initialize visibility based on current power and combat state
    local inCombat = UnitAffectingCombat("player")
    local currentPower = UnitPower("player", self.powerType)
    local startIndex = math.floor((maxPower - currentPower) / 2) + 1
    local endIndex = startIndex + currentPower - 1

    -- Show orbs if in combat OR regenerating essence
    local shouldShow = inCombat or currentPower < maxPower

    for i = 1, maxPower do
        if shouldShow and i >= startIndex and i <= endIndex then
            -- Visible on load
            essence[i].frame:SetAlpha(cfg.activeAlpha)
            essence[i].active = true
        else
            -- Hidden on load
            essence[i].frame:SetAlpha(0)
            essence[i].active = false
        end
    end

    return essence
end

-- Update essence display based on current power
function EvokerModule:UpdatePower(orbs)
    local inCombat = UnitAffectingCombat("player")
    local currentPower = UnitPower("player", self.powerType)
    local maxPower = #orbs

    -- Hide orbs only if out of combat AND at max essence
    if not inCombat and currentPower >= maxPower then
        for i = 1, maxPower do
            if orbs[i].active then
                orbs[i].fadeIn:Stop()
                orbs[i].fadeOut:Play()
                orbs[i].active = false
            end
        end
        return
    end

    -- Show orbs if in combat OR regenerating essence
    local startIndex = math.floor((maxPower - currentPower) / 2) + 1
    local endIndex = startIndex + currentPower - 1

    for i = 1, maxPower do
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
end

-- Register this module with the framework
MoePower:RegisterClassModule(EvokerModule)
