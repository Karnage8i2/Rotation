
local my_utility = require("my_utility/my_utility")

local menu_elements_dash_base =
{
    tree_tab            = tree_node:new(1),
    main_boolean        = checkbox:new(true, get_hash(my_utility.plugin_label .. "dash_base_main_bool")),
    spell_range         = slider_float:new(1.0, 15.0, 7.00, get_hash(my_utility.plugin_label .. "dash_base_spell_range_2")),
    trap_mode          = combo_box:new(0, get_hash(my_utility.plugin_label .. "dash_base_base_pos")),
    keybind            = keybind:new(0x01, false, get_hash(my_utility.plugin_label .. "dash_base_keybind_pos"))
}

local function menu()
    if menu_elements_dash_base.tree_tab:push("Dash") then
        menu_elements_dash_base.main_boolean:render("Enable Spell", "")
        if menu_elements_dash_base.main_boolean:get() then
            menu_elements_dash_base.spell_range:render("Spell Range", "", 1)
            local options = {"Auto", "Keybind"}
            menu_elements_dash_base.trap_mode:render("Mode", options, "")
            menu_elements_dash_base.keybind:render("Keybind", "")
        end
        menu_elements_dash_base.tree_tab:pop()
    end
end

local spell_id_dash = 358761
local next_time_allowed_cast = 0.1

local function logics(target)
    -- Basic checks
    local menu_boolean = menu_elements_dash_base.main_boolean:get()
    if not menu_boolean then
        return false
    end

    local current_time = get_time_since_inject()
    if current_time < next_time_allowed_cast then
        return false
    end

    if not utility.is_spell_ready(spell_id_dash) then
        return false
    end

    -- Keybind mode check
    local keybind_used = menu_elements_dash_base.keybind:get_state()
    local trap_mode = menu_elements_dash_base.trap_mode:get()
    if trap_mode == 1 and keybind_used == 0 then
        return false
    end

    -- Range check
    local player_position = get_player_position()
    local target_position = target:get_position()
    local spell_range = menu_elements_dash_base.spell_range:get()

    if player_position:squared_dist_to_ignore_z(target_position) > (spell_range * spell_range) then
        return false
    end

    -- Cast attempt
    local cast_position = target_position:get_extended(player_position, -3.50)
    if not evade.is_dangerous_position(cast_position) then
        if cast_spell.position(spell_id_dash, cast_position, 0.5) then
            next_time_allowed_cast = current_time + 0.2
            console.print("Rouge, Casted Dash")
            return true
        end
    end

    return false
end

return {
    menu = menu,
    logics = logics
}