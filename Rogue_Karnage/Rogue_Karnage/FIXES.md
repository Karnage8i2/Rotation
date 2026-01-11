# Rogue Death Trap Script - Fixes Log

## Latest Fixes (2025-01-27)

### Updated Spell Rotation and Logic

**Major Update:** Completely revised spell rotation to optimize for current meta and performance.

**New Rotation Order:**
1. Caltrop (area control)
2. Smoke Grenade (defensive setup)
3. Poison Trap (damage over time)
4. Shadow Imbuement (always maintain)
5. Shadow Clone (frequent usage)
6. Penetrating Shot (primary damage, spammed aggressively)
7. Dash (mobility)
8. Shadow Step (advanced mobility)
9. Dark Shroud (utility)

**Files Modified:**
- `spell_priority.lua` - Updated spell priority order
- `main.lua` - Updated rotation logic and spell handling
- All spell files updated to reflect new rotation priorities

**Technical Details:**
- Caltrop now leads rotation for immediate area control
- Smoke Grenade positioned early for defensive setup
- Poison Trap follows for damage over time
- Shadow Imbuement maintains highest priority for buff uptime
- Penetrating Shot aggressively spammed after main rotation
- Enhanced targeting integrated throughout rotation

### Enhanced Shadow Clone Logic

**Issue:** Shadow Clone was using fixed 10-second timer instead of normal cooldown logic.

**Files Fixed:**
- `spells/shadow_clone.lua` - Removed fixed timer, uses normal cooldown and energy
- `main.lua` - Updated Shadow Clone handling in rotation

**Technical Details:**
- Removed 10-second timer restriction
- Now uses normal spell cooldown and energy availability
- Enhanced positioning logic for maximum effect
- Multiple fallback casting methods for reliability
- Comprehensive error handling and debugging

### Improved Dance of Knives Logic

**Issue:** Dance of Knives needed better integration with current rotation and Shadow Imbuement dependency.

**Files Fixed:**
- `spells/dance_of_knives.lua` - Added Shadow Imbuement dependency and 12-second timer
- `main.lua` - Updated Dance of Knives handling

**Technical Details:**
- Added dependency on Shadow Imbuement being active
- 12-second timer logic following Shadow Clone
- Enhanced targeting support for optimal positioning
- Dynamic positioning during channeling
- Pause functionality in dangerous areas

### Boss Exception for Minimum Enemy Count

**New Feature:** Added logic to bypass the minimum enemy count threshold when a boss enemy is present, ensuring optimal spell usage in boss fights.

**Files Modified:**
- `main.lua` - Added boss check in the `evaluate_targets` function
- `death_trap.lua` - Added boss exception to enemy count check
- `poison_trap.lua` - Implemented boss detection logic
- `dance_of_knives.lua` - Added boss bypass for minimum enemy threshold
- `rain_of_arrows.lua` - Added boss exception logic
- `caltrop.lua` - Implemented boss detection for enemy count override
- `penetrating_shot.lua` - Added boss exception to minimum enemy check

**Technical Details:**
- Added a `boss_present` boolean flag that checks if `boss_units_count > 0`
- Modified conditional checks to bypass minimum enemy count when a boss is present
- Maintained keybind override functionality alongside the new boss detection
- Added debug output in some spells to indicate when boss detection is triggering the bypass

### Minimum Enemy Count Threshold Fix

**Issue:** The script was ignoring the minimum enemy count setting when elite/champion enemies were present, causing suboptimal spell usage in many scenarios.

**Files Fixed:**
- `main.lua` - Added global check in the `evaluate_targets` function
- `death_trap.lua` - Implemented effective threshold check
- `poison_trap.lua` - Added minimum enemy count validation
- `dance_of_knives.lua` - Added global minimum enemy count check
- `rain_of_arrows.lua` - Fixed minimum enemy threshold logic
- `caltrop.lua` - Added proper enemy count validation
- `penetrating_shot.lua` - Fixed enemy count check logic

