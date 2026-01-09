local my_utility = require("my_utility/my_utility")
local menu_module = require("menu")
local spell_data = require("my_utility/spell_data")

local max_spell_range = 17.0
local max_charges = 4
local current_charges = 4
local charge_refresh_time = 0.0
local charge_cooldown = 4.0 -- 4 seconds per charge

local menu_elements = {
    tree_tab = tree_node:new(1),
    main_boolean = checkbox:new(true, get_hash(my_utility.plugin_label .. "main_boolean_evade")),
    use_out_of_combat = checkbox:new(true, get_hash(my_utility.plugin_label .. "use_out_of_combat_evade")),
    targeting_mode = combo_box:new(0, get_hash(my_utility.plugin_label .. "targeting_mode_evade")),
    mobility_only = checkbox:new(false, get_hash(my_utility.plugin_label .. "mobility_only_evade")),
    min_target_range = slider_float:new(3, max_spell_range - 1, 5, get_hash(my_utility.plugin_label .. "min_target_range_evade")),
    min_ooc_evade_range = slider_float:new(2.5, 5, 3, get_hash(my_utility.plugin_label .. "min_ooc_evade_range_evade")),
    min_cooldown = slider_float:new(0.1, 3.0, 0.2, get_hash(my_utility.plugin_label .. "min_cooldown_evade")),
    save_charges = slider_int:new(0, max_charges, 1, get_hash(my_utility.plugin_label .. "save_charges_evade")),
    debug_enabled = checkbox:new(false, get_hash(my_utility.plugin_label .. "debug_enabled_evade")) -- Disable debug by default
}

local function render_menu()
    if menu_elements.tree_tab:push("Evade") then
        menu_elements.main_boolean:render("Enable Evade - In combat", "")
        if menu_elements.main_boolean:get() then
            local options = {"Best Ranged", "Best Melee", "Best Cursor", "Closest Cursor"}
            menu_elements.targeting_mode:render("Targeting Mode", options, "How to select targets")
            menu_elements.mobility_only:render("Only use for mobility", "")
            if menu_elements.mobility_only:get() then
                menu_elements.min_target_range:render("Min Target Distance", "Minimum distance to target for mobility use", 1)
            end
            menu_elements.min_cooldown:render("Minimum Cooldown", "Minimum time between casts", 2)
            menu_elements.save_charges:render("Save Charges", "Minimum number of charges to keep reserved", 1)
            menu_elements.debug_enabled:render("Enable Debug Output", "Show detailed information about evade behavior")
        end

        menu_elements.use_out_of_combat:render("Enable Evade - Out of combat", "")
        if menu_elements.use_out_of_combat:get() then
            menu_elements.min_ooc_evade_range:render("Min Distance Out of Combat", "Minimum travel distance to use evade out of combat", 1)
        end
        
        menu_elements.tree_tab:pop()
    end
end

local evade_spell_id = spell_data.evade.spell_id
local next_time_allowed_cast = 0.0
local last_cast_time = 0.0
local last_cast_position = nil

-- Function to update charges
local function update_charges()
    local current_time = get_time_since_inject()
    
    -- If we have max charges, no need to update
    if current_charges >= max_charges then
        return
    end
    
    -- If it's time to add a charge
    if current_time >= charge_refresh_time then
        current_charges = current_charges + 1
        
        -- If we still don't have max charges, set the next refresh time
        if current_charges < max_charges then
            charge_refresh_time = current_time + charge_cooldown
        end
    end
end

local function cast(target_selector_data, best_ranged_target, best_melee_target, best_cursor_target, closest_cursor_target, closest_cursor_target_angle)
    if not menu_elements.main_boolean:get() then return false end
    
    update_charges() -- Update charges first
    
    local current_time = get_time_since_inject()
    if current_time < next_time_allowed_cast then return false end
    
    -- Check if we have enough charges
    local min_charges = menu_elements.save_charges:get()
    if current_charges <= min_charges then
        return false
    end
    
    if not (utility and utility.is_spell_ready and utility.is_spell_ready(evade_spell_id)) then return false end
    
    -- Get debug setting
    local debug_enabled = menu_elements.debug_enabled:get()
    
    -- Select target based on targeting mode
    local target = nil
    local targeting_mode = menu_elements.targeting_mode:get()
    
    if targeting_mode == 0 then
        target = best_ranged_target
    elseif targeting_mode == 1 then
        target = best_melee_target
    elseif targeting_mode == 2 then
        target = best_cursor_target
    else
        target = closest_cursor_target
    end
    
    if not target then
        return false
    end
    
    -- Check mobility only mode
    local target_pos = target:get_position()
    local player_pos = get_player_position()
    local distance = target_pos:dist_to_ignore_z(player_pos)
    
    if menu_elements.mobility_only:get() then
        local min_range = menu_elements.min_target_range:get()
        
        if distance > max_spell_range or distance < min_range then
            return false
        end
    end
    
    -- Cast the spell
    if cast_spell and cast_spell.position and cast_spell.position(evade_spell_id, target_pos, 0.0) then
        next_time_allowed_cast = current_time + menu_elements.min_cooldown:get()
        last_cast_time = current_time
        last_cast_position = target_pos
        
        -- Reduce charges and set refresh time if this is the first charge used
        current_charges = current_charges - 1
        if current_charges == max_charges - 1 then
            charge_refresh_time = current_time + charge_cooldown
        end
        
        return menu_elements.min_cooldown:get()
    end
    
    return false
