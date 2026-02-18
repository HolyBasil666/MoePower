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

        -- Add fade animations
        local fadeInGroup, fadeOutGroup = MoePower:AddOrbAnimations(essenceFrame)

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
    local startIndex, endIndex = MoePower:GetVisibleRange(currentPower, maxPower)

    -- Show orbs if in combat OR regenerating essence
    local shouldShow = inCombat or currentPower < maxPower

    for i = 1, maxPower do
        if shouldShow and i >= startIndex and i <= endIndex then
            -- Visible on load
            essence[i].frame:SetAlpha(MoePower.ACTIVE_ALPHA)
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
    local shouldHide = not inCombat and currentPower >= maxPower

    -- Always update orb display first
    local startIndex, endIndex = MoePower:GetVisibleRange(currentPower, maxPower)

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

    -- Schedule delayed hide or cancel pending hide
    if shouldHide then
        MoePower:ScheduleHideOrbs(orbs, 1)
    else
        MoePower:CancelHideOrbs()
    end
end

-- Register this module with the framework
MoePower:RegisterClassModule(EvokerModule)
