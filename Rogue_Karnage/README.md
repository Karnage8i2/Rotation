# Rogue-DeathTrap Smoke Enhanced

## Current Spell Rotation (Updated 2025-01-27)

The script now uses a sophisticated spell priority system with the following order:

### Core Rotation Priority:
1. **Caltrop** - Area denial and crowd control
2. **Smoke Grenade** - Defensive positioning and enemy disruption
3. **Poison Trap** - Damage over time and area control
4. **Shadow Imbuement** - Always maintain buff (highest priority)
5. **Shadow Clone** - Frequent usage based on cooldown and energy
6. **Penetrating Shot** - Primary damage spell (spammed aggressively)
7. **Dash** - Mobility and positioning
8. **Shadow Step** - Advanced mobility and positioning
9. **Dark Shroud** - Additional utility and defense

### Special Spell Logic:
- **Shadow Imbuement**: Always maintained, conflicts with other imbuements are avoided
- **Shadow Clone**: Uses enhanced targeting for optimal positioning, cast when available
- **Dance of Knives**: Cast every 12 seconds after Shadow Clone, requires Shadow Imbuement to be active
- **Penetrating Shot**: Aggressively spammed after main rotation completes

## Major Enhancements

1. **Advanced Targeting System:**
   - Improved target selection with weighted scoring based on enemy types
   - Target caching to reduce performance impact
   - Multiple targeting modes (ranged, melee, cursor-based)
   - Better enemy prioritization for AoE abilities
   - Enhanced targeting for all AoE spells (Death Trap, Poison Trap, Rain of Arrows, etc.)

2. **Enhanced Menu System:**
   - Comprehensive settings panel for fine-tuning all aspects
   - Debug visualization options for targeting and range indicators
   - Organized spell categories (equipped vs. inactive)
   - Custom enemy weighting options

3. **Optimized Spell Prioritization:**
   - Structured spell priority system based on effectiveness
   - Smarter casting logic for situational spells
   - Better buff and debuff tracking
   - Improved resource management

4. **Performance Improvements:**
   - Cached targeting to reduce CPU usage
   - Configurable targeting refresh rate
   - Optimized spell evaluation logic
   - Early returns when minimum enemy count isn't met

5. **Momentum Management:**
   - Smart stacking of Momentum buff for maximum damage output
   - Automatic Dash and Shadow Step usage for Momentum generation
   - Priority-based spell casting that respects Momentum mechanics

6. **Enhanced Visualization:**
   - Debug mode with visual indicators for targeting
   - Range indicators for abilities
   - Target highlighting based on priority

7. **Customizable Enemy Scoring:**
   - Configurable weights for different enemy types
   - Special handling for elites, champions, and bosses
   - Bonus scoring for vulnerable enemies

## Recent Changes

### Latest Updates (Last Updated: 2025-01-27)

1. **Updated Spell Rotation:**
   - Caltrop now leads the rotation for area control
   - Smoke Grenade positioned early for defensive setup
   - Poison Trap follows for damage over time
   - Shadow Imbuement maintains highest priority for buff uptime
   - Shadow Clone uses enhanced targeting for optimal positioning
   - Penetrating Shot aggressively spammed after main rotation

2. **Enhanced Shadow Clone Logic:**
   - Removed fixed 10-second timer restriction
   - Now uses normal spell cooldown and energy availability
   - Enhanced positioning logic for maximum effect
   - Comprehensive error handling and debugging
   - Multiple fallback casting methods for reliability

3. **Improved Dance of Knives:**
   - Added dependency on Shadow Imbuement being active
   - 12-second timer logic following Shadow Clone
   - Enhanced targeting support for optimal positioning
   - Dynamic positioning during channeling
   - Pause functionality in dangerous areas

4. **Boss Enemy Exception:**
   - Added logic to bypass minimum enemy count threshold when a boss is present
   - Ensures optimal spell usage during boss fights even with strict minimum enemy count settings
   - Implemented consistently across all spell files

5. **Fixed Minimum Enemy Count Threshold:**
   - Resolved the issue where spells would ignore the minimum enemy count setting when elite/champion enemies were present
   - Implemented consistent enemy count checking across all spells
   - Added debugging output for easier verification of enemy counting
   - Maintained keybind override functionality for manual casting

6. **Enhanced Error Handling:**
   - Improved error checking for all spell registrations
   - Added robust error handling with pcall to prevent crashes
   - Enhanced error reporting for easier troubleshooting
   - Better parameter validation for all spell functions

7. **Targeting System Refinements:**
   - Fixed edge cases in target evaluation logic
   - Improved filtering of invalid targets
   - Better handling of targeting when minimum enemy count isn't met
   - More consistent application of enemy count threshold across all spells

8. **Performance Optimization:**
   - Reduced unnecessary spell evaluations
   - Implemented early returns when minimum enemy count isn't met
   - More efficient enemy counting with cached results
   - Better resource management during spell evaluation

### Previous Updates (2025-05-30)

1. **Advanced Enemy Targeting:**
   - Added weighted targeting system with enemy cluster detection
   - Improved targeting for multi-enemy situations
   - Better prioritization of dangerous enemies

2. **Enhanced Spell Management:**
   - Improved channeled spell handling for Dance of Knives
   - Dynamic position updating during channel
   - Automatic pause when in dangerous areas

3. **Auto-Play Intelligence:**
   - Added awareness of auto-play objectives
   - Script adapts behavior based on current objective (combat, looting, travel)
   - Improved mobility during travel objectives

4. **Loot Management:**
   - Automatic pickup of potions during combat when needed
   - Collection of high-value items (gold, obols) in close proximity
   - Integration with health potion tracking

5. **Terrain Navigation:**
   - Added walkability checks before casting positional abilities
   - Automatic detection of inaccessible areas
   - Finding alternative cast positions when primary target is unwalkable

6. **Boss Ability Recognition:**
   - Added detection for common dangerous boss abilities
   - Registered specific evade patterns for Butcher and Ashava abilities
   - Improved avoidance of circular and rectangular danger zones

7. **Error Resilience:**
   - Added robust error handling for spell registration
   - Graceful handling of API changes
   - Detailed error reporting for easier troubleshooting

## Usage Guide

1. **Basic Setup:**
   - Enable the plugin and select your preferred mode (Melee or Ranged)
   - Adjust the Dash Cooldown setting based on your preferences

2. **Advanced Configuration:**
   - Fine-tune targeting settings in the Settings panel
   - Customize enemy weights for your preferred playstyle
   - Enable debug visualization options to better understand targeting

3. **Spell Customization:**
   - All spells can be individually configured in the Equipped Spells menu
   - Disable or adjust specific abilities as needed
   - Inactive spells are accessible in a separate menu for quick enabling

4. **Playstyle Adaptation:**
   - The script will automatically adapt to your equipped spells
   - Customize the script behavior based on your preferred build

## Compared to Previous Version

This enhanced version maintains all the functionality of the original Death_Trap - Smoke script while adding:
   - More robust targeting with better performance
   - Enhanced spell prioritization with current rotation logic
   - Comprehensive customization options
   - Better visualization and debugging tools
   - Improved overall consistency and effectiveness
   - Advanced error handling and recovery mechanisms

