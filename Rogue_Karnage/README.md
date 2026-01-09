# Rogue Season 11 Builds

## Current Build Profiles (Updated 2026-01-09)

The script now includes 6 optimized Season 11 Rogue builds with intelligent AOE/Boss rotation modes.

### Available Profiles:

1. **Death Trap** - AOE burst trap build
2. **Dance of Knives** - Channeling AOE build
3. **Heartseeker** - Ranged precision build
4. **Flurry** - Melee rapid attack build
5. **Rain of Arrows** - Ranged AOE volley build
6. **Poison Twisting Blades** - Melee poison build

### Rotation Modes:

Each profile includes three rotation modes:
- **Auto**: Automatically adapts based on enemy density (default)
  - Uses Boss Priority for elites/champions/bosses or small packs
  - Uses AOE Priority for large trash packs (5+ enemies)
- **AOE Priority**: Optimized for trash pack clearing
- **Boss Priority**: Optimized for single target, elites, and bosses

### Profile Details:

#### 1. Death Trap Build
**AOE Rotation:**
- Quick stealth setup with Concealment
- Shadow Imbuement to amplify traps
- Death Trap as primary nuke
- Layered Poison Trap for sustained AOE
- Caltrop for vulnerable/control

**Boss Rotation:**
- Dark Shroud for defensive layer
- Concealment for burst window
- Shadow Imbuement to amplify damage
- Death Trap on priority targets
- Poison Trap for sustained damage

#### 2. Dance of Knives Build
**AOE Rotation:**
- Poison Imbuement to amplify Dance
- Dance of Knives channel on packs
- Poison Trap for area damage
- Caltrop for control

**Boss Rotation:**
- Concealment for defensive setup
- Poison Imbuement synergy
- Longer Dance of Knives channels
- Poison Trap for sustained damage

#### 3. Heartseeker Build
**AOE Rotation:**
- Caltrop for vulnerable setup
- Poison Trap for area damage
- Shadow Imbuement for damage boost
- Barrage as AOE core
- Heartseeker filler

**Boss Rotation:**
- Dark Shroud for defense
- Smoke Grenade for damage amp
- Shadow Imbuement for boost
- Shadow Clone for burst
- Heartseeker spam
- Flurry for close range

#### 4. Flurry Build
**AOE Rotation:**
- Shadow Imbuement for multiplier
- Poison Trap for area damage
- Flurry spam as primary

**Boss Rotation:**
- Dark Shroud for defense
- Smoke Grenade for boss damage
- Shadow Imbuement multiplier
- Shadow Clone for burst
- Caltrop for vulnerable
- Flurry spam

#### 5. Rain of Arrows Build
**AOE Rotation:**
- Caltrop for vulnerable
- Shadow Imbuement boost
- Rain of Arrows primary AOE
- Barrage secondary AOE

**Boss Rotation:**
- Dark Shroud defense
- Smoke Grenade amp
- Poison Trap control
- Shadow Imbuement boost
- Shadow Clone burst
- Rain of Arrows primary
- Barrage secondary
- Heartseeker filler

#### 6. Poison Twisting Blades Build
**AOE Rotation:**
- Poison Imbuement synergy
- Death Trap burst setup
- Poison Trap layered damage
- Twisting Blades spam

**Boss Rotation:**
- Concealment stealth opener
- Poison Imbuement synergy
- Shadow Imbuement support
- Death Trap burst
- Poison Trap sustained damage
- Twisting Blades primary
- Blade Shift basic attack

## Major Enhancements

1. **Advanced Targeting System:**
   - Improved target selection with weighted scoring based on enemy types
   - Target caching to reduce performance impact
   - Multiple targeting modes (ranged, melee, cursor-based)
   - Better enemy prioritization for AoE abilities
   - Enhanced targeting for all AoE spells

2. **Intelligent Rotation System:**
   - Auto-detection of AOE vs Boss scenarios
   - Separate optimized rotations for each mode
   - Manual override options available
   - Adaptive cooldown management

3. **Enhanced Menu System:**
   - Comprehensive settings panel for fine-tuning
   - Debug visualization options
   - Organized spell categories (equipped vs. inactive)
   - Custom enemy weighting options

4. **Performance Improvements:**
   - Cached targeting to reduce CPU usage
   - Configurable targeting refresh rate
   - Optimized spell evaluation logic
   - Early returns for efficiency

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

