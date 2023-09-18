# Multi-Resets

A multi-instance macro for Minecraft Bedrock Edition Speedrunning.

Supported Auto-reset Versions: 1.19.50, 1.16.10, 1.16.1, 1.16.0.58, 1.16.0.57, 1.16.0.51, 1.14.60, 1.2.13

## Setup

[Quick Setup Video](https://youtu.be/W16rlDLTXfY)

- Install the 64-bit version of [AHK V1.1](https://www.autohotkey.com/download/ahk-install.exe)
- Download the latest release
- Enable the ability to multi-instance by running `configs/RegisterMulti.ahk`.
- The macro needs to know where to click; go through the setup by opening `configs/Setup.ahk`.
  
If the arrangement of instances is changed, setup is to be redone.
## Manual Resetting

- To enter an instance, press the stop reset hotkey while hovering over your desired instance
- To reset all instances, press the reset hotkey while on the wall screen 

## Options

### Macro
- `Reset Mode`: Use manual if auto-reset isn't supported.
- `Min/Max Coordinate`: Automatically resets if the spawn is not within the range of the minimum and maximum coordinates.
- `Auto Restart`: Automatically restarts Minecraft after a certain number of resets (resetThreshold).
- `Reset Threshold`: Number of resets accumulated between instances to restart Minecraft.
- `Number of Instances`: Number of instances. Recommended amount: Total Logical Processors / 4.
- `Layout`: The arrangement of instances (x, y).
- `Key Delay`: Delay (in milliseconds) between world creation clicks. Set it to or above 50 for verification.
### Timer
- `Anchor`: The anchor point for the timer placement.
- `Offset`: The X and Y offsets (in pixels) from where the timer is anchored.
- `Font`: Can use any font installed on your system.
- `Colour`: Any valid hexadecimal colour.
- `Decimals`: Number of decimal places for the timer.
- `Auto Split`: Automatically stops the timer when the credits roll. Supported versions: 1.16.1, 1.16.10.

### Other
- `Read Screen Memory`: Relies on memory to know which screen you're on. Use only if the macro can't find buttons by their pixel colour. Supports: 1.16.1 and 1.2.13.
- `Threads Utilisation`: The precentage of CPU threads the instances will utilise.

## Known Issues

- For some, the macro retrieves the wrong pixel colour; enable `readScreenMemory`, if this is the case.

- Something to know: clicking/tabbing to other windows when instances are launching will mess up the macro.
