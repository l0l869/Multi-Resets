# Multi-Resets

A multi-instance macro for Minecraft Bedrock Edition Speedrunning.

Supported Auto-reset Versions: 1.19.50, 1.16.10, 1.16.1, 1.16.0.58, 1.16.0.57, 1.16.0.51, 1.14.60, 1.2.13

## Setup

- Install [AHK V1.1](https://www.autohotkey.com/download/ahk-install.exe) (64-bit version)
- Download the latest release
- You can start resetting by using the setupless mode.
    - Make sure your Minecraft GUI Scale Modifier is set to its highest value. 
    - For 1.19.50, you'll need to do the setup and set your language to Japanese for old world creation UI.
        - If the arrangement of instances is changed, setup is to be redone.

## Settings

### Macro
- **Reset Mode**: Use manual if auto-reset isn't supported.
- **Min/Max Coordinate**: Automatically resets if the spawn is not within the range of the minimum and maximum coordinates.
- **Auto Restart**: Automatically restarts Minecraft after a certain number of resets (Reset Threshold).
- **Reset Threshold**: Number of resets accumulated between instances to restart Minecraft.
- **Number of Instances**: Recommended amount: Total Logical Processors / 4.
- **Layout**: The arrangement of instances (x, y).
- **Key Delay**: Delay (in milliseconds) between world creation clicks. Set it to or above 50 for verification.

### Timer
- **Anchor**: The anchor point for the timer placement.
- **Offset**: The X and Y offsets (in pixels) from where the timer is anchored.
- **Font**: Can use any font installed on your system.
- **Colour**: Any valid hexadecimal colour in the ARGB form.
- **Animation Speed**: In seconds, the length of the animation. Set 0 to omit.
- **Decimals**: Number of decimal places.
- **Auto Split**: Automatically stops the timer when the credits roll. Supported versions: 1.16.1, 1.16.10.

### Other
- **Reset Method**: How the macro resets. Setup requires setting pixels to know where and when to click. Setupless automatically finds the text of buttons.
- **Read Screen Memory**: Relies on memory to know which screen you're on. Use only if the macro can't find buttons by their pixel colour. Supports: 1.16.1 and 1.2.13.
- **Coop Mode**: Prevents the 0/8 bug.
- **Threads Utilisation**: The precentage of CPU threads the instances will utilise.

## Manual Resetting

- **Enter Instance**: press the stop reset hotkey while hovering over your desired instance
- **Reset All Instances**: press the reset hotkey while on the wall screen