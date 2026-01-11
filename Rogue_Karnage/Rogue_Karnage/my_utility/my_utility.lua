local function is_auto_play_enabled()
    -- auto play fire spells without orbwalker
    local is_auto_play_active = auto_play and auto_play.is_active and auto_play.is_active();
    local auto_play_objective = auto_play and auto_play.get_objective and auto_play.get_objective();
    local is_auto_play_fighting = auto_play_objective == objective.fight;
    if is_auto_play_active and is_auto_play_fighting then
        return true;
    end

    return false;
end

local blood_mist_buff_name = "Necromancer_BloodMist";
local blood_mist_buff_name_hash = blood_mist_buff_name;
local blood_mist_buff_name_hash_c = 493422;

local mount_buff_name = "Generic_SetCannotBeAddedToAITargetList";
local mount_buff_name_hash = mount_buff_name;
local mount_buff_name_hash_c = 1923;

local shrine_conduit_buff_name = "Shine_Conduit";
local shrine_conduit_buff_name_hash = shrine_conduit_buff_name;
local shrine_conduit_buff_name_hash_c = 421661;

-- Enhanced targeting functions
local function is_buff_active(spell_id, buff_id, min_stack_count)
    -- set default set count to 1 if not passed
    min_stack_count = min_stack_count or 1

    -- get player buffs
    local local_player = get_local_player()
    if not local_player then return false end
    local local_player_buffs = local_player:get_buffs()
    if not local_player_buffs then return false end

    -- for every buff
    for _, buff in ipairs(local_player_buffs) do
        -- if we have a matching spell and buff id and
        -- we have at least the minimum amount of stack or the buff has more than 0.2 seconds remaining
        if buff.name_hash == spell_id and buff.type == buff_id and (buff.stacks >= min_stack_count or buff:get_remaining_time() > 0.2) then
            return true
        end
    end

    return false
end

local function buff_stack_count(spell_id, buff_id)
    -- get player buffs
    local local_player = get_local_player()
    if not local_player then return 0 end
    local local_player_buffs = local_player:get_buffs()
    if not local_player_buffs then return 0 end

    -- iterate over each buff
    for _, buff in ipairs(local_player_buffs) do
        -- check for matching spell and buff id
        if buff.name_hash == spell_id and buff.type == buff_id then
            -- return the stack amount immediately
            return buff.stacks
        end
    end

    -- return 0 if no matching buff is found
    return 0
end

local function enemy_count_in_range(radius, position)
    local all_units_count = 0
    local normal_units_count = 0
    local elite_units_count = 0
    local champion_units_count = 0
    local boss_units_count = 0
    local radius_squared = radius * radius
    
    local enemies = actors_manager.get_enemy_npcs()
    for _, enemy in ipairs(enemies) do
        local enemy_position = enemy:get_position()
        local distance_sqr = enemy_position:squared_dist_to_ignore_z(position)
        
        if distance_sqr <= radius_squared then
            all_units_count = all_units_count + 1
            
            if enemy:is_boss() then
                boss_units_count = boss_units_count + 1
            elseif enemy:is_champion() then
                champion_units_count = champion_units_count + 1
            elseif enemy:is_elite() then
                elite_units_count = elite_units_count + 1
            else
                normal_units_count = normal_units_count + 1
            end
        end
    end
    
    return all_units_count, normal_units_count, elite_units_count, champion_units_count, boss_units_count
end

local function is_in_range(target, range)
    if not target then return false end
    
    local player_position = get_player_position()
    local target_position = target:get_position()
    local distance_sqr = target_position:squared_dist_to_ignore_z(player_position)
    
    return distance_sqr <= (range * range)
end

local function is_action_allowed()
    -- evade abort
    local local_player = get_local_player();
    if not local_player then
        return false
    end  
    
    local player_position = local_player:get_position();
    if evade and evade.is_dangerous_position and evade.is_dangerous_position(player_position) then
        -- Throttle this message to reduce spam
        local current_time = get_time_since_inject()
        local last_evade_block_message = _G.last_evade_block_message or 0
        local evade_block_message_interval = 2.0 -- Show message every 2 seconds instead of every frame
        
        if current_time - last_evade_block_message >= evade_block_message_interval then
            _G.last_evade_block_message = current_time
            console.print("I CANT ATTACK - EVADE BLOCK!!!!!!")
        end
        return false;
    end

    local busy_spell_id_1 = 337031
    local active_spell_id = local_player:get_active_spell_id()
    if active_spell_id == busy_spell_id_1 then
        return false
    end

    local is_mounted = false;
    local is_blood_mist = false;
    local is_shrine_conduit = false;
    local local_player_buffs = local_player:get_buffs();
    for _, buff in ipairs(local_player_buffs) do
          -- console.print("buff name ", buff:name());
          -- console.print("buff hash ", buff.name_hash);
          if buff.name_hash == blood_mist_buff_name_hash_c then
              is_blood_mist = true;
              break;
          end
  
          if buff.name_hash == mount_buff_name_hash_c then
            is_mounted = true;
              break;
          end
  
          if buff.name_hash == shrine_conduit_buff_name_hash_c then
            is_shrine_conduit = true;
              break;
          end
    end
  
    -- do not make any actions while in blood mist
    if is_blood_mist or is_mounted or is_shrine_conduit then
        -- console.print("Blocking Actions for Some Buff");
        return false;
    end

    return true
