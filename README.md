# internal-kbd

A small Linux utility script for temporarily disabling the internal laptop keyboard by grabbing its input event device.

This is mainly useful when using an external keyboard, cleaning the keyboard, or avoiding accidental input from a damaged/internal keyboard.

## What it does

`internal-kbd` finds or uses an internal keyboard input device and grabs it through Python `evdev`, preventing key events from reaching the desktop session.

It works at the Linux input-device level, so it should work on both Wayland and X11.

## Features

- Disable the internal keyboard
- Re-enable the keyboard
- Check current status
- Toggle on/off
- Optional timeout safety
- Optional manual device override
- Uses a PID file to track the grab process
- Cleans up stale PID files

## Requirements

- Linux
- Python 3
- `python-evdev`
- `sudo` access

On Arch/EndeavourOS:

```bash
sudo pacman -S python-evdev
```
On Fedora:
```bash
sudo dnf install python3-evdev
```
Usage  
```bash
./internal-kbd disable
./internal-kbd enable
./internal-kbd status
./internal-kbd toggle
```
## Device override

By default, the script tries to find a keyboard device automatically.

To manually choose a device:
```bash
DEV=/dev/input/event2 ./internal-kbd disable
```
You can inspect input devices with:
```bash
ls -l /dev/input/by-path/
cat /proc/bus/input/devices
```
## Timeout safety

To automatically re-enable the keyboard after a set number of seconds:
```bash
TIMEOUT=60 ./internal-kbd disable
```
This is useful for testing so you do not accidentally lock yourself out.

## Safety notes

Make sure you have another way to control the computer before disabling the internal keyboard, such as:

- an external keyboard
- SSH access
- a touchscreen
- a known timeout value

This script grabs the input device and does not record keystrokes.

## Example

Disable the internal keyboard for 5 minutes:
```bash
TIMEOUT=300 ./internal-kbd disable
```
Re-enable it manually:
```bash
./internal-kbd enable
```
Check whether it is currently active:
```bash
./internal-kbd status
```

## Disclaimer

This is a personal utility script. Use carefully, especially when testing new device paths.
