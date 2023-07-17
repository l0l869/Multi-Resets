# Multi-Resets

A multi-instance macro for Minecraft Bedrock Edition Speedrunning.

Supported Versions: 1.16.10, 1.16.1, 1.16.0.58, 1.16.0.57, 1.16.0.51, 1.14.60, 1.2.13

### Setup

[Quick Setup Video](https://youtu.be/W16rlDLTXfY)

- Install the 64-bit version of [AHK V1.1](https://www.autohotkey.com/download/ahk-install.exe)
- Download the latest release
- Enable the ability to multi-instance by running `configs/RegisterMulti.ahk`.
- The macro needs to know where to click; go through the setup by opening `configs/Setup.ahk`.
  
If the arrangement of instances is changed, setup is to be redone.
### Configuration

- Edit the settings in `configs/Configs.ini`. 
- To customise hotkeys: [Hotkey Documentation](https://www.autohotkey.com/docs/v1/Hotkeys.htm).
- If the macro ever goes rogue, press Right Control to terminate the script.
- Make sure to restart the script after making any changes.

### Options

#### Macro
- **min/maxCoords**: Automatically resets if the spawn is not within the range of the minimum and maximum coordinates.
- **autoRestart**: Automatically restarts Minecraft after a certain number of resets (resetThreshold).
- **resetThreshold**: Number of resets accumulated between instances to restart Minecraft.
- **keyDelay**: Delay (in milliseconds) between world creation clicks. Set it to or above 50 for verification.
- **numInstances**: Number of instances. Recommended amount: Total Logical Processors / 4.
- **layoutDimensions**: The arrangement of instances (x, y).
- **threadsUsage**: The precentage of CPU threads the instances will utilise.
- **readScreenMemory**: Relies on memory to know which screen you're on. Use only if the macro can't find buttons by their pixel colour. Supports: 1.16.1 and 1.2.13.

#### Timer
- **timerActivated**: Enable or disable the timer. Set to `true` or `false`.
- **anchor**: The anchor point for the timer placement. Options: `TopLeft`, `TopRight`, `BottomLeft`, `BottomRight`.
- **offset**: The X and Y offsets (in pixels) from where the timer is anchored.
- **decimalPlaces**: Number of decimal places for the timer. Can be set from 0 to 3.
- **refreshRate**: The frequency (in milliseconds) at which the timer updates.
- **autoSplit**: Automatically stops the timer when the credits roll. Supported versions: 1.16.1, 1.16.10.

### Known Issues

- For some, the macro retrieves the wrong pixel colour; set `readScreenMemory` to `true`, if this is the case.

- Something to know: clicking/tabbing to other windows when instances are launching will mess up the macro.
