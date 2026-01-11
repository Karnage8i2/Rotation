local my_utility = require("my_utility/my_utility")
local menu_module = require("menu")
local enhanced_targeting = require("my_utility/enhanced_targeting")
local enhancements_manager = require("my_utility/enhancements_manager")
local evade = require("spells/evade")
local shadow_imbuement = require("spells/shadow_imbuement")

local dance_of_knives_menu_elements_base =
{
    main_tab           = tree_node:new(1),
    main_boolean       = checkbox:new(true, get_hash(my_utility.plugin_label .. "disable_enable_dance")),
    distance   = slider_float:new(1.0, 20.0, 7.50, get_hash(my_utility.plugin_label .. "dance_knives_distance")),
    animation_delay   = slider_float:new(0.0, 5.0, 0.00, get_hash(my_utility.plugin_label .. "dance_knives_animation_delay")),
    interval   = slider_float:new(0.0, 5.0, 0.40, get_hash(my_utility.plugin_label .. "dance_knives_interval")),
    dynamic_position = checkbox:new(true, get_hash(my_utility.plugin_label .. "dance_knives_dynamic_position")),
    pause_in_danger = checkbox:new(true, get_hash(my_utility.plugin_label .. "dance_knives_pause_in_danger")),
}

local function render_menu()
    if dance_of_knives_menu_elements_base.main_tab:push("Dance of Knives") then
        dance_of_knives_menu_elements_base.main_boolean:render("Enable Spell", "")

        if dance_of_knives_menu_elements_base.main_boolean:get() then
            dance_of_knives_menu_elements_base.distance:render("Distance", "", 2)
            dance_of_knives_menu_elements_base.animation_delay:render("Animation Delay", "", 2)
            dance_of_knives_menu_elements_base.interval:render("Interval", "", 2)
            dance_of_knives_menu_elements_base.dynamic_position:render("Dynamic Positioning", "Automatically update position as enemies move")
            dance_of_knives_menu_elements_base.pause_in_danger:render("Pause in Danger", "Pause channeling when in dangerous area")
        end

        dance_of_knives_menu_elements_base.main_tab:pop()
    end
end