end

local function out_of_combat()
    if not menu_elements.use_out_of_combat:get() then return false end
    
    update_charges() -- Update charges first
    
    local current_time = get_time_since_inject()
    if current_time < next_time_allowed_cast then return false end
    
    -- Check if we have enough charges
    local min_charges = menu_elements.save_charges:get()
    if current_charges <= min_charges then
        return false
    end
    
    if not (utility and utility.is_spell_ready and utility.is_spell_ready(evade_spell_id)) then return false end
    
    -- Get debug setting
    local debug_enabled = menu_elements.debug_enabled:get()
    
    -- Check if we are in a safezone
    local in_combat_area = my_utility.is_buff_active(spell_data.in_combat_area.spell_id, spell_data.in_combat_area.buff_id)
    if not in_combat_area then
        return false
    end
    
    local local_player = get_local_player()
    local is_moving = local_player:is_moving()
    local is_dashing = local_player:is_dashing()
    
    -- If standing still
    if not is_moving then
        return false
    end
    
    -- Handle cursor targeting modes
    local targeting_mode = menu_elements.targeting_mode:get()
    if targeting_mode == 2 or targeting_mode == 3 then -- Cursor modes
        local destination = get_cursor_position()
        if cast_spell and cast_spell.position and cast_spell.position(evade_spell_id, destination, 0.0) then
            next_time_allowed_cast = current_time + menu_elements.min_cooldown:get()
            last_cast_time = current_time
            last_cast_position = destination
            
            -- Reduce charges and set refresh time if this is the first charge used
            current_charges = current_charges - 1
            if current_charges == max_charges - 1 then
                charge_refresh_time = current_time + charge_cooldown
            end
            
            return menu_elements.min_cooldown:get()
        end
    end
    
    -- Don't spam evade if already dashing
    if is_dashing then
        return false
    end
    
    -- Check move destination distance
    local destination = local_player:get_move_destination()
    local player_pos = local_player:get_position()
    local distance = player_pos:dist_to_ignore_z(destination)
    local min_evade_distance = menu_elements.min_ooc_evade_range:get()
    
    if distance >= min_evade_distance then
        if cast_spell and cast_spell.position and cast_spell.position(evade_spell_id, destination, 0.0) then
            next_time_allowed_cast = current_time + menu_elements.min_cooldown:get()
            last_cast_time = current_time
            last_cast_position = destination
            
            -- Reduce charges and set refresh time if this is the first charge used
            current_charges = current_charges - 1
            if current_charges == max_charges - 1 then
                charge_refresh_time = current_time + charge_cooldown
            end
            
            return menu_elements.min_cooldown:get()
        end
    end
    
    return false
end

-- Add a compatible logics function that works with the main spell rotation
local function logics(target)
    -- Enable debugging to track issues
    local debug_enabled = menu_elements.debug_enabled:get()
    
    -- Basic checks
    if not menu_elements.main_boolean:get() then
        return false
    end
    
    update_charges() -- Update charges first
    
    local current_time = get_time_since_inject()
    if current_time < next_time_allowed_cast then
        return false
    end
    
    -- Check if we have enough charges
    local min_charges = menu_elements.save_charges:get()
    if current_charges <= min_charges then
        return false
    end
    
    if not (utility and utility.is_spell_ready and utility.is_spell_ready(evade_spell_id)) then
        return false
    end
    
    -- Make sure target is valid
    local target_pos
    local player_pos = get_player_position()
    
    -- During momentum stacking, target might be nil or invalid
    if not target or not target.get_position then
        -- If no valid target, use cursor position as fallback
        target_pos = get_cursor_position()
        if not target_pos then
            -- If cursor position also fails, use move destination
            local local_player = get_local_player()
            if local_player and local_player:is_moving() then
                target_pos = local_player:get_move_destination()
            else
                -- As last resort, use a point in front of player
                local direction = vec3.new(1, 0, 0) -- Forward vector
                target_pos = vec3.new(player_pos.x + 5, player_pos.y, player_pos.z) -- 5 units in front
            end
        end
    else
        target_pos = target:get_position()
    end
    
    -- Calculate distance
    local distance = target_pos:dist_to_ignore_z(player_pos)
    
    -- Check mobility only mode
    if menu_elements.mobility_only:get() then
        local min_range = menu_elements.min_target_range:get()
        
        if distance > max_spell_range or distance < min_range then
            return false
        end
    end
    
    -- Cast the spell
    if cast_spell and cast_spell.position and cast_spell.position(evade_spell_id, target_pos, 0.0) then
        next_time_allowed_cast = current_time + menu_elements.min_cooldown:get()
        last_cast_time = current_time
        last_cast_position = target_pos
        
        -- Reduce charges and set refresh time if this is the first charge used
        current_charges = current_charges - 1
        if current_charges == max_charges - 1 then
            charge_refresh_time = current_time + charge_cooldown
        end
        
        return true
    end
    
    return false
