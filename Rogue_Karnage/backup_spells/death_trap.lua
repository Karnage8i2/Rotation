local my_utility = require("my_utility/my_utility")
local my_target_selector = require("my_utility/my_target_selector")
local menu_module = require("menu")
local enhanced_targeting = require("my_utility/enhanced_targeting")
local enhancements_manager = require("my_utility/enhancements_manager")

local menu_elements =
{
    tree_tab              = tree_node:new(1),
    main_boolean          = checkbox:new(true, get_hash(my_utility.plugin_label .. "main_boolean_trap_base")),
   
    trap_mode            = combo_box:new(0, get_hash(my_utility.plugin_label .. "trap_base_base")),
    keybind              = keybind:new(0x01, false, get_hash(my_utility.plugin_label .. "trap_base_keybind")),
    keybind_ignore_hits  = checkbox:new(true, get_hash(my_utility.plugin_label .. "keybind_ignore_min_hitstrap_base")),

    min_hits             = slider_int:new(1, 20, 1, get_hash(my_utility.plugin_label .. "min_hits_to_casttrap_base")),
    
    allow_percentage_hits = checkbox:new(true, get_hash(my_utility.plugin_label .. "allow_percentage_hits_trap_base")),
    min_percentage_hits   = slider_float:new(0.1, 1.0, 0.55, get_hash(my_utility.plugin_label .. "min_percentage_hits_trap_base")),
    spell_range          = slider_float:new(1.0, 15.0, 3.50, get_hash(my_utility.plugin_label .. "death_trap_spell_range_2")),
    spell_radius         = slider_float:new(0.50, 10.0, 5.50, get_hash(my_utility.plugin_label .. "death_trap_spell_radius_2")),
    debug_enabled        = checkbox:new(false, get_hash(my_utility.plugin_label .. "debug_enabled_death_trap")),
}

local function render_menu()
    if menu_elements.tree_tab:push("Death Trap") then
        menu_elements.main_boolean:render("Enable Spell", "");

        local options =  {"Auto", "Keybind"};
        menu_elements.trap_mode:render("Mode", options, "");

        menu_elements.keybind:render("Keybind", "");
        menu_elements.keybind_ignore_hits:render("Keybind Ignores Min Hits", "");

        menu_elements.min_hits:render("Min Hits", "");

        menu_elements.allow_percentage_hits:render("Allow Percentage Hits", "");
        if menu_elements.allow_percentage_hits:get() then
            menu_elements.min_percentage_hits:render("Min Percentage Hits", "", 1);
        end       

        menu_elements.spell_range:render("Spell Range", "", 1)
        menu_elements.spell_radius:render("Spell Radius", "", 1)
        menu_elements.debug_enabled:render("Enable Debug", "Show debug information")

        menu_elements.tree_tab:pop();
    end
end

local death_trap_spell_id = 421161;
local next_time_allowed_cast = 0.01;