end

local function is_spell_allowed(spell_enable_check, next_cast_allowed_time, spell_id)
    if not spell_enable_check then
        return false;
    end;

    local current_time = get_time_since_inject();
    if current_time < next_cast_allowed_time then
        return false;
    end;
    
    if not (utility and utility.is_spell_ready and utility.is_spell_ready(spell_id)) then
        return false;
    end;

    if not (utility and utility.is_spell_affordable and utility.is_spell_affordable(spell_id)) then
        return false;
    end;

    -- evade abort - make this check safer since evade might not be initialized properly
    local should_check_evade = true
    local local_player = get_local_player()
    if local_player then
        local player_position = local_player:get_position()
        -- Safely check for evade's existence to avoid nil errors
        if should_check_evade and _G.evade and type(_G.evade.is_dangerous_position) == "function" then
            if _G.evade.is_dangerous_position(player_position) then
                -- console.print("Dangerous position detected by evade")
                return false
            end
        end
    end

    -- Special handling for penetrating shot - allow it to work like fast mode
    if spell_id == 377137 then -- penetrating shot spell ID
        if is_auto_play_enabled() then
            return true;
        end
        
        -- For penetrating shot, be more permissive with orbwalker modes
        local current_orb_mode = orbwalker and orbwalker.get_orb_mode and orbwalker.get_orb_mode() or 0
        
        -- Allow penetrating shot in any mode except none
        if current_orb_mode ~= orb_mode.none then
            return true;
        end
        
        return false;
    end

    -- Allow all Rogue spells to work independently of orbwalker mode, if the
    -- user has enabled this behavior via the menu flag. They still respect
    -- cooldown, affordability, and evade checks above.
    local allow_without_orbwalker = _G.tb_core_cast_without_orbwalker
    if allow_without_orbwalker == nil then
        allow_without_orbwalker = true
    end
    if allow_without_orbwalker then
        return true
    end

    if is_auto_play_enabled() then
        return true;
    end

    local current_orb_mode = orbwalker and orbwalker.get_orb_mode and orbwalker.get_orb_mode() or 0
    
    if current_orb_mode == orb_mode.none then
        return false
    end

    local is_current_orb_mode_pvp = current_orb_mode == orb_mode.pvp
    local is_current_orb_mode_clear = current_orb_mode == orb_mode.clear
    
     -- is pvp or clear (both)
     if not is_current_orb_mode_pvp and not is_current_orb_mode_clear then
        return false;
    end

    return true
end

local function generate_points_around_target(target_position, radius, num_points)
    local points = {};
    for i = 1, num_points do
        local angle = (i - 1) * (2 * math.pi / num_points);
        local x = target_position:x() + radius * math.cos(angle);
        local y = target_position:y() + radius * math.sin(angle);
        table.insert(points, vec3.new(x, y, target_position:z()));
    end
    return points;
end

local function get_best_point(target_position, circle_radius, current_hit_list)
    local points = generate_points_around_target(target_position, circle_radius * 0.75, 8); -- Generate 8 points around target
    local hit_table = {};

    local player_position = get_player_position();
    for _, point in ipairs(points) do
        local hit_list = utility and utility.get_units_inside_circle_list and utility.get_units_inside_circle_list(point, circle_radius) or {};

        local hit_list_collision_less = {};
        for _, obj in ipairs(hit_list) do
            local is_wall_collision = target_selector and target_selector.is_wall_collision and target_selector.is_wall_collision(player_position, obj, 2.0) or false;
            if not is_wall_collision then
                table.insert(hit_list_collision_less, obj);
            end
        end

        table.insert(hit_table, {
            point = point, 
            hits = #hit_list_collision_less, 
            victim_list = hit_list_collision_less
        });
    end

    -- sort by the number of hits
    table.sort(hit_table, function(a, b) return a.hits > b.hits end);

    local current_hit_list_amount = #current_hit_list;
    if hit_table[1].hits > current_hit_list_amount then
        return hit_table[1]; -- returning the point with the most hits
    end
    
    return {point = target_position, hits = current_hit_list_amount, victim_list = current_hit_list};
