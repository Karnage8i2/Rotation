local my_utility = require("my_utility/my_utility")
local menu_module = require("menu")
-- Add enhanced targeting and enhancements manager
local enhanced_targeting = require("my_utility/enhanced_targeting")
local enhancements_manager = require("my_utility/enhancements_manager")

local menu_elements_rain_of_arrows =
{
    tree_tab            = tree_node:new(1),
    main_boolean        = checkbox:new(true, get_hash(my_utility.plugin_label .. "rain_of_arrows_main_bool_base")),
  
    rain_of_arrows_mode         = combo_box:new(0, get_hash(my_utility.plugin_label .. "rain_base_base")),
    keybind               = keybind:new(0x01, false, get_hash(my_utility.plugin_label .. "rain_base_keybind")),
    keybind_ignore_hits   = checkbox:new(true, get_hash(my_utility.plugin_label .. "keybind_ignore_min_hits_rain_base")),

    min_hits              = slider_int:new(1, 20, 6, get_hash(my_utility.plugin_label .. "min_hits_to_cast_rain_base")),
    
    allow_percentage_hits = checkbox:new(true, get_hash(my_utility.plugin_label .. "allow_percentage_hits_rain_base")),
    min_percentage_hits   = slider_float:new(0.1, 1.0, 0.40, get_hash(my_utility.plugin_label .. "min_percentage_hits_rain_base")),
    soft_score            = slider_float:new(2.0, 15.0, 6.0, get_hash(my_utility.plugin_label .. "min_percentage_hits_rain_base_soft_core")),
    
    -- Add spell range and radius sliders for better customization
    spell_radius          = slider_float:new(5.0, 12.0, 7.0, get_hash(my_utility.plugin_label .. "rain_of_arrows_spell_radius")),
    spell_range           = slider_float:new(5.0, 15.0, 7.0, get_hash(my_utility.plugin_label .. "rain_of_arrows_spell_range")),
}

local function render_menu()
    
    if menu_elements_rain_of_arrows.tree_tab:push("Rain Of Arrows") then
        menu_elements_rain_of_arrows.main_boolean:render("Enable Spell", "");

        local options =  {"Auto", "Keybind"};
        menu_elements_rain_of_arrows.rain_of_arrows_mode:render("Mode", options, "");

        menu_elements_rain_of_arrows.keybind:render("Keybind", "");
        menu_elements_rain_of_arrows.keybind_ignore_hits:render("Keybind Ignores Min Hits", "");

        menu_elements_rain_of_arrows.min_hits:render("Min Hits", "");

        menu_elements_rain_of_arrows.allow_percentage_hits:render("Allow Percentage Hits", "");
        if menu_elements_rain_of_arrows.allow_percentage_hits:get() then
            menu_elements_rain_of_arrows.min_percentage_hits:render("Min Percentage Hits", "", 1);
            menu_elements_rain_of_arrows.soft_score:render("Soft Score", "", 1);
        end       
        
        -- Add spell range and radius options to menu
        menu_elements_rain_of_arrows.spell_range:render("Spell Range", "", 1)
        menu_elements_rain_of_arrows.spell_radius:render("Spell Radius", "", 1)

        menu_elements_rain_of_arrows.tree_tab:pop();
    end
end

local rain_of_arrows_spell_id = 400232;

-- script does not use this data as spell is casted by position
local spell_data_rain_of_arrows = spell_data:new(
    3.0,                        -- radius
    4.0,                        -- range
    2.0,                        -- cast_delay
    1.0,                        -- projectile_speed
    false,                      -- has_collision
    rain_of_arrows_spell_id,    -- spell_id
    spell_geometry.circular,    -- geometry_type
    targeting_type.skillshot    --targeting_type
)

local my_target_selector = require("my_utility/my_target_selector");

-- Define default values but will use menu values in the actual function
local default_spell_radius = 7.0
local default_spell_max_range = 7.0

local next_time_allowed_cast = 0.0;

