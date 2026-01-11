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

    min_hits              = slider_int:new(1, 20, 2, get_hash(my_utility.plugin_label .. "pen_shot_base_min_hits_to_casttrap_base_pos")),  -- Reduced default from 4 to 2
    
    allow_percentage_hits = checkbox:new(true, get_hash(my_utility.plugin_label .. "allow_percentage_hits_pen_shot_base_pos")),
    min_percentage_hits   = slider_float:new(0.1, 1.0, 0.50, get_hash(my_utility.plugin_label .. "min_percentage_hits_pen_shot_base_pos")),
    soft_score            = slider_float:new(2.0, 15.0, 3.0, get_hash(my_utility.plugin_label .. "min_percentage_hits_pen_shot_base_soft_core_pos")),  -- Reduced default from 6.0 to 3.0

    spell_range   = slider_float:new(1.0, 15.0, 10.0, get_hash(my_utility.plugin_label .. "pen_shot_base_spell_range")),
    spell_radius   = slider_float:new(0.50, 5.0, 1.50, get_hash(my_utility.plugin_label .. "pen_shot_base_spell_radius")),
    
    -- Wall bounce optimization for Eaglehorn ricochet mechanics
    enable_wall_bounce    = checkbox:new(true, get_hash(my_utility.plugin_label .. "pen_shot_wall_bounce_enable")),
    wall_bounce_min_hits  = slider_int:new(2, 10, 3, get_hash(my_utility.plugin_label .. "pen_shot_wall_bounce_min_hits")),
    auto_position_bounce  = checkbox:new(true, get_hash(my_utility.plugin_label .. "pen_shot_auto_position_bounce")),
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

        -- Wall bounce optimization options
        menu_elements.enable_wall_bounce:render("Enable Wall Bounce", "Optimize penetrating shot for Eaglehorn ricochet mechanics")
        if menu_elements.enable_wall_bounce:get() then
            menu_elements.wall_bounce_min_hits:render("Min Bounce Hits", "Minimum hits required to use wall bounce optimization", 1)
            menu_elements.auto_position_bounce:render("Auto Position for Bounce", "Automatically position behind enemies for optimal bounce setup", 1)
        end

        menu_elements.tree_tab:pop();
    end
end

local spell_id_penetration_shot = 377137;
local spell_data_penetration_shot = spell_data:new(
    1.50,                        -- radius
    20.0,                        -- range
    .02,                        -- cast_delay
    5.0,                        -- projectile_speed
    true,                      -- has_collision
    spell_id_penetration_shot,           -- spell_id
    spell_geometry.rectangular, -- geometry_type
    targeting_type.skillshot    --targeting_type
)
local next_time_allowed_cast = 0.0;
local global_penetration_shot_last_cast_position = nil;

-- Wall bounce optimization for Eaglehorn ricochet mechanics
local function find_optimal_wall_bounce_position(player_position, target_position, spell_range)
    local optimal_cast_position = target_position
    local max_hits = 0
    local closest_wall_distance = 999999
    
    -- Check 8 directions around the target for wall bounce opportunities
    for i = 1, 8 do
        local angle = (i - 1) * (2 * math.pi / 8)
        local test_direction = vec3.new(math.cos(angle), math.sin(angle), 0)
        
        -- Test position at spell range in this direction
        local test_position = nil
        local test_success = pcall(function()
            test_position = player_position:add(test_direction:multiply(spell_range))
        end)
        
        if test_success and test_position then
            -- Check if this position would hit a wall
            local wall_collision = prediction.is_wall_collision(player_position, test_position, 0.15)
            
            if wall_collision then
                -- Calculate distance to this wall
                local wall_distance = player_position:dist_to(test_position)
                
                -- Calculate potential hits from ricochet
                local ricochet_hits = 0
                
                -- Count enemies that would be hit by the initial shot
                local initial_hits = my_utility.enemy_count_in_range(1.5, player_position)
                ricochet_hits = ricochet_hits + initial_hits
                
                -- Count enemies that would be hit by the ricochet (bounce back)
                local bounce_direction = nil
                local bounce_success = pcall(function()
                    bounce_direction = player_position:subtract(test_position):normalize()
                end)
                
                if bounce_success and bounce_direction then
                    local bounce_position = nil
                    local bounce_pos_success = pcall(function()
                        bounce_position = test_position:add(bounce_direction:multiply(spell_range * 0.5))
                    end)
                    
                    if bounce_pos_success and bounce_position then
                        local bounce_hits = my_utility.enemy_count_in_range(1.5, bounce_position)
                        ricochet_hits = ricochet_hits + bounce_hits
                    end
                end
                
                -- Prioritize closest wall with good hit count, or better hit count if similar distance
                local should_update = false
                if wall_distance < closest_wall_distance - 2.0 then
                    -- Much closer wall, prefer it even with fewer hits
                    should_update = true
                elseif wall_distance <= closest_wall_distance + 2.0 and ricochet_hits > max_hits then
                    -- Similar distance but more hits
                    should_update = true
                elseif ricochet_hits > max_hits + 2 then
                    -- Significantly more hits, prefer it
                    should_update = true
                end
                
                if should_update then
                    max_hits = ricochet_hits
                    optimal_cast_position = test_position
                    closest_wall_distance = wall_distance
                end
            end
        end
    end
    
    return optimal_cast_position, max_hits, closest_wall_distance
