local my_utility = require("my_utility/my_utility")

local enhanced_targeting = {}

function enhanced_targeting.draw_targeting_visualization(spell_range, spell_radius, debug_enabled)
    if not debug_enabled then return end
    
    local player_position = get_player_position()
    
    -- Draw spell range
    graphics.circle_3d(player_position, spell_range, color_blue(0.3), 2)
    
    -- Draw spell effect radius at cursor position
    local cursor_pos = get_cursor_position()
    graphics.circle_3d(cursor_pos, spell_radius, color_green(0.3), 2)
    
    -- Draw potential targets in range
    local targets = utility.get_units_inside_circle_list(player_position, spell_range)
    for _, target in ipairs(targets) do
        local target_pos = target:get_position()
        local is_elite = target:is_elite()
        local is_boss = target:is_boss()
        
        -- Color code by enemy type
        local target_color = color_white(0.7)
        if is_boss then
            target_color = color_red(0.7)
        elseif is_elite then
            target_color = color_purple(0.7)
        end
        
        graphics.circle_3d(target_pos, 0.5, target_color, 1)
    end
end

function enhanced_targeting.get_optimal_target(player_position, spell_range)
    -- Get all potential targets
    local targets = target_selector.get_near_target_list(player_position, spell_range)
    if #targets == 0 then return nil end
    
    -- Weight targets based on various factors
    local best_target = nil
    local best_score = 0
    
    for _, target in ipairs(targets) do
        local base_score = 1
        local position = target:get_position()
        local distance = player_position:dist_to(position)
        local hp_percent = target:get_health() / target:get_max_health()
        
        -- Adjust score based on enemy type
        if target:is_boss() then
            base_score = base_score * 5
        elseif target:is_elite() then
            base_score = base_score * 3
        elseif target:is_champion() then
            base_score = base_score * 2
        end
        
        -- Adjust for health - prioritize low health targets
        local hp_modifier = 2 - hp_percent
        
        -- Adjust for distance - closer is better
        local distance_modifier = 1 - (distance / spell_range) * 0.5
        
        -- Calculate final score
        local score = base_score * hp_modifier * distance_modifier
        
        if score > best_score then
            best_score = score
            best_target = target
        end
    end
    
    return best_target
end

function enhanced_targeting.optimize_aoe_positioning(spell_id, spell_radius, min_hits)
    local player_position = get_player_position()
    local enemies = utility.get_units_inside_circle_list(player_position, 15.0)
    
    -- Find optimal clustering
    local best_position = nil
    local max_hits = 0
    
    -- Grid search for optimal position
    local search_radius = 10.0
    local step_size = 2.0
    
    for x = -search_radius, search_radius, step_size do
        for y = -search_radius, search_radius, step_size do
            local test_pos = vec3.new(
                player_position:x() + x,
                player_position:y() + y,
                player_position:z()
            )
            
            -- Check if position is walkable
            if utility.is_point_walkeable(test_pos) then
                -- Count enemies that would be hit
                local hits = 0
                for _, enemy in ipairs(enemies) do
                    local enemy_pos = enemy:get_position()
                    if test_pos:dist_to(enemy_pos) <= spell_radius then
                        hits = hits + 1
                    end
                end
                
                if hits > max_hits then
                    max_hits = hits
                    best_position = test_pos
                end
            end
        end
    end
    
    -- Only cast if we can hit required number of enemies
    local required_hits = min_hits or 3
    if max_hits >= required_hits and best_position then
        if cast_spell.position(spell_id, best_position, 0.3) then
            return true, max_hits
        end
    end
    
    return false, 0
end

return enhanced_targeting 