local my_utility = require("my_utility/my_utility")
local my_target_selector = require("my_utility/my_target_selector")
local menu_module = require("menu")
-- Add enhanced targeting and enhancements manager
local enhanced_targeting = require("my_utility/enhanced_targeting")
local enhancements_manager = require("my_utility/enhancements_manager")

local menu_elements = {
    tree_tab = tree_node:new(1),
    main_boolean = checkbox:new(true, get_hash(my_utility.plugin_label .. "caltrop_enabled")),
    min_enemies = slider_int:new(1, 5, 1, get_hash(my_utility.plugin_label .. "caltrop_min_enemies")),
    cast_range = slider_float:new(1.0, 25.0, 15.0, get_hash(my_utility.plugin_label .. "caltrop_cast_range")), -- Increased range
    cast_delay = slider_float:new(0.0, 2.0, 0.05, get_hash(my_utility.plugin_label .. "caltrop_cast_delay")), -- Reduced default delay
    aoe_radius = slider_float:new(1.0, 8.0, 6.0, get_hash(my_utility.plugin_label .. "caltrop_aoe_radius")), -- Added AoE radius control
    cast_mode = combo_box:new(2, get_hash(my_utility.plugin_label .. "caltrop_cast_mode")) -- Default to Aggressive mode
}

local function render_menu()
    if menu_elements.tree_tab:push("Caltrop") then
        menu_elements.main_boolean:render("Enable Spell", "")
        if menu_elements.main_boolean:get() then
            menu_elements.min_enemies:render("Minimum Enemies", "Minimum number of enemies required")
            menu_elements.cast_range:render("Cast Range", "Maximum casting range", 1)
            menu_elements.cast_delay:render("Cast Delay", "Time between casts", 3)
            menu_elements.aoe_radius:render("AoE Check Radius", "Radius to check for enemy clusters", 1)
            local options = {"Always", "Defensive Only", "Aggressive"}
            menu_elements.cast_mode:render("Cast Mode", options, "When to use Caltrop")
        end
        menu_elements.tree_tab:pop()
    end
end

local spell_id = 389667
local next_cast_time = 0.01
local last_cast_position = nil

local function get_best_cast_position(entity_list, player_position)
    local best_pos = nil
    local max_enemies = 0
    local cast_range = menu_elements.cast_range:get()
    local aoe_radius = menu_elements.aoe_radius:get()

    -- First priority: Find position with most enemies
    for _, enemy in ipairs(entity_list) do
        local enemy_pos = enemy:get_position()
        if enemy_pos:squared_dist_to_ignore_z(player_position) <= (cast_range * cast_range) then
            local enemies_nearby = 0
            for _, other in ipairs(entity_list) do
                if enemy_pos:squared_dist_to_ignore_z(other:get_position()) <= (aoe_radius * aoe_radius) then
                    enemies_nearby = enemies_nearby + 1
                end
            end

            if enemies_nearby >= max_enemies then
                max_enemies = enemies_nearby
                best_pos = enemy_pos
            end
        end
    end

    -- Second priority: If no good cluster found or in aggressive mode, target any enemy
    if not best_pos or menu_elements.cast_mode:get() == 2 then
        for _, enemy in ipairs(entity_list) do
            local enemy_pos = enemy:get_position()
            if enemy_pos:squared_dist_to_ignore_z(player_position) <= (cast_range * cast_range) then
                return enemy_pos, 1
            end
        end
    end

    return best_pos, max_enemies
end

-- Updated logics function to handle different parameter sets
local function logics(entity_list, target_selector_data, target)
    -- Handle case when called with single target parameter
    if not target_selector_data and entity_list and entity_list.get_position then
        target = entity_list
        entity_list = actors_manager.get_enemy_npcs()
    end
    
    -- Basic checks
    if not menu_elements.main_boolean:get() then
        return false
    end

    local current_time = get_time_since_inject()
    if current_time < next_cast_time then
        return false
    end

    if not utility.is_spell_ready(spell_id) then
        return false
    end

    -- Get player position and cast mode
    local player_position = get_player_position()
    local cast_mode = menu_elements.cast_mode:get()
    
    -- Update spell range info for visualization
    local aoe_radius = menu_elements.aoe_radius:get()
    local cast_range = menu_elements.cast_range:get()
    enhancements_manager.update_spell_range("caltrop", cast_range, aoe_radius, last_cast_position)

    -- Ensure we have valid entity_list
    if not entity_list or #entity_list == 0 then
        entity_list = actors_manager.get_enemy_npcs()
        if #entity_list == 0 then
            return false
        end
    end

    -- Check for minimum enemy count (global setting)
    local all_units_count, normal_units_count, elite_units_count, champion_units_count, boss_units_count = 
        my_utility.enemy_count_in_range(aoe_radius, player_position)
    
    -- Get global minimum enemy count setting
    local global_min_enemies = menu_module.menu_elements.enemy_count_threshold:get()
    local spell_min_enemies = menu_elements.min_enemies:get()
    
    -- Use the higher of the two thresholds
    local effective_min_enemies = math.max(global_min_enemies, spell_min_enemies)
    
    -- Check if there's a boss present (bypass minimum enemy count if true)
    local boss_present = boss_units_count > 0
    
    -- Skip if not enough enemies and no boss present
    if not boss_present and all_units_count < effective_min_enemies then
        return false
    end

    -- Find best position to cast
    local cast_position, enemies_hit = get_best_cast_position(entity_list, player_position)

    -- Ensure we have a valid position
    if not cast_position then
        return false
    end

    -- Handle different cast modes
    if cast_mode == 1 then -- Defensive Only
        local local_player = get_local_player()
        if local_player:get_health_percent() > 0.90 then -- More aggressive health threshold
            return false
        end
    end
    -- Mode 2 (Aggressive) has no additional checks

    -- More permissive position reuse check
    if last_cast_position and last_cast_position:squared_dist_to_ignore_z(cast_position) < (1.5 * 1.5) then
        return false
    end

    -- Check if enhanced targeting is enabled and try to use it
    if menu_module.menu_elements.enhanced_targeting:get() and 
       menu_module.menu_elements.aoe_optimization:get() then
       
        -- Apply cast mode restrictions for defensive mode
        if cast_mode == 1 then -- Defensive Only
            local local_player = get_local_player()
            if local_player:get_health_percent() > 0.90 then
                return false
            end
        end
       
        local success, hit_count = enhanced_targeting.optimize_aoe_positioning(
            spell_id, 
            aoe_radius, 
            effective_min_enemies
        )
        
        if success then
            next_cast_time = current_time + menu_elements.cast_delay:get()
            last_cast_position = player_position -- Approximate position since we don't know exact cast position
            console.print(string.format("Rouge Plugin: Casted Caltrop using enhanced targeting, hitting ~%d enemies", hit_count))
            return true
        end
    end

    -- Attempt to cast
    if cast_spell.position(spell_id, cast_position, 0.0) then
        next_cast_time = current_time + menu_elements.cast_delay:get()
        last_cast_position = cast_position
        console.print(string.format("Rouge Plugin: Casted Caltrop hitting %d enemies", enemies_hit))
        return true
    end

    return false
end

return {
    menu = render_menu,
    logics = logics,
    menu_elements = menu_elements
}