local my_utility = require("my_utility/my_utility")
local menu_module = require("menu")
local enhanced_targeting = require("my_utility/enhanced_targeting")
local enhancements_manager = require("my_utility/enhancements_manager")
local evade = require("spells/evade")
local poison_imbuement = require("spells/poison_imbuement")

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

local function get_resource_percent()
    local player = get_local_player()
    if not player or type(player.get_primary_resource_current) ~= "function" or type(player.get_primary_resource_max) ~= "function" then
        return nil
    end
    local current = player:get_primary_resource_current()
    local max = player:get_primary_resource_max()
    if not current or not max or max == 0 then
        return nil
    end
    return current / max
end

        dance_of_knives_menu_elements_base.main_tab:pop()
    end
end

local spell_id_dance_of_knives = 1690398
local next_time_allowed_cast = 0.0
local is_currently_channeling = false
local last_target_position = nil
local last_channel_check_time = 0.0
local channel_check_interval = 0.15
local last_cast_time = 0.0
local cast_interval = 4.0 -- Cast every 12 seconds (after Shadow Clone's 10s)
local last_no_enemy_log_time = 0.0

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
    local distance = dance_of_knives_menu_elements_base.distance:get() * 1.5
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
    if false and not poison_imbuement.is_active() then
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

    -- Cross-check with actual enemy units to avoid ghost counts
    local real_enemy_in_range = false
    do
        local enemies = actors_manager.get_enemy_npcs()
        for _, enemy in ipairs(enemies) do
            if enemy:is_enemy() then
                local pos = enemy:get_position()
                if pos and pos:dist_to(player_position) <= distance then
                    real_enemy_in_range = true
                    break
                end
            end
        end
    end

    -- If there are no enemies at all nearby, do nothing
    if all_units_count == 0 or not real_enemy_in_range then
        return false
    end

    -- Get global minimum enemy count setting
    local global_min_enemies = menu_module.menu_elements.enemy_count_threshold:get()
    local effective_min_enemies = math.max(global_min_enemies, 3)
    
    -- Check if there's a boss present (bypass minimum enemy count if true)
    local boss_present = boss_units_count > 0
    
    -- Skip if not enough enemies total and no boss present
    if not boss_present and all_units_count < effective_min_enemies then
        local now = current_time
        if now - last_no_enemy_log_time > 1.0 then
            console.print("Dance of Knives: Not enough enemies to cast")
            last_no_enemy_log_time = now
        end
        return false
    end

    -- Fallback logic: Cast Dance of Knives at player position (Whirlwind-style spin)
    if all_units_count >= effective_min_enemies or boss_present then
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
