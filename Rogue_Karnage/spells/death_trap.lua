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
    prefer_boss_position = checkbox:new(true, get_hash(my_utility.plugin_label .. "death_trap_prefer_boss_position")),
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
        menu_elements.prefer_boss_position:render("Prefer Boss Position", "Cast Death Trap directly on boss/elite when present (guaranteed hit)")
        menu_elements.debug_enabled:render("Enable Debug", "Show debug information")

        menu_elements.tree_tab:pop();
    end
end

local death_trap_spell_id = 421161;
local next_time_allowed_cast = 0.01;

local function logics(entity_list, target_selector_data, best_target)
    local debug_enabled = menu_elements.debug_enabled:get()
    
    -- Always log when function is called to debug boss fights
    if debug_enabled then
        local has_best = best_target and best_target:is_valid()
        local list_count = (type(entity_list) == "table") and #entity_list or 0
        console.print(string.format("Death Trap: Called with best_target=%s, entity_list count=%d", 
            tostring(has_best), list_count))
    end
    
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
    if not player_position then
        if debug_enabled then console.print("Death Trap: No player position") end
        return false
    end
    
    -- Handle keybind mode
    local keybind_used = menu_elements.keybind:get_state()
    local trap_mode = menu_elements.trap_mode:get()
    if trap_mode == 1 and keybind_used == 0 then
        if debug_enabled then console.print("Death Trap: Keybind not pressed") end
        return false
    end
    
    -- Check for Prefer Boss Position FIRST - allows casting even with empty entity list
    local prefer_boss = menu_elements.prefer_boss_position:get()
    if debug_enabled then
        console.print(string.format("Death Trap: Prefer boss=%s, best_target valid=%s", 
            tostring(prefer_boss), tostring(best_target and best_target:is_valid())))
    end
    
    if prefer_boss and best_target and best_target:is_valid() then
        local spell_range = menu_elements.spell_range:get()
        local boss_pos = best_target:get_position()
        if boss_pos then
            local dist_sqr = player_position:squared_dist_to_ignore_z(boss_pos)
            local dist = math.sqrt(dist_sqr)
            if debug_enabled then
                console.print(string.format("Death Trap: Distance to best_target: %.2f (range: %.2f)", dist, spell_range))
            end
            
            if dist_sqr <= (spell_range * spell_range) then
                if debug_enabled then console.print("Death Trap: Prefer Boss Position - attempting cast on best_target") end
                if cast_spell and cast_spell.position and cast_spell.position(death_trap_spell_id, boss_pos, 0.40) then
                    next_time_allowed_cast = current_time + 0.01
                    _G.last_death_trap_time = current_time
                    console.print("Rouge Plugin: Casted Death Trap directly on best_target (Prefer Boss Position)")
                    return true
                else
                    if debug_enabled then console.print("Death Trap: Cast failed on best_target position") end
                end
            else
                if debug_enabled then console.print("Death Trap: best_target out of range") end
            end
        else
            if debug_enabled then console.print("Death Trap: best_target has no position") end
        end
    end
    
    -- Note: We don't immediately fail if entity_list is empty, as we can still detect enemies
    -- using my_utility.enemy_count_in_range() below. The entity_list is used for AoE optimization
    -- but we can work without it for simple scenarios.
    
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
    
    -- Check if there's a high-value target present (bypass minimum enemy count if true)
    -- Also check if best_target is provided and valid (might be boss/elite even if not counted)
    local high_value_present = boss_units_count > 0 or elite_units_count > 0 or champion_units_count > 0
    local best_target_is_high_value = false
    
    if best_target and best_target:is_valid() then
        -- Check if best_target is actually a boss/elite by checking distance and rarity
        local target_rarity = best_target:get_rarity()
        if target_rarity and (target_rarity == 4 or target_rarity == 5 or target_rarity == 6) then
            -- 4=elite, 5=champion, 6=boss (approximate values, may vary)
            best_target_is_high_value = true
            high_value_present = true
            if debug_enabled then
                console.print("Death Trap: best_target is high-value (rarity: " .. tostring(target_rarity) .. ")")
            end
        end
    end
    
    if high_value_present and debug_enabled then
        console.print("Death Trap: High-value target detected - bypassing minimum enemy count requirement")
    end

    -- Do not cast on a single normal enemy when no high-value target is present
    if not high_value_present and all_units_count <= 1 then
        if debug_enabled then
            console.print("Death Trap: Skipping single normal enemy (no high-value targets)")
        end
        return false
    end

    -- Treat any pack of 5+ normal enemies as a valid AoE even without high-value targets
    local normal_pack_ok = (not high_value_present) and (all_units_count or 0) >= 5
    
    -- Skip if not enough enemies and not using keybind override and no high-value target present
    local keybind_ignore_hits = menu_elements.keybind_ignore_hits:get()
    local can_bypass_threshold = (trap_mode == 1 and keybind_used > 0 and keybind_ignore_hits)
    
    if not (can_bypass_threshold or high_value_present or normal_pack_ok) and all_units_count < effective_min_enemies then
        if debug_enabled then 
            console.print(string.format("Death Trap: Not enough enemies (%d < %d required)", 
                all_units_count, effective_min_enemies))
        end
        return false
    end

    -- Get AOE data only if we have entity_list, otherwise try direct targeting
    local area_data = nil
    local has_entity_list = (type(entity_list) == "table" and #entity_list > 0)
    
    if has_entity_list then
        area_data = my_target_selector.get_most_hits_circular(player_position, spell_range, spell_radius)
    else
        if debug_enabled then console.print("Death Trap: No entity_list, using direct enemy detection") end
    end
    
    if not has_entity_list or not area_data or not area_data.main_target then
        if high_value_present and best_target and best_target:is_valid() then
            local boss_pos = best_target:get_position()
            local dist_sqr = player_position:squared_dist_to_ignore_z(boss_pos)
            if dist_sqr <= (spell_range * spell_range) then
                if debug_enabled then console.print("Death Trap: High-value target fallback - casting directly on target (no AoE main target)") end
                if cast_spell and cast_spell.position and cast_spell.position(death_trap_spell_id, boss_pos, 0.40) then
                    next_time_allowed_cast = current_time + 0.01
                    _G.last_death_trap_time = current_time
                    console.print("Rouge Plugin: Casted Death Trap on high-value target via fallback")
                    return true
                end
            end
        end
        if debug_enabled then console.print("Death Trap: No main target found") end
        return false
    end

    -- Only proceed with detailed casting if we have area_data from entity_list
    if not has_entity_list or not area_data then
        if debug_enabled then console.print("Death Trap: No area data available, cannot cast") end
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
        if high_value_present and best_target and best_target:is_valid() then
            local boss_pos = best_target:get_position()
            local dist_sqr = player_position:squared_dist_to_ignore_z(boss_pos)
            if dist_sqr <= (spell_range * spell_range) then
                if debug_enabled then console.print("Death Trap: High-value target fallback - AoE point out of range, casting on target") end
                if cast_spell and cast_spell.position and cast_spell.position(death_trap_spell_id, boss_pos, 0.40) then
                    next_time_allowed_cast = current_time + 0.01
                    _G.last_death_trap_time = current_time
                    console.print("Rouge Plugin: Casted Death Trap on boss via range fallback")
                    return true
                end
            end
        end
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