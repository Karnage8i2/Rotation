# Death Trap Rogue Script - Enhanced Edition

This document outlines the enhanced features added to the Death Trap Rogue script.

## Current Spell Rotation Integration

The enhanced features are fully integrated with the current spell rotation:

### Core Rotation with Enhancements:
1. **Caltrop** - Enhanced targeting for optimal area control placement
2. **Smoke Grenade** - Enhanced targeting for defensive positioning
3. **Poison Trap** - Enhanced targeting for optimal trap placement
4. **Shadow Imbuement** - Always maintained with conflict avoidance
5. **Shadow Clone** - Enhanced targeting for maximum enemy coverage
6. **Penetrating Shot** - Enhanced targeting for optimal linear positioning
7. **Dash** - Enhanced evade integration for mobility
8. **Shadow Step** - Enhanced positioning for advanced mobility
9. **Dark Shroud** - Enhanced utility management

### Special Integration:
- **Dance of Knives** - Enhanced targeting with dynamic positioning and danger detection

## Enhanced Features

### Enhanced Targeting System

The enhanced targeting system provides improved spell targeting with:

- **Advanced AoE Positioning**: Optimizes placement of AoE spells for maximum enemy coverage
- **Smart Target Selection**: Prioritizes targets based on type, health, and positioning
- **Visual Targeting Feedback**: Shows target selection with color-coded indicators
- **Boss Exception Logic**: Bypasses minimum enemy count when bosses are present
- **Linear Spell Optimization**: Special handling for Penetrating Shot and other linear spells

To enable, go to `Enhancements > Enhanced Targeting` in the menu.

### Enhanced Evade System

The enhanced evade system provides improved survivability through:

- **Shadow Step Integration**: Automatically uses Shadow Step to escape dangerous areas
- **Dash Integration**: Uses Dash as a fallback mobility option
- **Intelligent Positioning**: Calculates the safest position to evade to
- **Danger Zone Detection**: Identifies and avoids dangerous boss abilities

To enable, go to `Enhancements > Enhanced Evade` in the menu.

### Automatic Resource Management

The resource management system optimizes your resource usage:

- **Energy Optimization**: Adjusts spell usage based on current energy levels
- **Automatic Buff Maintenance**: Keeps important buffs active at all times
- **Automatic Health Management**: Uses potions and defensive abilities when health is low
- **Imbuement Conflict Resolution**: Prevents conflicts between different imbuements

To enable, go to `Enhancements > Auto Resource/Buff/Health Management` in the menu.

### Position Optimization

The position optimization system automatically adjusts your position during combat:

- **Enemy Avoidance**: Moves away from dangerous enemies and AoEs
- **Optimal AoE Positioning**: Positions you for maximum spell effectiveness
- **Safe Movement**: Ensures movement paths avoid obstacles and enemies
- **Dynamic Positioning**: Updates position during channeled spells like Dance of Knives

To enable, go to `Enhancements > Position Optimization` in the menu.

### Enhanced Debug Visualization

The enhanced debug system provides improved visual feedback:

- **Spell Area Visualization**: Shows spell ranges and effect areas
- **Enemy Information**: Displays detailed information about nearby enemies
- **Resource Tracking**: Shows health and energy bars with status indicators
- **Cooldown Tracking**: Visually displays cooldown status of key abilities
- **Targeting Feedback**: Shows which targets are selected and why

To enable, go to `Enhancements > Enhanced Debug` in the menu.

## Setup Instructions

1. Make sure all required utility files are in place:
   - `my_utility/enhanced_targeting.lua`
   - `my_utility/enhanced_evade.lua`
   - `my_utility/resource_manager.lua`
   - `my_utility/position_optimizer.lua`
   - `my_utility/enhanced_debug.lua`
   - `my_utility/enhancements_manager.lua`
   - `my_utility/buff_tracker.lua`
   - `my_utility/dynamic_priority.lua`

2. Enable the desired enhancements in the menu under the "Enhancements" section

3. Configure spell-specific settings in the "Equipped Spells" menu

## Configuration Options

Each enhancement system has its own configuration options:

### Enhanced Targeting Options
- **AoE Optimization**: Enables optimal AoE spell positioning
- **Smart Target Selection**: Uses improved target selection algorithm
- **Boss Exception**: Bypasses minimum enemy count for bosses
- **Linear Optimization**: Optimizes linear spells like Penetrating Shot

### Enhanced Evade Options
- **Shadow Step Integration**: Uses Shadow Step for advanced evasion
- **Dash Integration**: Uses Dash as fallback mobility
- **Danger Detection**: Identifies dangerous boss abilities
- **Safe Position Calculation**: Finds safest position to evade to

### Health Management Options
- **Auto Potion Threshold**: Health % threshold for auto potion use
- **Defensive Skills Threshold**: Health % threshold for defensive skills
- **Imbuement Conflict Resolution**: Prevents imbuement conflicts

### Debug Options
- **Draw Spell Areas**: Show spell ranges and effect areas
- **Draw Enemy Info**: Show detailed enemy information
- **Draw Resource Bars**: Show player resource bars
- **Draw Targeting Info**: Show targeting decisions and reasoning

## Spell-Specific Enhancements

### Caltrop
- Enhanced targeting for optimal area control placement
- Boss exception for minimum enemy count
- Visual feedback for placement decisions

### Smoke Grenade
- Enhanced targeting for defensive positioning
- Boss exception for minimum enemy count
- Optimal defensive area placement

### Poison Trap
- Enhanced targeting for optimal trap placement
- Boss exception for minimum enemy count
- Maximum damage over time positioning

### Shadow Clone
- Enhanced targeting for maximum enemy coverage
- Multiple fallback casting methods
- Comprehensive error handling
- Visual feedback for positioning decisions

### Penetrating Shot
- Enhanced targeting for optimal linear positioning
- Boss exception for minimum enemy count
- Aggressive spamming after main rotation
- Linear optimization for maximum penetration

### Dance of Knives
- Enhanced targeting with dynamic positioning
- Pause functionality in dangerous areas
- Shadow Imbuement dependency checking
- 12-second timer logic following Shadow Clone

## Troubleshooting

If you encounter issues with the enhancements:

1. Try disabling individual enhancements to isolate the problem
2. Check the console for error messages
3. Make sure all utility files are properly installed
4. Verify that you have the required spells equipped
5. Check minimum enemy count settings
6. Verify boss exception logic is working

## Performance Considerations

- Enhanced targeting can impact performance on slower systems
- Consider reducing targeting refresh rate for better performance
- Disable unused enhancement features
- Use debug visualization sparingly during high-performance scenarios

## Credits

Enhanced Death Trap Rogue Script - Smoke Edition
Based on the original Death Trap Rogue script with additional enhancements.
Updated for current spell rotation and logic (2025-01-27). 