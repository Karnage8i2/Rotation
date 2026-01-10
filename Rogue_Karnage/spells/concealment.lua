local my_utility = require("my_utility/my_utility")

local menu_elements_concealment_base = 
{
    tree_tab              = tree_node:new(1),
    main_boolean          = checkbox:new(true, get_hash(my_utility.plugin_label .. "main_boolean_concealment")),
    apply_vulnerable       = checkbox:new(true, get_hash(my_utility.plugin_label .. "apply_vulnerable_concealment")),
    as_defensive           = checkbox:new(true, get_hash(my_utility.plugin_label .. "as_defensive_concealment")),
    defensive_health       = slider_float:new(0.0, 1.0, 0.30, get_hash(my_utility.plugin_label .. "%_hp_to_cast_concealment")),
    min_cooldown          = slider_float:new(0.0, 20.0, 0.5, get_hash(my_utility.plugin_label .. "min_cooldown_concealment"))
}

local function menu()
    
    if menu_elements_concealment_base.tree_tab:push("Concealment") then
        menu_elements_concealment_base.main_boolean:render("Enable Spell", "")

        if menu_elements_concealment_base.main_boolean:get() then
            menu_elements_concealment_base.apply_vulnerable:render("Use Concealment as Offensive ability", "Applies Vulnerable to enemies")
            menu_elements_concealment_base.as_defensive:render("Use Concealment as Defensive ability", "Stealths to stop enemy targetting")
                if menu_elements_concealment_base.as_defensive:get() then
                    menu_elements_concealment_base.defensive_health:render("Min cast HP Percent", "", 2)
                end
            menu_elements_concealment_base.min_cooldown:render("Min Cooldown (seconds)", "Minimum time between casts", 1)
        end

        menu_elements_concealment_base.tree_tab:pop()
    end
end

local next_time_allowed_cast = 0.0;
local spell_id_concealment = 794965;
local function logics()

    local menu_boolean = menu_elements_concealment_base.main_boolean:get();
    local is_logic_allowed = my_utility.is_spell_allowed(
                menu_boolean, 
                next_time_allowed_cast, 
                spell_id_concealment);

    if not is_logic_allowed then
    return false;
    end;
    
    -- Check minimum cooldown from last cast
    local current_time = get_time_since_inject();
    local last_cast_time = _G.last_concealment_time or 0
    local min_cooldown = menu_elements_concealment_base.min_cooldown:get()
    if current_time - last_cast_time < min_cooldown then
        return false;
    end
    
    local player_pos = get_player_position()

    -- Check if at least one condition is met (OR logic, not AND)
    local defensive_check_passed = false
    local offensive_check_passed = false
    
    -- Use Concealment as Defensive ability
    if menu_elements_concealment_base.as_defensive:get() then
        local local_player = get_local_player();
        local player_current_health = local_player:get_current_health();
        local player_max_health = local_player:get_max_health();
        local health_percentage = player_current_health / player_max_health;
        local menu_min_percentage = menu_elements_concealment_base.defensive_health:get();
        if health_percentage <= menu_min_percentage then
            defensive_check_passed = true
        end
    else
        -- If defensive check is disabled, consider it passed
        defensive_check_passed = true
    end

    -- Use Concealment as Offensive ability
    if menu_elements_concealment_base.apply_vulnerable:get() then
        local area_data = target_selector.get_most_hits_target_circular_area_light(player_pos, 6.0, 6.0, false)
        local units = area_data.n_hits
        if units >= 1 then
            offensive_check_passed = true
        end
    else
        -- If offensive check is disabled, consider it passed
        offensive_check_passed = true
    end
    
    -- Must pass at least one check (OR logic)
    if not (defensive_check_passed or offensive_check_passed) then
        return false
    end

    -- if units < menu_elements_concealment_base.min_max_targets:get() then
    --     return false;
    -- end;

    if cast_spell.self(spell_id_concealment, 0.000) then
        
        -- Update cooldown tracking
        _G.last_concealment_time = current_time;
        next_time_allowed_cast = current_time + 0.5;
        console.print("Casted Concealment")
        return true;
    end;


    return false;
end

return 
{
    menu = menu,
    logics = logics,   
}