local my_utility = require("my_utility/my_utility")
-- Add enhanced targeting and enhancements manager
local enhanced_targeting = require("my_utility/enhanced_targeting")
local enhancements_manager = require("my_utility/enhancements_manager")
local menu_module = require("menu")

local menu_elements_barrage_base =
{
    tree_tab            = tree_node:new(1),
    main_boolean        = checkbox:new(true, get_hash(my_utility.plugin_label .. "barrage_base_main_bool")),
    use_combo_points    = checkbox:new(false, get_hash(my_utility.plugin_label .. "barrage_use_combo_points")),
    combo_points_slider = slider_int:new(0, 6, 0, get_hash(my_utility.plugin_label .. "barrage__min_combo_points")),
    spell_range         = slider_float:new(5.0, 12.0, 9.0, get_hash(my_utility.plugin_label .. "barrage_spell_range")),
    spell_width         = slider_float:new(1.0, 6.0, 3.0, get_hash(my_utility.plugin_label .. "barrage_spell_width")),
}

local function menu()
    if menu_elements_barrage_base.tree_tab:push("Barrage") then
        menu_elements_barrage_base.main_boolean:render("Enable Spell", "")
        menu_elements_barrage_base.use_combo_points:render("Use Combo Points", "")
        if menu_elements_barrage_base.use_combo_points:get() then
            menu_elements_barrage_base.combo_points_slider:render("Min Combo Points", "")
        end
        menu_elements_barrage_base.spell_range:render("Spell Range", "", 1)
        menu_elements_barrage_base.spell_width:render("Spell Width", "", 1)
        menu_elements_barrage_base.tree_tab:pop()
    end
end

local spell_id_barrage = 439762;

local spell_data_barrage = spell_data:new(
    3.0,                        -- radius
    9.0,                        -- range
    1.5,                        -- cast_delay
    3.0,                        -- projectile_speed
    true,                       -- has_collision
    spell_id_barrage,           -- spell_id
    spell_geometry.rectangular, -- geometry_type
    targeting_type.skillshot    -- targeting_type
)

local next_time_allowed_cast = 0.0;
local last_cast_position = nil;

local function logics(target)
    local menu_boolean = menu_elements_barrage_base.main_boolean:get();
    local is_logic_allowed = my_utility.is_spell_allowed(
                menu_boolean, 
                next_time_allowed_cast, 
                spell_id_barrage);

    if not is_logic_allowed then
        return false;
    end;

    local player_local = get_local_player();

    if menu_elements_barrage_base.use_combo_points:get() then
        local combo_points = player_local:get_rogue_combo_points()
        local min_combo_points = menu_elements_barrage_base.combo_points_slider:get()
        if combo_points < min_combo_points then
            
            return false
        end
    end
    
    -- Get spell parameters
    local spell_range = menu_elements_barrage_base.spell_range:get()
    local spell_width = menu_elements_barrage_base.spell_width:get()
    
    -- Update spell range info for visualization
    enhancements_manager.update_spell_range("barrage", spell_range, spell_width, last_cast_position)
    
    local player_position = get_player_position();
    local target_position = target:get_position();

    -- Check if enhanced targeting is enabled and try to use it
    if menu_module and menu_module.menu_elements and 
       menu_module.menu_elements.enhanced_targeting and 
       menu_module.menu_elements.enhanced_targeting:get() and 
       menu_module.menu_elements.aoe_optimization and
       menu_module.menu_elements.aoe_optimization:get() then
        
        -- Get enemies safely
        local enemies = {}
        pcall(function()
            enemies = utility.get_units_inside_circle_list(player_position, spell_range) or {}
        end)
        
        -- For linear targeting, we need a special approach
        local best_pos = nil
        local max_hits = 0
        
        -- Function to count enemies hit by a line
        local function count_enemies_in_line(pos, width)
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
                        if dist_to_line <= width then
                            count = count + 1
                        end
                    end
                end)
            end
            
            return count
        end
        
        -- Find best direction for barrage if there are enemies
        if #enemies > 0 then
            for _, enemy in ipairs(enemies) do
                pcall(function()
                    local enemy_pos = enemy:get_position()
                    if enemy_pos then
                        local hits = count_enemies_in_line(enemy_pos, spell_width)
                        
                        if hits > max_hits then
                            max_hits = hits
                            best_pos = enemy_pos
                        end
                    end
                end)
            end
            
            if best_pos and max_hits >= 2 then
                -- Check for wall collision safely
                local is_wall_collision = false
                pcall(function()
                    is_wall_collision = prediction.is_wall_collision(player_position, best_pos, 0.15)
                end)
                
                if not is_wall_collision then
                    -- Try to cast the spell safely
                    local cast_success = false
                    pcall(function()
                        cast_success = cast_spell.position(spell_id_barrage, best_pos, 0.4)
                    end)
                    
                    if cast_success then
                        local current_time = get_time_since_inject()
                        next_time_allowed_cast = current_time + 0.9
                        last_cast_position = best_pos
                        console.print(string.format("Rouge Plugin: Casted Barrage using enhanced targeting, hitting ~%d enemies", max_hits))
                        return true
                    end
                end
            end
        end
    end

    -- Add error handling to the normal target cast
    local cast_success = false
    pcall(function()
        if target and target:get_position() then
            cast_success = cast_spell.target(target, spell_data_barrage, false)
        end
    end)
    
    if cast_success then
        local current_time = get_time_since_inject();
        next_time_allowed_cast = current_time + 0.9;
        last_cast_position = target:get_position();
        console.print("Rogue, Casted Barrage");
        return true;
    end;
            
    return false;
end

return 
{
    menu = menu,
    logics = logics,   
}