local function logics(entity_list, target_selector_data, best_target)
    local debug_enabled = menu_elements.debug_enabled:get()
    
    -- Basic checks
    if not menu_elements.main_boolean:get() then
        if debug_enabled then console.print("Death Trap: Disabled in menu") end
        return false
    end

    local current_time = get_time_since_inject()
    if current_time < next_time_allowed_cast then
        if debug_enabled then console.print("Death Trap: On cooldown") end
        return false
    end

    if not (utility and utility.is_spell_ready and utility.is_spell_ready(death_trap_spell_id)) then
        if debug_enabled then console.print("Death Trap: Spell not ready") end
        return false
    end
    
    -- Get player position
    local player_position = get_player_position()
    
    -- Handle keybind mode
    local keybind_used = menu_elements.keybind:get_state()
    local trap_mode = menu_elements.trap_mode:get()
    if trap_mode == 1 and keybind_used == 0 then
        if debug_enabled then console.print("Death Trap: Keybind not pressed") end
        return false
    end
    
    -- Check if we have a valid entity list
    if not entity_list or #entity_list == 0 then
        if debug_enabled then console.print("Death Trap: No entities in list") end
        return false
    end
    
    -- Get spell parameters
    local spell_range = menu_elements.spell_range:get()
    local spell_radius = menu_elements.spell_radius:get()

    -- Update spell range info for visualization
    enhancements_manager.update_spell_range("death_trap", spell_range, spell_radius)
    
    -- Check for minimum enemy count (global setting)
    local all_units_count, normal_units_count, elite_units_count, champion_units_count, boss_units_count = 
        my_utility.enemy_count_in_range(spell_radius, player_position)
    
    if debug_enabled then
        console.print(string.format("Death Trap: Found %d units (%d normal, %d elite, %d champion, %d boss)", 
            all_units_count, normal_units_count, elite_units_count, champion_units_count, boss_units_count))
    end
    
    -- Get global minimum enemy count setting
    local global_min_enemies = menu_module.menu_elements.enemy_count_threshold:get()
    local spell_min_hits = menu_elements.min_hits:get()
    
    -- Use the higher of the two thresholds
    local effective_min_enemies = math.max(global_min_enemies, spell_min_hits)
    
    -- Check if there's a boss present (bypass minimum enemy count if true)
    local boss_present = boss_units_count > 0
    if boss_present and debug_enabled then
        console.print("Death Trap: Boss detected - bypassing minimum enemy count requirement")
    end
    
    -- Skip if not enough enemies and not using keybind override and no boss present
    local keybind_ignore_hits = menu_elements.keybind_ignore_hits:get()
    local can_bypass_threshold = (trap_mode == 1 and keybind_used > 0 and keybind_ignore_hits)
    
    if not (can_bypass_threshold or boss_present) and all_units_count < effective_min_enemies then
        if debug_enabled then 
            console.print(string.format("Death Trap: Not enough enemies (%d < %d required)", 
                all_units_count, effective_min_enemies))
        end
        return false
    end

    local area_data = my_target_selector.get_most_hits_circular(player_position, spell_range, spell_radius)
    if not area_data.main_target then
        if debug_enabled then console.print("Death Trap: No main target found") end
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
    
    if closest_distance_sqr > (spell_range * spell_range) and not (trap_mode == 1 and keybind_used > 0 and keybind_ignore_hits) then
        if debug_enabled then
            console.print("Death Trap: Target too far")
        end
        return false
    end
    
    -- Check walkability of the cast position
    if not (utility and utility.is_point_walkeable and utility.is_point_walkeable(best_cast_data.point)) then
        if debug_enabled then
            console.print("Death Trap: Target position not walkable")
        end
        
        -- Try to find an alternative nearby walkable position
        local alternative_positions = {}
        local radius = 2.0
        local num_points = 8
        
        for i = 1, num_points do
            local angle = (i - 1) * (2 * math.pi / num_points)
            local x = best_cast_data.point:x() + radius * math.cos(angle)
            local y = best_cast_data.point:y() + radius * math.sin(angle)
            local alt_pos = vec3.new(x, y, best_cast_data.point:z())
            
            if utility and utility.is_point_walkeable and utility.is_point_walkeable(alt_pos) then
                table.insert(alternative_positions, alt_pos)
            end
        end
        
        -- Use the closest walkable position if any were found
        if #alternative_positions > 0 then
            local best_alt_pos = nil
            local min_dist = math.huge
            
            for _, pos in ipairs(alternative_positions) do
                local dist = player_position:dist_to(pos)
                if dist < min_dist then
                    min_dist = dist
                    best_alt_pos = pos
                end
            end
            
            if best_alt_pos then
                best_cast_data.point = best_alt_pos
                if debug_enabled then
                    console.print("Death Trap: Using alternative walkable position")
                end
            else
                return false
            end
        else
            return false
        end
    end
    
    -- Check if enhanced targeting is enabled and try to use it
    if menu_module.menu_elements.enhanced_targeting and menu_module.menu_elements.enhanced_targeting:get() and 
       menu_module.menu_elements.aoe_optimization and menu_module.menu_elements.aoe_optimization:get() then
        local success, hit_count = enhanced_targeting.optimize_aoe_positioning(
            death_trap_spell_id, 
            spell_radius, 
            effective_min_enemies
        )
        
        if success then
            next_time_allowed_cast = current_time + 0.01
            _G.last_death_trap_time = current_time
            console.print(string.format("Rouge Plugin: Casted Death Trap using enhanced targeting, hitting ~%d enemies", hit_count))
            return true
        end
    end
    
    -- Cast the spell
    if cast_spell and cast_spell.position and cast_spell.position(death_trap_spell_id, best_cast_data.point, 0.40) then
        next_time_allowed_cast = current_time + 0.01
        if not _G.global_poison_trap_last_cast_time then _G.global_poison_trap_last_cast_time = 0 end
        if not _G.global_poison_trap_last_cast_position then _G.global_poison_trap_last_cast_position = vec3.new(0, 0, 0) end
        _G.global_poison_trap_last_cast_time = current_time
        _G.global_poison_trap_last_cast_position = best_cast_data.point
        console.print(string.format("Rouge Plugin: Casted Death Trap hitting ~%d enemies", #best_cast_data.victim_list))
        return true
    else
        if debug_enabled then console.print("Death Trap: Failed to cast") end
    end
 
    return false
end

return {
    menu = render_menu,
    logics = logics,
    menu_elements = menu_elements
}