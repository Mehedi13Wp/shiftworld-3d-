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
# CC0 Kenney assets; sedan-sports has a closed road-car body, unlike open-wheel race.glb.
echo "Downloading detailed CC0 Spectral GT RS sports car (not Kenney low-poly)"
curl -fL --retry 3 --connect-timeout 25 "https://raw.githubusercontent.com/JaronKBragg7337/spectral-gt-rs/main/spectral_gt_rs_game_ready.glb" -o "assets/vehicles/red_supercar.glb.part"
test "$(wc -c < assets/vehicles/red_supercar.glb.part)" -gt 500000 || { echo "Detailed car asset missing or invalid"; exit 1; }
mv -f assets/vehicles/red_supercar.glb.part assets/vehicles/red_supercar.glb
fetch_glb "nature-kit/tree-detailed.glb" "assets/nature/tree_detailed.glb"
fetch_glb "nature-kit/tree-oak.glb" "assets/nature/tree_oak.glb"
echo "Importing actual car and tree meshes..."
godot --headless --editor --path . --import
echo "Building Android..."
godot --headless --path . --export-debug "Android" build/SHIFTWORLD-DEV.apk
test -s build/SHIFTWORLD-DEV.apk
cp -f build/SHIFTWORLD-DEV.apk /storage/emulated/0/Download/SHIFTWORLD-DEV.apk
echo "SUCCESS: Downloads/SHIFTWORLD-DEV.apk"
