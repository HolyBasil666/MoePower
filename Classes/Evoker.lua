-- Evoker Class Module for MoePower

local _, MoePower = ...

-- Evoker-specific configuration
local EvokerModule = {
    className = "EVOKER",
    powerType = Enum.PowerType.Essence,

    -- Visual settings
    config = {
        orbSize = 40,           -- Orb width and height
        arcRadius = 150,        -- Distance from center
        arcSpan = 55,           -- Total degrees of arc
        backgroundAtlas = "uf-essence-bg-active",  -- Background texture
        foregroundAtlas = "uf-essence-icon",       -- Foreground fill texture
        orbFallback = "Interface\\Minimap\\MiniMap-TrackingBorder",
        orbColor = {r = 0.3, g = 0.8, b = 0.9, a = 1},  -- Cyan/teal for essence (original)
        emptyColor = {r = 0.5, g = 0.5, b = 0.5, a = 0.4},  -- Gray for inactive
        glowColor = {r = 0.5, g = 1, b = 1, a = 0.6}   -- Cyan glow (original)
    }
}

-- Create essence orbs in arc formation
function EvokerModule:CreateOrbs(frame)
    local orbs = {}
    local maxPower = UnitPowerMax("player", self.powerType)
    if maxPower == 0 then
        maxPower = 6  -- Default fallback
    end

    local cfg = self.config
    local startAngle = 90 + (cfg.arcSpan / 2)  -- Start from top-left

    for i = 1, maxPower do
        -- Calculate position in arc
        local angle = startAngle - ((i - 1) * (cfg.arcSpan / (maxPower - 1)))
        local radian = math.rad(angle)
        local x = cfg.arcRadius * math.cos(radian)
        local y = cfg.arcRadius * math.sin(radian)

        -- Create orb container frame
        local orbFrame = CreateFrame("Frame", nil, frame)
        orbFrame:SetSize(cfg.orbSize, cfg.orbSize)
        orbFrame:SetPoint("CENTER", frame, "CENTER", x, y)

        -- Background essence texture (always visible)
        local background = orbFrame:CreateTexture(nil, "BACKGROUND")
        background:SetAllPoints(orbFrame)
        local bgSuccess = pcall(background.SetAtlas, background, cfg.backgroundAtlas)
        if not bgSuccess then
            background:SetColorTexture(0.2, 0.2, 0.2, 0.5)
        end

        -- Foreground essence fill texture (shows when active)
        local foreground = orbFrame:CreateTexture(nil, "ARTWORK")
        foreground:SetAllPoints(orbFrame)
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

    print("|cff00ff00MoePower:|r UpdatePower - Current: " .. currentPower .. " / Max: " .. maxPower)

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

            print("|cff00ff00MoePower:|r Showing orb " .. i)
        else
            -- Hide orb completely
            orbs[i].frame:Hide()
            orbs[i].active = false
        end
    end
end

-- Register this module with the framework
MoePower:RegisterClassModule(EvokerModule)