end

-- Find optimal player position for wall bounce setup
local function find_optimal_player_position_for_bounce(player_position, target_position, spell_range)
    local optimal_player_pos = player_position
    local max_bounce_hits = 0
    
    -- Check positions behind the enemy (opposite side from player)
    local enemy_to_player = nil
    local direction_success = pcall(function()
        enemy_to_player = player_position:subtract(target_position):normalize()
    end)
    
    if direction_success and enemy_to_player then
        -- Test positions behind the enemy
        for distance = 2.0, 8.0, 2.0 do
            local behind_enemy_pos = nil
            local behind_success = pcall(function()
                behind_enemy_pos = target_position:add(enemy_to_player:multiply(distance))
            end)
            
            if behind_success and behind_enemy_pos then
                -- Check if we can move to this position
                local can_move_there = not prediction.is_wall_collision(player_position, behind_enemy_pos, 0.15)
                
                if can_move_there then
                    -- Calculate potential bounce hits from this position
                    local bounce_position, bounce_hits = find_optimal_wall_bounce_position(behind_enemy_pos, target_position, spell_range)
                    
                    if bounce_hits > max_bounce_hits then
                        max_bounce_hits = bounce_hits
                        optimal_player_pos = behind_enemy_pos
                    end
                end
            end
        end
    end
    
    return optimal_player_pos, max_bounce_hits
end

