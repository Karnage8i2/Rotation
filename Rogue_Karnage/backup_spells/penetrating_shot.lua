local my_utility = require("my_utility/my_utility")
local menu_module = require("menu")
-- Add enhanced targeting and enhancements manager
local enhanced_targeting = require("my_utility/enhanced_targeting")
local enhancements_manager = require("my_utility/enhancements_manager")
local my_target_selector = require("my_utility/my_target_selector");

local menu_elements =
{
    tree_tab            = tree_node:new(1),
    main_boolean        = checkbox:new(true, get_hash(my_utility.plugin_label .. "pen_shot_base_main_bool")),

    trap_mode         = combo_box:new(0, get_hash(my_utility.plugin_label .. "pen_shot_base_mode")),
    keybind               = keybind:new(0x01, false, get_hash(my_utility.plugin_label .. "pen_shot_base_keybind_pos")),
    keybind_ignore_hits   = checkbox:new(true, get_hash(my_utility.plugin_label .. "pen_shot_base_keybind_ignore_min_hitstrap_base_pos")),

    min_hits              = slider_int:new(1, 20, 4, get_hash(my_utility.plugin_label .. "pen_shot_base_min_hits_to_casttrap_base_pos")),
    
    allow_percentage_hits = checkbox:new(true, get_hash(my_utility.plugin_label .. "allow_percentage_hits_pen_shot_base_pos")),
    min_percentage_hits   = slider_float:new(0.1, 1.0, 0.50, get_hash(my_utility.plugin_label .. "min_percentage_hits_pen_shot_base_pos")),
    soft_score            = slider_float:new(2.0, 15.0, 6.0, get_hash(my_utility.plugin_label .. "min_percentage_hits_pen_shot_base_soft_core_pos")),

    spell_range   = slider_float:new(1.0, 15.0, 10.0, get_hash(my_utility.plugin_label .. "pen_shot_base_spell_range")),
    spell_radius   = slider_float:new(0.50, 5.0, 1.50, get_hash(my_utility.plugin_label .. "pen_shot_base_spell_radius")),
}

local function render_menu()
    
    if menu_elements.tree_tab:push("Penetrating Shot") then
        menu_elements.main_boolean:render("Enable Spell", "");

        local options =  {"Auto", "Keybind"};
        menu_elements.trap_mode:render("Mode", options, "");

        menu_elements.keybind:render("Keybind", "");
        menu_elements.keybind_ignore_hits:render("Keybind Ignores Min Hits", "");

        menu_elements.min_hits:render("Min Hits", "");

        menu_elements.allow_percentage_hits:render("Allow Percentage Hits", "");
        if menu_elements.allow_percentage_hits:get() then
            menu_elements.min_percentage_hits:render("Min Percentage Hits", "", 1);
            menu_elements.soft_score:render("Soft Score", "", 1);
        end       

        menu_elements.spell_range:render("Spell Range", "", 1)
        menu_elements.spell_radius:render("Spell Radius", "", 1)

        menu_elements.tree_tab:pop();
    end
end

local spell_id_penetration_shot = 377137;
local spell_data_penetration_shot = spell_data:new(
    1.50,                        -- radius
    20.0,                        -- range
    1.0,                        -- cast_delay
    5.0,                        -- projectile_speed
    true,                      -- has_collision
    spell_id_penetration_shot,           -- spell_id
    spell_geometry.rectangular, -- geometry_type
    targeting_type.skillshot    --targeting_type
)
local next_time_allowed_cast = 0.0;
local global_penetration_shot_last_cast_position = nil;

