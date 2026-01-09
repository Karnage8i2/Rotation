local my_utility = require("my_utility/my_utility")
local spell_data = require("my_utility/spell_data")

local buff_tracker = {}

-- Store buff data with expiration tracking
buff_tracker.player_buffs = {}
buff_tracker.enemy_buffs = {}
buff_tracker.last_update_time = 0
buff_tracker.update_interval = 0.1

-- Define important buff IDs for quick reference
buff_tracker.important_buffs = {
    -- Rogue core buffs
    concealment = 794966,
    shadow_imbuement = 380289,
    poison_imbuement = 358509,
    cold_imbuement = 359247,
    dark_shroud = 786383,
    inner_sight = 391682,
    
    -- Enemy debuffs
    vulnerable = 298962,
    crowd_control = 39809,
    frozen = 290962,
    trapped = 1285259,
    
    -- Enemy buffs
    damage_resistance_provider = 367226,
    damage_resistance_receiver = 367227
}

-- Initialize the buff tracker
function buff_tracker.initialize()
    buff_tracker.player_buffs = {}
    buff_tracker.enemy_buffs = {}
    buff_tracker.last_update_time = 0
    console.print("Buff Tracker: Initialized")
    return true
end

-- Update player buffs - call this regularly
function buff_tracker.update_player_buffs()
    local current_time = get_time_since_inject()
    
    -- Only update at the defined interval
    if current_time - buff_tracker.last_update_time < buff_tracker.update_interval then
        return
    end
    
    buff_tracker.last_update_time = current_time
    
    -- Get player and their buffs
    local player = get_local_player()
    if not player then return end
    
    local player_buffs = nil
    local success = pcall(function() 
        player_buffs = player:get_buffs()
    end)
    
    if not success or not player_buffs then
        return
    end
    
    -- Clear expired buffs
    for buff_id, buff_data in pairs(buff_tracker.player_buffs) do
        if buff_data.expiry_time and current_time > buff_data.expiry_time then
            buff_tracker.player_buffs[buff_id] = nil
        end
    end
    
    -- Update current buffs
    for _, buff in ipairs(player_buffs) do
        local buff_id = buff.name_hash
        local remaining = 0
        
        -- Safely get remaining time
        pcall(function()
            remaining = buff:get_remaining_time() or 0
        end)
        
        buff_tracker.player_buffs[buff_id] = {
            stacks = buff.stacks or 0,
            remaining = remaining,
            expiry_time = current_time + remaining,
            updated_at = current_time,
            type = buff.type
        }
    end
end

-- Check if player has a specific buff
function buff_tracker.has_buff(buff_id, min_stacks)
    min_stacks = min_stacks or 1
    
    -- Force an update if we haven't updated recently
    local current_time = get_time_since_inject()
    if current_time - buff_tracker.last_update_time > buff_tracker.update_interval then
        buff_tracker.update_player_buffs()
    end
    
    local buff = buff_tracker.player_buffs[buff_id]
    return buff ~= nil and buff.stacks >= min_stacks
end

-- Get buff stacks for a specific buff
function buff_tracker.get_buff_stacks(buff_id)
    -- Force an update if we haven't updated recently
    local current_time = get_time_since_inject()
    if current_time - buff_tracker.last_update_time > buff_tracker.update_interval then
        buff_tracker.update_player_buffs()
    end
    
    local buff = buff_tracker.player_buffs[buff_id]
    return buff and buff.stacks or 0
end

-- Get remaining time for a specific buff
function buff_tracker.get_buff_remaining(buff_id)
    -- Force an update if we haven't updated recently
    local current_time = get_time_since_inject()
    if current_time - buff_tracker.last_update_time > buff_tracker.update_interval then
        buff_tracker.update_player_buffs()
    end
    
    local buff = buff_tracker.player_buffs[buff_id]
    return buff and buff.remaining or 0
end

