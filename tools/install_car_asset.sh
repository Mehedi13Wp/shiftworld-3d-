#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
cd "$HOME/shiftworld-3d-"
mkdir -p assets/vehicles build
archive="$HOME/shiftworld-car-kit.zip"
url="https://kenney.nl/media/pages/assets/car-kit/1a312ec241-1775131960/kenney_car-kit.zip"
echo "Downloading original Kenney Car Kit (CC0)..."
curl -fL --retry 3 --connect-timeout 20 "$url" -o "$archive"
echo "Available sports models:"
unzip -Z1 "$archive" | grep -Ei '\.glb$' | grep -Ei 'race|sport|super|hatchback' || true
model="$(unzip -Z1 "$archive" | grep -Ei '\.glb$' | grep -Ei 'race|sport|super|hatchback' | head -n 1 || true)"
if [ -z "$model" ]; then
  echo "No sports model detected. See available GLB models:"
  unzip -Z1 "$archive" | grep -Ei '\.glb$' | head -30
  exit 1
fi
echo "Installing model: $model"
unzip -p "$archive" "$model" > assets/vehicles/red_supercar.glb
test -s assets/vehicles/red_supercar.glb
echo "Real 3D model installed. Importing..."
godot --headless --editor --path . --import
echo "Building Android APK..."
godot --headless --path . --export-debug "Android" build/SHIFTWORLD-DEV.apk
cp -f build/SHIFTWORLD-DEV.apk /storage/emulated/0/Download/SHIFTWORLD-DEV.apk
echo "DONE: Downloads/SHIFTWORLD-DEV.apk"