local function logics(entity_list, target_selector_data, best_target)
    
    local menu_boolean = menu_elements.main_boolean:get();
    local is_logic_allowed = my_utility.is_spell_allowed(
                menu_boolean, 
                next_time_allowed_cast, 
                spell_id_penetration_shot);

    if not is_logic_allowed then
        return false;
    end;

    local player_position = get_player_position()
    local keybind_used = menu_elements.keybind:get_state();
    local trap_mode = menu_elements.trap_mode:get();
    if trap_mode == 1 then
        if  keybind_used == 0 then   
            return false;
        end;
    end;

    local keybind_ignore_hits = menu_elements.keybind_ignore_hits:get();
   
    ---@type boolean
    local keybind_can_skip = keybind_ignore_hits == true and keybind_used > 0;
    
    -- Get spell parameters
    local spell_radius = menu_elements.spell_radius:get()
    local spell_range = menu_elements.spell_range:get()
    
    -- Update spell range info for visualization
    enhancements_manager.update_spell_range("penetrating_shot", spell_range, spell_radius, global_penetration_shot_last_cast_position)
    
    -- Check for minimum enemy count (global setting)
    local all_units_count, normal_units_count, elite_units_count, champion_units_count, boss_units_count = 
        my_utility.enemy_count_in_range(spell_radius, player_position)
    
    -- Get global minimum enemy count setting
    local global_min_enemies = menu_module.menu_elements.enemy_count_threshold:get()
    local spell_min_hits = menu_elements.min_hits:get()
    
    -- Use the higher of the two thresholds
    local effective_min_enemies = math.max(global_min_enemies, spell_min_hits)
    
    -- Check if there's a boss present (bypass minimum enemy count if true)
    local boss_present = boss_units_count > 0
    
    -- Skip if not enough enemies and not using keybind override and no boss present
    if not (keybind_can_skip or boss_present) and all_units_count < effective_min_enemies then
        return false
    end
    
    local is_percentage_hits_allowed = menu_elements.allow_percentage_hits:get();
    local min_percentage = menu_elements.min_percentage_hits:get();
    if not is_percentage_hits_allowed then
        min_percentage = 0.0;
    end

    local min_hits_menu = menu_elements.min_hits:get();

    local area_data = my_target_selector.get_most_hits_rectangle(player_position, spell_range, spell_radius)

    if not area_data.main_target then
        return false;
    end


    local is_area_valid = my_target_selector.is_valid_area_spell_aio(area_data, min_hits_menu, entity_list, min_percentage);
    -- console.print("hits " .. area_data.hits_amount)
    -- console.print("is_area_valid " .. tostring(is_area_valid) )
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

    if not constains_relevant and area_data.score < menu_elements.soft_score:get() and not keybind_can_skip  then
        return false;
    end    

    local cast_position = area_data.main_target:get_position();
    local player_position = get_player_position()
    local is_wall_collision = prediction.is_wall_collision(player_position, cast_position, 0.15);
    if is_wall_collision then
        return false
    end

    -- Check if enhanced targeting is enabled and try to use it
    if menu_module and menu_module.menu_elements and 
       menu_module.menu_elements.enhanced_targeting and 
       menu_module.menu_elements.enhanced_targeting:get() and 
       menu_module.menu_elements.aoe_optimization and
       menu_module.menu_elements.aoe_optimization:get() then
       
        -- For penetrating shot, we need a special case since it's a linear skill shot
        local enemies = {}
        pcall(function()
            enemies = utility.get_units_inside_circle_list(player_position, spell_range) or {}
        end)
        
        local best_pos = nil
        local max_hits = 0
        
        -- Function to count enemies hit by a line
        local function count_enemies_in_line(pos, radius)
            -- Check for null values first
            if not pos then return 0 end
            
            local count = 0
            local direction = nil
            
            -- Safely calculate direction with pcall
            local dir_success = pcall(function()
                direction = pos:subtract(player_position)
                if direction and direction:length_3d() > 0 then
                    direction = direction:normalize()
                else
                    error("Invalid direction vector")
                end
            end)
            
            -- If we couldn't get a valid direction, return 0
            if not dir_success or not direction then
                return 0
            end
            
            local max_dist = player_position:dist_to(pos)
            
            for _, enemy in ipairs(enemies) do
                -- Wrap each enemy calculation in pcall
                pcall(function()
                    local enemy_pos = enemy:get_position()
                    if not enemy_pos then return end
                    
                    -- Safely project point on line
                    local proj = nil
                    pcall(function()
                        proj = my_utility.project_point_on_line(player_position, direction, enemy_pos)
                    end)
                    
                    if not proj then return end
                    
                    -- Check if projection is within line length
                    local proj_dist = player_position:dist_to(proj)
                    if proj_dist <= max_dist then
                        -- Check if enemy is close enough to the line
                        local dist_to_line = enemy_pos:dist_to(proj)
                        if dist_to_line <= radius then
                            count = count + 1
                        end
                    end
                end)
            end
            
            return count
        end
        
        -- Find best direction for penetrating shot
        if #enemies > 0 then
            for _, enemy in ipairs(enemies) do
                pcall(function()
                    local enemy_pos = enemy:get_position()
                    if enemy_pos then
                        local hits = count_enemies_in_line(enemy_pos, spell_radius)
                        
                        if hits > max_hits then
                            max_hits = hits
                            best_pos = enemy_pos
                        end
                    end
                end)
            end
            
            if best_pos and max_hits >= effective_min_enemies then
                -- Check for wall collision
                local is_wall_collision = false
                pcall(function()
                    is_wall_collision = prediction.is_wall_collision(player_position, best_pos, 0.15)
                end)
                
                if not is_wall_collision then
                    local cast_success = false
                    pcall(function()
                        cast_success = cast_spell.position(spell_id_penetration_shot, best_pos, 0.4)
                    end)
                    
                    if cast_success then
                        local current_time = get_time_since_inject()
                        next_time_allowed_cast = current_time + 0.4
                        global_penetration_shot_last_cast_position = best_pos
                        _G.last_penetrating_shot_time = current_time
                        console.print(string.format("Rouge Plugin: Casted Penetrating Shot using enhanced targeting, hitting ~%d enemies", max_hits))
                        return true
                    end
                end
            end
        end
    end

    if not is_wall_collision then
        local cast_success = false
        pcall(function()
            cast_success = cast_spell.position(spell_id_penetration_shot, cast_position, 0.4)
        end)
        
        if cast_success then
        local current_time = get_time_since_inject();
        next_time_allowed_cast = current_time + 0.4;
            global_penetration_shot_last_cast_position = cast_position;
            _G.last_penetrating_shot_time = current_time;
            
        console.print("Rouge Plugin, Casted pen shot");
        return true;
        end
    end
    return false;
end


return 
{
    menu = render_menu,
    logics = logics,   
}