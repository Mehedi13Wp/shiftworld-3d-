#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
cd "$HOME/shiftworld-3d-"
mkdir -p assets/vehicles build
url="https://raw.githubusercontent.com/Hidencod/tge-assets/main/packs/car-kit/race.glb"
echo "Downloading CC0 Kenney racing car GLB from GitHub mirror..."
curl -fL --retry 3 --connect-timeout 20 "$url" -o assets/vehicles/red_supercar.glb
test "$(wc -c < assets/vehicles/red_supercar.glb)" -gt 10000 || { echo "Invalid GLB download"; exit 1; }
echo "3D GLB downloaded. Importing..."
godot --headless --editor --path . --import
echo "Building Android APK..."
mkdir -p build
godot --headless --path . --export-debug "Android" build/SHIFTWORLD-DEV.apk
test -s build/SHIFTWORLD-DEV.apk
cp -f build/SHIFTWORLD-DEV.apk /storage/emulated/0/Download/SHIFTWORLD-DEV.apk
echo "DONE: Downloads/SHIFTWORLD-DEV.apk"