end

-- Function to check if a position is dangerous (used by auto-play movement logic)
local function is_dangerous_position(position)
    -- Simple implementation - can be expanded to check for more danger conditions
    local in_combat_area = my_utility.is_buff_active(spell_data.in_combat_area.spell_id, spell_data.in_combat_area.buff_id)
    if not in_combat_area then
        return false -- Not in a combat area, so not dangerous
    end
    
    -- Check if there are too many enemies nearby
    local danger_radius = 5.0 -- Danger detection radius
    local all_units_count = my_utility.enemy_count_in_range(danger_radius, position)
    
    -- Consider position dangerous if there are more than 5 enemies nearby
    return all_units_count > 5
end

-- Register common dangerous boss abilities
-- These registrations only happen once when the script loads
local function register_dangerous_spells()
    -- Wrap dangerous spell registrations in pcall to catch errors
    local function try_register_circular_spell(internal_names, menu_name, radius, color, danger, explosion_delay, is_moving, set_to_player, set_to_player_delay)
        local success, result = pcall(function()
            return evade.register_circular_spell(
                internal_names, 
                menu_name, 
                radius, 
                color, 
                danger, 
                explosion_delay,
                is_moving,
                set_to_player,
                set_to_player_delay
            )
        end)
        
        if not success then
            console.print("Error registering circular spell '" .. menu_name .. "': " .. tostring(result))
        end
    end
    
    local function try_register_rectangular_spell(id, names, width, length, color, is_dynamic, danger, is_project, project_speed, max_time, set_to_player, set_to_player_delay)
        local success, result = pcall(function()
            return evade.register_rectangular_spell(
                id,
                names, 
                width, length, 
                color,
                is_dynamic, 
                danger,
                is_project, 
                project_speed, 
                max_time,
                set_to_player,
                set_to_player_delay
            )
        end)
        
        if not success then
            console.print("Error registering rectangular spell '" .. id .. "': " .. tostring(result))
        end
    end
    
    local function try_register_cone_spell(id, names, radius, angle, color, danger, explosion_delay, is_moving)
        local success, result = pcall(function()
            return evade.register_cone_spell(
                id,
                names, 
                radius, 
                angle, 
                color,
                danger,
                explosion_delay,
                is_moving
            )
        end)
        
        if not success then
            console.print("Error registering cone spell '" .. id .. "': " .. tostring(result))
        end
    end

    -- Butcher abilities
    try_register_circular_spell(
        {"BossTeleportSlam"}, 
        "Teleport Slam", 
        6.0, 
        color_red(200), 
        danger_level.high, 
        0.8,
        false,
        false,
        0.5
    )
    
    try_register_circular_spell(
        {"GroundSpikes"}, 
        "Ground Spikes", 
        4.0, 
        color_orange(200), 
        danger_level.medium, 
        0.5,
        true,
        false,
        0.5
    )
    
    -- Ashava abilities
    try_register_rectangular_spell(
        "AshavasweepingStrike",
        {"SweepingStrike"}, 
        5.0, 10.0, 
        color_red(180),
        true, 
        danger_level.high,
        false, 
        0, 
        3.0,
        false,
        0.5
    )
    
    -- Generic fireballs and projectiles (many bosses use these)
    try_register_circular_spell(
        {"BossFireball", "FireballImpact"}, 
        "Boss Fireball", 
        4.0, 
        color_red(200), 
        danger_level.medium, 
        0.5,
        false,
        false,
        0.5
    )
    
    -- Poison/Plague areas
    try_register_circular_spell(
        {"PoisonCloud", "ToxicFumes"}, 
        "Poison Area", 
        4.5, 
        color_green(180), 
        danger_level.medium, 
        0.3,
        true,
        false,
        0.5
    )
end

-- Call registration once with error handling
local success, error_message = pcall(register_dangerous_spells)
if not success then
    console.print("Error in register_dangerous_spells: " .. tostring(error_message))
end

return {
    menu = render_menu,
    logics = logics,
    out_of_combat = out_of_combat,
    menu_elements = menu_elements,
    is_dangerous_position = is_dangerous_position
}
