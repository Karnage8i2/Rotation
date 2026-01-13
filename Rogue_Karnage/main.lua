local my_utility = require("my_utility/my_utility")
local my_target_selector = require("my_utility/my_target_selector")
local spell_data = require("my_utility/spell_data")
local spell_priority_default = require("spell_priority")
local menu = require("menu")
local enhancements_manager = require("my_utility/enhancements_manager")
local boss_buff_manager = require("my_utility/boss_buff_manager")

-- Add fallback checks for undefined variables at the top of the file
local function safe_get_menu_element(element, fallback)
    if element and type(element.get) == "function" then
        return element:get()
    end
    return fallback
end

-- Returns the active spell priority list based on selected profile
-- With rotation mode support for Death Trap (AOE vs Boss optimization)
local function get_active_spell_priority(player_position)
    -- Profile: 0 = Penetrating Shot (default), 1 = Death Trap (S11 Mobalytics), 2 = Flurry Shadow Imbuement Pit, 3 = Heartseeker Pit Hybrid
    local profile_index = safe_get_menu_element(menu.menu_elements.profile, 0)
    local rotation_mode = safe_get_menu_element(menu.menu_elements.rotation_mode, 0) -- 0=Auto, 1=AOE Priority, 2=Boss Priority

    if profile_index == 1 then
        -- S11 Death Trap Build (Mobalytics: https://mobalytics.gg/diablo-4/builds/rogue-death-trap)
        -- Determine rotation type: AOE for trash, Boss for single target
        local use_boss_rotation = false
        
        if rotation_mode == 2 then
            -- Boss Priority forced
            use_boss_rotation = true
        elseif rotation_mode == 1 then
            -- AOE Priority forced
            use_boss_rotation = false
        else
            -- Auto: detect based on enemy composition
            if player_position then
                local all_units, normal_units, elite_units, champion_units, boss_units = 
                    my_utility.enemy_count_in_range(15.0, player_position)
                
                -- Use Boss rotation if: boss present, champion present, or few enemies (elite focused)
                if (boss_units and boss_units > 0) or 
                   (champion_units and champion_units > 0) or
                   (elite_units and elite_units > 0 and all_units <= 3) then
                    use_boss_rotation = true
                end
            end
        end
        
        if use_boss_rotation then
            -- Boss Rotation: Defensive setup + burst combo
            return {
                "dark_shroud",       -- defensive layer
                "concealment",       -- stealth + vulnerable
                "shadow_imbuement",  -- amplify Death Trap
                "death_trap",        -- primary nuke (smart boss targeting)
                "poison_trap",       -- sustained damage
                "caltrop",           -- vulnerable if needed
                "shadow_step",       -- mobility
                "dash",              -- repositioning
                "blade_shift",       -- basic attack for energy
                "puncture",          -- alternative basic
            }
        else
            -- AOE Rotation: Fast clear for trash packs
            return {
                "concealment",       -- quick stealth
                "shadow_imbuement",  -- amplify traps
                "death_trap",        -- AOE nuke
                "poison_trap",       -- area damage
                "caltrop",           -- control
                "dark_shroud",       -- defense when needed
                "shadow_step",       -- mobility
                "dash",              -- quick repositioning
                "blade_shift",       -- basic attack for energy
                "puncture",          -- alternative basic
            }
        end
    elseif profile_index == 2 then
        -- Heartseeker-standard-PIT profile (balanced boss + trash)
        -- Priority: setup/CC -> imbuement -> Shadow Clone (boss/elite burst) -> Heartseeker core ST -> Flurry secondary -> mobility -> fallback
        return {
            "caltrop",           -- Vulnerable + Control setup
            "smoke_grenade",     -- Extra control/DR on elites/bosses
            "poison_trap",       -- Additional area control / damage where equipped
            "shadow_imbuement",  -- Always prep Flurry with imbuement when possible
            "shadow_clone",      -- Boss/elite burst multiplier, synced with imbuement
            "heartseeker",       -- Primary single-target core for this pit build
            "flurry",            -- Secondary melee AoE / cleanup when in range
            "dash",              -- Gap-close / dodge; allowed even with auto movement disabled
            "shadow_step",       -- Extra mobility + combo where enabled
            "penetrating_shot",  -- Fallback spender if equipped
        }
    elseif profile_index == 3 then
        -- Heartseeker Pit Hybrid profile
        -- Boss/elite prio: dark_shroud -> caltrop -> smoke_grenade -> shadow_clone -> barrage -> heartseeker
        -- Trash prio: dark_shroud -> caltrop -> smoke_grenade -> shadow_clone (on big packs) -> barrage -> heartseeker
        -- The main loop and boss/aoe mode flags control when these are allowed; this list encodes relative spell priority.
        return {
            "dark_shroud",   -- keep DR up before going in
            "caltrop",       -- ground control / damage zone first in packs
            "poison_trap",   -- poison trap for extra AoE and boss damage in the hybrid profile
            "smoke_grenade", -- CC + damage amp once enemies are in caltrops
            "shadow_clone",  -- burst window once setup is in place
            "barrage",       -- core spender for AoE/boss damage in hybrid profile
            "heartseeker",   -- default filler / main damage
        }
    elseif profile_index == 4 then
        return {
            "dance_of_knives",
            "concealment",
            "poison_imbuement",
            "poison_trap",
            "caltrop",
            "dash",
        }
    elseif profile_index == 5 then
        -- TB Leveling profile (Pit push variant uses Concealment + Poison Imbue + Death Trap + Poison Trap)
        return {
            "concealment",        -- stealth / unstoppable opener for pit push
            "poison_imbuement",   -- poison imbuement for TB leveling / pit burst
            "shadow_imbuement",   -- optional shadow imbuement support
            "death_trap",         -- pit burst nuke
            "poison_trap",        -- layered poison trap under packs / elites
            "twisting_blade",     -- main spender
            "blade_shift",        -- basic
            "puncture",           -- alt basic (if you ever swap)
            "shadow_step",        -- mobility / engage
            "dash",               -- extra mobility
        }
    end  
      
    -- Default Penetrating Shot profile (from spell_priority.lua)
    return spell_priority_default
end

-- Simple build configuration, used to specialize behavior for certain profiles
local build_config = {
    pit_flurry_shadow_imb = {
        profile_index = 2,   -- Heartseeker-standard-PIT profile index
        trash_enemy_threshold = 4, -- Enemies at/above this count are treated as AoE trash packs
    }
}

local function safe_get_player_position()
    local pos = get_player_position()
    if not pos then
        -- Return a default position if player position is nil
        return vec3.new(0, 0, 0)
    end
    return pos
end

local function safe_get_cursor_position()
    local pos = get_cursor_position()
    if not pos then
        -- Return a default position if cursor position is nil
        return vec3.new(0, 0, 0)
    end
    return pos
end

local function safe_get_local_player()
    local player = get_local_player()
    if not player then
        return nil
    end
    return player
end

local function safe_get_resource_percent()
    local player = safe_get_local_player()
    if not player or type(player.get_primary_resource_current) ~= "function" or type(player.get_primary_resource_max) ~= "function" then
        return nil
    end
    local current = player:get_primary_resource_current()
    local max = player:get_primary_resource_max()
    if not current or not max or max == 0 then
        return nil
    end
    return current / max
end

-- Add fallback for utility functions that might not exist
local function safe_utility_is_spell_ready(spell_id)
    -- spell_id must be a valid number
    if type(spell_id) ~= "number" then
        return false
    end

    if utility and type(utility.is_spell_ready) == "function" then
        return utility.is_spell_ready(spell_id)
    end
    return false
end

local function safe_utility_is_spell_affordable(spell_id)
    if utility and type(utility.is_spell_affordable) == "function" then
        return utility.is_spell_affordable(spell_id)
    end
    return false
end

local function safe_utility_use_health_potion()
    if utility and type(utility.use_health_potion) == "function" then
        return utility.use_health_potion()
    end
    return false
end

local function safe_utility_is_point_walkeable(position)
    if utility and type(utility.is_point_walkeable) == "function" then
        return utility.is_point_walkeable(position)
    end
    return true -- Default to walkable if function doesn't exist
end

local function safe_utility_get_units_inside_circle_list(position, radius)
    if utility and type(utility.get_units_inside_circle_list) == "function" then
        return utility.get_units_inside_circle_list(position, radius)
    end
    return {}
end

local function safe_utility_get_units_inside_rectangle_list(start_pos, end_pos, width)
    if utility and type(utility.get_units_inside_rectangle_list) == "function" then
        return utility.get_units_inside_rectangle_list(start_pos, end_pos, width)
    end
    return {}
end

local function safe_cast_spell_position(spell_id, position, delay)
    if cast_spell and type(cast_spell.position) == "function" then
        return cast_spell.position(spell_id, position, delay or 0.0)
    end
    return false
end

local function safe_pathfinder_move_to_cpathfinder(position)
    return false
end

local function safe_target_selector_get_target_closer(position, range)
    if target_selector and type(target_selector.get_target_closer) == "function" then
        return target_selector.get_target_closer(position, range)
    end
    return nil
end

local function safe_target_selector_is_wall_collision(player_pos, target, distance)
    if target_selector and type(target_selector.is_wall_collision) == "function" then
        return target_selector.is_wall_collision(player_pos, target, distance)
    end
    return false
end

local function safe_auto_play_is_active()
    -- Auto-play is disabled at script level: always report inactive
    return false
end

local function safe_auto_play_get_objective()
    if auto_play and type(auto_play.get_objective) == "function" then
        return auto_play.get_objective()
    end
    return nil
end

local function safe_loot_manager_get_all_items_chest_sort_by_distance()
    if loot_manager and type(loot_manager.get_all_items_chest_sort_by_distance) == "function" then
        return loot_manager.get_all_items_chest_sort_by_distance()
    end
    return {}
end

local function safe_loot_manager_is_lootable_item(item, is_gold, is_potion)
    if loot_manager and type(loot_manager.is_lootable_item) == "function" then
        return loot_manager.is_lootable_item(item, is_gold or false, is_potion or false)
    end
    return false
end

local function safe_loot_manager_loot_item_orbwalker(item)
    if loot_manager and type(loot_manager.loot_item_orbwalker) == "function" then
        return loot_manager.loot_item_orbwalker(item)
    end
    return false
end

local function safe_loot_manager_loot_item(item, is_gold, is_potion)
    if loot_manager and type(loot_manager.loot_item) == "function" then
        return loot_manager.loot_item(item, is_gold or false, is_potion or false)
    end
    return false
end

local function safe_loot_manager_is_potion_necessary()
    if loot_manager and type(loot_manager.is_potion_necessary) == "function" then
        return loot_manager.is_potion_necessary()
    end
    return false
end

local function safe_loot_manager_is_potion(item)
    if loot_manager and type(loot_manager.is_potion) == "function" then
        return loot_manager.is_potion(item)
    end
    return false
end

local function safe_loot_manager_is_gold(item)
    if loot_manager and type(loot_manager.is_gold) == "function" then
        return loot_manager.is_gold(item)
    end
    return false
end

local function safe_loot_manager_is_obols(item)
    if loot_manager and type(loot_manager.is_obols) == "function" then
        return loot_manager.is_obols(item)
    end
    return false
end

local function safe_actors_manager_get_enemy_npcs()
    if actors_manager and type(actors_manager.get_enemy_npcs) == "function" then
        return actors_manager.get_enemy_npcs()
    end
    return {}
end

local function safe_prediction_get_future_unit_position(unit, time)
    if prediction and type(prediction.get_future_unit_position) == "function" then
        return prediction.get_future_unit_position(unit, time)
    end
    return unit and unit:get_position() or vec3.new(0, 0, 0)
end

local function safe_graphics_w2s(position)
    if graphics and type(graphics.w2s) == "function" then
        return graphics.w2s(position)
    end
    return vec3.new(0, 0, 0)
end

local function safe_graphics_circle_3d(position, radius, color, thickness, segments)
    if graphics and type(graphics.circle_3d) == "function" then
        graphics.circle_3d(position, radius, color, thickness or 1.0, segments or 36)
    end
end

local function is_player_mounted()
    local player = safe_get_local_player()
    if not player then
        return false
    end

    local buffs = player:get_buffs()
    if not buffs then
        return false
    end

    local mount_buff_hash = 1923
    for _, buff in ipairs(buffs) do
        if buff.name_hash == mount_buff_hash then
            return true
        end
    end

    return false
end

local function try_auto_mount()
    -- Placeholder: platform does not expose a key or mount API here.
    -- Keeps signature so a real implementation can be plugged in later.
    return false
end

-- Add fallback for evade functions
local function safe_evade_is_dangerous_position(position)
    if evade and type(evade.is_dangerous_position) == "function" then
        return evade.is_dangerous_position(position)
    end
    return false
end

-- Add fallback for orbwalker functions
local function safe_orbwalker_get_orb_mode()
    if orbwalker and type(orbwalker.get_orb_mode) == "function" then
        return orbwalker.get_orb_mode()
    end
    return 0 -- Default to none mode
end

local function safe_orbwalker_set_block_movement(block)
    if orbwalker and type(orbwalker.set_block_movement) == "function" then
        orbwalker.set_block_movement(block)
    end
end

local function safe_orbwalker_set_clear_toggle(clear)
    if orbwalker and type(orbwalker.set_clear_toggle) == "function" then
        orbwalker.set_clear_toggle(clear)
    end
end

-- Helper to determine if script-driven movement should be treated as disabled
local function is_movement_disabled()
    -- Always disable script-driven movement: you control all movement yourself.
    return true
end

-- Add fallback for console functions
local function safe_console_print(message)
    if console and type(console.print) == "function" then
        console.print(message)
    end
end

-- Add fallback for get_time_since_inject
local function safe_get_time_since_inject()
    if get_time_since_inject then
        return get_time_since_inject()
    end
    return 0
end

-- Add fallback for get_hash
local function safe_get_hash(key)
    if get_hash then
        return get_hash(key)
    end
    return 0
end

-- Add fallback for get_equipped_spell_ids
local function safe_get_equipped_spell_ids()
    if get_equipped_spell_ids then
        return get_equipped_spell_ids()
    end
    return {}
end

-- Add fallback for on_render_menu
local function safe_on_render_menu(callback)
    if on_render_menu then
        on_render_menu(callback)
    end
end

-- Add fallback for on_update
local function safe_on_update(callback)
    if on_update then
        on_update(callback)
    end
end

-- Add fallback for on_render
local function safe_on_render(callback)
    if on_render then
        on_render(callback)
    end
end

local local_player = safe_get_local_player()
if local_player == nil then
    return
end

local character_id = local_player:get_character_class_id();
local is_rogue = character_id == 3;
if not is_rogue then
 return
end;

if console and type(console.print) == "function" then
    console.print("Rogue_Karnage: script initialized for Rogue")
end

-- orbwalker settings
safe_orbwalker_set_block_movement(true);
safe_orbwalker_set_clear_toggle(true);

local spells =
{
    concealment             = require("spells/concealment"),
    caltrop                 = require("spells/caltrop"),
    puncture                = require("spells/puncture"),
    heartseeker             = require("spells/heartseeker"),
    forcefull_arrow         = require("spells/forcefull_arrow"),
    blade_shift             = require("spells/blade_shift"),
    invigorating_strike     = require("spells/invigorating_strike"),
    twisting_blade          = require("spells/twisting_blade"),
    barrage                 = require("spells/barrage"),
    rapid_fire              = require("spells/rapid_fire"),
    flurry                  = require("spells/flurry"),
    penetrating_shot        = require("spells/penetrating_shot"),
    shadow_step             = require("spells/shadow_step"),
    smoke_grenade           = require("spells/smoke_grenade"),
    poison_trap             = require("spells/poison_trap"),
    dark_shroud             = require("spells/dark_shroud"),
    shadow_imbuement        = require("spells/shadow_imbuement"),
    poison_imbuement        = require("spells/poison_imbuement"),
    cold_imbuement          = require("spells/cold_imbuement"),
    shadow_clone            = require("spells/shadow_clone"),
    death_trap              = require("spells/death_trap"),
    rain_of_arrows          = require("spells/rain_of_arrows"),
    dance_of_knives         = require("spells/dance_of_knives"),
    evade                  = require("spells/evade"),
    dash                   = require("spells/dash"),
}

-- Add tracking variables for spell timings and cooldowns
if not _G.last_death_trap_time then _G.last_death_trap_time = 0 end
if not _G.last_concealment_time then _G.last_concealment_time = 0 end
if not _G.last_heartseeker_cast_time then _G.last_heartseeker_cast_time = 0 end
if not _G.last_shadowstep_time then _G.last_shadowstep_time = 0 end
if not _G.last_health_potion_time then _G.last_health_potion_time = 0 end
if not _G.last_dash_time then _G.last_dash_time = 0 end

if not _G.last_auto_loot_check_time then _G.last_auto_loot_check_time = 0 end
if not _G.auto_loot_check_interval then _G.auto_loot_check_interval = 0.4 end

if not _G.last_auto_mount_time then _G.last_auto_mount_time = 0 end
if not _G.auto_mount_interval then _G.auto_mount_interval = 3.0 end

-- Variables for casting
local can_move = 0.0
local cast_end_time = 0.0
local cast_delay = 0.2

-- Add global enemy blacklist at the top of the file, near the other globals
if not _G.blacklisted_enemies then _G.blacklisted_enemies = {} end

-- Add these global variables near the other globals
if not _G.last_position then _G.last_position = nil end
if not _G.time_at_position then _G.time_at_position = 0 end
if not _G.stuck_detection_time then _G.stuck_detection_time = 3.0 end -- seconds to consider player stuck

safe_on_render_menu(function()
    if not menu.menu_elements.main_tree:push("Rouge_Karnage") then
        return
    end

    menu.menu_elements.main_boolean:render("Enable Plugin", "")
    if safe_get_menu_element(menu.menu_elements.main_boolean, false) == false then
        menu.menu_elements.main_tree:pop()
        return
    end

    local options = {"Melee", "Ranged"}
    menu.menu_elements.mode:render("Mode", options, "")

    local profile_options = {"Penetrating Shot", "Death Trap (S11)", "Heartseeker-standard-PIT", "Heartseeker Pit Hybrid", "Dance of Knives PIT", "TB Leveling"}
    menu.menu_elements.profile:render("Profile", profile_options, "")
    
    -- Rotation Mode (for profiles that support it, like Death Trap)
    if current_profile_index == 1 then
        local rotation_options = {"Auto (Smart Detection)", "AOE Priority", "Boss Priority"}
        menu.menu_elements.rotation_mode:render("Rotation Mode", rotation_options, "Auto: Detects enemy composition | AOE: Optimized for trash | Boss: Optimized for single target")
    end
    
    menu.menu_elements.evade_cooldown:render("Evade Cooldown", "")

    -- Only show Boss Mode and Slow Penetrating Shot options for the Penetrating Shot profile (index 0)
    local current_profile_index = safe_get_menu_element(menu.menu_elements.profile, 0)
    if current_profile_index == 0 then
        menu.menu_elements.boss_mode:render("Boss Mode", menu.boss_mode_description)
        menu.menu_elements.slow_penetrating_shot:render("Slow Penetrating Shot", menu.slow_penetrating_shot_description)
        if safe_get_menu_element(menu.menu_elements.slow_penetrating_shot, false) then
            menu.menu_elements.slow_penetrating_shot_delay:render("Penetrating Shot Delay", menu.slow_penetrating_shot_delay_description, 3)
        end
    end

    -- Only show Pit push option for the TB Leveling profile (index 5)
    if current_profile_index == 5 then
        menu.menu_elements.pit_push:render("Pit push", menu.pit_push_description)
    end

    -- Global Helltide/NMD mode (available for all profiles)
    menu.menu_elements.helltide_nmd:render("Helltide-NMD", menu.helltide_nmd_description)

    if menu.menu_elements.settings_tree:push("Settings") then
        menu.menu_elements.enemy_count_threshold:render("Minimum Enemy Count",
            "       Minimum number of enemies in Enemy Evaluation Radius to consider them for targeting")
        menu.menu_elements.targeting_refresh_interval:render("Targeting Refresh Interval",
            "       Time between target checks in seconds       ", 1)
        menu.menu_elements.max_targeting_range:render("Max Targeting Range",
            "       Maximum range for targeting       ")
        menu.menu_elements.min_enemy_distance:render("Minimum Enemy Distance",
            "       Minimum distance to enemies before targeting them       ", 1)
        menu.menu_elements.cursor_targeting_radius:render("Cursor Targeting Radius",
            "       Area size for selecting target around the cursor       ", 1)
        menu.menu_elements.cursor_targeting_angle:render("Cursor Targeting Angle",
            "       Maximum angle between cursor and target to cast targetted spells       ")
        menu.menu_elements.best_target_evaluation_radius:render("Enemy Evaluation Radius",
            "       Area size around an enemy to evaluate if it's the best target       \n" ..
            "       If you use huge aoe spells, you should increase this value       \n" ..
            "       Size is displayed with debug/display targets with faded white circles       ", 1)

        menu.menu_elements.enable_enemy_blacklist:render("Enable Enemy Blacklisting",
            "Temporarily avoid targeting enemies that have been skipped - helps prevent getting stuck on elites in pit")
        if safe_get_menu_element(menu.menu_elements.enable_enemy_blacklist, false) then
            menu.menu_elements.blacklist_elite_enemies:render("Blacklist Elite Enemies",
                "Prioritize blacklisting elite enemies that are causing navigation problems")
            menu.menu_elements.blacklist_duration:render("Blacklist Duration", 
                "How long (in seconds) to avoid targeting a blacklisted enemy", 1)
        end

        menu.menu_elements.custom_enemy_weights:render("Custom Enemy Weights",
            "Enable custom enemy weights for determining best targets within Enemy Evaluation Radius")
        if safe_get_menu_element(menu.menu_elements.custom_enemy_weights, false) then
            if menu.menu_elements.custom_enemy_weights_tree:push("Custom Enemy Weights") then
                menu.menu_elements.enemy_weight_normal:render("Normal Enemy Weight",
                    "Weighing score for normal enemies - default is 2")
                menu.menu_elements.enemy_weight_elite:render("Elite Enemy Weight",
                    "Weighing score for elite enemies - default is 10")
                menu.menu_elements.enemy_weight_champion:render("Champion Enemy Weight",
                    "Weighing score for champion enemies - default is 15")
                menu.menu_elements.enemy_weight_boss:render("Boss Enemy Weight",
                    "Weighing score for boss enemies - default is 50")
                menu.menu_elements.enemy_weight_damage_resistance:render("Damage Resistance Aura Enemy Weight",
                    "Weighing score for enemies with damage resistance aura - default is 25")
                menu.menu_elements.custom_enemy_weights_tree:pop()
            end
        end

        menu.menu_elements.enable_debug:render("Enable Debug", "")
        if safe_get_menu_element(menu.menu_elements.enable_debug, false) then
            if menu.menu_elements.debug_tree:push("Debug") then
                menu.menu_elements.draw_targets:render("Display Targets", menu.draw_targets_description)
                menu.menu_elements.draw_max_range:render("Display Max Range",
                    "Draw max range circle")
                menu.menu_elements.draw_melee_range:render("Display Melee Range",
                    "Draw melee range circle")
                menu.menu_elements.draw_enemy_circles:render("Display Enemy Circles",
                    "Draw enemy circles")
                menu.menu_elements.draw_cursor_target:render("Display Cursor Target", menu.cursor_target_description)
                menu.menu_elements.debug_tree:pop()
            end
        end

        if menu.menu_elements.hold_position_combat then
            menu.menu_elements.hold_position_combat:render("Hold position in Combo/Clear", "")
        end

        if menu.menu_elements.tb_core_no_orbwalker == nil then
            menu.menu_elements.tb_core_no_orbwalker = checkbox:new(true, safe_get_hash((my_utility and my_utility.plugin_label or "death_trap_rogue_") .. "tb_core_no_orbwalker"))
        end
        menu.menu_elements.tb_core_no_orbwalker:render("Allow TB core spells without orbwalker", menu.tb_core_no_orbwalker_description)
        _G.tb_core_cast_without_orbwalker = safe_get_menu_element(menu.menu_elements.tb_core_no_orbwalker, true)

        menu.menu_elements.settings_tree:pop()
    end

    local equipped_spells = safe_get_equipped_spell_ids()
    table.insert(equipped_spells, spell_data.evade.spell_id) -- add evade to the list
    table.insert(equipped_spells, spell_data.death_trap.spell_id) -- force death_trap as equipped
    table.insert(equipped_spells, spell_data.concealment.spell_id) -- force concealment as equipped
    table.insert(equipped_spells, spell_data.shadow_step.spell_id) -- force shadow_step as equipped
    table.insert(equipped_spells, spell_data.shadow_imbuement.spell_id) -- force shadow_imbuement as equipped
    table.insert(equipped_spells, spell_data.dance_of_knives.spell_id) -- force dance_of_knives as equipped
    table.insert(equipped_spells, spell_data.poison_imbuement.spell_id) -- force poison_imbuement as equipped
    table.insert(equipped_spells, spell_data.poison_trap.spell_id) -- force poison_trap as equipped

    -- Create a lookup table for equipped spells
    local equipped_lookup = {}
    for _, spell_id in ipairs(equipped_spells) do
        -- Check each spell in spell_data to find matching spell_id
        for spell_name, data in pairs(spell_data) do
            if data.spell_id == spell_id then
                equipped_lookup[spell_name] = true
                break
            end
        end
    end

    if menu.menu_elements.spells_tree:push("Equipped Spells") then
        -- Display spells in priority order, but only if they're equipped
        local active_spell_priority = get_active_spell_priority()
        for _, spell_name in ipairs(active_spell_priority) do
            if equipped_lookup[spell_name] and spells[spell_name] then
                local spell = spells[spell_name]
                if spell and spell.menu then
                    spell.menu()
                end
            end
        end
        menu.menu_elements.spells_tree:pop()
    end

    if menu.menu_elements.disabled_spells_tree:push("Inactive Spells") then
        local active_spell_priority = get_active_spell_priority()
        for _, spell_name in ipairs(active_spell_priority) do
            local spell = spells[spell_name]
            if spell and spell.menu and (not equipped_lookup[spell_name] or 
               (spell.menu_elements and not safe_get_menu_element(spell.menu_elements.main_boolean, false))) then
                spell.menu()
            end
        end
        menu.menu_elements.disabled_spells_tree:pop()
    end

    -- Add enhancements menu
    enhancements_manager.render_enhancements_menu(menu.menu_elements)

    menu.menu_elements.main_tree:pop();
end)

 -- Targets
 local best_ranged_target = nil
 local best_ranged_target_visible = nil
 local best_melee_target = nil
 local best_melee_target_visible = nil
 local closest_target = nil
 local closest_target_visible = nil
 local best_cursor_target = nil
 local closest_cursor_target = nil
 local closest_cursor_target_angle = 0
 
 -- Target lock to reduce jittery target switching
 local TARGET_LOCK_DURATION = 0.4
 local locked_target = nil
 local locked_target_until = 0.0

-- Target scores
local ranged_max_score = 0
local ranged_max_score_visible = 0
local melee_max_score = 0
local melee_max_score_visible = 0
local cursor_max_score = 0

-- Targeting settings
local max_targeting_range = menu.menu_elements.max_targeting_range:get()
local collision_table = { true, 1 } -- collision width
local floor_table = { true, 5.0 }   -- floor height
local angle_table = { false, 90.0 } -- max angle

-- Cache for heavy function results
local next_target_update_time = 0.0 -- Time of next target evaluation
local next_cast_time = 0.0          -- Time of next possible cast
local targeting_refresh_interval = menu.menu_elements.targeting_refresh_interval:get()

-- Default enemy weights for different enemy types
local normal_monster_value = 2
local elite_value = 10
local champion_value = 15
local boss_value = 50
local damage_resistance_value = 25

-- Apply custom weights if enabled
if menu.menu_elements.custom_enemy_weights:get() then
    normal_monster_value = menu.menu_elements.enemy_weight_normal:get()
    elite_value = menu.menu_elements.enemy_weight_elite:get()
    champion_value = menu.menu_elements.enemy_weight_champion:get()
    boss_value = menu.menu_elements.enemy_weight_boss:get()
    damage_resistance_value = menu.menu_elements.enemy_weight_damage_resistance:get()
end

local target_selector_data_all = nil

-- Enhanced target evaluation function
local function evaluate_targets(target_list, melee_range)
    local best_ranged_target = nil
    local best_melee_target = nil
    local best_cursor_target = nil
    local closest_cursor_target = nil
    local closest_cursor_target_angle = 0

    local ranged_max_score = 0
    local melee_max_score = 0
    local cursor_max_score = 0

    local melee_range_sqr = melee_range * melee_range
    local player_position = get_player_position()
    local cursor_position = get_cursor_position()
    local cursor_targeting_radius = menu.menu_elements.cursor_targeting_radius:get()
    local cursor_targeting_radius_sqr = cursor_targeting_radius * cursor_targeting_radius
    local best_target_evaluation_radius = menu.menu_elements.best_target_evaluation_radius:get()
    local cursor_targeting_angle = menu.menu_elements.cursor_targeting_angle:get()
    local enemy_count_threshold = menu.menu_elements.enemy_count_threshold:get()

    -- Pit push behavior: when TB Leveling profile (index 5) and pit_push enabled, raise the minimum
    -- enemy count slightly so we don't dive tiny trash-only packs.
    local profile_index_for_pit = safe_get_menu_element(menu.menu_elements.profile, 0)
    local pit_push_enabled = profile_index_for_pit == 5 and safe_get_menu_element(menu.menu_elements.pit_push, false)
    local helltide_nmd_enabled = safe_get_menu_element(menu.menu_elements.helltide_nmd, false)
    if pit_push_enabled and enemy_count_threshold < 2 then
        enemy_count_threshold = 2
    end
    local min_enemy_distance = menu.menu_elements.min_enemy_distance:get()
    local min_enemy_distance_sqr = min_enemy_distance * min_enemy_distance
    local closest_cursor_distance_sqr = math.huge
    
    -- Clean up expired blacklisted enemies
    local current_time = get_time_since_inject()
    if menu.menu_elements.enable_enemy_blacklist:get() then
        for id, data in pairs(_G.blacklisted_enemies) do
            if current_time > data.expiry_time then
                _G.blacklisted_enemies[id] = nil
                console.print("Removed enemy " .. id .. " from blacklist (expired)")
            end
        end
    end

    -- First check if we have enough enemies to satisfy the minimum enemy count threshold
    local total_valid_enemies = 0
    local has_boss_enemy = false
    local has_high_value_enemy = false
    for _, unit in ipairs(target_list) do
        total_valid_enemies = total_valid_enemies + 1
        if unit:is_boss() then
            has_boss_enemy = true
        end
        if unit:is_boss() or unit:is_champion() or unit:is_elite() then
            has_high_value_enemy = true
        end
    end
    
    do
        local local_player_hp = safe_get_local_player()
        if local_player_hp and type(local_player_hp.get_current_health) == "function" and type(local_player_hp.get_max_health) == "function" then
            local current_hp = local_player_hp:get_current_health()
            local max_hp = local_player_hp:get_max_health()
            if max_hp and max_hp > 0 then
                local hp_percent = current_hp / max_hp
                if hp_percent < 0.30 then
                    local concealment_spell = spells["concealment"]
                    if concealment_spell and concealment_spell.logics and (not concealment_spell.menu_elements or concealment_spell.menu_elements.main_boolean:get()) then
                        if concealment_spell.logics() then
                            cast_end_time = current_time + 0.3
                            return
                        end
                    end
                end
            end
        end
    end

    -- If we don't have enough valid enemies total and no boss is present, return empty targets
    if pit_push_enabled then
        if total_valid_enemies < enemy_count_threshold and not has_high_value_enemy then
            return {
                best_ranged_target = nil,
                best_melee_target = nil,
                best_cursor_target = nil,
                closest_cursor_target = nil,
                closest_cursor_target_angle = 0,
                ranged_max_score = 0,
                melee_max_score = 0,
                cursor_max_score = 0
            }
        end
    elseif helltide_nmd_enabled then
        -- In Helltide/NMD mode, treat elites/champions/bosses as high-value when deciding
        -- whether a small pack is worth engaging.
        if total_valid_enemies < enemy_count_threshold and not has_high_value_enemy then
            return {
                best_ranged_target = nil,
                best_melee_target = nil,
                best_cursor_target = nil,
                closest_cursor_target = nil,
                closest_cursor_target_angle = 0,
                ranged_max_score = 0,
                melee_max_score = 0,
                cursor_max_score = 0
            }
        end
    else
        if total_valid_enemies < enemy_count_threshold and not has_boss_enemy then
            return {
                best_ranged_target = nil,
                best_melee_target = nil,
                best_cursor_target = nil,
                closest_cursor_target = nil,
                closest_cursor_target_angle = 0,
                ranged_max_score = 0,
                melee_max_score = 0,
                cursor_max_score = 0
            }
        end
    end

    for _, unit in ipairs(target_list) do
        local unit_id = nil
        pcall(function() unit_id = unit:get_id() or tostring(unit) end)
        
        -- Skip blacklisted enemies
        if menu.menu_elements.enable_enemy_blacklist:get() and unit_id and _G.blacklisted_enemies[unit_id] then
            console.print("Skipping blacklisted enemy: " .. unit_id)
            goto continue
        end
        
        local unit_health = unit:get_current_health()
        local unit_name = unit:get_skin_name()
        local unit_position = unit:get_position()
        local distance_sqr = unit_position:squared_dist_to_ignore_z(player_position)
        local cursor_distance_sqr = unit_position:squared_dist_to_ignore_z(cursor_position)
        local buffs = unit:get_buffs()

        -- Skip enemies that are too close based on min_enemy_distance setting
        if distance_sqr < min_enemy_distance_sqr then
            -- If we're skipping an elite enemy and blacklisting is enabled, add it to the blacklist
            if menu.menu_elements.enable_enemy_blacklist:get() and 
               menu.menu_elements.blacklist_elite_enemies:get() and
               unit:is_elite() and unit_id then
                local blacklist_duration = menu.menu_elements.blacklist_duration:get()
                _G.blacklisted_enemies[unit_id] = {
                    expiry_time = current_time + blacklist_duration,
                    position = unit_position,
                    is_elite = unit:is_elite(),
                    is_champion = unit:is_champion(),
                    is_boss = unit:is_boss()
                }
                console.print("Blacklisted elite enemy " .. unit_id .. " for " .. blacklist_duration .. " seconds")
            end
            goto continue
        end

        -- Get enemy count in range of enemy unit
        local all_units_count, normal_units_count, elite_units_count, champion_units_count, boss_units_count = my_utility.enemy_count_in_range(best_target_evaluation_radius, unit_position)

        -- Calculate total score based on enemy count and enemy type weights
        local total_score = normal_units_count * normal_monster_value
        if boss_units_count > 0 then
            total_score = total_score + boss_value * boss_units_count
        elseif champion_units_count > 0 then
            total_score = total_score + champion_value * champion_units_count
        elseif elite_units_count > 0 then
            total_score = total_score + elite_value * elite_units_count
        end

        -- Check for damage resistance buffs
        for _, buff in ipairs(buffs) do
            if spell_data.enemies and spell_data.enemies.damage_resistance and 
               buff.name_hash == spell_data.enemies.damage_resistance.spell_id then
                -- If enemy is provider of damage resistance aura
                if spell_data.enemies.damage_resistance.buff_ids and 
                   buff.type == spell_data.enemies.damage_resistance.buff_ids.provider then
                    total_score = total_score + damage_resistance_value
                    break
                else -- Enemy is receiver of damage resistance aura
                    total_score = total_score - damage_resistance_value
                    break
                end
            end
        end

        -- Add bonus score for vulnerable or recently hit enemies
        if unit:is_vulnerable() then
            total_score = total_score + 5000
        end

        -- Update best ranged target if this unit has higher score
        if distance_sqr <= max_targeting_range * max_targeting_range then
            if total_score > ranged_max_score then
                best_ranged_target = unit
                ranged_max_score = total_score
            end
        end

        -- Update best melee target if this unit is in melee range and has higher score
        if distance_sqr <= melee_range_sqr then
            if total_score > melee_max_score then
                best_melee_target = unit
                melee_max_score = total_score
            end
        end

        -- Update cursor targets
        if cursor_distance_sqr <= cursor_targeting_radius_sqr then
            local is_within_angle = my_utility.is_target_within_angle(player_position, cursor_position, unit_position, cursor_targeting_angle)
            
            if is_within_angle then
                if total_score > cursor_max_score then
                    best_cursor_target = unit
                    cursor_max_score = total_score
                end

                if cursor_distance_sqr < closest_cursor_distance_sqr then
                    closest_cursor_target = unit
                    closest_cursor_distance_sqr = cursor_distance_sqr
                    closest_cursor_target_angle = cursor_targeting_angle
                end
            end
        end
        
        ::continue::
    end

    return {
        best_ranged_target = best_ranged_target,
        best_melee_target = best_melee_target,
        best_cursor_target = best_cursor_target,
        closest_cursor_target = closest_cursor_target,
        closest_cursor_target_angle = closest_cursor_target_angle,
        ranged_max_score = ranged_max_score,
        melee_max_score = melee_max_score,
        cursor_max_score = cursor_max_score
    }
end

-- Initialize enhancements
local enhancements_initialized = false

safe_on_update(function()
    local local_player = safe_get_local_player()
    if not local_player or not safe_get_menu_element(menu.menu_elements.main_boolean, false) then
        return
    end

    if not _G.rogue_karnage_loaded_logged then
        if console and type(console.print) == "function" then
            console.print("Rogue_Karnage: script initialized for Rogue")
        end
        _G.rogue_karnage_loaded_logged = true
    end

    if not my_utility.is_action_allowed() then
        return
    end

    local current_time = safe_get_time_since_inject()

    -- Initialize enhancements if not done already
    if not enhancements_initialized then
        enhancements_initialized = enhancements_manager.initialize(menu.menu_elements)
    end
    
    -- Initialize boss buff manager if not done already
    if not _G.boss_buff_manager_initialized then
        _G.boss_buff_manager_initialized = boss_buff_manager.initialize()
    end
    
    -- Global auto-mount when out of combat
    do
        local player_position = safe_get_player_position()
        local enemy_count = 0
        if player_position then
            local all_units_count = 0
            pcall(function()
                all_units_count = my_utility.enemy_count_in_range(20.0, player_position)
            end)
            enemy_count = all_units_count or 0
        end

        if not is_player_mounted() and enemy_count == 0 then
            local now = safe_get_time_since_inject()
            if now - _G.last_auto_mount_time >= _G.auto_mount_interval then
                if try_auto_mount() then
                    _G.last_auto_mount_time = now
                end
            end
        end
    end
    
    -- Determine if script-driven movement should be disabled (Death Trap profile, single target)
    local disable_script_movement = false
    do
        local profile_index = safe_get_menu_element(menu.menu_elements.profile, 0)
        if profile_index == 1 then -- Death Trap profile
            local player_position = safe_get_player_position()
            if player_position then
                local enemy_count = 0
                local ok, all_units_count = pcall(function()
                    return my_utility.enemy_count_in_range(20.0, player_position)
                end)
                if ok and type(all_units_count) == "number" then
                    enemy_count = all_units_count
                end

                if enemy_count <= 1 then
                    disable_script_movement = true
                end
            end
        end
    end

    -- Process stuck detection and auto-blacklisting
    local player_position = safe_get_player_position()
    if player_position then
        if not _G.last_position then
            _G.last_position = player_position
            _G.time_at_position = current_time
        else
            local movement_threshold = 1.0 -- Units of movement to consider player moved
            local distance_moved = player_position:dist_to(_G.last_position)
            
            if distance_moved > movement_threshold then
                -- Player moved, reset timer
                _G.last_position = player_position
                _G.time_at_position = current_time
            else
                -- Check if player is stuck
                local time_stuck = current_time - _G.time_at_position
                if time_stuck > _G.stuck_detection_time and safe_get_menu_element(menu.menu_elements.enable_enemy_blacklist, false) then
                    -- Player might be stuck, blacklist nearby elite enemies
                    console.print("Possible stuck detected! Blacklisting nearby elite enemies")
                    
                    -- Get nearby enemies
                    local danger_radius = 20.0
                    local enemies = safe_utility_get_units_inside_circle_list(player_position, danger_radius)
                    local blacklisted_count = 0
                    
                    for _, enemy in ipairs(enemies) do
                        if (enemy:is_elite() or enemy:is_champion()) and blacklisted_count < 3 then
                            local enemy_id = nil
                            pcall(function() enemy_id = enemy:get_id() or tostring(enemy) end)
                            
                            if enemy_id and not _G.blacklisted_enemies[enemy_id] then
                                local blacklist_duration = safe_get_menu_element(menu.menu_elements.blacklist_duration, 15.0) * 2 -- Double duration for stuck detection
                                _G.blacklisted_enemies[enemy_id] = {
                                    expiry_time = current_time + blacklist_duration,
                                    position = enemy:get_position(),
                                    is_elite = enemy:is_elite(),
                                    is_champion = enemy:is_champion(),
                                    is_boss = enemy:is_boss()
                                }
                                blacklisted_count = blacklisted_count + 1
                                console.print("Auto-blacklisted enemy " .. enemy_id .. " for " .. blacklist_duration .. " seconds")
                            end
                        end
                    end
                    
                    -- Reset timer to prevent constant blacklisting
                    _G.time_at_position = current_time
                    
                    -- Force a new path calculation
                    if blacklisted_count > 0 then
                                            -- Try to use dash or shadow step to escape
                    if false and safe_utility_is_spell_ready(spells.dash.spell_id) then
                        -- Get random direction away from current position
                        local random_angle = math.random() * 2 * math.pi
                        local escape_dir = vec3.new(math.cos(random_angle), math.sin(random_angle), 0)
                        local dash_pos = player_position:add(escape_dir:multiply(5.0))
                        
                        if safe_utility_is_point_walkeable(dash_pos) then
                            if safe_cast_spell_position(spells.dash.spell_id, dash_pos, 0.1) then
                                _G.last_dash_time = current_time
                                safe_console_print("Auto-used Dash to escape stuck position")
                                cast_end_time = current_time + 0.2
                            end
                        end
                    end
                    end
                end
            end
        end
    end
    
    -- Process enhanced evade if enabled (with throttling to reduce spam)
    if menu.menu_elements.enhanced_evade and safe_get_menu_element(menu.menu_elements.enhanced_evade, false) then
        -- Throttle evade processing to reduce spam
        local current_time = get_time_since_inject()
        local last_evade_check = _G.last_evade_check or 0
        local evade_check_interval = 0.5 -- Check evade every 0.5 seconds instead of every frame
        
        if current_time - last_evade_check >= evade_check_interval then
            _G.last_evade_check = current_time
            
            -- Wrap evade processing in pcall to prevent script errors
            local evaded = false
            local evade_success = pcall(function()
                evaded = enhancements_manager.process_evade(menu.menu_elements)
            end)
            
            if evade_success and evaded then
                -- Successfully evaded, skip the rest of this frame
                return
            end
        end
    end
    
    -- Manage buffs if enabled
    if menu.menu_elements.auto_buff_management and safe_get_menu_element(menu.menu_elements.auto_buff_management, false) then
        -- Wrap buff management in pcall to prevent script errors
        local buff_managed, buff_action = false, nil
        local buff_success = pcall(function()
            buff_managed, buff_action = enhancements_manager.manage_buffs(menu.menu_elements)
        end)
        
        if buff_success and buff_managed then
            -- Buff management took action, skip the rest of this frame
            return
        end
    end
    
    -- Position optimization if enabled and we're not casting
    if menu.menu_elements.position_optimization 
       and safe_get_menu_element(menu.menu_elements.position_optimization, false) 
       and not is_movement_disabled()
       and not disable_script_movement
       and current_time > cast_end_time then
        -- Wrap position optimization in pcall to prevent script errors
        local position_result = { should_move = false }
        local position_success = pcall(function()
            position_result = enhancements_manager.optimize_position(menu.menu_elements)
        end)
        
        if position_success and position_result and position_result.should_move then
            -- Temporarily disable orbwalker movement blocking
            safe_orbwalker_set_block_movement(false)
            -- Let the script handle movement this frame
            return
        end
    end

    -- Check auto-play objective to adapt behavior
    if safe_auto_play_is_active() then
        local current_objective = safe_auto_play_get_objective()
        
        -- Skip combat logic for non-combat objectives
        if current_objective == objective.loot then
            -- Throttle auto-loot checks to reduce spam
            local now = safe_get_time_since_inject()
            if now - _G.last_auto_loot_check_time >= _G.auto_loot_check_interval then
                _G.last_auto_loot_check_time = now

                -- Only handle loot functionality
                local nearby_items = safe_loot_manager_get_all_items_chest_sort_by_distance()
                for _, item in ipairs(nearby_items) do
                    if safe_loot_manager_is_lootable_item(item, false, false) then
                        safe_loot_manager_loot_item_orbwalker(item)
                        return
                    end
                end
            end
            return
        elseif current_objective == objective.sell or current_objective == objective.repair then
            -- Skip combat rotation during selling/repairing
            return
        elseif current_objective == objective.travel then
            -- During travel, only use mobility spells and avoid combat
            safe_console_print("Auto-play: objective.travel active, evaluating auto-mount")
            local player_position = safe_get_player_position()
            local enemy_count = 0
            if player_position then
                local all_units_count = 0
                pcall(function()
                    all_units_count = my_utility.enemy_count_in_range(20.0, player_position)
                end)
                enemy_count = all_units_count or 0
            end

            if not is_player_mounted() and enemy_count == 0 then
                local now = safe_get_time_since_inject()
                if now - _G.last_auto_mount_time >= _G.auto_mount_interval then
                    if try_auto_mount() then
                        _G.last_auto_mount_time = now
                    end
                end
            end

            if spells.evade and spells.evade.out_of_combat and current_time - _G.last_dash_time > 5.0 then
                spells.evade.out_of_combat()
            end
            return
        end
        -- Continue with combat rotation for objective.fight
    end

    -- Option B: gate casting by Hold position in Combo/Clear instead of movement.
    -- If hold_position_combat is enabled, only run the combat rotation when
    -- orbwalker mode is PvP or Clear; otherwise skip this frame.
    -- TB Leveling profile (index 5) is exempt so it can auto-cast independently of orbwalker.
    local profile_index_hold = safe_get_menu_element(menu.menu_elements.profile, 0)
    if profile_index_hold ~= 5 and menu.menu_elements.hold_position_combat and safe_get_menu_element(menu.menu_elements.hold_position_combat, false) then
        local current_orb_mode = safe_orbwalker_get_orb_mode()
        if not (orb_mode and (current_orb_mode == orb_mode.pvp or current_orb_mode == orb_mode.clear)) then
            return
        end
    end

    -- Target selection setup with improved cached targeting
    local player_position = safe_get_player_position()
    local target_list = {}
    local target_evaluation = {}
    
    if current_time >= next_target_update_time then
        -- Only run heavy targeting operations when necessary
        max_targeting_range = safe_get_menu_element(menu.menu_elements.max_targeting_range, 30)
        targeting_refresh_interval = safe_get_menu_element(menu.menu_elements.targeting_refresh_interval, 0.2)
        
        collision_table = {false, 1.0}
        floor_table = {true, 3.0}
        angle_table = {false, 90.0}

        target_list = my_target_selector.get_target_list(
        player_position,
            max_targeting_range,
        collision_table,
        floor_table,
        angle_table)

        target_selector_data_all = my_target_selector.get_target_selector_data(
        player_position,
            target_list)
            
        -- Get all targeting information
        local melee_range = (menu.menu_elements.mode:get() <= 0) and 9.0 or 2.0
        target_evaluation = evaluate_targets(target_list, melee_range)
        
        -- Cache results
        best_ranged_target = target_evaluation.best_ranged_target
        best_melee_target = target_evaluation.best_melee_target
        best_cursor_target = target_evaluation.best_cursor_target
        closest_cursor_target = target_evaluation.closest_cursor_target
        closest_cursor_target_angle = target_evaluation.closest_cursor_target_angle
        ranged_max_score = target_evaluation.ranged_max_score
        melee_max_score = target_evaluation.melee_max_score
        cursor_max_score = target_evaluation.cursor_max_score
        
        next_target_update_time = current_time + targeting_refresh_interval
    end

    if not target_selector_data_all or not target_selector_data_all.is_valid then
        return
    end

    -- Range setup based on mode
    local is_auto_play_active = safe_auto_play_is_active()
    local max_range = 26.0
    local mode_id = safe_get_menu_element(menu.menu_elements.mode, 0)
    local is_ranged = mode_id >= 1
    if mode_id <= 0 then -- melee
        max_range = 10.0
    end

    if is_auto_play_active then
        if is_ranged then
            max_range = 20.0  -- Increased range for ranged mode in auto-play
        else
            max_range = 12.0  -- Keep existing range for melee mode in auto-play
        end
    end

    -- Determine primary target based on configuration and context
    local closest_target = target_selector_data_all.closest_unit
    local candidate_target = nil
    
    if is_ranged then
        candidate_target = best_ranged_target
    else
        candidate_target = best_melee_target
    end
    
    if not candidate_target then
        candidate_target = closest_target
    end

    local best_target = candidate_target

    -- Heartseeker build check
    local spell_id_heartseeker = 363402
    local is_heartseeker_build = is_ranged and safe_utility_is_spell_ready(spell_id_heartseeker)
    local is_best_target_exception = false

    if is_heartseeker_build and best_target then
        if best_target:is_vulnerable() then
            is_best_target_exception = true
        end

        if not is_best_target_exception then
            local buffs = best_target:get_buffs()
            if buffs then
                for _, debuff in ipairs(buffs) do
                    if debuff.name_hash == 39809 or debuff.name_hash == 298962 then
                        is_best_target_exception = true
                        break
                    end
                end
            end
        end
    end

    -- Check if boss mode is enabled
    local boss_mode_enabled = safe_get_menu_element(menu.menu_elements.boss_mode, false)
    do
        local profile_index_bossmode = safe_get_menu_element(menu.menu_elements.profile, 0)
        if profile_index_bossmode ~= 0 then
            boss_mode_enabled = false
        end
    end
    
    -- Boss Mode: Skip normal rotation and spam all spells aggressively
    if boss_mode_enabled then
        -- Boss Mode: Cast buffs immediately when there's an enemy to attack
        if target_list and #target_list > 0 then
            -- Add a delay to prevent spam in boss mode
            local last_boss_buff_check = _G.last_boss_buff_check or 0
            if current_time - last_boss_buff_check >= 0.5 then -- Check every 500ms instead of every frame
                _G.last_boss_buff_check = current_time
                
                -- In boss mode, cast buffs for any enemy encounter, not just bosses/champions
                local buff_casted, buff_spell = boss_buff_manager.process_boss_buff_rotation(target_list, target_selector_data_all, best_target, true)
                if buff_casted then
                    cast_end_time = current_time + 0.1 -- Fast buff casting in boss mode
                    console.print("Boss mode: Cast " .. buff_spell .. " buff immediately")
                    return -- Exit after casting buff to prioritize buffs
                end
            end
        end
        
        -- Cast penetrating shot as rapidly as possible (hold button behavior)
        local spell = spells["penetrating_shot"]
        if spell and spell.logics and utility.is_spell_ready(377137) and 
           (not spell.menu_elements or spell.menu_elements.main_boolean:get()) then
            local result = spell.logics(target_list, target_selector_data_all, best_target)
            if result then
                cast_end_time = current_time + 0.01 -- Minimal delay for rapid casting
            end
        end
        
        -- Boss Mode: Prioritize area control spells (smoke grenade, poison trap, caltrops)
        local boss_area_spells = {"smoke_grenade", "poison_trap", "caltrop"}
        for _, spell_name in ipairs(boss_area_spells) do
            local spell = spells[spell_name]
            if not spell or not spell.logics then goto continue_boss_area end
            if spell.menu_elements and not spell.menu_elements.main_boolean:get() then goto continue_boss_area end
            
            -- Check if spell is ready and affordable
            local spell_id = nil
            if spell_name == "poison_trap" then spell_id = 416528
            elseif spell_name == "smoke_grenade" then spell_id = 356162
            elseif spell_name == "caltrop" then spell_id = 389667
            end
            
            if spell_id and utility.is_spell_ready(spell_id) and utility.is_spell_affordable(spell_id) then
                local result = spell.logics(target_list, target_selector_data_all, best_target)
                if result then
                    cast_end_time = current_time + 0.05 -- Faster casting in boss mode
                    console.print("Boss mode: Cast " .. spell_name .. " successfully")
                    break -- Cast one area spell per frame
                end
            end
            ::continue_boss_area::
        end
        
        -- Spam all other damage spells off cooldown
        local player_pos = safe_get_player_position()
        local active_spell_priority = get_active_spell_priority(player_pos)
        for _, spell_name in ipairs(active_spell_priority) do
            if spell_name ~= "penetrating_shot" and spell_name ~= "smoke_grenade" and spell_name ~= "poison_trap" and spell_name ~= "caltrop" then
                local spell = spells[spell_name]
                if not spell or not spell.logics then goto continue_boss end
                if spell.menu_elements and not spell.menu_elements.main_boolean:get() then goto continue_boss end
                
                -- Check if spell is ready and affordable
                local spell_id = nil
                if spell_name == "shadow_clone" then spell_id = 357628
                elseif spell_name == "shadow_imbuement" then spell_id = 380288
                elseif spell_name == "dash" then spell_id = 358761
                elseif spell_name == "shadow_step" then spell_id = 355606
                elseif spell_name == "dark_shroud" then spell_id = 786381
                end
                
                if spell_id and utility.is_spell_ready(spell_id) and utility.is_spell_affordable(spell_id) then
                    local result = false
                    
                    -- Cast based on spell type
                    if spell_name == "shadow_clone" then
                        result = spell.logics()
                    elseif spell_name == "shadow_imbuement" or spell_name == "dark_shroud" then
                        result = spell.logics()
                    elseif spell_name == "dash" or spell_name == "shadow_step" then
                        result = spell.logics(best_target)
                    else
                        result = spell.logics(best_target)
                    end
                    
                    if result then
                        cast_end_time = current_time + 0.05 -- Faster casting in boss mode
                        console.print("Boss mode: Cast " .. spell_name .. " successfully")
                        break -- Only cast one spell per frame in boss mode
                    end
                end
            end
            ::continue_boss::
        end
        return -- Exit early in boss mode
    end
    
    -- Normal Mode: Main spell rotation with prioritization
    -- Check if we're fighting a boss (like Belial) and enable aggressive mode
    local is_boss_fight = false
    if best_target and (best_target:is_boss() or best_target:is_champion()) then
        is_boss_fight = true
        console.print("Boss fight detected - enabling aggressive mode")
    elseif player_position then
        local ok_boss_scan, all_units_b, normal_b, elite_b, champion_b, boss_b = pcall(function()
            return my_utility.enemy_count_in_range(12.0, player_position)
        end)
        if ok_boss_scan and ((elite_b or 0) > 0 or (champion_b or 0) > 0 or (boss_b or 0) > 0) then
            is_boss_fight = true
        end
    end

    -- Pit build specialization: determine trash AoE vs single-target burst mode
    local profile_index = safe_get_menu_element(menu.menu_elements.profile, 0)
    -- Treat Death Trap PIT (1), Heartseeker-standard-PIT (2), Heartseeker Pit Hybrid (3) and Dance of Knives PIT (4) as pit profiles
    local is_pit_flurry_profile = (build_config.pit_flurry_shadow_imb and (profile_index == 1 or profile_index == build_config.pit_flurry_shadow_imb.profile_index or profile_index == 3 or profile_index == 4))
    local is_trash_aoe_mode = false
    local is_single_target_burst = false

    if is_pit_flurry_profile then
        local enemy_count_near_player = 0
        local high_value_near_player = false
        if player_position then
            local ok, all_units_count, normal_units_count, elite_units_count, champion_units_count, boss_units_count = pcall(function()
                return my_utility.enemy_count_in_range(build_config.pit_flurry_shadow_imb.trash_enemy_threshold + 2.0, player_position)
            end)
            if ok then
                enemy_count_near_player = all_units_count or 0
                high_value_near_player = (elite_units_count or 0) > 0 or (champion_units_count or 0) > 0 or (boss_units_count or 0) > 0
            end
        end

        if high_value_near_player and enemy_count_near_player <= build_config.pit_flurry_shadow_imb.trash_enemy_threshold then
            -- Few enemies but at least one elite/champion/boss: treat as single-target burst
            is_single_target_burst = true
        elseif enemy_count_near_player >= build_config.pit_flurry_shadow_imb.trash_enemy_threshold then
            -- High enemy count: prefer trash AoE behavior
            is_trash_aoe_mode = true
        end
    end
    
    -- Process boss buff rotation for boss/elite encounters (normal mode only)
    if (is_boss_fight or boss_buff_manager.is_boss_encounter(target_list, best_target)) then
        local buff_casted, buff_spell = boss_buff_manager.process_boss_buff_rotation(target_list, target_selector_data_all, best_target, false)
        if buff_casted then
            cast_end_time = current_time + 0.3
            console.print("Boss Buff Manager: Cast " .. buff_spell .. " for buff effect before penetrating shot")
            return -- Exit after casting buff spell to prioritize buffs over penetrating shot
        end
    end
    
    -- Cast penetrating shot with configurable speed (Penetrating Shot profile only)
    local profile_index = safe_get_menu_element(menu.menu_elements.profile, 0)
    if profile_index == 0 then
        local spell = spells["penetrating_shot"]
        if spell and spell.logics and utility.is_spell_ready(377137) and 
           (not spell.menu_elements or spell.menu_elements.main_boolean:get()) then
            -- Check if slow penetrating shot is enabled and apply cooldown
            local last_penetrating_shot_time = _G.last_penetrating_shot_time or 0
            local cast_delay = safe_get_menu_element(menu.menu_elements.slow_penetrating_shot, false) and 
                              safe_get_menu_element(menu.menu_elements.slow_penetrating_shot_delay, 0.01) or 0.001
            
            -- Check if enough time has passed since last cast
            if current_time - last_penetrating_shot_time >= cast_delay then
                local result = spell.logics(target_list, target_selector_data_all, best_target)
                if result then
                    cast_end_time = current_time + 0.1 -- Small delay for next frame
                    return -- Exit after casting penetrating shot to prioritize it
                elseif is_boss_fight then
                    console.print("Penetrating shot failed to cast in boss fight")
                end
            end
        end
    end
    
    -- Check if spells were cast recently to prevent over-prioritization over penetrating shot
    -- Reduce cooldowns in boss fights for more aggressive casting
    local cooldown_multiplier = is_boss_fight and 0.3 or 1.0 -- 70% reduction in boss fights for area spells

    -- Pit build adjustments: be more aggressive in AoE trash and controlled in single-target burst
    if is_pit_flurry_profile then
        if is_trash_aoe_mode then
            -- In high-density trash, spam area tools and imbuement more aggressively
            cooldown_multiplier = 0.5 * cooldown_multiplier
        elseif is_single_target_burst then
            -- In boss/elite single-target, lean on existing boss multiplier but avoid going too crazy
            cooldown_multiplier = math.max(cooldown_multiplier, 0.4)
        end
    end
    
    local caltrop_cooldown = 3.0 * cooldown_multiplier -- 3 second cooldown for caltrop to prevent spam
    local smoke_grenade_cooldown = 4.0 * cooldown_multiplier -- 4 second cooldown for smoke grenade to prevent spam
    local poison_trap_cooldown = 4.0 * cooldown_multiplier -- 4 second cooldown for poison trap to prevent spam
    if is_pit_flurry_profile and is_trash_aoe_mode then
        poison_trap_cooldown = 3.0 * cooldown_multiplier
    end
    local shadow_imbuement_cooldown = 8.0 * cooldown_multiplier -- 8 second cooldown for shadow imbuement to prevent spam
    local shadow_clone_cooldown = 5.0 * cooldown_multiplier -- 5 second cooldown for shadow clone to prevent spam
    if is_pit_flurry_profile and is_trash_aoe_mode then
        -- In high-density trash AoE, allow more frequent Shadow Clone usage for faster clear
        shadow_clone_cooldown = 3.0 * cooldown_multiplier
    end
    local dash_cooldown = 3.0 * cooldown_multiplier -- 3 second cooldown for dash to prevent spam
    local shadow_step_cooldown = 4.0 * cooldown_multiplier -- 4 second cooldown for shadow step to prevent spam
    local dark_shroud_cooldown = 6.0 * cooldown_multiplier -- 6 second cooldown for dark shroud to prevent spam
    
    local last_caltrop_time = _G.last_caltrop_time or 0
    local last_smoke_grenade_time = _G.last_smoke_grenade_time or 0
    local last_poison_trap_time = _G.last_poison_trap_time or 0
    local last_shadow_imbuement_time = _G.last_shadow_imbuement_time or 0
    local last_shadow_clone_time = _G.last_shadow_clone_time or 0
    local last_dash_time = _G.last_dash_time or 0
    local last_shadow_step_time = _G.last_shadow_step_time or 0
    local last_dark_shroud_time = _G.last_dark_shroud_time or 0
    
    local caltrop_ready = (current_time - last_caltrop_time) >= caltrop_cooldown
    local smoke_grenade_ready = (current_time - last_smoke_grenade_time) >= smoke_grenade_cooldown
    local poison_trap_ready = (current_time - last_poison_trap_time) >= poison_trap_cooldown
    local shadow_imbuement_ready = (current_time - last_shadow_imbuement_time) >= shadow_imbuement_cooldown
    local shadow_clone_ready = (current_time - last_shadow_clone_time) >= shadow_clone_cooldown
    local dash_ready = (current_time - last_dash_time) >= dash_cooldown
    local shadow_step_ready = (current_time - last_shadow_step_time) >= shadow_step_cooldown
    local dark_shroud_ready = (current_time - last_dark_shroud_time) >= dark_shroud_cooldown
    
    -- In boss fights, prioritize area control spells first
    if is_boss_fight then
        local boss_area_spells = {"smoke_grenade", "poison_trap", "caltrop"}
        for _, spell_name in ipairs(boss_area_spells) do
            local spell = spells[spell_name]
            if not spell or not spell.logics then goto continue_boss_area_normal end
            if spell.menu_elements and not spell.menu_elements.main_boolean:get() then goto continue_boss_area_normal end
            
            -- Check cooldown for this specific spell
            local spell_cooldown = 0
            local last_cast_time = 0
            if spell_name == "caltrop" then 
                spell_cooldown = caltrop_cooldown
                last_cast_time = last_caltrop_time
            elseif spell_name == "smoke_grenade" then 
                spell_cooldown = smoke_grenade_cooldown
                last_cast_time = last_smoke_grenade_time
            elseif spell_name == "poison_trap" then 
                spell_cooldown = poison_trap_cooldown
                last_cast_time = last_poison_trap_time
            end
            
            local spell_ready = (current_time - last_cast_time) >= spell_cooldown
            if not spell_ready then goto continue_boss_area_normal end
            
            local result = spell.logics(target_list, target_selector_data_all, best_target)
            if result then
                cast_end_time = current_time + 0.3
                if spell_name == "caltrop" then
                    _G.last_caltrop_time = current_time
                elseif spell_name == "smoke_grenade" then
                    _G.last_smoke_grenade_time = current_time
                elseif spell_name == "poison_trap" then
                    _G.last_poison_trap_time = current_time
                end
                console.print("Boss fight: Cast " .. spell_name .. " successfully")
                return
            end
            ::continue_boss_area_normal::
        end
    end
    
    local profile_index_rotation = safe_get_menu_element(menu.menu_elements.profile, 0)
    if profile_index_rotation == 1 then
        local dark_shroud_spell = spells["dark_shroud"]
        if dark_shroud_spell and dark_shroud_spell.logics and (not dark_shroud_spell.menu_elements or dark_shroud_spell.menu_elements.main_boolean:get()) then
            if dark_shroud_spell.logics() then
                cast_end_time = current_time + 0.2
                return
            end
        end

        local concealment_spell = spells["concealment"]
        if concealment_spell and concealment_spell.logics and (not concealment_spell.menu_elements or concealment_spell.menu_elements.main_boolean:get()) then
            if concealment_spell.logics() then
                cast_end_time = current_time + 0.2
                return
            end
        end

        local death_trap_spell = spells["death_trap"]
        if death_trap_spell and death_trap_spell.logics and (not death_trap_spell.menu_elements or death_trap_spell.menu_elements.main_boolean:get()) then
            if death_trap_spell.logics(target_list, target_selector_data_all, best_target) then
                cast_end_time = current_time + 0.4
                _G.last_death_trap_time = current_time
                return
            end
        end

        if is_boss_fight then
            local shadow_step_spell = spells["shadow_step"]
            if false and shadow_step_spell and shadow_step_spell.logics and (not shadow_step_spell.menu_elements or shadow_step_spell.menu_elements.main_boolean:get()) then
                if not is_movement_disabled() then
                    if shadow_step_spell.logics(target_list, target_selector_data_all, best_target, closest_target) then
                        _G.last_shadow_step_time = current_time
                        cast_end_time = current_time + 0.2
                        return
                    end
                end
            end

            local heartseeker_spell = spells["heartseeker"]
            if heartseeker_spell and heartseeker_spell.logics then
                local hs_target = best_target or closest_target
                if hs_target and hs_target:is_enemy() then
                    if heartseeker_spell.logics(hs_target) then
                        _G.last_heartseeker_cast_time = current_time
                        cast_end_time = current_time + 0.2
                        return
                    end
                end
            end
        else
            local player_position_rot = safe_get_player_position()
            local enemy_count_all = 0
            do
                local all_units_count = 0
                all_units_count = select(1, my_utility.enemy_count_in_range(6.0, player_position_rot))
                enemy_count_all = all_units_count or 0
            end

            if enemy_count_all >= 3 then
                local poison_trap_spell = spells["poison_trap"]
                if poison_trap_spell and poison_trap_spell.logics and (not poison_trap_spell.menu_elements or poison_trap_spell.menu_elements.main_boolean:get()) then
                    if poison_trap_spell.logics(target_list, target_selector_data_all, best_target) then
                        _G.last_poison_trap_time = current_time
                        cast_end_time = current_time + 0.3
                        return
                    end
                end

                local flurry_spell = spells["flurry"]
                if flurry_spell and flurry_spell.logics and (not flurry_spell.menu_elements or flurry_spell.menu_elements.main_boolean:get()) then
                    local fl_target = best_target or closest_target
                    if fl_target and fl_target:is_enemy() then
                        if flurry_spell.logics(fl_target) then
                            cast_end_time = current_time + 0.3
                            return
                        end
                    end
                end
            end
        end
    end

    -- Meta Build Spell Rotation Implementation
    -- For the Death Trap profile, optionally skip heavy spells on a single normal enemy
    local skip_heavy_for_single_normal = false
    do
        local profile_index_single = safe_get_menu_element(menu.menu_elements.profile, 0)
        if profile_index_single == 1 and player_position then
            local all_units_count, normal_units_count, elite_units_count, champion_units_count, boss_units_count =
                my_utility.enemy_count_in_range(12.0, player_position)
            local high_value_present = (elite_units_count or 0) > 0 or (champion_units_count or 0) > 0 or (boss_units_count or 0) > 0
            if not high_value_present and (all_units_count or 0) <= 1 then
                skip_heavy_for_single_normal = true
            end
        end
    end

    -- TB Leveling Pit push: elite / big-pack burst sequence using the user's pit bar
    do
        local profile_index_pit = safe_get_menu_element(menu.menu_elements.profile, 0)
        local pit_push_enabled = (profile_index_pit == 5) and safe_get_menu_element(menu.menu_elements.pit_push, false)
        if pit_push_enabled and best_target and best_target.is_enemy and best_target:is_enemy() then
            local target_position = best_target:get_position()
            local ok_counts, all_units_count, normal_units_count, elite_units_count, champion_units_count, boss_units_count = pcall(function()
                return my_utility.enemy_count_in_range(8.0, target_position)
            end)
            if ok_counts then
                local high_value_present = (elite_units_count or 0) > 0 or (champion_units_count or 0) > 0 or (boss_units_count or 0) > 0
                local dense_pack = (all_units_count or 0) >= 3
                if high_value_present or dense_pack then
                    -- 1) Concealment opener for unstoppable / crit burst
                    do
                        local concealment_spell = spells["concealment"]
                        if concealment_spell and concealment_spell.logics and (not concealment_spell.menu_elements or concealment_spell.menu_elements.main_boolean:get()) then
                            if concealment_spell.logics() then
                                cast_end_time = current_time + 0.2
                                return
                            end
                        end
                    end

                    -- 2) Poison Imbuement before committing Death Trap / TB
                    do
                        local poison_imb_spell = spells["poison_imbuement"]
                        if poison_imb_spell and poison_imb_spell.logics and (not poison_imb_spell.menu_elements or poison_imb_spell.menu_elements.main_boolean:get()) then
                            if poison_imb_spell.logics() then
                                cast_end_time = current_time + 0.2
                                return
                            end
                        end
                    end

                    -- 3) Death Trap on the elite / best pack center
                    do
                        local death_trap_spell = spells["death_trap"]
                        if death_trap_spell and death_trap_spell.logics and (not death_trap_spell.menu_elements or death_trap_spell.menu_elements.main_boolean:get()) then
                            if death_trap_spell.logics(target_list, target_selector_data_all, best_target) then
                                _G.last_death_trap_time = current_time
                                cast_end_time = current_time + 0.4
                                return
                            end
                        end
                    end

                    -- 4) Poison Trap layered under the same pack for extra damage / control
                    do
                        local poison_trap_spell = spells["poison_trap"]
                        if poison_trap_spell and poison_trap_spell.logics and (not poison_trap_spell.menu_elements or poison_trap_spell.menu_elements.main_boolean:get()) then
                            if poison_trap_spell.logics(target_list, target_selector_data_all, best_target) then
                                _G.last_poison_trap_time = current_time
                                cast_end_time = current_time + 0.3
                                return
                            end
                        end
                    end
                end
            end
        end
    end

    local player_position = safe_get_player_position()
    local active_spell_priority = get_active_spell_priority(player_position)
    local profile_index_rotation_meta = safe_get_menu_element(menu.menu_elements.profile, 0)
    local is_dance_of_knives_profile = (profile_index_rotation_meta == 4)
    local is_dance_channeling = false
    do
        local dok_spell = spells["dance_of_knives"]
        if dok_spell and dok_spell.update_channel and cast_spell and type(cast_spell.is_channel_spell_active) == "function" then
            is_dance_channeling = cast_spell.is_channel_spell_active(1690398)
        end
    end
    local resource_percent = safe_get_resource_percent()
    local is_low_resource = resource_percent and resource_percent < 0.20 or false
    for _, spell_name in ipairs(active_spell_priority) do
        if spell_name == "penetrating_shot" or spell_name == "death_trap" then goto continue end -- Skip penetrating shot and death trap (handled separately)
        
        local spell = spells[spell_name]
        if not spell or not spell.logics then
            goto continue
        end
        
        -- Skip if spell isn't enabled or loaded
        if spell.menu_elements and not spell.menu_elements.main_boolean:get() then
            goto continue
        end

        if is_dance_channeling and is_dance_of_knives_profile then
            if spell_name ~= "concealment" and
               spell_name ~= "dash" and
               spell_name ~= "caltrop" and
               spell_name ~= "evade" then
                goto continue
            end
        end

        if skip_heavy_for_single_normal then
            if spell_name == "caltrop" or
               spell_name == "smoke_grenade" or
               spell_name == "poison_trap" or
               spell_name == "shadow_imbuement" or
               spell_name == "shadow_clone" or
               spell_name == "dash" or
               spell_name == "shadow_step" then
                goto continue
            end
        end
        
        -- Dance of Knives PIT: conditional casting and safety logic
        if is_dance_of_knives_profile then
            if is_low_resource then
                if spell_name == "poison_trap" then
                    goto continue
                end
            end

            -- Concealment: only commit in boss/elite situations, not on pure trash packs
            if spell_name == "concealment" and not is_boss_fight then
                if player_position then
                    local all_units_count_dok, normal_units_count_dok, elite_units_count_dok, champion_units_count_dok, boss_units_count_dok =
                        my_utility.enemy_count_in_range(12.0, player_position)
                    local has_high_value = (elite_units_count_dok or 0) > 0 or (champion_units_count_dok or 0) > 0 or (boss_units_count_dok or 0) > 0
                    if not has_high_value then
                        goto continue
                    end
                else
                    goto continue
                end
            end

            -- Ensure Poison Imbuement is applied right before Dance of Knives when possible
            if spell_name == "dance_of_knives" then
                local poison_imb_spell = spells["poison_imbuement"]
                local dok_target = best_target or closest_target
                if poison_imb_spell and poison_imb_spell.will_cast and dok_target then
                    local should_cast_poison = false
                    local ok, result = pcall(function()
                        return poison_imb_spell.will_cast(dok_target)
                    end)
                    if ok and result then
                        should_cast_poison = true
                    end

                    if should_cast_poison and poison_imb_spell.logics then
                        local cast_ok = poison_imb_spell.logics(dok_target)
                        if cast_ok then
                            cast_end_time = current_time + 0.2
                            goto continue
                        end
                    end
                end
            end

            -- Caltrops: only when kiting is actually needed or in high-density trash
            if spell_name == "caltrop" then
                local local_player_dok = safe_get_local_player()
                local low_health = false
                if local_player_dok and type(local_player_dok.get_health_percent) == "function" then
                    low_health = local_player_dok:get_health_percent() < 0.75
                end

                local in_danger = false
                if spells.evade and type(spells.evade.is_dangerous_position) == "function" and player_position then
                    in_danger = spells.evade.is_dangerous_position(player_position)
                end

                local need_kite = low_health or in_danger or is_trash_aoe_mode
                if not need_kite then
                    goto continue
                end
            end
        end

        -- Meta build timing: Shadow Clone every 5 seconds for damage doubling + Unstoppable
        if spell_name == "shadow_clone" then
            local last_shadow_clone_time = _G.last_shadow_clone_time or 0
            -- Default meta timing: every 5 seconds, but allow faster reuse in Pit trash AoE mode
            local shadow_clone_interval = 5.0
            if is_pit_flurry_profile and is_trash_aoe_mode then
                shadow_clone_interval = 3.0
            end

            if current_time - last_shadow_clone_time < shadow_clone_interval then
                if is_boss_fight then
                    console.print("Shadow Clone: Meta build timing (" .. shadow_clone_interval .. "s) - " .. (shadow_clone_interval - (current_time - last_shadow_clone_time)) .. "s remaining")
                end
                goto continue
            end
        end
        
        -- Meta build cooldown checks with improved messaging
        if spell_name == "caltrop" and not caltrop_ready then
            if is_boss_fight then console.print("Caltrops: Meta build damage multiplier on cooldown - " .. (caltrop_cooldown - (current_time - last_caltrop_time)) .. "s remaining") end
            goto continue
        elseif spell_name == "smoke_grenade" and not smoke_grenade_ready then
            if is_boss_fight then console.print("Smoke Grenade: Meta build elite/boss damage on cooldown - " .. (smoke_grenade_cooldown - (current_time - last_smoke_grenade_time)) .. "s remaining") end
            goto continue
        elseif spell_name == "poison_trap" and not poison_trap_ready then
            if is_boss_fight then console.print("Poison Trap: Meta build Pit Push variant on cooldown - " .. (poison_trap_cooldown - (current_time - last_poison_trap_time)) .. "s remaining") end
            goto continue
        elseif spell_name == "shadow_imbuement" and not shadow_imbuement_ready then
            if is_boss_fight then console.print("Shadow Imbuement: Meta build damage multiplier on cooldown - " .. (shadow_imbuement_cooldown - (current_time - last_shadow_imbuement_time)) .. "s remaining") end
            goto continue
        elseif spell_name == "dash" and not dash_ready then
            if is_boss_fight then console.print("Dash: Meta build mobility on cooldown - " .. (dash_cooldown - (current_time - last_dash_time)) .. "s remaining") end
            goto continue
        elseif spell_name == "shadow_step" and not shadow_step_ready then
            if is_boss_fight then console.print("Shadow Step: Meta build mobility on cooldown - " .. (shadow_step_cooldown - (current_time - last_shadow_step_time)) .. "s remaining") end
            goto continue
        end
        
        -- Different spell types have different parameter requirements
        local result = false
        
        -- Meta build spell casting logic
        if spell_name == "shadow_clone" then
            result = spell.logics()
            if result then
                _G.last_shadow_clone_time = current_time
                cast_end_time = current_time + 0.4
                if is_boss_fight then console.print("Shadow Clone: Meta build damage doubling + Unstoppable active") end
                return
            end
        elseif spell_name == "shadow_imbuement" or 
               spell_name == "poison_imbuement" or 
               spell_name == "cold_imbuement" then
            -- Meta build: Maintain imbuements for damage multipliers
            result = spell.logics()
            if result then
                cast_end_time = current_time + 0.3
                if spell_name == "shadow_imbuement" then
                    _G.last_shadow_imbuement_time = current_time
                    if is_boss_fight then console.print("Shadow Imbuement: Meta build Pit Push variant active") end
                end
                return
            end
        elseif spell_name == "caltrop" or
               spell_name == "smoke_grenade" or
               spell_name == "poison_trap" then
            -- Meta build: Area control spells for damage multipliers on elites/bosses
            result = spell.logics(target_list, target_selector_data_all, best_target)
            if result then
                cast_end_time = current_time + 0.3
                if spell_name == "caltrop" then
                    _G.last_caltrop_time = current_time
                    if is_boss_fight then console.print("Caltrops: Meta build damage multiplier deployed") end
                elseif spell_name == "smoke_grenade" then
                    _G.last_smoke_grenade_time = current_time
                    if is_boss_fight then console.print("Smoke Grenade: Meta build elite/boss damage deployed") end
                elseif spell_name == "poison_trap" then
                    _G.last_poison_trap_time = current_time
                    if is_boss_fight then console.print("Poison Trap: Meta build Pit Push variant deployed") end
                end
                return
            end
        elseif spell_name == "dash" or spell_name == "shadow_step" then
            -- Meta build: Mobility spells for positioning and Momentum
            local move_target = best_target or closest_target
            if not move_target or not move_target.is_enemy or not move_target:is_enemy() then
                goto continue
            end

            local player_position_mt = safe_get_player_position()
            local target_position_mt = move_target:get_position()
            if not player_position_mt or not target_position_mt then
                goto continue
            end

            if spell_name == "dash" then
                -- Dash: use as a gap closer when target is not too close and not too far
                local dash_min_gap = 4.0
                local dash_max_gap = 12.0
                local dist_sqr_mt = player_position_mt:squared_dist_to_ignore_z(target_position_mt)
                if dist_sqr_mt < (dash_min_gap * dash_min_gap) or dist_sqr_mt > (dash_max_gap * dash_max_gap) then
                    goto continue
                end

                -- Dash is allowed even when Disable Auto Movement is enabled
                if is_dance_of_knives_profile and is_dance_channeling then
                    goto continue
                end
                result = spell.logics(move_target)
                if result then
                    _G.last_dash_time = current_time
                    local profile_index_dash = safe_get_menu_element(menu.menu_elements.profile, 0)
                    local dash_pause = 0.2
                    if profile_index_dash == 1 then
                        dash_pause = 0.45
                    end
                    cast_end_time = current_time + dash_pause
                    if is_boss_fight then console.print("Dash: Meta build mobility used") end
                    return
                end
            elseif spell_name == "shadow_step" then
                -- Shadow Step still respects the Disable Auto Movement toggle, except for the Death Trap
                -- and TB Leveling profiles (which rely on scripted Step for proper rotation). Let the
                -- spell's own menu-controlled range logic decide when it's in range instead of adding
                -- another hardcoded distance gate here.
                local profile_index_shadow = safe_get_menu_element(menu.menu_elements.profile, 0)
                if profile_index_shadow == 1 or profile_index_shadow == 5 or not is_movement_disabled() then
                    result = spell.logics(target_list, target_selector_data_all, move_target, closest_target)
                    if result then
                        _G.last_shadow_step_time = current_time
                        cast_end_time = current_time + 0.2
                        if is_boss_fight then console.print("Shadow Step: Meta build mobility used") end
                        return
                    end
                end
            end
        elseif spell_name == "heartseeker" then
            -- Heartseeker handling:
            --  * In the dedicated Heartseeker build, keep the special logic that
            --    prefers high-value / already-debuffed targets.
            --  * In the Heartseeker-standard-PIT profile, treat Heartseeker as a
            --    straightforward filler on the best target so it can spam more
            --    reliably on single-target when chosen.
            if is_pit_flurry_profile then
                -- Simple filler behavior for the pit Flurry build
                local hs_target = best_target or closest_target
                if hs_target and hs_target:is_enemy() then
                    if spell.logics(hs_target) then
                        _G.last_heartseeker_cast_time = current_time
                        cast_end_time = current_time + spell.menu_elements_heartseeker_base.spell_cast_delay:get()
                        return
                    end
                end
            elseif is_best_target_exception then
	            local sorted_entities = {}
	            for i, v in ipairs(target_list) do
	                sorted_entities[i] = v
	            end

	            table.sort(sorted_entities, function(a, b)
	                return my_target_selector.get_unit_weight(a) > my_target_selector.get_unit_weight(b)
	            end)

	            for _, unit in ipairs(sorted_entities) do
                    if spell.logics(unit) then
                        _G.last_heartseeker_cast_time = current_time
                        cast_end_time = current_time + spell.menu_elements_heartseeker_base.spell_cast_delay:get()
                        return
                    end
                end
            end
        else
            -- Standard target spells
            result = spell.logics(best_target)
            if result then
                cast_end_time = current_time + 0.3
            return
        end
        end
        
        ::continue::
    end

    -- Heartseeker filler: if we're on a Heartseeker-focused profile and nothing
    -- above has returned, try to cast Heartseeker as a basic filler.
    do
        local profile_index = safe_get_menu_element(menu.menu_elements.profile, 0)
        if profile_index == 1 or profile_index == 3 then -- Heartseeker profiles
            local heartseeker_spell = spells["heartseeker"]
            if heartseeker_spell and heartseeker_spell.logics then
                -- Prefer best_target, fall back to closest_target
                local hs_target = best_target or closest_target
                if hs_target and hs_target:is_enemy() then
                    -- Range detection: don't bother trying filler on very far targets
                    local player_position = safe_get_player_position()
                    local target_position = hs_target:get_position()
                    local max_range = 26
                    if heartseeker_spell.menu_elements_heartseeker_base
                       and heartseeker_spell.menu_elements_heartseeker_base.filler_range then
                        max_range = heartseeker_spell.menu_elements_heartseeker_base.filler_range:get()
                    end

                    if player_position:squared_dist_to_ignore_z(target_position) > (max_range * max_range) then
                        goto hs_filler_end
                    end

                    local ok = heartseeker_spell.logics(hs_target)
                    if ok then
                        local current_time = safe_get_time_since_inject()
                        local delay = 0.1
                        if heartseeker_spell.menu_elements_heartseeker_base
                           and heartseeker_spell.menu_elements_heartseeker_base.spell_cast_delay then
                            delay = heartseeker_spell.menu_elements_heartseeker_base.spell_cast_delay:get()
                        end
                        cast_end_time = current_time + delay
                        return
                    end
                end
            end
        end
    end
    ::hs_filler_end::

    -- Meta build: Cast Penetrating Shot with configurable speed (Penetrating Shot profile only)
    local profile_index_meta = safe_get_menu_element(menu.menu_elements.profile, 0)
    if profile_index_meta == 0 then
        local spell = spells["penetrating_shot"]
        if spell and spell.logics and utility.is_spell_ready(377137) and 
           (not spell.menu_elements or spell.menu_elements.main_boolean:get()) then
            -- Check if slow penetrating shot is enabled and apply cooldown
            local last_penetrating_shot_time = _G.last_penetrating_shot_time or 0
            local cast_delay = safe_get_menu_element(menu.menu_elements.slow_penetrating_shot, false) and 
                              safe_get_menu_element(menu.menu_elements.slow_penetrating_shot_delay, 0.01) or 0.001
            
            -- Check if enough time has passed since last cast
            if current_time - last_penetrating_shot_time >= cast_delay then
                local result = spell.logics(target_list, target_selector_data_all, best_target)
                if result then
                    cast_end_time = current_time + 0.1 -- Small delay for next frame
                    if is_boss_fight then console.print("Penetrating Shot: Meta build primary damage spam") end
                end
            end
        end
    end

    -- Auto-play movement logic with wall bounce optimization
    -- Completely disable auto movement when using the Dance of Knives PIT profile
    -- Also disable script-driven auto movement for TB Leveling profile (index 5)
    local profile_index_movement = safe_get_menu_element(menu.menu_elements.profile, 0)
    if (not is_dance_of_knives_profile)
       and profile_index_movement ~= 5
       and current_time >= can_move
       and my_utility.is_auto_play_enabled() then
        local is_dangerous = false
        -- Safely check if evade has is_dangerous_position function
        if spells.evade and type(spells.evade.is_dangerous_position) == "function" then
            is_dangerous = spells.evade.is_dangerous_position(player_position)
        end
        
        if not is_dangerous then
                            -- Check for wall bounce positioning opportunities
                local best_target = best_target or target_selector_data_all and target_selector_data_all.best_target
                if best_target and best_target:is_enemy() then
                    local target_pos = best_target:get_position()
                    
                    -- Check if we're near walls for bounce optimization
                    local is_near_wall = false
                    local closest_wall_distance = 999999
                    local closest_wall_direction = nil
                    
                    for i = 1, 4 do
                        local angle = (i - 1) * (math.pi / 2)
                        local test_direction = vec3.new(math.cos(angle), math.sin(angle), 0)
                        local test_position = player_position:add(test_direction:multiply(20.0))
                        
                        if prediction.is_wall_collision(player_position, test_position, 0.15) then
                            local wall_distance = player_position:dist_to(test_position)
                            if wall_distance < closest_wall_distance then
                                closest_wall_distance = wall_distance
                                closest_wall_direction = test_direction
                                is_near_wall = true
                            end
                        end
                    end
                    
                    -- If near walls, try to position behind enemy for optimal bounce
                    if is_near_wall and closest_wall_direction then
                        -- Position behind enemy, but also consider the closest wall direction
                        local enemy_to_player = player_position:subtract(target_pos):normalize()
                        local behind_enemy_pos = target_pos:add(enemy_to_player:multiply(6.0))
                        
                        -- Also try positioning that aligns with the closest wall
                        local wall_aligned_pos = target_pos:add(closest_wall_direction:multiply(4.0))
                        
                        -- Choose the better position (behind enemy or wall-aligned)
                        local optimal_pos = behind_enemy_pos
                        if player_position:dist_to(wall_aligned_pos) < player_position:dist_to(behind_enemy_pos) then
                            optimal_pos = wall_aligned_pos
                        end
                        
                        -- Check if we can move to this position
                        if not prediction.is_wall_collision(player_position, optimal_pos, 0.15) then
                            if safe_pathfinder_move_to_cpathfinder(optimal_pos) then
                                can_move = current_time + 2.0
                                if is_boss_fight then console.print("Movement: Positioning for closest wall bounce optimization (wall distance: " .. string.format("%.1f", closest_wall_distance) .. "m)") end
                                return
                            end
                        end
                    end
                end
            
            -- Standard movement logic (fallback)
            if not is_movement_disabled() then
                local closer_target = safe_target_selector_get_target_closer(player_position, 15.0)
                if closer_target then
                    local move_pos = closer_target:get_position():get_extended(player_position, 4.0)
                    if safe_pathfinder_move_to_cpathfinder(move_pos) then
                        can_move = current_time + 1.50
                    end
                end
            end
        end
    end

    -- Out of combat evade (with throttling to reduce spam)
    if spells.evade and spells.evade.menu_elements 
       and safe_get_menu_element(spells.evade.menu_elements.use_out_of_combat, false)
       and not is_movement_disabled() then
        local current_time = get_time_since_inject()
        local last_ooc_evade_check = _G.last_ooc_evade_check or 0
        local ooc_evade_check_interval = 1.0 -- Check out-of-combat evade every 1 second
        
        if current_time - last_ooc_evade_check >= ooc_evade_check_interval then
            _G.last_ooc_evade_check = current_time
            
            if spells.evade.out_of_combat() then
                return
            end
        end
    end
    
    -- Enhanced loot management during combat (throttled)
    if safe_get_menu_element(menu.menu_elements.main_boolean, false) then
        local now = safe_get_time_since_inject()
        if now - _G.last_auto_loot_check_time >= _G.auto_loot_check_interval then
            _G.last_auto_loot_check_time = now

            -- Attempt to loot potions if needed
            if safe_loot_manager_is_potion_necessary() then
                local nearby_items = safe_loot_manager_get_all_items_chest_sort_by_distance()
                for _, item in ipairs(nearby_items) do
                    if safe_loot_manager_is_potion(item) and safe_loot_manager_is_lootable_item(item, false, true) then
                        local item_pos = item:get_position()
                        if player_position:dist_to(item_pos) < 4.0 then
                            if safe_loot_manager_loot_item(item, false, true) then
                                safe_console_print("Looted potion during combat")
                                _G.last_health_potion_time = current_time
                                return
                            end
                        end
                    end
                end
            end
            
            -- Check for high-value items (gold, obols) in close proximity
            local nearby_items = safe_loot_manager_get_all_items_chest_sort_by_distance()
            for _, item in ipairs(nearby_items) do
                if (safe_loot_manager_is_gold(item) or safe_loot_manager_is_obols(item)) and 
                   not safe_evade_is_dangerous_position(player_position) then
                    local item_pos = item:get_position()
                    if player_position:dist_to(item_pos) < 2.0 then
                        if safe_loot_manager_loot_item(item, true, false) then
                            safe_console_print("Looted currency during combat")
                            return
                        end
                    end
                end
            end
        end
    end
