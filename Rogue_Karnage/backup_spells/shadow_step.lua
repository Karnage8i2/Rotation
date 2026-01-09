local my_utility = require("my_utility/my_utility")

local menu_elements_shadow_step_base = {
    tree_tab = tree_node:new(1),
    main_boolean = checkbox:new(true, get_hash(my_utility.plugin_label .. "shadow_step_base_bool_main")),
    spell_range = slider_float:new(1.0, 25.0, 20.0, get_hash(my_utility.plugin_label .. "shadow_step_range")), -- Increased max and default range
    min_range = slider_float:new(0.0, 6.50, 2.0, get_hash(my_utility.plugin_label .. "shadow_step_min_range")), -- Decreased default min range
    cast_mode = combo_box:new(0, get_hash(my_utility.plugin_label .. "shadow_step_cast_mode")),
    cast_delay = slider_float:new(0.0, 1.0, 0.001, get_hash(my_utility.plugin_label .. "shadow_step_cast_delay")) -- Decreased default delay
}

local function menu()
    if menu_elements_shadow_step_base.tree_tab:push("Shadow Step") then
        menu_elements_shadow_step_base.main_boolean:render("Enable Spell", "")
        if menu_elements_shadow_step_base.main_boolean:get() then
            menu_elements_shadow_step_base.spell_range:render("Max Range", "", 1)
            menu_elements_shadow_step_base.min_range:render("Min Range", "", 1)
            local options = {"Always", "Gap Close Only"}
            menu_elements_shadow_step_base.cast_mode:render("Usage Mode", options, "")
            menu_elements_shadow_step_base.cast_delay:render("Cast Delay", "Time between casts", 3)
        end
        menu_elements_shadow_step_base.tree_tab:pop()
    end
end

local spell_id_shadow_step = 355606
local next_time_allowed_cast = 0.0
local last_cast_position = nil
local last_target_id = nil

local function logics(entity_list, target_selector_data, best_target, closest_target)
    local menu_boolean = menu_elements_shadow_step_base.main_boolean:get()
    local is_logic_allowed = my_utility.is_spell_allowed(
        menu_boolean,
        next_time_allowed_cast,
        spell_id_shadow_step)

    if not is_logic_allowed then
        return false
    end

    local player_position = get_player_position()
    local spell_range = menu_elements_shadow_step_base.spell_range:get()
    local min_range = menu_elements_shadow_step_base.min_range:get()

    -- Reduced cooldown check for the same target
    if best_target and best_target:get_id() == last_target_id then
        local current_time = get_time_since_inject()
        if current_time < next_time_allowed_cast then
            return false
        end
    end

    -- Modified target selection for more aggressive behavior
    if menu_elements_shadow_step_base.cast_mode:get() == 0 then -- Always mode
        if best_target then
            local target_dist = player_position:squared_dist_to_ignore_z(best_target:get_position())
            if target_dist > (min_range * min_range) and target_dist <= (spell_range * spell_range) then
                if cast_spell.target(best_target, spell_id_shadow_step, 0.5, false) then
                    local current_time = get_time_since_inject()
                    next_time_allowed_cast = current_time + menu_elements_shadow_step_base.cast_delay:get()
                    last_cast_position = best_target:get_position()
                    last_target_id = best_target:get_id()
                    console.print("Rouge Plugin, Casted Shadow Step")
                    return true
                end
            end
        end
    else -- Gap Close mode
        -- Find the furthest target within range to maximize gap closing
        local max_dist = min_range * min_range
        local furthest_target = nil
        for _, target in ipairs(entity_list) do
            local target_dist = player_position:squared_dist_to_ignore_z(target:get_position())
            if target_dist > max_dist and target_dist <= (spell_range * spell_range) then
                furthest_target = target
                max_dist = target_dist
            end
        end

        if furthest_target then
            if cast_spell.target(furthest_target, spell_id_shadow_step, 0.5, false) then
                local current_time = get_time_since_inject()
                next_time_allowed_cast = current_time + menu_elements_shadow_step_base.cast_delay:get()
                last_cast_position = furthest_target:get_position()
                last_target_id = furthest_target:get_id()
                console.print("Rouge Plugin, Casted Shadow Step Gap Close")
                return true
            end
        end
    end

    return false
end

return {
    menu = menu,
    logics = logics
}