-- Track important buffs on an enemy
function buff_tracker.track_enemy_buffs(enemy)
    if not enemy then return {} end
    
    local enemy_id = nil
    local success = pcall(function()
        enemy_id = enemy:get_id() or tostring(enemy)
    end)
    
    if not success or not enemy_id then
        return {}
    end
    
    local current_time = get_time_since_inject()
    
    -- Initialize enemy entry if needed
    if not buff_tracker.enemy_buffs[enemy_id] then
        buff_tracker.enemy_buffs[enemy_id] = {
            buffs = {},
            last_update = 0
        }
    end
    
    -- Only update at intervals to save performance
    if current_time - buff_tracker.enemy_buffs[enemy_id].last_update < buff_tracker.update_interval then
        return buff_tracker.enemy_buffs[enemy_id].buffs
    end
    
    -- Get enemy buffs
    local enemy_buffs = nil
    success = pcall(function() 
        enemy_buffs = enemy:get_buffs()
    end)
    
    if not success or not enemy_buffs then
        return {}
    end
    
    -- Clear old data
    buff_tracker.enemy_buffs[enemy_id].buffs = {}
    buff_tracker.enemy_buffs[enemy_id].last_update = current_time
    
    -- Store important buffs
    for _, buff in ipairs(enemy_buffs) do
        local buff_id = buff.name_hash
        
        -- Only track important buffs to save memory
        for name, id in pairs(buff_tracker.important_buffs) do
            if buff_id == id then
                local remaining = 0
                
                -- Safely get remaining time
                pcall(function()
                    remaining = buff:get_remaining_time() or 0
                end)
                
                buff_tracker.enemy_buffs[enemy_id].buffs[buff_id] = {
                    stacks = buff.stacks or 0,
                    remaining = remaining,
                    name = name,
                    type = buff.type
                }
                break
            end
        end
    end
    
    return buff_tracker.enemy_buffs[enemy_id].buffs
end

-- Check if enemy has a specific buff
function buff_tracker.enemy_has_buff(enemy, buff_id)
    if not enemy then return false end
    
    local enemy_id = nil
    local success = pcall(function()
        enemy_id = enemy:get_id() or tostring(enemy)
    end)
    
    if not success or not enemy_id then
        return false
    end
    
    -- Make sure we have tracked this enemy
    local buffs = buff_tracker.track_enemy_buffs(enemy)
    
    -- Check if the buff exists
    return buffs[buff_id] ~= nil
end

-- Clean up old enemy data periodically
function buff_tracker.clean_enemy_data()
    local current_time = get_time_since_inject()
    local cleanup_interval = 5.0 -- Clean every 5 seconds
    
    -- Only clean at intervals
    if not buff_tracker.last_cleanup_time or current_time - buff_tracker.last_cleanup_time > cleanup_interval then
        buff_tracker.last_cleanup_time = current_time
        
        local enemies_to_remove = {}
        local data_expiry = 10.0 -- Remove data older than 10 seconds
        
        -- Find expired enemy data
        for enemy_id, data in pairs(buff_tracker.enemy_buffs) do
            if current_time - data.last_update > data_expiry then
                table.insert(enemies_to_remove, enemy_id)
            end
        end
        
        -- Remove expired data
        for _, enemy_id in ipairs(enemies_to_remove) do
            buff_tracker.enemy_buffs[enemy_id] = nil
        end
    end
end

-- Get a comprehensive summary of player buffs
function buff_tracker.get_player_buff_summary()
    buff_tracker.update_player_buffs()
    
    local summary = {
        has_concealment = buff_tracker.has_buff(buff_tracker.important_buffs.concealment),
        has_shadow_imbuement = buff_tracker.has_buff(buff_tracker.important_buffs.shadow_imbuement),
        has_poison_imbuement = buff_tracker.has_buff(buff_tracker.important_buffs.poison_imbuement),
        has_cold_imbuement = buff_tracker.has_buff(buff_tracker.important_buffs.cold_imbuement),
        has_dark_shroud = buff_tracker.has_buff(buff_tracker.important_buffs.dark_shroud)
    }
    
    return summary
end

return buff_tracker 