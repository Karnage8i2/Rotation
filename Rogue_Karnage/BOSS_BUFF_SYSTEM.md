# Boss Buff Management System

## Overview

The Boss Buff Management System automatically casts poison trap, caltrops, and smoke grenade for their buff effects before spamming penetrating shot in boss/elite encounters. This ensures optimal damage output by maintaining important buffs during critical fights.

## Features

- **Automatic Detection**: Detects boss/elite encounters automatically
- **5-Second Rotation**: Repeats buff casting every 5 seconds as requested
- **Priority System**: Casts spells in priority order (poison trap → caltrop → smoke grenade)
- **Cooldown Management**: Respects individual spell cooldowns
- **Menu Integration**: Can be enabled/disabled through the menu system

## How It Works

### Detection
The system detects boss/elite encounters by checking:
- If the best target is a boss, champion, or elite
- If any target in the target list is a boss, champion, or elite

### Rotation Logic
1. **5-Second Timer**: The system waits 5 seconds between buff rotations
2. **Priority Order**: Attempts to cast spells in this order:
   - Poison Trap (4s cooldown)
   - Caltrop (3s cooldown) 
   - Smoke Grenade (4s cooldown)
3. **Cooldown Respect**: Only casts spells that are off cooldown
4. **Single Cast**: Casts one spell per rotation to avoid overwhelming the system

### Integration with Main Rotation
- **Pre-Penetrating Shot**: Buff spells are cast before penetrating shot spam
- **Priority Override**: When a buff spell is cast, the system exits to prioritize the buff
- **Normal Mode**: Continues with normal rotation when not in boss/elite encounters

## Menu Options

### Boss Buff Management
- **Location**: Enhancements → Boss Buff Management
- **Description**: "Automatically cast poison trap, caltrops, and smoke grenade for buff effects in boss/elite encounters"
- **Default**: Enabled (true)

## Configuration

### Spell Cooldowns
- Poison Trap: 4.0 seconds
- Caltrop: 3.0 seconds  
- Smoke Grenade: 4.0 seconds

### Rotation Interval
- Buff rotation repeats every 5.0 seconds

## Debug Information

The system provides console output for debugging:
- "Boss Buff Manager: Starting buff rotation (5s interval)"
- "Boss Buff Manager: Attempting to cast [spell] for buff effect"
- "Boss Buff Manager: Cast [spell] successfully"
- "Boss Buff Manager: [spell] not ready (cooldown: Xs remaining)"

## Usage

1. **Enable the System**: Go to Enhancements → Boss Buff Management and enable it
2. **Encounter Boss/Elite**: The system will automatically detect boss/elite encounters
3. **Automatic Rotation**: Buff spells will be cast every 5 seconds before penetrating shot spam
4. **Monitor Console**: Check console output for system status and debugging

## Technical Details

### Files Modified
- `main.lua`: Added boss buff manager integration
- `menu.lua`: Added menu option for boss buff management
- `my_utility/enhancements_manager.lua`: Added menu rendering for boss buff management
- `my_utility/boss_buff_manager.lua`: New boss buff management system

### Dependencies
- Requires poison trap, caltrop, and smoke grenade spells to be enabled
- Integrates with existing spell priority system
- Uses existing targeting and spell casting infrastructure

## Troubleshooting

### System Not Working
1. Check if Boss Buff Management is enabled in the menu
2. Verify that poison trap, caltrop, and smoke grenade are enabled
3. Check console output for error messages
4. Ensure you're in a boss/elite encounter

### Spells Not Casting
1. Check individual spell cooldowns
2. Verify spell requirements (energy, positioning, etc.)
3. Check console output for specific failure reasons

### Performance Issues
1. The system only activates during boss/elite encounters
2. Buff rotation is limited to once every 5 seconds
3. Only one spell is cast per rotation to minimize performance impact 