# Core Rotation Logic

## Current Spell Priority (Updated 2025-01-27)

The spell rotation has been updated to prioritize the following core abilities in order:

### 1. Caltrop (Area Control)
- **Priority**: Highest (leads rotation)
- **Logic**: Area denial and crowd control
- **Conditions**: 
  - Minimum enemy count requirements
  - Enhanced targeting for optimal placement
  - Boss exception for minimum enemy count
- **Timing**: Cast early in rotation for area control

### 2. Smoke Grenade (Defensive Setup)
- **Priority**: High
- **Logic**: Defensive positioning and enemy disruption
- **Conditions**:
  - Minimum enemy count requirements
  - Enhanced targeting for optimal defensive positioning
  - Boss exception for minimum enemy count
- **Timing**: Cast early for defensive setup

### 3. Poison Trap (Damage Over Time)
- **Priority**: High
- **Logic**: Damage over time and area control
- **Conditions**:
  - Minimum enemy count requirements
  - Enhanced targeting for optimal trap placement
  - Boss exception for minimum enemy count
- **Timing**: Follows defensive setup for damage over time

### 4. Shadow Imbuement (Always Active)
- **Priority**: Critical
- **Logic**: Always maintain Shadow Imbuement buff
- **Conditions**: 
  - Cast if not active
  - Avoid conflicts with other imbuements (Poison/Cold)
- **Timing**: Immediate when buff expires

### 5. Shadow Clone (Frequent Usage)
- **Priority**: High
- **Logic**: Cast when available based on cooldown and energy
- **Conditions**:
  - Spell ready and affordable
  - Find optimal position for maximum enemy coverage
  - Use enhanced targeting if available
- **Timing**: Based on normal spell cooldown and energy availability

### 6. Penetrating Shot (Primary Damage)
- **Priority**: High
- **Logic**: Primary damage spell, spammed aggressively
- **Conditions**:
  - Minimum enemy count requirements
  - Enhanced targeting for optimal linear positioning
  - Boss exception for minimum enemy count
- **Timing**: Cast after main rotation, then spammed aggressively

### 7. Dash (Mobility)
- **Priority**: Medium
- **Logic**: Mobility and positioning
- **Conditions**:
  - Available and ready
  - Used for positioning and escape
- **Timing**: As needed for mobility

### 8. Shadow Step (Advanced Mobility)
- **Priority**: Medium
- **Logic**: Advanced mobility and positioning
- **Conditions**:
  - Available and ready
  - Used for advanced positioning and escape
- **Timing**: As needed for advanced mobility

### 9. Dark Shroud (Utility)
- **Priority**: Medium
- **Logic**: Additional utility and defense
- **Conditions**:
  - Available and ready
  - Used for additional utility
- **Timing**: As needed for utility

### Special: Dance of Knives (After Core Rotation)
- **Priority**: High (special timing)
- **Logic**: Cast every 12 seconds after Shadow Clone, requires Shadow Imbuement
- **Conditions**:
  - Shadow Imbuement must be active
  - Time-based (12-second interval to follow Shadow Clone)
  - Minimum enemy count requirements
  - Enhanced targeting for optimal positioning
- **Timing**: Every 12 seconds from last cast

## Implementation Details

### Caltrop Changes
- Now leads the rotation for area control
- Enhanced targeting for optimal placement
- Boss exception for minimum enemy count

### Smoke Grenade Changes
- Positioned early for defensive setup
- Enhanced targeting for defensive positioning
- Boss exception for minimum enemy count

### Poison Trap Changes
- Follows defensive setup for damage over time
- Enhanced targeting for optimal trap placement
- Boss exception for minimum enemy count

### Shadow Imbuement Changes
- Removed complex enemy count and priority mode checks
- Simplified to always maintain the buff
- Added conflict checking with other imbuements

### Shadow Clone Changes
- Removed 10-second timer restriction
- Now uses normal spell cooldown and energy availability
- Enhanced positioning logic for maximum effect
- Maintains enhanced targeting support
- Added comprehensive error handling and debugging

### Penetrating Shot Changes
- Now primary damage spell, spammed aggressively
- Enhanced targeting for optimal linear positioning
- Boss exception for minimum enemy count
- Aggressive spamming after main rotation

### Dance of Knives Changes
- Added dependency on Shadow Imbuement being active
- Added 12-second timer logic
- Maintains existing enemy count and enhanced targeting logic
- Positioned to follow Shadow Clone in the rotation

## Spell Priority Order

```lua
local spell_priority = {
    -- Core rotation: Caltrop leads, Shadow Imbuement always active, Shadow Clone frequent, Penetrating Shot spammed
    "caltrop",
    "smoke_grenade", 
    "poison_trap",
    "shadow_imbuement",
    "shadow_clone",
    "penetrating_shot",
    "dash",
    "shadow_step",
    "dark_shroud"
}
```

## Benefits

1. **Area Control First**: Caltrop leads for immediate area control
2. **Defensive Setup**: Smoke Grenade provides early defensive positioning
3. **Damage Over Time**: Poison Trap follows for sustained damage
4. **Consistent Buff Uptime**: Shadow Imbuement is always maintained
5. **Frequent Shadow Clone Usage**: Can be used as often as cooldown and energy allow
6. **Aggressive Damage**: Penetrating Shot spammed for maximum damage output
7. **Enhanced Performance**: Optimized positioning for maximum effect
8. **Maintains Flexibility**: Other spells still function normally in the rotation

## Troubleshooting

If spells are not casting properly, check the following:

### Common Issues and Solutions

1. **Spell Not Ready**
   - Check if spell is on cooldown
   - Verify the spell is equipped and available

2. **Insufficient Energy**
   - Ensure you have enough energy to cast spells
   - Check energy regeneration and management

3. **Menu Disabled**
   - Verify spell is enabled in the menu
   - Check the main plugin is enabled

4. **No Enemies in Range**
   - Spells require enemies to be in range to cast
   - Check spell range settings in the menu

5. **Minimum Enemy Count**
   - Check if minimum enemy count threshold is met
   - Boss enemies bypass this requirement

### Success Messages
Look for these console messages to confirm spells are working:
- `"Rouge Plugin: Casted Caltrop using enhanced targeting"`
- `"Rouge Plugin: Casted Shadow Clone using enhanced targeting, affecting ~X enemies"`
- `"Rouge Plugin: Casted Shadow Imbuement"`
- `"Dance of Knives: Waiting for Shadow Imbuement to be active"`

## Notes

- The rotation maintains compatibility with existing enhanced targeting and enemy count systems
- All spells still respect their individual enable/disable settings
- Shadow Clone now uses standard spell cooldown timing instead of fixed intervals
- Enhanced targeting and AOE optimization features are preserved
- Comprehensive error handling and fallback casting methods are implemented
- Boss enemies bypass minimum enemy count requirements for optimal boss fight performance 