local my_utility = require("my_utility/my_utility")
local enhanced_targeting = require("my_utility/enhanced_targeting")
local enhanced_evade = require("my_utility/enhanced_evade")
local resource_manager = require("my_utility/resource_manager")
local position_optimizer = require("my_utility/position_optimizer")
local enhanced_debug = require("my_utility/enhanced_debug")

local enhancements_manager = {}

-- Track spell ranges for visualization
local spell_ranges = {
    death_trap = { range = 0, radius = 0 },
    poison_trap = { range = 0, radius = 0 },
    smoke_grenade = { range = 0, radius = 0 },
    rain_of_arrows = { range = 0, radius = 0 }
}

-- Update spell range info for visualization
function enhancements_manager.update_spell_range(spell_name, range, radius, last_cast_position)
    if spell_ranges[spell_name] then
        spell_ranges[spell_name].range = range
        spell_ranges[spell_name].radius = radius
        if last_cast_position then
            spell_ranges[spell_name].last_cast_position = last_cast_position
        end
    end
end

-- Handle menu rendering for enhancements
function enhancements_manager.render_enhancements_menu(menu_elements)
    if menu_elements.enhancements_tree:push("Enhancements") then
        menu_elements.enhanced_targeting:render("Enhanced Targeting", "Enable enhanced targeting system")
        
        if menu_elements.enhanced_targeting:get() and menu_elements.enhanced_targeting_tree:push("Targeting Options") then
            menu_elements.aoe_optimization:render("AoE Optimization", "Optimize AoE spell positioning")
            menu_elements.optimal_target_selection:render("Smart Target Selection", "Use improved target selection algorithm")
            menu_elements.enhanced_targeting_tree:pop()
        end
        
        menu_elements.enhanced_evade:render("Enhanced Evade", "Enable enhanced evade system with dash and shadow step integration")
        menu_elements.auto_resource_management:render("Auto Resource Management", "Automatically manage resources for optimal spell usage")
        menu_elements.auto_buff_management:render("Auto Buff Management", "Automatically maintain important buffs")
        
        menu_elements.position_optimization:render("Position Optimization", "Automatically optimize positioning during combat")
        menu_elements.disable_auto_movement:render("Disable Auto Movement", "Prevent the script from issuing any automatic movement commands (pathfinder/orbwalker moves)")
        menu_elements.enhanced_debug_viz:render("Enhanced Debug", "Enable enhanced visual debugging")
        
        if menu_elements.enhanced_debug_viz:get() and menu_elements.enhanced_debug_tree:push("Debug Options") then
            menu_elements.draw_spell_areas:render("Draw Spell Areas", "Show spell ranges and effect areas")
            menu_elements.draw_enemy_info:render("Draw Enemy Info", "Show detailed enemy information")
            menu_elements.draw_resource_bars:render("Draw Resource Bars", "Show player resource bars")
            menu_elements.enhanced_debug_tree:pop()
        end
        
        menu_elements.enhancements_tree:pop()
    end
end

-- Initialize the enhancement system
function enhancements_manager.initialize(menu_elements)
    if menu_elements.enhanced_evade:get() then
        enhanced_evade.setup_evade(menu_elements.evade_cooldown:get())
    end
    
    -- Initialize any other needed components
    return true
end

-- Handle rendering
function enhancements_manager.on_render(menu_elements)
    local debug_enabled = menu_elements.enable_debug:get() and menu_elements.enhanced_debug_viz:get()
    
    -- Enhanced debug visualization
    if debug_enabled then
        if menu_elements.draw_resource_bars:get() then
            enhanced_debug.enhanced_debug_visualization(true)
        end
        
        if menu_elements.draw_spell_areas:get() then
            enhanced_debug.draw_spell_areas(spell_ranges, true)
        end
        
        if menu_elements.draw_enemy_info:get() then
            enhanced_debug.draw_enemy_info(true)
        end
    end
end

-- Apply enhanced targeting to spells
function enhancements_manager.apply_enhanced_targeting(spell_id, spell_radius, min_hits, debug_enabled)
    if not debug_enabled then return false, 0 end
    
    local success, hits = enhanced_targeting.optimize_aoe_positioning(spell_id, spell_radius, min_hits)
    return success, hits
end

-- Manage buffs based on settings
function enhancements_manager.manage_buffs(menu_elements)
    if not menu_elements.auto_buff_management:get() then return false, nil end
    
    return resource_manager.manage_buffs()
end

-- Process enhanced evade
function enhancements_manager.process_evade(menu_elements)
    if not menu_elements.enhanced_evade:get() then return false end
    
    return enhanced_evade.enhanced_evade_logics()
end

-- Optimize position if enabled
function enhancements_manager.optimize_position(menu_elements)
    if not menu_elements.position_optimization:get() then 
        return { should_move = false }
    end
    
    return position_optimizer.optimize_position()
end

return enhancements_manager 