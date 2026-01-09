local my_utility = require("my_utility/my_utility")
local buff_tracker = require("my_utility/buff_tracker")
local spell_data = require("my_utility/spell_data")

local dynamic_priority = {}

-- Default priorities from spell_priority.lua
local default_priorities = {
    "evade",
    "shadow_step",
    "dash",
    "concealment",
    "shadow_imbuement",
    "poison_imbuement",
    "cold_imbuement",
    "death_trap",
    "poison_trap",
    "smoke_grenade",
    "dark_shroud",
    "dance_of_knives",
    "rain_of_arrows",
    "penetrating_shot",
    "caltrop",
    "barrage",
    "rapid_fire",
    "forcefull_arrow",
    "flurry",
    "blade_shift",
    "shadow_clone",
    "twisting_blade",
    "invigorating_strike",
    "puncture",
    "heartseeker"
}

-- Prioritize defensive abilities
local defensive_priorities = {
    "evade",
    "dash",
    "shadow_step",
    "dark_shroud", 
    "concealment",
    "shadow_imbuement",
    "dance_of_knives",
    "rain_of_arrows",
    "penetrating_shot",
    "poison_trap",
    "smoke_grenade",
    "shadow_clone",
    "barrage",
    "flurry",
    "rapid_fire",
    "forcefull_arrow",
    "blade_shift",
    "twisting_blade",
    "invigorating_strike",
    "puncture",
    "heartseeker"
}

-- Prioritize AoE damage for groups
local aoe_priorities = {
    "evade",
    "dance_of_knives",
    "death_trap",
    "poison_trap",
    "rain_of_arrows",
    "smoke_grenade",
    "caltrop",
    "penetrating_shot",
    "shadow_imbuement",
    "poison_imbuement",
    "cold_imbuement",
    "barrage",
    "shadow_step",
    "dash",
    "flurry",
    "rapid_fire",
    "forcefull_arrow",
    "blade_shift",
    "shadow_clone",
    "concealment",
    "dark_shroud",
    "twisting_blade",
    "invigorating_strike",
    "puncture",
    "heartseeker"
}

-- Prioritize boss damage
local boss_priorities = {
    "evade",
    "shadow_step",
    "death_trap",
    "poison_trap",
    "penetrating_shot",
    "shadow_imbuement",
    "poison_imbuement",
    "cold_imbuement",
    "barrage",
    "dance_of_knives",
    "rain_of_arrows",
    "dash",
    "rapid_fire",
    "flurry",
    "forcefull_arrow",
    "blade_shift",
    "shadow_clone",
    "concealment",
    "dark_shroud",
    "twisting_blade",
    "invigorating_strike",
    "puncture",
    "heartseeker"
}

-- Prioritize burst damage
local burst_priorities = {
    "evade",
    "death_trap",
    "penetrating_shot",
    "shadow_step",
    "barrage",
    "heartseeker",
    "dash",
    "dance_of_knives",
    "rapid_fire",
    "flurry",
    "forcefull_arrow",
    "shadow_imbuement",
    "poison_imbuement",
    "cold_imbuement",
    "poison_trap",
    "rain_of_arrows",
    "blade_shift",
    "shadow_clone",
    "concealment",
    "dark_shroud",
    "twisting_blade",
    "invigorating_strike",
    "puncture",
    "caltrop"
}

-- Priority when conserving resources
local conserve_priorities = {
    "evade",
    "dash",
    "shadow_step",
    "invigorating_strike",
    "puncture",
    "concealment",
    "twisting_blade",
    "dark_shroud",
    "poison_trap",
    "caltrop",
    "shadow_imbuement",
    "poison_imbuement",
    "cold_imbuement",
    "smoke_grenade",
    "death_trap",
    "dance_of_knives",
    "rain_of_arrows",
    "penetrating_shot",
    "barrage",
    "rapid_fire",
    "flurry",
    "forcefull_arrow",
    "blade_shift",
    "shadow_clone",
    "heartseeker"
}

-- Determine combat situation and return appropriate spell priority list
function dynamic_priority.get_priorities(player, target, enemy_count)
    -- Default to standard priorities
    local priorities = default_priorities
    
    -- Get player state
    local player_health_percent = 1.0
    local energy_percent = 1.0
    
    if player then
        pcall(function()
            player_health_percent = player:get_health() / player:get_max_health()
            energy_percent = player:get_energy() / player:get_max_energy()
        end)
    end
    
    -- Check for boss target
    local is_boss = false
    if target then
        pcall(function()
            is_boss = target:is_boss()
        end)
    end
    
    -- Defensive mode when low health
    if player_health_percent < 0.40 then
        return defensive_priorities
    end
    
    -- AoE mode when fighting groups
    if enemy_count and enemy_count > 4 then
        return aoe_priorities
    end
    
    -- Boss mode when fighting bosses
    if is_boss then
        return boss_priorities
    end
    
    -- Conserve mode when energy is low
    if energy_percent < 0.25 then
        return conserve_priorities
    end
    
    -- Default priorities
    return default_priorities
end

-- Get enhanced cast sequence for specific scenarios
function dynamic_priority.get_special_sequence(condition)
    if condition == "low_health_escape" then
        return {"dark_shroud", "concealment", "shadow_step", "dash"}
    elseif condition == "burst_damage" then
        return {"shadow_step", "death_trap", "penetrating_shot", "dance_of_knives"}
    elseif condition == "group_clear" then
        return {"death_trap", "poison_trap", "rain_of_arrows", "dance_of_knives", "caltrop"}
    elseif condition == "boss_opener" then
        return {"shadow_step", "concealment", "death_trap", "penetrating_shot", "poison_trap"}
    elseif condition == "energy_regen" then
        return {"invigorating_strike", "puncture", "twisting_blade"}
    else
        return nil
    end
end

return dynamic_priority 