end)

-- Enhanced rendering logic with performance optimization
safe_on_render(function()
    if not safe_get_menu_element(menu.menu_elements.main_boolean, false) or not safe_get_menu_element(menu.menu_elements.enable_debug, false) then
        return
    end

    -- Performance optimization: Throttle debug rendering to reduce stuttering
    local current_time = get_time_since_inject()
    local last_debug_render_time = _G.last_debug_render_time or 0
    local debug_render_interval = 0.1 -- Render debug info every 100ms instead of every frame
    
    if current_time - last_debug_render_time < debug_render_interval then
        return
    end
    _G.last_debug_render_time = current_time

    local local_player = safe_get_local_player()
    if not local_player then
        return
    end

    local player_position = local_player:get_position()
    local player_screen_position = safe_graphics_w2s(player_position)
    if player_screen_position:is_zero() then
        return
    end

    -- Draw player range circles (reduced segments for better performance)
    if safe_get_menu_element(menu.menu_elements.draw_max_range, false) then
        safe_graphics_circle_3d(player_position, safe_get_menu_element(menu.menu_elements.max_targeting_range, 30), color_white(85), 3.5, 72) -- Reduced from 144 to 72
    end
    
    if safe_get_menu_element(menu.menu_elements.draw_melee_range, false) then
        safe_graphics_circle_3d(player_position, 7.0, color_white(85), 2.5, 72) -- Reduced from 144 to 72
    end

    -- Draw cursor target radius
    if safe_get_menu_element(menu.menu_elements.draw_cursor_target, false) then
        local cursor_position = safe_get_cursor_position()
        safe_graphics_circle_3d(cursor_position, safe_get_menu_element(menu.menu_elements.cursor_targeting_radius, 5.0), color_yellow(85), 1.0, 36) -- Reduced from 72 to 36
    end

    -- Draw enemy circles and positions (limited to first 10 enemies for performance)
    if safe_get_menu_element(menu.menu_elements.draw_enemy_circles, false) then
        local enemies = safe_actors_manager_get_enemy_npcs()
        local enemy_count = 0
        for _, obj in ipairs(enemies) do
            if enemy_count >= 10 then break end -- Limit to 10 enemies for performance
            local position = obj:get_position()
            safe_graphics_circle_3d(position, 1, color_white(100), 1.0, 18) -- Reduced segments
            safe_graphics_circle_3d(safe_prediction_get_future_unit_position(obj, 0.4), 0.5, color_yellow(100), 1.0, 12) -- Reduced segments
            enemy_count = enemy_count + 1
        end
    end

    -- Draw targets (reduced segments for better performance)
    if safe_get_menu_element(menu.menu_elements.draw_targets, false) then
        -- Draw best ranged target
        if best_ranged_target then
            safe_graphics_circle_3d(best_ranged_target:get_position(), 1.5, color_green(150), 2.0, 24) -- Reduced from 36 to 24
        end
        
        -- Draw best melee target
        if best_melee_target then
            safe_graphics_circle_3d(best_melee_target:get_position(), 1.5, color_blue(150), 2.0, 24) -- Reduced from 36 to 24
        end
        
        -- Draw cursor targets
        if best_cursor_target then
            safe_graphics_circle_3d(best_cursor_target:get_position(), 1.5, color_purple(150), 2.0, 24) -- Reduced from 36 to 24
        end
        
        if closest_cursor_target then
            safe_graphics_circle_3d(closest_cursor_target:get_position(), 1.5, color_red(150), 2.0, 24) -- Reduced from 36 to 24
        end
    end

    -- Call enhanced rendering if debug is enabled (with throttling)
    enhancements_manager.on_render(menu.menu_elements)
end);

if console and type(console.print) == "function" then
    console.print("Rouge_Karnage | Version 1")
end