local function logics(entity_list, target_selector_data, best_target)
    
    local menu_boolean = menu_elements_rain_of_arrows.main_boolean:get();
    local is_logic_allowed = my_utility.is_spell_allowed(
                menu_boolean, 
                next_time_allowed_cast, 
                rain_of_arrows_spell_id);

    if not is_logic_allowed then
        return false;
    end;

    local player_position = get_player_position()
    local keybind_used = menu_elements_rain_of_arrows.keybind:get_state();
    local rain_of_arrows_mode = menu_elements_rain_of_arrows.rain_of_arrows_mode:get();
    if rain_of_arrows_mode == 1 then
        if  keybind_used == 0 then   
            return false;
        end;
    end;
    
    local keybind_ignore_hits = menu_elements_rain_of_arrows.keybind_ignore_hits:get();

    ---@type boolean
    local keybind_can_skip = keybind_ignore_hits == true and keybind_used > 0;
    
    -- Use menu values for radius and range
    local actual_spell_radius = menu_elements_rain_of_arrows.spell_radius:get()
    local actual_spell_max_range = menu_elements_rain_of_arrows.spell_range:get()
    
    -- Update spell range info for visualization
    enhancements_manager.update_spell_range("rain_of_arrows", actual_spell_max_range, actual_spell_radius)
    
    -- Check for minimum enemy count (global setting)
    local all_units_count, normal_units_count, elite_units_count, champion_units_count, boss_units_count = 
        my_utility.enemy_count_in_range(actual_spell_radius, player_position)
    
    -- Get global minimum enemy count setting
    local global_min_enemies = menu_module.menu_elements.enemy_count_threshold:get()
    local spell_min_hits = menu_elements_rain_of_arrows.min_hits:get()
    
    -- Use the higher of the two thresholds
    local effective_min_enemies = math.max(global_min_enemies, spell_min_hits)
    
    -- Check if there's a boss present (bypass minimum enemy count if true)
    local boss_present = boss_units_count > 0
    
    -- Skip if not enough enemies and not using keybind override and no boss present
    if not (keybind_can_skip or boss_present) and all_units_count < effective_min_enemies then
        return false
    end
    
    local is_percentage_hits_allowed = menu_elements_rain_of_arrows.allow_percentage_hits:get();
    local min_percentage = menu_elements_rain_of_arrows.min_percentage_hits:get();
   
    if not is_percentage_hits_allowed then
        min_percentage = 0.0;
    end

    local min_hits_menu = menu_elements_rain_of_arrows.min_hits:get();

	--local spell_range = 5.0
	--local spell_radius = 10.0
	local area_data = my_target_selector.get_most_hits_circular(player_position, actual_spell_max_range, actual_spell_radius)
    if not area_data.main_target then

        return false;
    end
    
    local is_area_valid = my_target_selector.is_valid_area_spell_aio(area_data, min_hits_menu, entity_list, min_percentage);

    if not is_area_valid and not keybind_can_skip  then
        return false;
    end

    if not area_data.main_target:is_enemy() then
        return false;
    end
    
    local constains_relevant = false;
    for _, victim in ipairs(area_data.victim_list) do
        if victim:is_elite() or victim:is_champion() or victim:is_boss() then
            constains_relevant = true;
            break;
        end
    end

    local soft_score = is_percentage_hits_allowed and menu_elements_rain_of_arrows.soft_score:get() or 1
    
    if not constains_relevant and area_data.score < soft_score and not keybind_can_skip  then
       
        return false;
    end

    local cast_position = area_data.main_target:get_position();
    local cast_position_distance_sqr = cast_position:squared_dist_to_ignore_z(player_position);
    if cast_position_distance_sqr < 2.0 and not keybind_can_skip  then
        return false;
    end
 
    cast_spell.position(rain_of_arrows_spell_id, cast_position, 1.0);
    local current_time = get_time_since_inject();
    next_time_allowed_cast = current_time + 0.4;
         
    console.print("Rouge Plugin, Casted Rain Of Arrows");

    -- Check if enhanced targeting is enabled and try to use it
    if menu_module.menu_elements.enhanced_targeting:get() and 
       menu_module.menu_elements.aoe_optimization:get() then
        local success, hit_count = enhanced_targeting.optimize_aoe_positioning(
            rain_of_arrows_spell_id, 
            actual_spell_radius, 
            effective_min_enemies
        )
        
        if success then
            local current_time = get_time_since_inject();
            next_time_allowed_cast = current_time + 0.4;
            console.print(string.format("Rouge Plugin: Casted Rain Of Arrows using enhanced targeting, hitting ~%d enemies", hit_count))
            return true
        end
    end

    return true;
 
end


return 
{
    menu = render_menu,
    logics = logics,   
}