#!/bin/bash
# ax-screenshot.sh - Take screenshots of macOS app windows
# Usage: ax-screenshot.sh <app_name> [output_file] [--region x,y,w,h]
#
# Examples:
#   ax-screenshot.sh VATTracker                      # Capture window to /tmp/<app>_window.png
#   ax-screenshot.sh VATTracker screenshot.png       # Capture to specific file
#   ax-screenshot.sh VATTracker out.png --toolbar    # Capture just toolbar (52px height)

set -e

APP_NAME="${1:-}"
OUTPUT="${2:-}"
OPTION="${3:-}"

if [ -z "$APP_NAME" ]; then
    echo "Usage: ax-screenshot.sh <app_name> [output_file] [--toolbar]" >&2
    exit 1
fi

# Default output path
if [ -z "$OUTPUT" ]; then
    OUTPUT="/tmp/${APP_NAME,,}_window.png"
fi

# Check if app is running
if ! pgrep -xq "$APP_NAME"; then
    echo "Error: $APP_NAME is not running" >&2
    exit 1
fi

# Activate the app
osascript -e "tell application \"$APP_NAME\" to activate" 2>/dev/null
sleep 0.3

# Get window bounds
BOUNDS=$(osascript -e "
tell application \"System Events\"
    tell process \"$APP_NAME\"
        set winPos to position of front window
        set winSize to size of front window
        set x to item 1 of winPos
        set y to item 2 of winPos
        set w to item 1 of winSize
        set h to item 2 of winSize
        return (x as text) & \",\" & (y as text) & \",\" & (w as text) & \",\" & (h as text)
    end tell
end tell
" 2>/dev/null)

if [ -z "$BOUNDS" ]; then
    echo "Error: Could not get window bounds" >&2
    exit 1
fi

IFS=',' read -r X Y W H <<< "$BOUNDS"

# Modify for toolbar-only capture
if [ "$OPTION" == "--toolbar" ]; then
    H=52
fi

# Capture the window region
screencapture -x -R"${X},${Y},${W},${H}" "$OUTPUT"

echo "$OUTPUT"
