# Death Trap Rogue - Debugging Guide

If you're experiencing issues with the script not attacking or other functionality problems, follow this guide to troubleshoot:

## Current Spell Rotation Debugging

The script now uses a sophisticated spell priority system. If spells aren't casting in the expected order, check:

### Spell Priority Order (Current):
1. Caltrop (area control)
2. Smoke Grenade (defensive setup)
3. Poison Trap (damage over time)
4. Shadow Imbuement (always maintain)
5. Shadow Clone (frequent usage)
6. Penetrating Shot (primary damage, spammed aggressively)
7. Dash (mobility)
8. Shadow Step (advanced mobility)
9. Dark Shroud (utility)

### Special Spell Logic:
- **Dance of Knives**: Cast every 12 seconds after Shadow Clone, requires Shadow Imbuement to be active

## Common Issues and Solutions

### Character Not Attacking

1. **Enable Debug Mode**
   - Open the menu and check "Enable Debug Mode" under "Debug Options"
   - Also enable "Verbose Logging" and "Draw Target Info" 
   - This will display detailed information about why attacks might not be happening

2. **Check Console Output**
   - Look at the console output for error messages
   - The script now displays detailed error information in the console
   - Look for specific spell casting messages like:
     - `"Rouge Plugin: Casted Caltrop using enhanced targeting"`
     - `"Rouge Plugin: Casted Shadow Clone using enhanced targeting, affecting ~X enemies"`
     - `"Rouge Plugin: Casted Shadow Imbuement"`
     - `"Dance of Knives: Waiting for Shadow Imbuement to be active"`

3. **Check Targeting**
   - Make sure there are valid targets within range
   - The debug mode will show information about available targets
   - If no targets are found, try increasing "Max Targeting Range" in Settings

4. **Check Spell Availability**
   - Make sure your character has the necessary spells unlocked
   - Check if you're out of resources (Energy/Spirit)
   - Verify that spells aren't on cooldown

5. **Mode Selection**
   - Try switching between "Melee" and "Ranged" modes
   - Different modes use different targeting logic and spell priorities

6. **Minimum Enemy Count**
   - Check if minimum enemy count threshold is met
   - Boss enemies bypass this requirement
   - Look for debug messages about enemy counting

### Spell-Specific Issues

#### Shadow Imbuement Not Casting
- Check if other imbuements (Poison/Cold) are active (conflicts are avoided)
- Verify the spell is enabled in the menu
- Check if the spell is ready and affordable

#### Shadow Clone Not Casting
- Check if spell is on cooldown (no longer uses fixed 10-second timer)
- Verify you have enough energy
- Check if enhanced targeting is finding optimal positions
- Look for fallback casting messages

#### Dance of Knives Not Casting
- Verify Shadow Imbuement is active (required dependency)
- Check if 12 seconds have passed since last Shadow Clone cast
- Verify minimum enemy count is met (or boss is present)
- Check if you're in a dangerous area (pause functionality)

#### Penetrating Shot Not Spamming
- Verify the spell is enabled in the menu
- Check if minimum enemy count is met (or boss is present)
- Look for enhanced targeting messages
- Verify the spell is being spammed after main rotation

### Improving Performance

1. **Reduce Debug Options**
   - Turn off debug options when not needed as they can impact performance

2. **Adjust Targeting Refresh Interval**
   - Increase the "Targeting Refresh Interval" for better performance
   - Default is 0.3 seconds, try 0.5-1.0 for better performance

3. **Disable Unused Features**
   - Disable features you don't need (Position Optimization, Dynamic Priorities, etc.)

4. **Check Enhanced Targeting Impact**
   - Enhanced targeting can impact performance on slower systems
   - Consider disabling if performance is poor
   - Use debug visualization sparingly during high-performance scenarios

## Advanced Troubleshooting

### Log Files

The script now creates detailed log files that can help diagnose issues:

1. Look for the `logs` folder in your script directory
2. Check the most recent log file for detailed error information
3. A log.txt file in the parent directory will contain critical errors

### Restarting the Script

Sometimes a clean restart can fix issues:

1. Completely disable the script in the menu
2. Reload your game or reset the script
3. Re-enable the script

### Enhanced Error Handling

The script has improved error handling:

- Detailed error messages in console and logs
- Graceful recovery from many types of errors
- Better debugging tools
- Fallback mechanisms when functions are unavailable

### Performance Monitoring

Monitor these aspects for performance issues:

1. **CPU Usage**: Check if script is causing high CPU usage
2. **Targeting Caching**: Verify early returns are working when minimum enemy count isn't met
3. **Spell Evaluations**: Check that unnecessary evaluations are being skipped
4. **Error Handling**: Confirm error handling prevents crashes

## New Features

### Dynamic Priorities

The script now includes a dynamic priority system that adjusts spell priorities based on combat situations:

- Enable "Use Dynamic Priorities" in the Dynamic Priorities menu
- Set "AoE Priority Threshold" to define when to prioritize AoE abilities
- Enable "Boss Mode" to optimize for boss fights

### Buff Tracking

The script now tracks buffs and debuffs to make better decisions:

- Automatically maintains important buffs like Shadow Imbuement
- Prioritizes targets with useful debuffs
- Tracks momentum stacks and other important resources
- Prevents conflicts between different imbuements

### Enhanced Targeting Debug

When enhanced targeting is enabled, you can see:

- Spell ranges shown as circles around the player
- Potential targets highlighted with color coding
- Actual effect areas when spells are cast
- Targeting decisions with reasoning

### Boss Exception Logic

The script now has special handling for boss fights:

- Bosses bypass minimum enemy count requirements
- Look for debug messages about boss detection
- Verify boss exception is working correctly

## Reporting Issues

If you continue experiencing problems:

1. Enable "Verbose Logging" in Debug Options
2. Reproduce the issue
3. Note the current spell rotation and any error messages
4. Share the log files when reporting the problem
5. Include information about your spell setup and settings

## Quick Debug Checklist

- [ ] Main plugin enabled
- [ ] Spell-specific settings enabled
- [ ] Minimum enemy count settings appropriate
- [ ] Enhanced targeting enabled (if desired)
- [ ] Debug mode enabled for troubleshooting
- [ ] Console showing spell casting messages
- [ ] No error messages in console or logs
- [ ] Spell rotation following expected order
- [ ] Performance acceptable for your system

If you continue experiencing issues after following this guide, please report the problem with your log files and current settings. 