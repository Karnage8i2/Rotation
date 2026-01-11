local my_utility = require("my_utility/my_utility")

local enhanced_evade = {}

-- Define spell IDs
local shadow_step_spell_id = 420327
local dash_spell_id = 420268

-- Create a wrapper for the evade module with fallback implementations
local evade_wrapper = {}

-- Initialize the wrapper
function evade_wrapper.initialize()
    -- Check if global evade exists
    if _G.evade then
        -- Copy all existing methods from global evade
        for k, v in pairs(_G.evade) do
            evade_wrapper[k] = v
        end
        
        -- Report what we found
        console.print("Rogue Plugin: Found evade module, creating compatibility wrapper")
    else
        console.print("Rogue Plugin: No evade module found, using fallback implementations")
    end
    
    -- Add fallback implementations for missing methods
    if type(evade_wrapper.register_circular_spell) ~= "function" then
        evade_wrapper.register_circular_spell = function(id, radius, delay)
            console.print("Rogue Plugin: Using fallback register_circular_spell")
            return true -- Return success
        end
    end
    
    if type(evade_wrapper.get_dangerous_areas) ~= "function" then
        -- Fallback implementation that returns an empty table
        evade_wrapper.get_dangerous_areas = function()
            return {}
        end
    end
    
    if type(evade_wrapper.set_evade_cooldown) ~= "function" then
        evade_wrapper.set_evade_cooldown = function(cooldown)
            console.print("Rogue Plugin: Using fallback set_evade_cooldown: " .. tostring(cooldown))
            return true
        end
    end
    
    if type(evade_wrapper.execute_evade) ~= "function" then
        evade_wrapper.execute_evade = function()
            console.print("Rogue Plugin: No execute_evade method available")
            return false
        end
    end
    
    -- Simple implementation for dangerous position checks
    if type(evade_wrapper.is_dangerous_position) ~= "function" then
        evade_wrapper.is_dangerous_position = function(position)
            -- Simple implementation - check if there are too many enemies nearby
            local danger_radius = 5.0
            local all_units_count = my_utility.enemy_count_in_range(danger_radius, position)
            
            -- Consider position dangerous if there are more than 5 enemies nearby
            return all_units_count > 5
        end
    end
    
    return true
end

-- Initialize the wrapper right away
evade_wrapper.initialize()

function enhanced_evade.setup_evade(cooldown_seconds)
    -- We always return true now because we have fallbacks
    console.print("Rogue Plugin: Enhanced evade initialized with compatibility layer")
    
    -- Try to set cooldown
    local cooldown_set = pcall(function()
        evade_wrapper.set_evade_cooldown(cooldown_seconds or 6)
    end)
    
    if not cooldown_set then
        console.print("Rogue Plugin: Warning - couldn't set evade cooldown")
    end
    
    return true
end

function enhanced_evade.enhanced_evade_logics()
    -- Attempt to get dangerous areas
    local dangerous_areas = {}
    pcall(function()
        dangerous_areas = evade_wrapper.get_dangerous_areas() or {}
    end)
    
    if not dangerous_areas or #dangerous_areas == 0 then
        return false -- No dangerous areas
    end
    
    local player_pos = get_player_position()
    if not player_pos then
        return false -- No valid player position
    end
    
    -- Check if shadow step is available
    if utility.is_spell_ready(shadow_step_spell_id) then
        -- Find safe positions to shadow step to
        local safe_positions = {}
        local radius = 10.0
        local num_points = 12
        
        for i = 1, num_points do
            local angle = (i - 1) * (2 * math.pi / num_points)
            local x = player_pos:x() + radius * math.cos(angle)
            local y = player_pos:y() + radius * math.sin(angle)
            local test_pos = vec3.new(x, y, player_pos:z())
            
            -- Check if position is safe from all dangerous areas
            local is_safe = true
            for _, area in ipairs(dangerous_areas) do
                if area and type(area.contains_point) == "function" and area:contains_point(test_pos) then
                    is_safe = false
                    break
                end
            end
            
            if is_safe and utility.is_point_walkeable(test_pos) then
                table.insert(safe_positions, test_pos)
            end
        end
        
        -- Use shadow step to teleport to safe position
        if #safe_positions > 0 then
            if cast_spell.position(shadow_step_spell_id, safe_positions[1], 0.1) then
                console.print("Enhanced Evade: Used Shadow Step to evade danger")
                return true
            end
        end
    end
    
    -- Try dash as a fallback
    if utility.is_spell_ready(dash_spell_id) then
        local current_time = get_time_since_inject()
        if not _G.last_dash_time or current_time - _G.last_dash_time > 5 then
            -- Find escape direction (away from danger)
            local escape_dir = vec3.new(0, 0, 0)
            for _, area in ipairs(dangerous_areas) do
                if area and type(area.get_center) == "function" then
                    pcall(function()
                        local area_center = area:get_center()
                        if not area_center then return end
                        
                        -- Safely calculate direction
                        local direction = nil
                        pcall(function()
                            direction = player_pos:subtract(area_center)
                            if direction and direction:length_3d() > 0 then
                                direction = direction:normalize()
                                escape_dir = escape_dir:add(direction)
                            end
                        end)
                    end)
                end
            end
            
            if escape_dir:length_3d() > 0 then
                escape_dir = escape_dir:normalize()
                local dash_pos = player_pos:add(escape_dir:multiply(5.0))
                
                if utility.is_point_walkeable(dash_pos) then
                    if cast_spell.position(dash_spell_id, dash_pos, 0.1) then
                        _G.last_dash_time = current_time
                        console.print("Enhanced Evade: Used Dash to evade danger")
                        return true
                    end
                end
            end
        end
    end
    
    -- Fall back to regular evade if our skills aren't available
    local evade_successful = false
    pcall(function()
        evade_successful = evade_wrapper.execute_evade()
    end)
    
    if evade_successful then
        console.print("Enhanced Evade: Used standard evade")
    end
    
    return evade_successful
end

return enhanced_evade 