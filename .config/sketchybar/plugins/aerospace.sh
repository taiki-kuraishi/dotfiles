#!/usr/bin/env bash

# Toggles the background of this workspace item on/off depending on whether
# it is the currently focused AeroSpace workspace.
# $1 is the workspace id this item was created for (see sketchybarrc).
# $FOCUSED_WORKSPACE comes from the aerospace_workspace_change event payload.

if [ "$1" = "$FOCUSED_WORKSPACE" ]; then
    sketchybar --set "$NAME" background.drawing=on
else
    sketchybar --set "$NAME" background.drawing=off
fi
