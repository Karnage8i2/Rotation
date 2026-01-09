local my_utility = require("my_utility/my_utility")
-- Add enhanced targeting and enhancements manager
local enhanced_targeting = require("my_utility/enhanced_targeting")
local enhancements_manager = require("my_utility/enhancements_manager")
local menu_module = require("menu")

local menu_elements_shadow_clone_base =
{
    tree_tab            = tree_node:new(1),
    main_boolean        = checkbox:new(true, get_hash(my_utility.plugin_label .. "shadow_clone_main_bool_base")),
    spell_range   = slider_float:new(1.0, 15.0, 2.60, get_hash(my_utility.plugin_label .. "shadow_clone_spell_range")),
    spell_radius  = slider_float:new(1.0, 8.0, 4.0, get_hash(my_utility.plugin_label .. "shadow_clone_spell_radius")),
}

local function menu()
    
    if menu_elements_shadow_clone_base.tree_tab:push("Shadow Clone")then
        menu_elements_shadow_clone_base.main_boolean:render("Enable Spell", "")
        menu_elements_shadow_clone_base.spell_range:render("Spell Range", "", 1)
        menu_elements_shadow_clone_base.spell_radius:render("Clone Effect Radius", "Estimated area of effect for the clone", 1)
 
        menu_elements_shadow_clone_base.tree_tab:pop()
    end
end

local spell_id_shadow_clone = 357628;
local next_time_allowed_cast = 0.0;
local last_cast_position = nil;

local function logics()
    
    local menu_boolean = menu_elements_shadow_clone_base.main_boolean:get();
    local current_time = get_time_since_inject();
    
    local is_logic_allowed = my_utility.is_spell_allowed(
                menu_boolean, 
                next_time_allowed_cast, 
                spell_id_shadow_clone);

    if not is_logic_allowed then
        return false;
    end;

    -- Check if spell is ready
    if not utility.is_spell_ready(spell_id_shadow_clone) then
        return false
    end

    -- Check if spell is affordable
    if not utility.is_spell_affordable(spell_id_shadow_clone) then
        return false
    end

    -- Get spell parameters
    local spell_range = menu_elements_shadow_clone_base.spell_range:get()
    local spell_radius = menu_elements_shadow_clone_base.spell_radius:get()
    
    -- Update spell range info for visualization
    enhancements_manager.update_spell_range("shadow_clone", spell_range, spell_radius, last_cast_position)

    local player_position = get_player_position()
    if not player_position then
        return false
    end
    
    -- Find the best target position for maximum effect
    local best_position = player_position
    local enemies = actors_manager.get_enemy_npcs()
    local max_enemies = 0
    
    -- Look for position with most enemies in range
    for _, enemy in ipairs(enemies) do
        local enemy_pos = enemy:get_position()
        local distance_sqr = player_position:squared_dist_to_ignore_z(enemy_pos)
        
        if distance_sqr <= (spell_range * spell_range) then
            local enemies_in_range = 0
            for _, other_enemy in ipairs(enemies) do
                local other_pos = other_enemy:get_position()
                if enemy_pos:squared_dist_to_ignore_z(other_pos) <= (spell_radius * spell_radius) then
                    enemies_in_range = enemies_in_range + 1
                end
            end
            
            if enemies_in_range > max_enemies then
                max_enemies = enemies_in_range
                best_position = enemy_pos
            end
        end
    end

    -- Check if enhanced targeting is enabled and try to use it
    if menu_module and menu_module.menu_elements and 
       menu_module.menu_elements.enhanced_targeting and 
       menu_module.menu_elements.enhanced_targeting:get() and 
       menu_module.menu_elements.aoe_optimization and
       menu_module.menu_elements.aoe_optimization:get() then
        
        local enemies = {}
        pcall(function()
            enemies = utility.get_units_inside_circle_list(player_position, spell_range) or {}
        end)
        
        -- If we have enemies, try enhanced targeting
        if #enemies > 0 then
            local success, hit_count = false, 0
            pcall(function()
                success, hit_count = enhanced_targeting.optimize_aoe_positioning(
                    spell_id_shadow_clone, 
                    spell_radius, 
                    1
                )
            end)
            
            if success then
                next_time_allowed_cast = current_time + 5.0
                last_cast_position = best_position
                console.print(string.format("Rouge Plugin: Casted Shadow Clone using enhanced targeting, affecting ~%d enemies", hit_count))
                return true
            end
        end
    end

    -- Fallback: Cast at best position found
    local cast_success = false
    
    -- Try multiple casting methods for reliability
    pcall(function()
        cast_success = cast_spell.position(spell_id_shadow_clone, best_position, 0.6)
    end)
    
    if not cast_success then
        -- Try casting at player position as ultimate fallback
        pcall(function()
            cast_success = cast_spell.position(spell_id_shadow_clone, player_position, 0.6)
        end)
    end
    
    if cast_success then
        next_time_allowed_cast = current_time + 5.0;
        last_cast_position = best_position;
        console.print("Rouge Plugin: Casted Shadow Clone");
        return true;
    end;
            
    return false;
end


return 
{
    menu = menu,
    logics = logics
}