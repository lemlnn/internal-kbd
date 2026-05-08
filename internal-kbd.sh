#!/usr/bin/env bash
set -euo pipefail

# Internal keyboard grabber for Wayland/X11
# Usage:
#   internal-kbd disable
#   internal-kbd enable
#   internal-kbd status
#   internal-kbd toggle
#
# Optional overrides:
#   DEV=/dev/input/by-path/your-keyboard-event-kbd internal-kbd disable
#   TIMEOUT=60 internal-kbd disable

APP_NAME="internal-kbd"

DEV="${DEV:-}"
TIMEOUT="${TIMEOUT:-0}"

PIDFILE="${PIDFILE:-/run/user/$UID/${APP_NAME}.pid}"
LOGFILE="${LOGFILE:-/run/user/$UID/${APP_NAME}.log}"

process_exists() {
  local pid="${1:-}"
  [[ "$pid" =~ ^[0-9]+$ ]] && [[ -d "/proc/$pid" ]]
}

pid_from_file() {
  [[ -f "$PIDFILE" ]] || return 1
  cat "$PIDFILE"
}

is_running() {
  local pid
  pid="$(pid_from_file 2>/dev/null || true)"
  process_exists "$pid"
}

resolve_device() {
  local candidate

  if [[ -n "$DEV" ]]; then
    readlink -f "$DEV"
    return
  fi

  # Prefer non-USB keyboard devices first, usually the internal laptop keyboard.
  for candidate in /dev/input/by-path/*-event-kbd; do
    [[ -e "$candidate" ]] || continue
    case "$candidate" in
      *usb*) continue ;;
    esac
    readlink -f "$candidate"
    return
  done

  # Fallback: any keyboard device.
  for candidate in /dev/input/by-path/*-event-kbd; do
    [[ -e "$candidate" ]] || continue
    readlink -f "$candidate"
    return
  done

  return 1
}

wait_for_grab() {
  local i

  for ((i = 0; i < 30; i++)); do
    if [[ -f "$PIDFILE" ]] && is_running && grep -q "Successfully grabbed" "$LOGFILE" 2>/dev/null; then
      return 0
    fi

    if grep -qiE "traceback|error|permission denied|no such file" "$LOGFILE" 2>/dev/null; then
      return 1
    fi

    sleep 0.1
  done

  return 1
}

disable_kbd() {
  local dev_path
  dev_path="$(resolve_device || true)"

  if [[ -z "$dev_path" || ! -e "$dev_path" ]]; then
    echo "Device not found."
    echo "Set one manually with:"
    echo "  DEV=/dev/input/by-path/...-event-kbd $0 disable"
    exit 1
  fi

  if is_running; then
    echo "Already disabled. Grabber PID: $(cat "$PIDFILE")"
    exit 0
  fi

  rm -f "$PIDFILE"
  : > "$LOGFILE"

  echo "Grabbing internal keyboard: $dev_path"
  echo "Authenticating sudo first..."
  sudo -v

  nohup sudo -n python3 - "$dev_path" "$PIDFILE" "$TIMEOUT" > "$LOGFILE" 2>&1 <<'PY' &
import os
import select
import signal
import sys
import time
from evdev import InputDevice

dev_path = sys.argv[1]
pidfile = sys.argv[2]
timeout = float(sys.argv[3])

running = True
deadline = time.monotonic() + timeout if timeout > 0 else None

def stop(signum, frame):
    global running
    running = False

signal.signal(signal.SIGTERM, stop)
signal.signal(signal.SIGINT, stop)

dev = InputDevice(dev_path)

try:
    dev.grab()

    with open(pidfile, "w", encoding="utf-8") as f:
        f.write(str(os.getpid()))

    print(f"Successfully grabbed {dev.path} ({dev.name})", flush=True)

    while running:
        if deadline is not None and time.monotonic() >= deadline:
            print("Timeout reached. Releasing keyboard.", flush=True)
            break

        readable, _, _ = select.select([dev.fd], [], [], 0.5)

        if dev.fd in readable:
            for _ in dev.read():
                pass

finally:
    try:
        dev.ungrab()
        print("Keyboard ungrabbed.", flush=True)
    except Exception:
        pass

    try:
        os.remove(pidfile)
    except FileNotFoundError:
        pass
PY

  sleep 0.1

  if wait_for_grab; then
    echo "Internal keyboard disabled."
    echo "PID: $(cat "$PIDFILE")"
    echo "Log: $LOGFILE"
  else
    echo "Failed to start grabber."
    echo "Log output:"
    cat "$LOGFILE" || true
    rm -f "$PIDFILE"
    exit 1
  fi
}

enable_kbd() {
  local pid

  if ! [[ -f "$PIDFILE" ]]; then
    echo "No PID file found. Keyboard may already be enabled."
    exit 0
  fi

  pid="$(cat "$PIDFILE")"

  if process_exists "$pid"; then
    echo "Stopping keyboard grabber PID: $pid"

    sudo -n kill "$pid" 2>/dev/null || sudo kill "$pid" 2>/dev/null || kill "$pid" 2>/dev/null || true
    sleep 0.5

    if process_exists "$pid"; then
      echo "Process still running. Force killing..."
      sudo -n kill -9 "$pid" 2>/dev/null || sudo kill -9 "$pid" 2>/dev/null || kill -9 "$pid" 2>/dev/null || true
    fi

    echo "Internal keyboard enabled."
  else
    echo "Stale PID file found. Removing it."
  fi

  rm -f "$PIDFILE"
}

status_kbd() {
  if is_running; then
    echo "Internal keyboard is disabled."
    echo "Grabber PID: $(cat "$PIDFILE")"
    echo "Log: $LOGFILE"
  else
    echo "Internal keyboard is enabled."
  fi
}

toggle_kbd() {
  if is_running; then
    enable_kbd
  else
    disable_kbd
  fi
}

case "${1:-}" in
  disable)
    disable_kbd
    ;;
  enable)
    enable_kbd
    ;;
  status)
    status_kbd
    ;;
  toggle)
    toggle_kbd
    ;;
  *)
    echo "Usage: $0 {disable|enable|status|toggle}"
    echo ""
    echo "Optional:"
    echo "  DEV=/dev/input/by-path/...-event-kbd $0 disable"
    echo "  TIMEOUT=60 $0 disable"
    exit 1
    ;;
esac#!/usr/bin/env bash
set -euo pipefail

# Internal keyboard grabber for Wayland/X11
# Usage:
#   internal-kbd disable
#   internal-kbd enable
#   internal-kbd status
#   internal-kbd toggle
#
# Optional overrides:
#   DEV=/dev/input/by-path/your-keyboard-event-kbd internal-kbd disable
#   TIMEOUT=60 internal-kbd disable

APP_NAME="internal-kbd"

DEV="${DEV:-}"
TIMEOUT="${TIMEOUT:-0}"

PIDFILE="${PIDFILE:-/run/user/$UID/${APP_NAME}.pid}"
LOGFILE="${LOGFILE:-/run/user/$UID/${APP_NAME}.log}"

process_exists() {
  local pid="${1:-}"
  [[ "$pid" =~ ^[0-9]+$ ]] && [[ -d "/proc/$pid" ]]
}

pid_from_file() {
  [[ -f "$PIDFILE" ]] || return 1
  cat "$PIDFILE"
}

is_running() {
  local pid
  pid="$(pid_from_file 2>/dev/null || true)"
  process_exists "$pid"
}

resolve_device() {
  local candidate

  if [[ -n "$DEV" ]]; then
    readlink -f "$DEV"
    return
  fi

  # Prefer non-USB keyboard devices first, usually the internal laptop keyboard.
  for candidate in /dev/input/by-path/*-event-kbd; do
    [[ -e "$candidate" ]] || continue
    case "$candidate" in
      *usb*) continue ;;
    esac
    readlink -f "$candidate"
    return
  done

  # Fallback: any keyboard device.
  for candidate in /dev/input/by-path/*-event-kbd; do
    [[ -e "$candidate" ]] || continue
    readlink -f "$candidate"
    return
  done

  return 1
}

wait_for_grab() {
  local i

  for ((i = 0; i < 30; i++)); do
    if [[ -f "$PIDFILE" ]] && is_running && grep -q "Successfully grabbed" "$LOGFILE" 2>/dev/null; then
      return 0
    fi

    if grep -qiE "traceback|error|permission denied|no such file" "$LOGFILE" 2>/dev/null; then
      return 1
    fi

    sleep 0.1
  done

  return 1
}

disable_kbd() {
  local dev_path
  dev_path="$(resolve_device || true)"

  if [[ -z "$dev_path" || ! -e "$dev_path" ]]; then
    echo "Device not found."
    echo "Set one manually with:"
    echo "  DEV=/dev/input/by-path/...-event-kbd $0 disable"
    exit 1
  fi

  if is_running; then
    echo "Already disabled. Grabber PID: $(cat "$PIDFILE")"
    exit 0
  fi

  rm -f "$PIDFILE"
  : > "$LOGFILE"

  echo "Grabbing internal keyboard: $dev_path"
  echo "Authenticating sudo first..."
  sudo -v

  nohup sudo -n python3 - "$dev_path" "$PIDFILE" "$TIMEOUT" > "$LOGFILE" 2>&1 <<'PY' &
import os
import select
import signal
import sys
import time
from evdev import InputDevice

dev_path = sys.argv[1]
pidfile = sys.argv[2]
timeout = float(sys.argv[3])

running = True
deadline = time.monotonic() + timeout if timeout > 0 else None

def stop(signum, frame):
    global running
    running = False

signal.signal(signal.SIGTERM, stop)
signal.signal(signal.SIGINT, stop)

dev = InputDevice(dev_path)

try:
    dev.grab()

    with open(pidfile, "w", encoding="utf-8") as f:
        f.write(str(os.getpid()))

    print(f"Successfully grabbed {dev.path} ({dev.name})", flush=True)

    while running:
        if deadline is not None and time.monotonic() >= deadline:
            print("Timeout reached. Releasing keyboard.", flush=True)
            break

        readable, _, _ = select.select([dev.fd], [], [], 0.5)

        if dev.fd in readable:
            for _ in dev.read():
                pass

finally:
    try:
        dev.ungrab()
        print("Keyboard ungrabbed.", flush=True)
    except Exception:
        pass

    try:
        os.remove(pidfile)
    except FileNotFoundError:
        pass
PY

  sleep 0.1

  if wait_for_grab; then
    echo "Internal keyboard disabled."
    echo "PID: $(cat "$PIDFILE")"
    echo "Log: $LOGFILE"
  else
    echo "Failed to start grabber."
    echo "Log output:"
    cat "$LOGFILE" || true
    rm -f "$PIDFILE"
    exit 1
  fi
}

enable_kbd() {
  local pid

  if ! [[ -f "$PIDFILE" ]]; then
    echo "No PID file found. Keyboard may already be enabled."
    exit 0
  fi

  pid="$(cat "$PIDFILE")"

  if process_exists "$pid"; then
    echo "Stopping keyboard grabber PID: $pid"

    sudo -n kill "$pid" 2>/dev/null || sudo kill "$pid" 2>/dev/null || kill "$pid" 2>/dev/null || true
    sleep 0.5

    if process_exists "$pid"; then
      echo "Process still running. Force killing..."
      sudo -n kill -9 "$pid" 2>/dev/null || sudo kill -9 "$pid" 2>/dev/null || kill -9 "$pid" 2>/dev/null || true
    fi

    echo "Internal keyboard enabled."
  else
    echo "Stale PID file found. Removing it."
  fi

  rm -f "$PIDFILE"
}

status_kbd() {
  if is_running; then
    echo "Internal keyboard is disabled."
    echo "Grabber PID: $(cat "$PIDFILE")"
    echo "Log: $LOGFILE"
  else
    echo "Internal keyboard is enabled."
  fi
}

toggle_kbd() {
  if is_running; then
    enable_kbd
  else
    disable_kbd
  fi
}

case "${1:-}" in
  disable)
    disable_kbd
    ;;
  enable)
    enable_kbd
    ;;
  status)
    status_kbd
    ;;
  toggle)
    toggle_kbd
    ;;
  *)
    echo "Usage: $0 {disable|enable|status|toggle}"
    echo ""
    echo "Optional:"
    echo "  DEV=/dev/input/by-path/...-event-kbd $0 disable"
    echo "  TIMEOUT=60 $0 disable"
    exit 1
    ;;
esac
