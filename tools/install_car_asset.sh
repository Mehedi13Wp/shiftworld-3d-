#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
cd "$HOME/shiftworld-3d-"
mkdir -p assets/vehicles assets/nature build
base="https://raw.githubusercontent.com/Hidencod/tge-assets/main/packs"
fetch_glb() {
  local src="$1" dest="$2" tmp
  tmp="${dest}.part"
  echo "Downloading $src"
  curl -fL --retry 3 --connect-timeout 20 "$base/$src" -o "$tmp"
  test "$(wc -c < "$tmp")" -gt 8000 || { echo "Invalid asset: $src"; rm -f "$tmp"; exit 1; }
  mv -f "$tmp" "$dest"
}
# Kenney Car Kit is CC0. sedan-sports is a closed-body street car with wheels.
echo "Downloading CC0 Kenney Sedan Sports (city street-car model)"
fetch_glb "car-kit/sedan-sports.glb" "assets/vehicles/sedan_sports.glb"
fetch_glb "nature-kit/tree-detailed.glb" "assets/nature/tree_detailed.glb"
fetch_glb "nature-kit/tree-oak.glb" "assets/nature/tree_oak.glb"
echo "Importing actual car and tree meshes..."
godot --headless --editor --path . --import
echo "Building Android..."
godot --headless --path . --export-debug "Android" build/SHIFTWORLD-DEV.apk
test -s build/SHIFTWORLD-DEV.apk
cp -f build/SHIFTWORLD-DEV.apk /storage/emulated/0/Download/SHIFTWORLD-DEV.apk
echo "SUCCESS: Downloads/SHIFTWORLD-DEV.apk"
