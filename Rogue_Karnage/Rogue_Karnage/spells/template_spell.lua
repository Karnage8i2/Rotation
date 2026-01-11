-- Template for all spell types
local my_utility = require("my_utility/my_utility")
local spell_data = require("my_utility/spell_data")

-- Common menu elements for all spell types
local menu_elements = {
    tree_tab = tree_node:new(1),
    main_boolean = checkbox:new(true, get_hash(my_utility.plugin_label .. "main_boolean_SPELL_NAME")),
    targeting_mode = combo_box:new({"Best Ranged", "Best Melee", "Best Cursor", "Closest Cursor"}, 0, get_hash(my_utility.plugin_label .. "targeting_mode_SPELL_NAME")),
    min_cooldown = slider_float:new(0.1, 3.0, 0.5, get_hash(my_utility.plugin_label .. "min_cooldown_SPELL_NAME")),
    min_range = slider_float:new(0.0, 10.0, 0.0, get_hash(my_utility.plugin_label .. "min_range_SPELL_NAME")),
    max_range = slider_float:new(5.0, 40.0, 35.0, get_hash(my_utility.plugin_label .. "max_range_SPELL_NAME")),
    min_enemies = slider_int:new(1, 10, 1, get_hash(my_utility.plugin_label .. "min_enemies_SPELL_NAME")),
    debug_enabled = checkbox:new(false, get_hash(my_utility.plugin_label .. "debug_enabled_SPELL_NAME"))
}

local function menu()
    if menu_elements.tree_tab:push("SPELL_NAME") then
        menu_elements.main_boolean:render("Enable Spell", "")
        if menu_elements.main_boolean:get() then
            menu_elements.targeting_mode:render("Targeting Mode", "How to select targets")
            menu_elements.min_range:render("Minimum Range", "Minimum range to cast", 2)
            menu_elements.max_range:render("Maximum Range", "Maximum range to cast", 2)
            menu_elements.min_enemies:render("Minimum Enemies", "Minimum enemies in range to cast", 0)
            menu_elements.min_cooldown:render("Minimum Cooldown", "Minimum time between casts", 2)
            menu_elements.debug_enabled:render("Enable Debug", "Show debug information")
        end
        menu_elements.tree_tab:pop()
    end
end

local next_time_allowed_cast = 0.0

-- Template for self-cast spells (like buffs, defensive abilities)
local function cast_self_spell(target_selector_data, best_ranged_target, best_melee_target, best_cursor_target, closest_cursor_target, closest_cursor_target_angle)
    if not menu_elements.main_boolean:get() then return false end
    
    local current_time = get_current_time()
    if current_time < next_time_allowed_cast then return false end
    
    if not is_spell_ready(spell_data.SPELL_NAME.spell_id) then return false end
    
    -- Add spell-specific conditions here
    
    if cast_spell.self(spell_data.SPELL_NAME.spell_id, 0.000) then
        next_time_allowed_cast = current_time + menu_elements.min_cooldown:get()
        return menu_elements.min_cooldown:get()
    end
    
    return false
end

-- Template for targeted spells (like single target attacks)
local function cast_targeted_spell(target_selector_data, best_ranged_target, best_melee_target, best_cursor_target, closest_cursor_target, closest_cursor_target_angle)
    if not menu_elements.main_boolean:get() then return false end
    
    local current_time = get_current_time()
    if current_time < next_time_allowed_cast then return false end
    
    if not is_spell_ready(spell_data.SPELL_NAME.spell_id) then return false end
    
    local target = nil
    local targeting_mode = menu_elements.targeting_mode:get()
    
    -- Select target based on targeting mode
    if targeting_mode == 0 then
        target = best_ranged_target
    elseif targeting_mode == 1 then
        target = best_melee_target
    elseif targeting_mode == 2 then
        target = best_cursor_target
    else
        target = closest_cursor_target
    end
    
    if not target then return false end
    
    local target_pos = target:get_position()
    local player_pos = get_player_position()
    local distance = target_pos:dist_to_ignore_z(player_pos)
    
    -- Range checks
    if distance < menu_elements.min_range:get() or distance > menu_elements.max_range:get() then
        return false
    end
    
    if cast_spell.targeted(spell_data.SPELL_NAME.spell_id, target, 0.000) then
        next_time_allowed_cast = current_time + menu_elements.min_cooldown:get()
        return menu_elements.min_cooldown:get()
    end
    
    return false
end

-- Template for ground-targeted spells (like AoE abilities)
local function cast_ground_targeted_spell(target_selector_data, best_ranged_target, best_melee_target, best_cursor_target, closest_cursor_target, closest_cursor_target_angle)
    if not menu_elements.main_boolean:get() then return false end
    
    local current_time = get_current_time()
    if current_time < next_time_allowed_cast then return false end
    
    if not is_spell_ready(spell_data.SPELL_NAME.spell_id) then return false end
    
    local target = nil
    local targeting_mode = menu_elements.targeting_mode:get()
    
    -- Select target based on targeting mode
    if targeting_mode == 0 then
        target = best_ranged_target
    elseif targeting_mode == 1 then
        target = best_melee_target
    elseif targeting_mode == 2 then
        target = best_cursor_target
    else
        target = closest_cursor_target
    end
    
    if not target then return false end
    
    local target_pos = target:get_position()
    local player_pos = get_player_position()
    local distance = target_pos:dist_to_ignore_z(player_pos)
    
    -- Range checks
    if distance < menu_elements.min_range:get() or distance > menu_elements.max_range:get() then
        return false
    end
    
    -- Check for minimum enemies in range
    local enemies_in_range = 0
    for _, unit in ipairs(target_selector_data.units) do
        if unit:get_position():dist_to_ignore_z(target_pos) <= spell_data.SPELL_NAME.radius then
            enemies_in_range = enemies_in_range + 1
        end
    end
    
    if enemies_in_range < menu_elements.min_enemies:get() then
        return false
    end
    
    if cast_spell.ground_targeted(spell_data.SPELL_NAME.spell_id, target_pos, 0.000) then
        next_time_allowed_cast = current_time + menu_elements.min_cooldown:get()
        return menu_elements.min_cooldown:get()
    end
    
    return false
end

return {
    menu = menu,
    cast = cast_targeted_spell, -- Change this based on spell type
    menu_elements = menu_elements
} 