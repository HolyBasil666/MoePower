-- Evoker Class Module for MoePower

local _, MoePower = ...

-- Evoker-specific configuration
local EvokerModule = {
    className = "EVOKER",
    powerType = Enum.PowerType.Essence,

    -- Visual settings
    config = {
        orbSize = 40,           -- Model width and height
        borderSize = 32,        -- Border width and height
        arcRadius = 150,        -- Distance from center
        arcSpan = 60,           -- Total degrees of arc
        modelId = 4417910,      -- spells/cfx_evoker_livingflame_precast.m2
        modelAlpha = 0.5,       -- Transparency
        borderAtlas = "uf-essence-icon",
        borderFallback = "Interface\\Minimap\\MiniMap-TrackingBorder",
        borderColor = {r = 1, g = 1, b = 1, a = 0.8},
        borderOffset = -1       -- Left offset for border
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

        -- Create orb frame with model
        local orb = CreateFrame("PlayerModel", nil, frame)
        orb:SetSize(cfg.orbSize, cfg.orbSize)
        orb:SetPoint("CENTER", frame, "CENTER", x, y)

        -- CRITICAL: Keep model loaded even when hidden
        orb:SetKeepModelOnHide(true)

        -- Set up the model using living flame spell effect
        pcall(orb.SetModel, orb, cfg.modelId)

        -- Clear any previous transforms
        orb:ClearTransform()

        -- Use old API (matching WeakAura's api: false setting)
        orb:SetPosition(0, 0, 0)  -- model_z, model_x, model_y
        orb:SetFacing(math.rad(90))  -- rotation

        -- Set transparency
        orb:SetAlpha(cfg.modelAlpha)

        -- Must call Show() for model to render
        orb:Show()

        -- Add border frame (behind model)
        local borderFrame = CreateFrame("Frame", nil, frame)
        borderFrame:SetSize(cfg.borderSize, cfg.borderSize)
        borderFrame:SetPoint("CENTER", orb, "CENTER", cfg.borderOffset, 0)
        borderFrame:SetFrameStrata("BACKGROUND")  -- Behind model

        -- Border texture - try atlas first, fallback to standard texture
        local border = borderFrame:CreateTexture(nil, "ARTWORK")
        border:SetAllPoints(borderFrame)

        -- Try to use atlas texture
        local success = pcall(border.SetAtlas, border, cfg.borderAtlas)
        if not success then
            -- Fallback to standard texture
            border:SetTexture(cfg.borderFallback)
        end
        border:SetVertexColor(cfg.borderColor.r, cfg.borderColor.g, cfg.borderColor.b, cfg.borderColor.a)

        -- Store references with clear naming
        orbs[i] = {
            animation = orb,           -- The living flame model
            background = borderFrame   -- The uf-essence-icon border
        }

        -- Start hidden (will show based on current essence)
        orb:Hide()
    end

    return orbs
end

-- Update orb display based on current power
function EvokerModule:UpdatePower(orbs)
    local currentPower = UnitPower("player", self.powerType)
    local maxPower = #orbs

    -- Calculate centered range of orbs to show
    -- For max=5: 1 essence shows pos 3, 2 shows 2-3, 3 shows 2-4, etc.
    local startIndex = math.floor((maxPower - currentPower) / 2) + 1
    local endIndex = startIndex + currentPower - 1

    for i = 1, maxPower do
        if i >= startIndex and i <= endIndex then
            orbs[i].animation:Show()  -- Show animation (model)
            if orbs[i].background then
                orbs[i].background:Show()  -- Show background (border)
            end
        else
            orbs[i].animation:Hide()  -- Hide animation
            if orbs[i].background then
                orbs[i].background:Hide()  -- Hide background
            end
        end
    end
end

-- Register this module with the framework
MoePower:RegisterClassModule(EvokerModule)
