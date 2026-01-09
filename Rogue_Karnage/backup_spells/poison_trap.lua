local my_utility = require("my_utility/my_utility")
local menu_module = require("menu")
local my_target_selector = require("my_utility/my_target_selector")
local enhanced_targeting = require("my_utility/enhanced_targeting")
local enhancements_manager = require("my_utility/enhancements_manager")

local menu_elements =
{
    tree_tab              = tree_node:new(1),
    main_boolean          = checkbox:new(true, get_hash(my_utility.plugin_label .. "main_boolean_trap_base_pos")),
   
    trap_mode         = combo_box:new(0, get_hash(my_utility.plugin_label .. "trap_base_base_pos")),
    keybind               = keybind:new(0x01, false, get_hash(my_utility.plugin_label .. "trap_base_keybind_pos")),
    keybind_ignore_hits   = checkbox:new(true, get_hash(my_utility.plugin_label .. "keybind_ignore_min_hitstrap_base_pos")),

    min_hits              = slider_int:new(1, 20, 4, get_hash(my_utility.plugin_label .. "min_hits_to_casttrap_base_pos")),
    
    allow_percentage_hits = checkbox:new(true, get_hash(my_utility.plugin_label .. "allow_percentage_hits_trap_base_pos")),
    min_percentage_hits   = slider_float:new(0.1, 1.0, 0.50, get_hash(my_utility.plugin_label .. "min_percentage_hits_trap_base_pos")),
    soft_score            = slider_float:new(2.0, 15.0, 4.0, get_hash(my_utility.plugin_label .. "min_percentage_hits_trap_base_soft_core_pos")),

    spell_range   = slider_float:new(1.0, 15.0, 3.10, get_hash(my_utility.plugin_label .. "poison_trap_spell_range_2")),
    spell_radius   = slider_float:new(0.50, 5.0, 3.50, get_hash(my_utility.plugin_label .. "poison_trap_spell_radius_2")),
}


local function render_menu()
    
    if menu_elements.tree_tab:push("Poison Trap") then
        menu_elements.main_boolean:render("Enable Spell", "");

        local options =  {"Auto", "Keybind"};
        menu_elements.trap_mode:render("Mode", options, "");

        menu_elements.keybind:render("Keybind", "");
        menu_elements.keybind_ignore_hits:render("Keybind Ignores Min Hits", "");

        menu_elements.min_hits:render("Min Hits", "");

        menu_elements.allow_percentage_hits:render("Allow Percentage Hits", "");
        if menu_elements.allow_percentage_hits:get() then
            menu_elements.min_percentage_hits:render("Min Percentage Hits", "", 1);
            menu_elements.soft_score:render("Soft Score", "", 1);
        end       

        menu_elements.spell_range:render("Spell Range", "", 1)
        menu_elements.spell_radius:render("Spell Radius", "", 1)

        menu_elements.tree_tab:pop();
    end
end

local poison_trap_id = 416528;
local next_time_allowed_cast = 0.0;
local global_poison_trap_last_cast_time = 0.0;
local global_poison_trap_last_cast_position = nil;
local debug_console = false;

