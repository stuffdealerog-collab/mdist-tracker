#!/usr/bin/env bash
# Runs a Godot test scene without touching the player's save: backs up user://save.json and restores it afterwards.
#   bash tools/safe_test.sh res://tests/look.tscn -- <args...>
UD="$APPDATA/Godot/app_userdata/Keyboard Seller Simulator"
G="${GODOT:-$LOCALAPPDATA/Programs/Godot/godot_console.exe}"
BK="$UD/save.json.testbak"
[ -f "$UD/save.json" ] && cp "$UD/save.json" "$BK"
cd "$(dirname "$0")/.."
"$G" --path . "$@"
rc=$?
if [ -f "$BK" ]; then mv -f "$BK" "$UD/save.json"; else rm -f "$UD/save.json"; fi
exit $rc