local spell_id_dance_of_knives = 1690398
local next_time_allowed_cast = 0.0
local is_currently_channeling = false
local last_target_position = nil
local last_channel_check_time = 0.0
local channel_check_interval = 0.25
local last_cast_time = 0.0
local cast_interval = 12.0 -- Cast every 12 seconds (after Shadow Clone's 10s)

-- Track Shadow Clone cast time
local last_shadow_clone_time = 0.0

local function update_channel_position()
    if not is_currently_channeling or not dance_of_knives_menu_elements_base.dynamic_position:get() then
        return
    end

    local current_time = get_time_since_inject()
    if current_time - last_channel_check_time < channel_check_interval then
        return
    end

    last_channel_check_time = current_time

    -- Find the best target position
    local player_position = get_player_position()
    local distance = dance_of_knives_menu_elements_base.distance:get()
    local enemies = actors_manager.get_enemy_npcs()
    local best_pos = nil
    local most_enemies = 0

    for _, enemy in ipairs(enemies) do
        local enemy_pos = enemy:get_position()
        local nearby_count = 0

        for _, other in ipairs(enemies) do
            if enemy_pos:dist_to(other:get_position()) <= distance then
                nearby_count = nearby_count + 1
            end
        end

        if nearby_count > most_enemies then
            most_enemies = nearby_count
            best_pos = enemy_pos
        end
    end

    -- Update the channel position if we found a better one
    if best_pos and (not last_target_position or best_pos:dist_to(last_target_position) > 2.0) then
        cast_spell.update_channel_spell_position(spell_id_dance_of_knives, best_pos)
        last_target_position = best_pos
        console.print("Updated Dance of Knives position")
    end

    -- Check if we need to pause in dangerous areas
    if dance_of_knives_menu_elements_base.pause_in_danger:get() and evade and type(evade.is_dangerous_position) == "function" and evade.is_dangerous_position(player_position) then
        cast_spell.pause_specific_channel_spell(spell_id_dance_of_knives, 1.0)
        console.print("Paused Dance of Knives due to danger")
    end
end

local function logics(target)
    -- Update channel position if already channeling
    update_channel_position()

    -- Check if already channeling
    if cast_spell.is_channel_spell_active(spell_id_dance_of_knives) then
        is_currently_channeling = true
        return false
    else
        is_currently_channeling = false
    end

    local menu_boolean = dance_of_knives_menu_elements_base.main_boolean:get()
    local current_time = get_time_since_inject()
    
    -- Check if enough time has passed since last cast
    if current_time - last_cast_time < cast_interval then
        return false
    end
    
    local is_logic_allowed = my_utility.is_spell_allowed(
        menu_boolean,
        next_time_allowed_cast,
        spell_id_dance_of_knives)

    if not is_logic_allowed then
        return false
    end

    -- Check if Shadow Imbuement is active (core requirement)
    if not shadow_imbuement.is_active() then
        console.print("Dance of Knives: Waiting for Shadow Imbuement to be active")
        return false
    end

    local player_position = get_player_position()
    
    -- Update spell range info for visualization
    local distance = dance_of_knives_menu_elements_base.distance:get()
    enhancements_manager.update_spell_range("dance_of_knives", distance, distance, last_target_position)
    
    -- Check for minimum enemy count (global setting)
    local all_units_count, normal_units_count, elite_units_count, champion_units_count, boss_units_count = 
        my_utility.enemy_count_in_range(distance, player_position)
    
    -- Get global minimum enemy count setting
    local global_min_enemies = menu_module.menu_elements.enemy_count_threshold:get()
    
    -- Check if there's a boss present (bypass minimum enemy count if true)
    local boss_present = boss_units_count > 0
    
    -- Skip if not enough enemies total and no boss present
    if not boss_present and all_units_count < global_min_enemies then
        console.print("Dance of Knives: Not enough enemies to cast")
        return false
    end

    -- Check if enhanced targeting is enabled and try to use it
    if menu_module.menu_elements.enhanced_targeting:get() and 
       menu_module.menu_elements.aoe_optimization:get() then
        
    local best_position = nil
        local hit_count = 0
        
        -- Use enhanced targeting to find optimal position
        local enemies = utility.get_units_inside_circle_list(player_position, distance * 1.5)
        if #enemies >= global_min_enemies or boss_present then
            -- Find optimal position with enhanced targeting
            local positions = {}
            local max_enemies = 0
            
            -- Grid search for optimal position
            local search_radius = distance
            local step_size = 2.0
            
            for x = -search_radius, search_radius, step_size do
                for y = -search_radius, search_radius, step_size do
                    local test_pos = vec3.new(
                        player_position:x() + x,
                        player_position:y() + y,
                        player_position:z()
                    )
                    
                    -- Count enemies that would be hit
                    local enemies_hit = 0
                    for _, enemy in ipairs(enemies) do
                        local enemy_pos = enemy:get_position()
                        if test_pos:dist_to(enemy_pos) <= distance then
                            enemies_hit = enemies_hit + 1
                end
            end
            
                    if enemies_hit > max_enemies then
                        max_enemies = enemies_hit
                        best_position = test_pos
                        hit_count = enemies_hit
            end
        end
    end

            if best_position and hit_count >= global_min_enemies then
        is_currently_channeling = true
        last_target_position = best_position
        
        -- Start channel with better parameters
        cast_spell.add_channel_spell(
            spell_id_dance_of_knives,
            0, -- start immediately
            15, -- longer duration (15 seconds)
            nil, -- no target
            best_position,
            dance_of_knives_menu_elements_base.animation_delay:get(),
            dance_of_knives_menu_elements_base.interval:get()
        )
        
                last_cast_time = current_time
        next_time_allowed_cast = current_time
                console.print(string.format("Rouge Plugin: Channeling Dance of Knives using enhanced targeting with %d enemies", hit_count))
        return true
            end
        end
    end

    -- Fallback logic: Cast Dance of Knives at player position if enhanced targeting is disabled or didn't find a position
    if all_units_count >= global_min_enemies or boss_present then
        console.print("Dance of Knives: Using fallback logic to cast at player position")
        is_currently_channeling = true
        last_target_position = player_position
        
        -- Start channel at player position
        cast_spell.add_channel_spell(
            spell_id_dance_of_knives,
            0, -- start immediately
            15, -- longer duration (15 seconds)
            nil, -- no target
            player_position,
            dance_of_knives_menu_elements_base.animation_delay:get(),
            dance_of_knives_menu_elements_base.interval:get()
        )
        
        last_cast_time = current_time
        next_time_allowed_cast = current_time
        console.print(string.format("Rouge Plugin: Channeling Dance of Knives at player position with %d enemies", all_units_count))
        return true
    end
    
    console.print("Dance of Knives: No suitable conditions met for casting")

    return false
end

return
{
    menu = render_menu,
    logics = logics,
    update_channel = update_channel_position
}