-- Main logics function that handles different parameter sets
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
    if current_time < next_time_allowed_cast then
        return false
    end

    if not utility.is_spell_ready(poison_trap_id) then
        return false
    end

    -- Get player position
    local player_position = get_player_position()
    
    -- Update spell range info for visualization
    local spell_radius = menu_elements.spell_radius:get()
    local spell_range = menu_elements.spell_range:get()
    enhancements_manager.update_spell_range("poison_trap", spell_range, spell_radius, global_poison_trap_last_cast_position)
    
    -- Handle keybind mode
    local keybind_used = menu_elements.keybind:get_state();
    local trap_mode = menu_elements.trap_mode:get();
    if trap_mode == 1 and keybind_used == 0 then
        return false
    end
    
    -- Check for minimum enemy count
    local all_units_count, normal_units_count, elite_units_count, champion_units_count, boss_units_count = 
        my_utility.enemy_count_in_range(spell_radius, player_position)
    
    -- Get minimum enemies requirement
    local global_min_enemies = menu_module.menu_elements.enemy_count_threshold:get()
    local spell_min_hits = menu_elements.min_hits:get()
    local effective_min_enemies = math.max(global_min_enemies, spell_min_hits)
    
    -- Check if there's a boss present (bypass minimum enemy count if true)
    local boss_present = boss_units_count > 0
    if boss_present and debug_console then
        console.print("poison_trap: Boss detected - bypassing minimum enemy count requirement")
    end
    
    -- Skip if not enough enemies and not using keybind override and no boss present
    local keybind_ignore_hits = menu_elements.keybind_ignore_hits:get()
    local keybind_can_skip = keybind_ignore_hits and keybind_used > 0;
    
    if not (keybind_can_skip or boss_present) and all_units_count < effective_min_enemies then
        if debug_console then
            console.print(string.format("poison_trap: Not enough enemies (%d < %d required)", 
                all_units_count, effective_min_enemies))
        end
        return false
    end
    
    -- Get percentage hit settings
    local min_percentage = 0.0
    if menu_elements.allow_percentage_hits:get() then
        min_percentage = menu_elements.min_percentage_hits:get()
    end
    
    -- Find best position to cast
    local area_data = my_target_selector.get_most_hits_circular(player_position, spell_range, spell_radius)
    
    -- Check if we have a valid target
    if not area_data.main_target then
        if debug_console then
            console.print("poison_trap: No main target found")
        end
        return false
    end
    
    -- Validate the area data
    local is_area_valid = my_target_selector.is_valid_area_spell_aio(area_data, spell_min_hits, entity_list, min_percentage)
    if not is_area_valid and not keybind_can_skip then
        if debug_console then
            console.print("poison_trap: Area not valid")
        end
        return false
    end
    
    -- Ensure target is an enemy
    if not area_data.main_target:is_enemy() then
        if debug_console then
            console.print("poison_trap: Main target is not an enemy")
        end
        return false
    end
    
    -- Check for elite/champion/boss enemies
    local contains_relevant = false
    for _, victim in ipairs(area_data.victim_list) do
        if victim:is_elite() or victim:is_champion() or victim:is_boss() then
            contains_relevant = true
            break
        end
    end
    
    -- Skip if no relevant targets and score is too low
    if not contains_relevant and area_data.score < menu_elements.soft_score:get() and not keybind_can_skip then
        if debug_console then
            console.print("poison_trap: No relevant targets and score too low")
        end
        return false
    end
    
    -- Get best cast position
    local cast_position = area_data.main_target:get_position()
    local best_cast_data = my_utility.get_best_point(cast_position, spell_radius, area_data.victim_list)
    
    -- Ensure cast position is in range
    local closest_distance_sqr = math.huge
    for _, victim in ipairs(best_cast_data.victim_list) do
        local distance_sqr = player_position:squared_dist_to_ignore_z(victim:get_position())
        closest_distance_sqr = math.min(closest_distance_sqr, distance_sqr)
    end
    
    if closest_distance_sqr > (spell_range * spell_range) and not keybind_can_skip then
        if debug_console then
            console.print("poison_trap: Target too far")
        end
        return false
    end
    
    -- Check if enhanced targeting is enabled and try to use it
    if menu_module.menu_elements.enhanced_targeting:get() and 
       menu_module.menu_elements.aoe_optimization:get() then
        local success, hit_count = enhanced_targeting.optimize_aoe_positioning(
            poison_trap_id, 
            spell_radius, 
            effective_min_enemies
        )
        
        if success then
            next_time_allowed_cast = current_time + 3.0
            global_poison_trap_last_cast_time = current_time
            console.print(string.format("Rouge Plugin: Casted Poison Trap using enhanced targeting, hitting ~%d enemies", hit_count))
            return true
        end
    end
    
    -- Cast the spell
    if cast_spell.position(poison_trap_id, best_cast_data.point, 0.40) then
        next_time_allowed_cast = current_time + 3.0
        global_poison_trap_last_cast_time = current_time
        global_poison_trap_last_cast_position = best_cast_data.point
        console.print("Rouge Plugin: Casted Poison Trap")
        return true
    end
    
    return false
end

return {
    menu = render_menu,
    logics = logics,
    menu_elements = menu_elements
}