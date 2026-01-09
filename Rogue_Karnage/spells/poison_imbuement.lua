local my_utility = require("my_utility/my_utility")
local menu_module = require("menu")

local poison_imbuement_menu_elements_base = 
{
    main_tab           = tree_node:new(1),
    main_boolean       = checkbox:new(true, get_hash(my_utility.plugin_label .. "poison_emb_main_bool_base")),
    priority_mode      = combo_box:new(1, get_hash(my_utility.plugin_label .. "poison_imbuement_priority")),
    min_enemies        = slider_int:new(1, 5, 1, get_hash(my_utility.plugin_label .. "poison_imbuement_min_enemies")),
    only_elite_or_boss = checkbox:new(true, get_hash(my_utility.plugin_label .. "poison_emb_only_elite_or_boss_boolean")),
}

local function menu()
    if poison_imbuement_menu_elements_base.main_tab:push("Poison Imbuement") then
        poison_imbuement_menu_elements_base.main_boolean:render("Enable Spell", "")
        if poison_imbuement_menu_elements_base.main_boolean:get() then
            local options = {"Always", "Elite/Boss Only", "Boss Only"}
            poison_imbuement_menu_elements_base.priority_mode:render("Usage Priority", options, "When to use Poison Imbuement")
            poison_imbuement_menu_elements_base.min_enemies:render("Minimum Enemies", "Minimum enemies in range to cast")
        end
        poison_imbuement_menu_elements_base.main_tab:pop()
    end
end

local spell_id_poison_imb = 358508
local next_time_allowed_cast = 0.0

local function is_active()
    local local_player = get_local_player()
    local buffs = local_player:get_buffs()
   
    for i, buff in ipairs(buffs) do
        if buff.name_hash == 358508 then
            -- console.print("Poison Imbuement Active")
            return true
        end
    end

    return false
end

local function will_cast(target)
    local menu_boolean = poison_imbuement_menu_elements_base.main_boolean:get()
    local is_logic_allowed = my_utility.is_spell_allowed(
        menu_boolean,
        next_time_allowed_cast,
        spell_id_poison_imb
    )

    if not is_logic_allowed or is_active() then
        if console and type(console.print) == "function" then
            console.print("[PoisonImb] will_cast blocked: is_logic_allowed=" .. tostring(is_logic_allowed) .. ", is_active=" .. tostring(is_active()))
        end
        return false
    end

    -- Read usage priority and minimum enemies (similar to Shadow Imbuement)
    local priority_mode = poison_imbuement_menu_elements_base.priority_mode and poison_imbuement_menu_elements_base.priority_mode:get() or 0
    local min_enemies = poison_imbuement_menu_elements_base.min_enemies and poison_imbuement_menu_elements_base.min_enemies:get() or 1

    local only_elite_or_boss = (priority_mode == 1 or priority_mode == 2)

    -- In Always mode, don't apply any enemy-count or special/boss gating beyond the
    -- global is_logic_allowed / is_active checks above. This makes Poison Imbue
    -- fire reliably whenever it's ready.
    if priority_mode == 0 then
        if console and type(console.print) == "function" then
            console.print("[PoisonImb] Always mode: will_cast=true (no enemy checks)")
        end
        return true
    end

    do
        local profile_index = nil
        if menu_module and menu_module.menu_elements and menu_module.menu_elements.profile and type(menu_module.menu_elements.profile.get) == "function" then
            profile_index = menu_module.menu_elements.profile:get()
        end
        if profile_index == 4 then
            -- Heartseeker PIT Hybrid profile: always allow casting regardless of elite/boss restriction
            only_elite_or_boss = false
        end
    end

    -- Evaluate nearby enemies for priority and minimum count
    local enemies = target_selector.get_near_target_list(get_player_position(), 12)
    local enemy_count = 0
    local special_found = false
    local boss_found = false

    for _, enemy in pairs(enemies) do
        enemy_count = enemy_count + 1
        
        local is_boss = enemy:is_boss()
        local is_special = enemy:is_champion() or enemy:is_elite() or is_boss
        if is_special then
            special_found = true
        end
        if is_boss then
            boss_found = true
        end
    end

    -- Enforce minimum enemies regardless of priority mode
    if enemy_count < min_enemies then
        if console and type(console.print) == "function" then
            console.print("[PoisonImb] Blocked: enemy_count=" .. tostring(enemy_count) .. " < min_enemies=" .. tostring(min_enemies))
        end
        return false
    end

    -- Elite/Boss Only or Boss Only modes add extra gating
    if only_elite_or_boss and not special_found then
        if console and type(console.print) == "function" then
            console.print("[PoisonImb] Blocked: only_elite_or_boss=true but no special_found")
        end
        return false
    end

    do
        local helltide_nmd_enabled = false
        if menu_module and menu_module.menu_elements and menu_module.menu_elements.helltide_nmd and type(menu_module.menu_elements.helltide_nmd.get) == "function" then
            helltide_nmd_enabled = menu_module.menu_elements.helltide_nmd:get()
        end

        if priority_mode == 2 then
            if not helltide_nmd_enabled then
                if not boss_found then
                    -- Boss Only: require at least one boss nearby
                    if console and type(console.print) == "function" then
                        console.print("[PoisonImb] Blocked: Boss Only, no boss_found and Helltide-NMD off")
                    end
                    return false
                end
            else
                -- In Helltide/NMD Boss Only mode, allow casting when there are
                -- enough high-value targets (elite/champion/boss), not just a boss.
                if not boss_found and not special_found then
                    if console and type(console.print) == "function" then
                        console.print("[PoisonImb] Blocked: Boss Only in Helltide-NMD, no boss or special found")
                    end
                    return false
                end
            end
        end
    end

    return true
end

local function logics(target)
    if will_cast(target) then
        local current_time = get_time_since_inject()
        if cast_spell.self(spell_id_poison_imb, 0.0) then
            next_time_allowed_cast = current_time + 0.2
            if console and type(console.print) == "function" then
                console.print("Rouge Plugin, Casted Poison Imb")
            end
            return true
        else
            if console and type(console.print) == "function" then
                console.print("[PoisonImb] cast_spell.self failed despite will_cast=true")
            end
        end
    end

    return false
end

return {
    menu = menu,
    logics = logics,
    is_active = is_active,
    will_cast = will_cast,
}