local my_utility = require("my_utility/my_utility")

local menu_elements_flurry_base =
{
    tree_tab            = tree_node:new(1),
    main_boolean        = checkbox:new(true, get_hash(my_utility.plugin_label .. "flurry_main_bool_base")),
    range               = slider_float:new(2.0, 8.0, 5.0, get_hash(my_utility.plugin_label .. "flurry_range")),
    min_enemies         = slider_int:new(1, 5, 2, get_hash(my_utility.plugin_label .. "flurry_min_enemies")),
    cooldown            = slider_float:new(0.15, 0.7, 0.35, get_hash(my_utility.plugin_label .. "flurry_cooldown")),
}

local function menu()
    
    if menu_elements_flurry_base.tree_tab:push("Flurry")then
        menu_elements_flurry_base.main_boolean:render("Enable Spell", "")
        if menu_elements_flurry_base.main_boolean:get() then
            menu_elements_flurry_base.range:render("Max Range", "Maximum distance to target for Flurry", 1)
            menu_elements_flurry_base.min_enemies:render("Min Enemies", "Minimum enemies in range to cast Flurry")
            menu_elements_flurry_base.cooldown:render("Cooldown", "Delay between Flurry casts", 2)
        end
 
        menu_elements_flurry_base.tree_tab:pop()
    end
end

local spell_id_flurry = 358339;

local spell_data_puncture = spell_data:new(
    2.0,                        -- radius
    0.3,                        -- range
    0.4,                        -- cast_delay
    0.4,                        -- projectile_speed
    true,                      -- has_collision
    spell_id_flurry,           -- spell_id
    spell_geometry.rectangular, -- geometry_type
    targeting_type.skillshot    --targeting_type
)
local next_time_allowed_cast = 0.0;
local function logics(target)
    
    local menu_boolean = menu_elements_flurry_base.main_boolean:get();
    local is_logic_allowed = my_utility.is_spell_allowed(
                menu_boolean, 
                next_time_allowed_cast, 
                spell_id_flurry);

    if not is_logic_allowed then
        return false;
    end;
    
    -- Validate target
    if not target then
        return false
    end

    -- Get player safely
    local player_local = get_local_player();
    if not player_local then
        return false
    end
    
    -- Get positions safely
    local player_position = get_player_position();
    if not player_position then
        return false
    end
    
    local target_position = nil
    pcall(function()
        target_position = target:get_position()
    end)
    
    if not target_position then
        return false
    end

    -- Only cast Flurry when the target is actually close to the player
    local max_flurry_range = menu_elements_flurry_base.range:get()

    local distance_sqr = player_position:squared_dist_to_ignore_z(target_position)
    if distance_sqr > (max_flurry_range * max_flurry_range) then
        return false
    end

    -- Additionally require a minimum number of nearby enemies
    local all_units_count = 0
    if my_utility and type(my_utility.enemy_count_in_range) == "function" then
        all_units_count = select(1, my_utility.enemy_count_in_range(max_flurry_range, player_position)) or 0
    end

    local min_flurry_enemies = menu_elements_flurry_base.min_enemies:get() -- require at least N enemies in melee range

    if all_units_count < min_flurry_enemies then
        return false
    end

    -- Safe cast with error handling
    local cast_success = false
    pcall(function()
        cast_success = cast_spell.target(target, spell_data_puncture, false)
    end)

    if cast_success then
        local current_time = get_time_since_inject();
        -- Cooldown between Flurries is controlled from the menu
        local cd = menu_elements_flurry_base.cooldown:get()
        next_time_allowed_cast = current_time + cd;

        console.print("Rouge, Casted Flurry");
        return true;
    end;
            
    return false;
end


return 
{
    menu = menu,
    logics = logics,   
}