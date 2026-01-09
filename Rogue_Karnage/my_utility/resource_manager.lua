local my_utility = require("my_utility/my_utility")
local spell_data = require("my_utility/spell_data")

local resource_manager = {}

-- Define spell IDs for resource management
local invigorating_strike_spell_id = 420278
local death_trap_spell_id = 421161
local rain_of_arrows_spell_id = 421168
local shadow_buff_id = 421143

function resource_manager.optimize_resource_usage()
    local player = get_local_player()
    if not player then return { should_cast = false } end
    
    -- Safely get resource values with pcall
    local energy = 0
    local max_energy = 1
    local energy_percent = 1.0
    local shadow_buff_active = false
    
    local success, error_msg = pcall(function()
        energy = player:get_energy() or 0
        max_energy = player:get_max_energy() or 1
        
        -- Verify values are valid
        if not energy or not max_energy or max_energy <= 0 then
            return false
        end
        
        energy_percent = energy / max_energy
        
        -- Safely check buffs
        pcall(function()
            shadow_buff_active = player:has_buff(shadow_buff_id) or false
        end)
        
        return true
    end)
    
    if not success then
        console.print("Rouge Plugin: Resource calculation error: " .. tostring(error_msg))
        return { should_cast = false }
    end
    
    local result = {
        should_cast = false,
        recommended_spell = nil,
        energy_percent = energy_percent,
        shadow_buff_active = shadow_buff_active
    }
    
    -- Dynamic spell priorities based on resources
    if energy_percent < 0.3 then
        -- Low energy mode - prioritize energy generation
        if utility.is_spell_ready(invigorating_strike_spell_id) then
            result.should_cast = true
            result.recommended_spell = "invigorating_strike"
        end
    elseif energy_percent > 0.8 then
        -- High energy mode - prioritize high-cost, high-damage spells
        if utility.is_spell_ready(death_trap_spell_id) then
            result.should_cast = true
            result.recommended_spell = "death_trap"
        elseif utility.is_spell_ready(rain_of_arrows_spell_id) then
            result.should_cast = true
            result.recommended_spell = "rain_of_arrows"
        end
    end
    
    return result
end

function resource_manager.manage_buffs()
    local player = get_local_player()
    if not player then return false, nil end
    
    local current_time = get_time_since_inject()
    
    -- Spell IDs
    local shadow_imbuement_spell_id = 421142
    local concealment_spell_id = 421063
    local shadow_imbuement_buff_id = 421143
    local concealment_buff_id = 421063
    
    -- Safely check for buffs with error handling
    local shadow_imbuement_active = false
    local concealment_active = false
    
    local success, error_msg = pcall(function()
        -- Check for important buffs with pcall to catch errors
        local success_shadow = pcall(function()
            shadow_imbuement_active = player:has_buff(shadow_imbuement_buff_id) or false
        end)
        
        local success_concealment = pcall(function()
            concealment_active = player:has_buff(concealment_buff_id) or false
        end)
        
        if not success_shadow or not success_concealment then
            return false
        end
        
        return true
    end)
    
    if not success then
        console.print("Rouge Plugin: Buff check error: " .. tostring(error_msg))
        return false, nil
    end
    
    -- Manage imbuements
    if not shadow_imbuement_active and utility.is_spell_ready(shadow_imbuement_spell_id) then
        if cast_spell.self(shadow_imbuement_spell_id, 0.1) then
            return true, "shadow_imbuement"
        end
    end
    
    -- Maintain concealment for stealth
    if not concealment_active and 
       utility.is_spell_ready(concealment_spell_id) and 
       (not _G.last_concealment_time or current_time - _G.last_concealment_time > 30) then
        if cast_spell.self(concealment_spell_id, 0.1) then
            _G.last_concealment_time = current_time
            return true, "concealment"
        end
    end
    
    return false, nil
end

return resource_manager 