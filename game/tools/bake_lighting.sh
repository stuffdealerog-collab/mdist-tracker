#!/usr/bin/env bash
# Bakes the flat's lightmaps (day + night): export static meshes with UV2, then bake in the editor via addons/kss_bake.
#   bash tools/bake_lighting.sh
set -e
cd "$(dirname "$0")/.."
G="${GODOT:-$LOCALAPPDATA/Programs/Godot/godot_console.exe}"
KSS_NOBAKE=1 KSS_NOTITLE=1 KSS_NOWAKE=1 "$G" --path . res://tests/bake_export.tscn 2>&1 | grep "^\[bake\] [0-9s]"
KSS_BAKE=1 "$G" --editor --path . 2>&1 | grep -E "kss_bake|Done baking"