**Technical Details:**
- Implemented consistent checking of `all_units_count` against the effective minimum threshold
- Created an `effective_min_enemies` variable that uses the higher value between global and spell-specific settings
- Added keybind override functionality to allow manual casting regardless of enemy count
- Added debug output for easier verification of enemy counting process

### Enhanced Error Handling

**Issue:** Script was crashing due to insufficient error handling in spell registrations and function calls.

**Files Fixed:**
- `main.lua` - Added comprehensive error handling with pcall
- All spell files - Added robust error handling
- `spells/evade.lua` - Enhanced error checking for evade spell registration

**Technical Details:**
- Added robust error handling with pcall for all spell registrations
- Enhanced parameter validation for all spell functions
- Improved error reporting for easier troubleshooting
- Fixed missing parameters in register_circular_spell and register_rectangular_spell calls
- Added fallback mechanisms when functions are unavailable

### Performance Optimizations

**Issue:** Script was performing unnecessary calculations and spell evaluations.

**Files Fixed:**
- `main.lua` - Implemented early returns and caching
- All spell files - Optimized evaluation logic

**Technical Details:**
- Implemented early returns when minimum enemy count requirements aren't met
- Reduced unnecessary spell evaluations with better early checks
- Improved caching of enemy count results to avoid redundant calculations
- Enhanced targeting refresh logic to reduce CPU load
- Added performance monitoring and optimization

## Previous Fixes (2024-07-06)

### Advanced Enemy Targeting
- Added weighted targeting system with enemy cluster detection
- Improved targeting for multi-enemy situations
- Better prioritization of dangerous enemies

### Enhanced Spell Management
- Improved channeled spell handling for Dance of Knives
- Dynamic position updating during channel
- Automatic pause when in dangerous areas

### Auto-Play Intelligence
- Added awareness of auto-play objectives
- Script adapts behavior based on current objective (combat, looting, travel)
- Improved mobility during travel objectives

### Loot Management
- Automatic pickup of potions during combat when needed
- Collection of high-value items (gold, obols) in close proximity
- Integration with health potion tracking

### Terrain Navigation
- Added walkability checks before casting positional abilities
- Automatic detection of inaccessible areas
- Finding alternative cast positions when primary target is unwalkable

### Boss Ability Recognition
- Added detection for common dangerous boss abilities
- Registered specific evade patterns for Butcher and Ashava abilities
- Improved avoidance of circular and rectangular danger zones

### Error Resilience
- Added robust error handling for spell registration
- Graceful handling of API changes
- Detailed error reporting for easier troubleshooting

## Testing Verification

To verify these fixes are working correctly:

### Spell Rotation Testing
1. Enable the script and observe the new rotation order
2. Verify Caltrop leads the rotation for area control
3. Confirm Shadow Imbuement is always maintained
4. Check that Penetrating Shot is spammed aggressively after main rotation

### Shadow Clone Testing
1. Verify Shadow Clone uses normal cooldown instead of fixed timer
2. Check that it casts when available based on cooldown and energy
3. Confirm enhanced targeting is working for optimal positioning

### Dance of Knives Testing
1. Verify it requires Shadow Imbuement to be active
2. Check 12-second timer logic following Shadow Clone
3. Confirm dynamic positioning and pause functionality work

### Boss Exception Testing
1. Set the minimum enemy count to a higher value (e.g., 4 or 5)
2. Fight a boss with minimum enemy count set high
3. Verify spells are cast despite not meeting the threshold
4. Confirm boss detection is working correctly

### Minimum Enemy Count Testing
1. Set the minimum enemy count to a higher value (e.g., 4 or 5)
2. Enter an area with scattered enemies where no clusters meet this threshold
3. Confirm that spells are not cast, even when elite/champion enemies are present
4. Use keybind mode with "Keybind Ignores Min Hits" enabled to verify manual override works

### Performance Testing
1. Monitor CPU usage during script operation
2. Verify early returns are working when minimum enemy count isn't met
3. Check that targeting caching is reducing redundant calculations
4. Confirm error handling prevents crashes

These fixes ensure the script follows the user's configured minimum enemy count settings more consistently, uses the optimal spell rotation for current meta, and provides better overall performance and reliability. 