end

function is_target_within_angle(origin, reference, target, max_angle)
    -- Create vector from origin to reference and normalize it
    local to_reference = vec3.new(reference:x() - origin:x(), reference:y() - origin:y(), reference:z() - origin:z())
    to_reference = to_reference:normalize()
    
    -- Create vector from origin to target and normalize it
    local to_target = vec3.new(target:x() - origin:x(), target:y() - origin:y(), target:z() - origin:z())
    to_target = to_target:normalize()
    
    -- Calculate the dot product
    local dot_product = to_reference:dot(to_target)
    
    -- Ensure dot product is in valid range for acos
    dot_product = math.max(-1.0, math.min(1.0, dot_product))
    
    -- Calculate the angle in degrees
    local angle = math.deg(math.acos(dot_product))
    
    -- Return true if angle is less than or equal to max_angle
    return angle <= max_angle
end

local function generate_points_around_target_rec(target_position, radius, num_points)
    local points = {}
    local angles = {}
    for i = 1, num_points do
        local angle = (i - 1) * (2 * math.pi / num_points)
        local x = target_position:x() + radius * math.cos(angle)
        local y = target_position:y() + radius * math.sin(angle)
        table.insert(points, vec3.new(x, y, target_position:z()))
        table.insert(angles, angle)
    end
    return points, angles
end

local function get_best_point_rec(target_position, rectangle_radius, width, current_hit_list)
    local points, angles = generate_points_around_target_rec(target_position, rectangle_radius, 8)
    local hit_table = {}

    for i, point in ipairs(points) do
        local angle = angles[i]
        -- Calculate the destination point based on width and angle
        local destination = vec3.new(point:x() + width * math.cos(angle), point:y() + width * math.sin(angle), point:z())

        local hit_list = utility and utility.get_units_inside_rectangle_list and utility.get_units_inside_rectangle_list(point, destination, width) or {}
        table.insert(hit_table, {point = point, hits = #hit_list, victim_list = hit_list})
    end

    table.sort(hit_table, function(a, b) return a.hits > b.hits end)

    local current_hit_list_amount = #current_hit_list
    if hit_table[1].hits > current_hit_list_amount then
        return hit_table[1] -- returning the point with the most hits
    end

    return {point = target_position, hits = current_hit_list_amount, victim_list = current_hit_list}
end

-- Define spell delays for better timing control
local spell_delays = {
    regular_cast = 0.2,
    channel_cast = 0.5,
    no_delay = 0.0
}

-- local local_player = get_local_player()
-- if local_player == nil then
--     return
-- end

local targeting_modes = {"Best Ranged", "Best Melee", "Best Cursor", "Closest Cursor"}

local plugin_label = "DEATHTRAP_ROGUE_ENHANCED_" -- add character name...

-- Project a point onto a line defined by a point and direction
function project_point_on_line(line_point, line_direction, point)
    -- Add input validation
    if not line_point or not line_direction or not point then
        return nil
    end
    
    -- Make sure direction is normalized
    local normalized_direction = line_direction
    if line_direction:length_3d() > 0 then
        normalized_direction = line_direction:normalize()
    else
        return nil  -- Can't project onto a zero-length direction
    end
    
    -- Vector from line_point to point
    local to_point = nil
    pcall(function()
        to_point = point:subtract(line_point)
    end)
    
    if not to_point then
        return nil
    end
    
    -- Calculate dot product
    local dot_product = to_point:dot(normalized_direction)
    
    -- Calculate projection point
    local projection = nil
    pcall(function()
        projection = line_point:add(normalized_direction:multiply(dot_product))
    end)
    
    return projection
end

-- Expose as part of my_utility
local my_utility = {
    plugin_label = "death_trap_rogue_",
    is_auto_play_enabled = is_auto_play_enabled,
    is_buff_active = is_buff_active,
    buff_stack_count = buff_stack_count,
    enemy_count_in_range = enemy_count_in_range,
    is_in_range = is_in_range,
    is_action_allowed = is_action_allowed,
    is_spell_allowed = is_spell_allowed,
    project_point_on_line = project_point_on_line,
    get_best_point = get_best_point,
    generate_points_around_target = generate_points_around_target,
    is_target_within_angle = is_target_within_angle,
    get_best_point_rec = get_best_point_rec,
    targeting_modes = targeting_modes,
    spell_delays = spell_delays
}

return my_utility