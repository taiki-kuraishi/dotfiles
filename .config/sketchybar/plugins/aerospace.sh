#!/usr/bin/env bash

# Toggles the background of this workspace item on/off depending on whether
# it is the currently focused AeroSpace workspace, and refreshes the app-icon
# label to reflect windows currently open in it.
# $1 is the workspace id this item was created for (see sketchybarrc).
# $FOCUSED_WORKSPACE comes from the aerospace_workspace_change event payload.

source "$CONFIG_DIR/icon_map.sh"

if [ "$1" = "$FOCUSED_WORKSPACE" ]; then
    sketchybar --set "$NAME" background.drawing=on
else
    sketchybar --set "$NAME" background.drawing=off
fi

apps=$(aerospace list-windows --workspace "$1" --format "%{app-name}" 2>/dev/null | sort -u)
icon_strip=""
while IFS= read -r app; do
    [ -z "$app" ] && continue
    __icon_map "$app"
    icon_strip+="${icon_result} "
done <<< "$apps"

sketchybar --set "$NAME" label="$icon_strip" label.drawing=on
