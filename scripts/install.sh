#!/usr/bin/env bash
# Copies the Tallymark folder into the game's AddOns folder.
# Change ADDONS_DIR if your game is installed somewhere else.
ADDONS_DIR="/Applications/World of Warcraft/_forever_/Interface/AddOns"

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$SCRIPT_DIR/../Tallymark"

if [ ! -d "$ADDONS_DIR" ]; then
    echo "AddOns folder not found:"
    echo "  $ADDONS_DIR"
    echo "Edit ADDONS_DIR at the top of this script."
    exit 1
fi

# Real copy, not a symlink. Symlinked folders may not load SavedVariables in Forever.
rm -rf "$ADDONS_DIR/Tallymark"
cp -R "$SRC" "$ADDONS_DIR/Tallymark"

echo "Tallymark installed to:"
echo "  $ADDONS_DIR/Tallymark"
echo "New or renamed files: restart the game. Lua changes only: /reload"
