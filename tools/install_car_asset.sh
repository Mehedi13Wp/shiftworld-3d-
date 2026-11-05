#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
cd "$HOME/shiftworld-3d-"
mkdir -p assets/vehicles assets/nature build
base="https://raw.githubusercontent.com/Hidencod/tge-assets/main/packs"
fetch_glb() {
  local src="$1" dest="$2" tmp
  tmp="${dest}.part"
  if [ -s "$dest" ] && [ "$(wc -c < "$dest")" -gt 8000 ]; then
    echo "Reusing cached asset: $dest"
    return
  fi
  echo "Downloading $src"
  curl -fL --retry 3 --connect-timeout 20 "$base/$src" -o "$tmp"
  test "$(wc -c < "$tmp")" -gt 8000 || { echo "Invalid asset: $src"; rm -f "$tmp"; exit 1; }
  mv -f "$tmp" "$dest"
}
# Optional higher-detail real-scale CC0 vehicle models from Innerscene.
# Failure is non-fatal: verified Kenney CC0 cars are the offline fallback.
fetch_real_car_optional() {
  local src="$1" dest="$2" tmp
  tmp="${dest}.real.part"
  if [ -s "$dest" ] && [ "$(wc -c < "$dest")" -gt 8000 ]; then
    return
  fi
  echo "Trying realistic CC0 car: $dest"
  if curl -fL --retry 2 --connect-timeout 15 --max-time 45 "$src" -o "$tmp" \
      && [ "$(wc -c < "$tmp")" -gt 300000 ] \
      && [ "$(head -c 4 "$tmp")" = "glTF" ]; then
    mv -f "$tmp" "$dest"
    echo "Realistic GLB installed: $dest"
  else
    rm -f "$tmp"
    echo "Realistic GLB unavailable; using Kenney fallback instead."
  fi
}
fetch_real_car_optional "https://www.innerscene.com/api/library/sedan-car-42109739/download" "assets/vehicles/sedan_city.glb"
fetch_real_car_optional "https://www.innerscene.com/api/library/suv-dc972cab/download" "assets/vehicles/suv_city.glb"
# Kenney Car Kit is CC0. sedan-sports is a closed-body street car with wheels.
echo "Downloading CC0 Kenney Sedan Sports (city street-car model)"
fetch_glb "car-kit/sedan-sports.glb" "assets/vehicles/sedan_sports.glb"
fetch_glb "car-kit/sedan.glb" "assets/vehicles/sedan_city.glb"
fetch_glb "car-kit/suv.glb" "assets/vehicles/suv_city.glb"
fetch_glb "nature-kit/tree-detailed.glb" "assets/nature/tree_detailed.glb"
fetch_glb "nature-kit/tree-oak.glb" "assets/nature/tree_oak.glb"
echo "Importing actual car and tree meshes..."
godot --headless --editor --path . --import
echo "Testing Manhattan scene + checkpoint gameplay..."
godot --headless --path . --script res://tools/test_city.gd
echo "Testing selected Scenic Water Garden route..."
godot --headless --path . --script res://tools/test_scenic.gd
echo "Building Android..."
godot --headless --path . --export-debug "Android" build/SHIFTWORLD-DEV.apk
test -s build/SHIFTWORLD-DEV.apk
cp -f build/SHIFTWORLD-DEV.apk /storage/emulated/0/Download/SHIFTWORLD-DEV.apk
echo "SUCCESS: Downloads/SHIFTWORLD-DEV.apk"
