local my_utility = require("my_utility/my_utility")

local position_optimizer = {}

function position_optimizer.optimize_position()
    -- Safely get player position
    local player_position = nil
    local position_valid = pcall(function()
        player_position = get_player_position()
        if not player_position then error("Invalid player position") end
    end)
    
    if not position_valid or not player_position then
        return { should_move = false }
    end
    
    -- Safely get enemies
    local enemies = {}
    pcall(function()
        enemies = utility.get_units_inside_circle_list(player_position, 10.0) or {}
    end)
    
    -- If no enemies nearby, no need to reposition
    if #enemies == 0 then
        return { should_move = false }
    end
    
    -- Calculate danger level from each enemy
    local danger_vectors = {}
    for _, enemy in ipairs(enemies) do
        -- Wrap each enemy calculation in pcall to prevent errors from breaking the whole function
        local success = pcall(function()
            local enemy_pos = enemy:get_position()
            -- Verify both positions are valid
            if not enemy_pos then return end
            
            local direction = nil
            -- Safely calculate direction
            pcall(function()
                direction = player_position:subtract(enemy_pos):normalize()
            end)
            
            -- Only proceed if we got a valid direction
            if not direction then return end
            
            local distance = player_position:dist_to(enemy_pos)
            local danger_weight = 1.0 / math.max(distance, 1.0)
            
            -- Increase danger for elites and bosses
            pcall(function()
                if enemy:is_boss() then
                    danger_weight = danger_weight * 3.0
                elseif enemy:is_elite() then
                    danger_weight = danger_weight * 2.0
                end
            end)
            
            table.insert(danger_vectors, {
                direction = direction,
                weight = danger_weight
            })
        end)
    end
    
    -- If we couldn't calculate any danger vectors, return
    if #danger_vectors == 0 then
        return { should_move = false }
    end
    
    -- Calculate optimal escape direction
    local escape_dir = vec3.new(0, 0, 0)
    for _, vector in ipairs(danger_vectors) do
        pcall(function()
            escape_dir = escape_dir:add(vector.direction:multiply(vector.weight))
        end)
    end
    
    -- Only move if we have significant danger
    if escape_dir:length_3d() > 0.5 then
        escape_dir = escape_dir:normalize()
        
        -- Find safe position to move to
        local desired_distance = 5.0
        local target_pos = nil
        
        -- Safely calculate target position
        pcall(function()
            target_pos = player_position:add(escape_dir:multiply(desired_distance))
        end)
        
        if not target_pos then
            return { should_move = false }
        end
        
        -- Try to use pathfinder to find valid path
        local path = nil
        pcall(function()
            path = pathfinder.find_path(player_position, target_pos)
        end)
        
        if path and #path > 1 then
            return {
                should_move = true,
                next_point = path[1],
                full_path = path
            }
        else
            -- Fallback if pathfinder failed: try direct movement
            local is_walkable = false
            pcall(function()
                is_walkable = utility.is_point_walkeable(target_pos)
            end)
            
            if is_walkable then
                return {
                    should_move = true,
                    next_point = target_pos,
                    full_path = {target_pos}
                }
            end
        end
    end
    
    return {
        should_move = false
    }
end

function position_optimizer.find_safe_position_near_enemies(max_range, min_range)
    -- Set default values if nil
    max_range = max_range or 10.0
    min_range = min_range or 3.0
    
    -- Safely get player position
    local player_position = nil
    local position_valid = pcall(function()
        player_position = get_player_position()
        if not player_position then error("Invalid player position") end
    end)
    
    if not position_valid or not player_position then
        return { should_move = false }
    end
    
    -- Safely get enemies
    local enemies = {}
    pcall(function()
        enemies = utility.get_units_inside_circle_list(player_position, max_range * 1.5) or {}
    end)
    
    -- If no enemies, no need to reposition
    if #enemies == 0 then
        return { should_move = false }
    end
    
    -- Find center of enemy mass
    local center_x, center_y = 0, 0
    local valid_enemies = 0
    
    for _, enemy in ipairs(enemies) do
        local success = pcall(function()
            local pos = enemy:get_position()
            if pos then
                center_x = center_x + pos:x()
                center_y = center_y + pos:y()
                valid_enemies = valid_enemies + 1
            end
        end)
    end
    
    -- Make sure we have valid enemies to calculate center
    if valid_enemies == 0 then
        return { should_move = false }
    end
    
    center_x = center_x / valid_enemies
    center_y = center_y / valid_enemies
    
    local center = nil
    pcall(function()
        center = vec3.new(center_x, center_y, player_position:z())
    end)
    
    if not center then
        return { should_move = false }
    end
    
    -- Find positions at optimal range from center
    local optimal_positions = {}
    local num_positions = 16
    
    for i = 1, num_positions do
        local success = pcall(function()
            local angle = (i - 1) * (2 * math.pi / num_positions)
            local distance = min_range + (max_range - min_range) * 0.5
            
            local x = center:x() + distance * math.cos(angle)
            local y = center:y() + distance * math.sin(angle)
            local test_pos = vec3.new(x, y, center:z())
            
            -- Score this position
            local score = 0
            local is_walkable = false
            
            pcall(function()
                is_walkable = utility.is_point_walkeable(test_pos)
            end)
            
            if is_walkable then
                -- Count nearby enemies for AoE potential
                local nearby_enemies = 0
                for _, enemy in ipairs(enemies) do
                    pcall(function()
                        local enemy_pos = enemy:get_position()
                        if enemy_pos and test_pos:dist_to(enemy_pos) <= max_range then
                            nearby_enemies = nearby_enemies + 1
                        end
                    end)
                end
                
                -- Score based on number of enemies in range and distance from player
                local dist_to_player = test_pos:dist_to(player_position)
                score = nearby_enemies * 10 - dist_to_player
                
                table.insert(optimal_positions, {
                    position = test_pos,
                    score = score
                })
            end
        end)
    end
    
    -- Sort positions by score
    if #optimal_positions > 0 then
        pcall(function()
            table.sort(optimal_positions, function(a, b)
                return a.score > b.score
            end)
        end)
    end
    
    -- Return best position if any were found
    if #optimal_positions > 0 then
        return {
            should_move = true,
            next_point = optimal_positions[1].position,
            score = optimal_positions[1].score
        }
    end
    
    return {
        should_move = false
    }
end

return position_optimizer 