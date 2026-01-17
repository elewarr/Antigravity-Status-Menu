#!/bin/bash
# ax-menu.sh - Access menu items in a macOS app
# Usage: ax-menu.sh <app_name> <menu_name> [menu_item_name]
#
# If menu_item_name is omitted, lists all items in the menu.
# If menu_item_name is provided, clicks that menu item.
#
# Examples:
#   ax-menu.sh VATTracker                    # List all menus
#   ax-menu.sh VATTracker "Widok"            # List items in Widok menu
#   ax-menu.sh VATTracker "Widok" "Tryb pełnoekranowy"  # Click menu item

set -e

APP_NAME="${1:-}"
MENU_NAME="${2:-}"
MENU_ITEM="${3:-}"

if [ -z "$APP_NAME" ]; then
    echo "Usage: ax-menu.sh <app_name> [menu_name] [menu_item_name]" >&2
    exit 1
fi

# Activate the app first
osascript -e "tell application \"$APP_NAME\" to activate" 2>/dev/null || true
sleep 0.2

if [ -z "$MENU_NAME" ]; then
    # List all menus
    osascript -e "tell application \"System Events\" to tell process \"$APP_NAME\" to tell menu bar 1 to get name of every menu bar item"
elif [ -z "$MENU_ITEM" ]; then
    # List items in specified menu
    osascript <<EOF
tell application "System Events"
    tell process "$APP_NAME"
        tell menu bar 1
            tell menu bar item "$MENU_NAME"
                tell menu 1
                    set itemNames to {}
                    repeat with mi in menu items
                        try
                            set itemName to name of mi
                            if itemName is not missing value then
                                set end of itemNames to itemName
                            else
                                set end of itemNames to "---"
                            end if
                        end try
                    end repeat
                    return itemNames
                end tell
            end tell
        end tell
    end tell
end tell
EOF
else
    # Click the specified menu item
    osascript <<EOF
tell application "System Events"
    tell process "$APP_NAME"
        tell menu bar 1
            tell menu bar item "$MENU_NAME"
                tell menu 1
                    click menu item "$MENU_ITEM"
                    return "Clicked: $MENU_NAME > $MENU_ITEM"
                end tell
            end tell
        end tell
    end tell
end tell
EOF
fi
