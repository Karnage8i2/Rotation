local my_utility = require("my_utility/my_utility")
local poison_imbuement = require("spells/poison_imbuement")
local cold_imbuement = require("spells/cold_imbuement")
local menu_module = require("menu")

local shadow_imbuement_menu_elements_base =
{
    main_tab           = tree_node:new(1),
    main_boolean       = checkbox:new(true, get_hash(my_utility.plugin_label .. "disable_enable_shadow_base")),
    priority_mode      = combo_box:new(0, get_hash(my_utility.plugin_label .. "shadow_imbuement_priority")),
    min_enemies        = slider_int:new(1, 5, 1, get_hash(my_utility.plugin_label .. "shadow_imbuement_min_enemies"))
}

local function menu()
    if shadow_imbuement_menu_elements_base.main_tab:push("Shadow Imbuement") then
        shadow_imbuement_menu_elements_base.main_boolean:render("Enable Spell", "")
        if shadow_imbuement_menu_elements_base.main_boolean:get() then
            local options = {"Always", "Elite/Boss Only", "Boss Only"}
            shadow_imbuement_menu_elements_base.priority_mode:render("Usage Priority", options, "When to use Shadow Imbuement")
            shadow_imbuement_menu_elements_base.min_enemies:render("Minimum Enemies", "Minimum enemies in range to cast")
        end
        shadow_imbuement_menu_elements_base.main_tab:pop()
    end
end

local spell_id_shadow_imb = 380288
local next_time_allowed_cast = 0.0

local function is_active()
    local local_player = get_local_player()
    local buffs = local_player:get_buffs()

    for i, buff in ipairs(buffs) do
        if buff.name_hash == spell_id_shadow_imb then
            return true
        end
    end

    return false
end

local function logics()
    -- Basic checks (local gating so we don't depend on orbwalker/auto-play)
    local current_time = get_time_since_inject()
    local menu_boolean = shadow_imbuement_menu_elements_base.main_boolean:get()

    if not menu_boolean then
        return false
    end

    if current_time < next_time_allowed_cast then
        return false
    end

    if not (utility and utility.is_spell_ready and utility.is_spell_ready(spell_id_shadow_imb)) then
        return false
    end

    if not (utility and utility.is_spell_affordable and utility.is_spell_affordable(spell_id_shadow_imb)) then
        return false
    end

    -- Read priority mode
    local priority_mode = shadow_imbuement_menu_elements_base.priority_mode:get() or 0

    -- In Always or Elite/Boss modes, just fire on cooldown whenever ready.
    -- This guarantees reliable casting for now regardless of enemy-count
    -- classification issues.
    if priority_mode == 0 or priority_mode == 1 then
        if cast_spell.self(spell_id_shadow_imb, 0.0) then
            next_time_allowed_cast = current_time
            console.print("Rouge Plugin, Casted Shadow Imbuement (prio " .. tostring(priority_mode) .. ")")
            return true
        end
        return false
    end

    -- For Boss Only mode, only act when buff is not active and apply conflict/enemy logic
    if not is_active() then
        local min_enemies = shadow_imbuement_menu_elements_base.min_enemies:get() or 1

        -- Count enemies around the player
        local player_position = get_player_position()
        local all_units_count, normal_units_count, elite_units_count, champion_units_count, boss_units_count =
            my_utility.enemy_count_in_range(10.0, player_position)

        -- Check if conditions are met based on priority mode
        if priority_mode == 2 then
            -- Boss Only: only cast if a boss is present
            -- Keep stricter conflict logic here, but in Helltide/NMD allow
            -- elite/champion-heavy packs to count as high-value as well.
            if poison_imbuement.is_active() or poison_imbuement.will_cast() or
               cold_imbuement.is_active() or cold_imbuement.will_cast() then
                return false
            end

            local helltide_nmd_enabled = false
            if menu_module and menu_module.menu_elements and menu_module.menu_elements.helltide_nmd and type(menu_module.menu_elements.helltide_nmd.get) == "function" then
                helltide_nmd_enabled = menu_module.menu_elements.helltide_nmd:get()
            end

            if not helltide_nmd_enabled then
                if boss_units_count == 0 then
                    return false
                end
            else
                local high_value_count = (elite_units_count or 0) + (champion_units_count or 0) + (boss_units_count or 0)
                if high_value_count == 0 or all_units_count < min_enemies then
                    return false
                end
            end
        end

        -- Cast Shadow Imbuement
        if cast_spell.self(spell_id_shadow_imb, 0.0) then
            -- No extra script delay; rely purely on game cooldown
            next_time_allowed_cast = current_time
            console.print("Rouge Plugin, Casted Shadow Imbuement")
            return true
        end
    end
        
    return false
end

return 
{
    menu = menu,
    logics = logics,
    is_active = is_active,
}