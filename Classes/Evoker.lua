-- Evoker Class Module for MoePower

local _, MoePower = ...

-- Evoker-specific configuration
local EvokerModule = {
    className = "EVOKER",
    powerType = Enum.PowerType.Essence,

    -- Timing tracking
    lastEssenceCount = 0,
    lastEssenceTime = 0,

    -- Visual settings
    config = {
        orbSize = 25,            -- Orb frame size (container)
        backgroundScale = 1.0,   -- Background texture scale (multiplier of orbSize)
        foregroundScale = 1.0,   -- Foreground texture scale (multiplier of orbSize)
        backgroundAtlas = "uf-essence-bg-active",  -- Background texture
        foregroundAtlas = "uf-essence-icon"        -- Foreground fill texture
    }
}

-- Create essence orbs in arc formation
function EvokerModule:CreateOrbs(frame, layoutConfig)
    local orbs = {}
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

        -- Create orb container frame
        local orbFrame = CreateFrame("Frame", nil, frame)
        orbFrame:SetSize(cfg.orbSize, cfg.orbSize)
        orbFrame:SetPoint("CENTER", frame, "CENTER", x, y)

        -- Background essence texture (always visible)
        local background = orbFrame:CreateTexture(nil, "BACKGROUND")
        local bgSize = cfg.orbSize * cfg.backgroundScale
        background:SetSize(bgSize, bgSize)
        background:SetPoint("CENTER", orbFrame, "CENTER", 0, 0)
        local bgSuccess = pcall(background.SetAtlas, background, cfg.backgroundAtlas)
        if not bgSuccess then
            background:SetColorTexture(0.2, 0.2, 0.2, 0.5)
        end

        -- Foreground essence fill texture (shows when active)
        local foreground = orbFrame:CreateTexture(nil, "ARTWORK")
        local fgSize = cfg.orbSize * cfg.foregroundScale
        foreground:SetSize(fgSize, fgSize)
        foreground:SetPoint("CENTER", orbFrame, "CENTER", 0, 0)
        local fgSuccess = pcall(foreground.SetAtlas, foreground, cfg.foregroundAtlas)
        if not fgSuccess then
            foreground:SetColorTexture(1, 1, 1, 1)
        end

        -- Store references
        orbs[i] = {
            frame = orbFrame,
            background = background,
            foreground = foreground,
            active = false
        }

        -- Start hidden (will show based on current essence)
        orbFrame:Hide()
    end

    return orbs
end

-- Update orb display based on current power
function EvokerModule:UpdatePower(orbs)
    local currentPower = UnitPower("player", self.powerType)
    local maxPower = #orbs
    local currentTime = GetTime()

    -- Update tracking
    if currentPower ~= self.lastEssenceCount then
        self.lastEssenceCount = currentPower
        self.lastEssenceTime = currentTime
    end

    -- Calculate centered range of orbs to show
    -- For max=5: 1 essence shows pos 3, 2 shows 2-3, 3 shows 2-4, etc.
    local startIndex = math.floor((maxPower - currentPower) / 2) + 1
    local endIndex = startIndex + currentPower - 1

    for i = 1, maxPower do
        if i >= startIndex and i <= endIndex then
            -- Show active/filled orb
            orbs[i].frame:Show()
            orbs[i].foreground:SetAlpha(1)
            orbs[i].active = true
        else
            -- Hide orb completely
            orbs[i].frame:Hide()
            orbs[i].active = false
        end
    end
end

-- Register this module with the framework
MoePower:RegisterClassModule(EvokerModule)
