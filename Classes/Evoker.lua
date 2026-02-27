-- Evoker Class Module for MoePower

local _, MoePower = ...

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

-- Hide when out of combat AND at full essence (essence regenerates, so showing while regenerating)
function EvokerModule:ShouldHideOOC(currentPower, maxPower)
    return currentPower >= maxPower
end

MoePower:RegisterClassModule(EvokerModule)