local function logics(entity_list, target_selector_data, best_target)
    
    local menu_boolean = menu_elements.main_boolean:get();
    local is_logic_allowed = my_utility.is_spell_allowed(
                menu_boolean, 
                next_time_allowed_cast, 
                spell_id_penetration_shot);

    if not is_logic_allowed then
        -- Only print debug message occasionally to reduce spam
        local last_debug_time = _G.last_penetrating_shot_debug_time or 0
        local current_time = get_time_since_inject()
        if current_time - last_debug_time > 2.0 then -- Only print every 2 seconds
            console.print("Penetrating shot: Logic not allowed")
            _G.last_penetrating_shot_debug_time = current_time
        end
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
    
    -- Simplified targeting for maximum casting speed
    local all_units_count, normal_units_count, elite_units_count, champion_units_count, boss_units_count = 
        my_utility.enemy_count_in_range(spell_radius, player_position)
    
    -- Check if we're fighting a boss
    local is_boss_fight = false
    if best_target and (best_target:is_boss() or best_target:is_champion()) then
        is_boss_fight = true
    end
    
    -- In boss fights, use a larger range to ensure we can target the boss
    if is_boss_fight then
        local boss_range = 25.0 -- Extended range for boss fights
        local boss_units_count = my_utility.enemy_count_in_range(boss_range, player_position)
        if boss_units_count >= 1 then
            all_units_count = boss_units_count -- Use the boss range count instead
            spell_range = boss_range -- Temporarily extend spell range for boss fights
        end
    end
    
    -- Allow casting if there's at least 1 enemy (simplified logic)
    if all_units_count < 1 then
        -- Only print debug message occasionally to reduce spam
        local last_no_enemies_debug_time = _G.last_penetrating_shot_no_enemies_debug_time or 0
        local current_time = get_time_since_inject()
        if current_time - last_no_enemies_debug_time > 3.0 then -- Only print every 3 seconds
            console.print("Penetrating shot: No enemies in range (count: " .. all_units_count .. ")")
            _G.last_penetrating_shot_no_enemies_debug_time = current_time
        end
        return false
    end
    
    -- Get a simple target - prefer best_target if available, otherwise use closest enemy
    local target_to_cast_at = best_target
    if not target_to_cast_at then
        -- Find closest enemy as fallback
        local closest_enemy = nil
        local closest_distance = 999999
        
        for _, entity in ipairs(entity_list) do
            if entity:is_enemy() then
                local dist = player_position:dist_to(entity:get_position())
                if dist < closest_distance and dist <= spell_range then
                    closest_distance = dist
                    closest_enemy = entity
                end
            end
        end
        
        target_to_cast_at = closest_enemy
    end
    
    if not target_to_cast_at or not target_to_cast_at:is_enemy() then
        -- Only print debug message occasionally to reduce spam
        local last_no_target_debug_time = _G.last_penetrating_shot_no_target_debug_time or 0
        local current_time = get_time_since_inject()
        if current_time - last_no_target_debug_time > 3.0 then -- Only print every 3 seconds
            console.print("Penetrating shot: No valid target found")
            _G.last_penetrating_shot_no_target_debug_time = current_time
        end
        return false
    end
    
    -- Wall bounce optimization for Eaglehorn ricochet mechanics
    local target_pos = nil
    local target_success = pcall(function()
        target_pos = target_to_cast_at:get_position()
    end)
    
    if not target_success or not target_pos then
        -- Only print debug message occasionally to reduce spam
        local last_target_pos_debug_time = _G.last_penetrating_shot_target_pos_debug_time or 0
        local current_time = get_time_since_inject()
        if current_time - last_target_pos_debug_time > 3.0 then -- Only print every 3 seconds
            console.print("Penetrating shot: Failed to get target position")
            _G.last_penetrating_shot_target_pos_debug_time = current_time
        end
        return false
    end
    
    -- Check if we're near walls for bounce optimization (only if enabled)
    local is_near_wall = false
    local wall_bounce_position = target_pos
    local bounce_hits = 0
    
    if menu_elements.enable_wall_bounce:get() then
        -- Test if there are walls nearby for ricochet opportunities
        for i = 1, 4 do
            local angle = (i - 1) * (math.pi / 2)
            local test_direction = vec3.new(math.cos(angle), math.sin(angle), 0)
            local test_position = nil
            
            local test_success = pcall(function()
                test_position = player_position:add(test_direction:multiply(spell_range))
            end)
            
            if test_success and test_position then
                local wall_collision = prediction.is_wall_collision(player_position, test_position, 0.15)
                if wall_collision then
                    is_near_wall = true
                    break
                end
            end
        end
        
        -- If near walls, optimize for bounce effects
        if is_near_wall then
            local optimal_bounce_pos, optimal_bounce_hits, wall_distance = find_optimal_wall_bounce_position(player_position, target_pos, spell_range)
            local min_bounce_hits = menu_elements.wall_bounce_min_hits:get()
            
            if optimal_bounce_hits >= min_bounce_hits then -- Only use bounce if it meets minimum hit requirement
                wall_bounce_position = optimal_bounce_pos
                bounce_hits = optimal_bounce_hits
                
                -- Try to position player behind enemy for optimal bounce setup (if auto-positioning is enabled)
                if menu_elements.auto_position_bounce:get() then
                    local optimal_player_pos, player_bounce_hits = find_optimal_player_position_for_bounce(player_position, target_pos, spell_range)
                    
                    if player_bounce_hits > bounce_hits then
                        -- Suggest movement to optimal position (this would be handled by movement system)
                        -- Only print debug message occasionally to reduce spam
                        local last_bounce_pos_debug_time = _G.last_penetrating_shot_bounce_pos_debug_time or 0
                        local current_time = get_time_since_inject()
                        if current_time - last_bounce_pos_debug_time > 5.0 then -- Only print every 5 seconds
                            console.print("Penetrating shot: Optimal bounce position found - " .. player_bounce_hits .. " potential hits")
                            _G.last_penetrating_shot_bounce_pos_debug_time = current_time
                        end
                        wall_bounce_position = optimal_bounce_pos
                        bounce_hits = player_bounce_hits
                    end
                end
                
                -- Only print debug message occasionally to reduce spam
                local last_wall_bounce_debug_time = _G.last_penetrating_shot_wall_bounce_debug_time or 0
                local current_time = get_time_since_inject()
                if current_time - last_wall_bounce_debug_time > 5.0 then -- Only print every 5 seconds
                    console.print("Penetrating shot: Wall bounce optimization - " .. bounce_hits .. " potential ricochet hits (wall distance: " .. string.format("%.1f", wall_distance) .. "m)")
                    _G.last_penetrating_shot_wall_bounce_debug_time = current_time
                end
            end
        end
    end
    
    -- In boss fights, use wall bounce if available, otherwise use standard positioning
    if is_boss_fight then
        if is_near_wall and bounce_hits > 1 then
            cast_position = wall_bounce_position
            local wall_distance = player_position:dist_to(wall_bounce_position)
            -- Only print debug message occasionally to reduce spam
            local last_boss_bounce_debug_time = _G.last_penetrating_shot_boss_bounce_debug_time or 0
            local current_time = get_time_since_inject()
            if current_time - last_boss_bounce_debug_time > 3.0 then -- Only print every 3 seconds
                console.print("Penetrating shot: Using wall bounce position for boss fight - " .. bounce_hits .. " hits (wall distance: " .. string.format("%.1f", wall_distance) .. "m)")
                _G.last_penetrating_shot_boss_bounce_debug_time = current_time
            end
        else
            -- Fallback to standard boss positioning
            local direction = nil
            local dir_success = pcall(function()
                direction = target_pos:subtract(player_position)
            end)
            
            if dir_success and direction and direction:length_3d() > 0 then
                local normalized_dir = nil
                local norm_success = pcall(function()
                    normalized_dir = direction:normalize()
                end)
                
                if norm_success and normalized_dir then
                    local offset_pos = nil
                    local offset_success = pcall(function()
                        local offset_distance = 2.0
                        offset_pos = player_position:add(normalized_dir:multiply(offset_distance))
                    end)
                    
                    if offset_success and offset_pos then
                        cast_position = offset_pos
                        -- Only print debug message occasionally to reduce spam
                        local last_boss_offset_debug_time = _G.last_penetrating_shot_boss_offset_debug_time or 0
                        local current_time = get_time_since_inject()
                        if current_time - last_boss_offset_debug_time > 3.0 then -- Only print every 3 seconds
                            console.print("Penetrating shot: Using offset position for boss fight")
                            _G.last_penetrating_shot_boss_offset_debug_time = current_time
                        end
                    else
                        cast_position = target_pos
                        -- Only print debug message occasionally to reduce spam
                        local last_boss_fallback_debug_time = _G.last_penetrating_shot_boss_fallback_debug_time or 0
                        local current_time = get_time_since_inject()
                        if current_time - last_boss_fallback_debug_time > 3.0 then -- Only print every 3 seconds
                            console.print("Penetrating shot: Offset calculation failed, using direct boss position")
                            _G.last_penetrating_shot_boss_fallback_debug_time = current_time
                        end
                    end
                else
                    cast_position = target_pos
                    -- Only print debug message occasionally to reduce spam
                    local last_boss_norm_debug_time = _G.last_penetrating_shot_boss_norm_debug_time or 0
                    local current_time = get_time_since_inject()
                    if current_time - last_boss_norm_debug_time > 3.0 then -- Only print every 3 seconds
                        console.print("Penetrating shot: Direction normalization failed, using direct boss position")
                        _G.last_penetrating_shot_boss_norm_debug_time = current_time
                    end
                end
            else
                cast_position = target_pos
                -- Only print debug message occasionally to reduce spam
                local last_boss_dir_debug_time = _G.last_penetrating_shot_boss_dir_debug_time or 0
                local current_time = get_time_since_inject()
                if current_time - last_boss_dir_debug_time > 3.0 then -- Only print every 3 seconds
                    console.print("Penetrating shot: Direction calculation failed, using direct boss position")
                    _G.last_penetrating_shot_boss_dir_debug_time = current_time
                end
            end
        end
    else
        -- Use wall bounce position if available and beneficial
        if is_near_wall and bounce_hits > 1 then
            cast_position = wall_bounce_position
        else
            cast_position = target_pos
        end
    end
    
    -- Wall collision check - allow intentional wall hits for bounce optimization
    local is_wall_collision = false
    if not is_boss_fight then
        is_wall_collision = prediction.is_wall_collision(player_position, cast_position, 0.15)
        if is_wall_collision and not (is_near_wall and menu_elements.enable_wall_bounce:get()) then
            -- Only block if we're not intentionally using wall bounce
            -- Only print debug message occasionally to reduce spam
            local last_wall_collision_debug_time = _G.last_penetrating_shot_wall_collision_debug_time or 0
            local current_time = get_time_since_inject()
            if current_time - last_wall_collision_debug_time > 3.0 then -- Only print every 3 seconds
                console.print("Penetrating shot: Unintentional wall collision detected")
                _G.last_penetrating_shot_wall_collision_debug_time = current_time
            end
            return false
        elseif is_wall_collision and is_near_wall and menu_elements.enable_wall_bounce:get() then
            -- Only print debug message occasionally to reduce spam
            local last_intentional_bounce_debug_time = _G.last_penetrating_shot_intentional_bounce_debug_time or 0
            local current_time = get_time_since_inject()
            if current_time - last_intentional_bounce_debug_time > 5.0 then -- Only print every 5 seconds
                console.print("Penetrating shot: Intentional wall bounce for Eaglehorn ricochet effect")
                _G.last_penetrating_shot_intentional_bounce_debug_time = current_time
            end
        end
    else
        if is_near_wall and menu_elements.enable_wall_bounce:get() then
            -- Only print debug message occasionally to reduce spam
            local last_boss_bounce_use_debug_time = _G.last_penetrating_shot_boss_bounce_use_debug_time or 0
            local current_time = get_time_since_inject()
            if current_time - last_boss_bounce_use_debug_time > 5.0 then -- Only print every 5 seconds
                console.print("Penetrating shot: Using wall bounce in boss fight for Eaglehorn ricochet")
                _G.last_penetrating_shot_boss_bounce_use_debug_time = current_time
            end
        else
            -- Only print debug message occasionally to reduce spam
            local last_boss_standard_debug_time = _G.last_penetrating_shot_boss_standard_debug_time or 0
            local current_time = get_time_since_inject()
            if current_time - last_boss_standard_debug_time > 5.0 then -- Only print every 5 seconds
                console.print("Penetrating shot: Standard boss fight positioning")
                _G.last_penetrating_shot_boss_standard_debug_time = current_time
            end
        end
    end

    -- Simple and fast casting
    local cast_success = false
    pcall(function()
        cast_success = cast_spell.position(spell_id_penetration_shot, cast_position, 0.4)
    end)
    
    if cast_success then
        local current_time = get_time_since_inject()
        next_time_allowed_cast = current_time + 0.001  -- Ultra-fast casting for hold button behavior
        global_penetration_shot_last_cast_position = cast_position
        _G.last_penetrating_shot_time = current_time
        
        -- Only print debug message occasionally to reduce spam
        local last_cast_success_debug_time = _G.last_penetrating_shot_cast_success_debug_time or 0
        local current_time = get_time_since_inject()
        if current_time - last_cast_success_debug_time > 2.0 then -- Only print every 2 seconds
            if is_boss_fight then
                console.print("Penetrating shot: Cast successful in boss fight")
            else
                console.print("Rouge Plugin: Casted Penetrating Shot (fast mode)")
            end
            _G.last_penetrating_shot_cast_success_debug_time = current_time
        end
        return true
    end
    
    -- Only print debug message occasionally to reduce spam
    local last_cast_fail_debug_time = _G.last_penetrating_shot_cast_fail_debug_time or 0
    local current_time = get_time_since_inject()
    if current_time - last_cast_fail_debug_time > 3.0 then -- Only print every 3 seconds
        if is_boss_fight then
            console.print("Penetrating shot: Cast failed in boss fight")
        end
        _G.last_penetrating_shot_cast_fail_debug_time = current_time
    end
    return false;
end


return 
{
    menu = render_menu,
    logics = logics,   
}