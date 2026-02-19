-- Evoker Class Module for MoePower

local _, MoePower = ...

-- Evoker-specific configuration
local EvokerModule = {
    className     = "EVOKER",
    specKeys      = { [1] = "DEVASTATION", [2] = "PRESERVATION", [3] = "AUGMENTATION" },
    powerType     = Enum.PowerType.Essence,
    powerTypeName = "ESSENCE",

    config = {
        orbSize         = 25,
        backgroundScale = 1.0,
        foregroundScale = 1.0,
        backgroundAtlas = "uf-essence-bg-active",
        foregroundAtlas = "uf-essence-icon",
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

-- Create essence display in arc or horizontal formation
function EvokerModule:CreateOrbs(frame, layoutConfig)
    local essence  = {}
    local cfg      = self.config
    local maxPower = UnitPowerMax("player", self.powerType)
    if maxPower == 0 then maxPower = 6 end

    local layout     = layoutConfig.layout or "arc"
    local arcRadius  = layoutConfig.arcRadius
    local arcSpan    = layoutConfig.arcSpan
    local startAngle = 90 + (arcSpan / 2)
    local arcStep    = maxPower > 1 and arcSpan / (maxPower - 1) or 0
    local horizStep  = cfg.orbSize + 4

    -- Hoist atlas checks outside loop: same result for every orb
    local useBgAtlas = C_Texture.GetAtlasInfo(cfg.backgroundAtlas) ~= nil
    local useFgAtlas = C_Texture.GetAtlasInfo(cfg.foregroundAtlas) ~= nil

    -- Hoist initial visibility query
    local currentPower         = UnitPower("player", self.powerType)
    local startIndex, endIndex = MoePower:GetVisibleRange(currentPower, maxPower)
    local shouldShow           = moduleInCombat or currentPower < maxPower

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

        local essenceFrame = CreateFrame("Frame", nil, frame)
        essenceFrame:SetSize(cfg.orbSize, cfg.orbSize)
        essenceFrame:SetPoint("CENTER", frame, "CENTER", x, y)

        local background = essenceFrame:CreateTexture(nil, "BACKGROUND")
        background:SetSize(cfg.orbSize * cfg.backgroundScale, cfg.orbSize * cfg.backgroundScale)
        background:SetPoint("CENTER", essenceFrame, "CENTER", 0, 0)
        if useBgAtlas then
            background:SetAtlas(cfg.backgroundAtlas)
        else
            background:SetColorTexture(1, 1, 1, 1)
        end

        local foreground = essenceFrame:CreateTexture(nil, "ARTWORK")
        foreground:SetSize(cfg.orbSize * cfg.foregroundScale, cfg.orbSize * cfg.foregroundScale)
        foreground:SetPoint("CENTER", essenceFrame, "CENTER", 0, 0)
        if useFgAtlas then
            foreground:SetAtlas(cfg.foregroundAtlas)
        else
            foreground:SetColorTexture(1, 1, 1, 1)
        end

        local fadeInGroup, fadeOutGroup = MoePower:AddOrbAnimations(essenceFrame)

        local active = shouldShow and i >= startIndex and i <= endIndex
        essenceFrame:SetAlpha(active and MoePower.ACTIVE_ALPHA or 0)

        essence[i] = {
            frame      = essenceFrame,
            background = background,
            foreground = foreground,
            fadeIn     = fadeInGroup,
            fadeOut    = fadeOutGroup,
            active     = active,
        }

        essenceFrame:Show()
    end

    return essence
end

-- Update essence display based on current power
function EvokerModule:UpdatePower(orbs)
    local currentPower     = UnitPower("player", self.powerType)
    local maxPower         = #orbs
    local shouldHide       = not moduleInCombat and currentPower >= maxPower
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

    if shouldHide then
        MoePower:ScheduleHideOrbs(orbs, 1)
    else
        MoePower:CancelHideOrbs()
    end
end

-- Register this module with the framework
MoePower:RegisterClassModule(EvokerModule)
