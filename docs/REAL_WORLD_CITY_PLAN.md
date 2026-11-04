# SHIFTWORLD 3D — $0 Real World City Plan

Keep existing Android highway game stable until the new city mode is independently tested.

## Data and rights
- Use OpenStreetMap road centerlines and building outlines, not Google Maps screenshots/tiles.
- Attribution: © OpenStreetMap contributors, data licensed under ODbL.
- City maps are generated offline and bundled with the game; no paid map API or runtime requests.
- Data geometry is approximate; building boxes are placeholders, not photorealistic representations.
- Avoid using public Overpass instances for mass downloads; cache extracts, respect limits, and use regional OSM extracts for larger releases.

## First playable milestone
1. Extract a 1.3 km wide Manhattan test area with tools/build_city_map.py.
2. Review OSM attribution, data size and completeness.
3. Load it into the separate scripts/city_world.gd renderer; test draw calls and FPS.
4. Add city selection, safe spawn location, intersection steering and camera follow.
5. Optimize mesh batching/chunk streaming, buildings and collisions.
6. Only after successful tests connect the city mode to the existing menu and produce one consolidated Android APK.

## Future
Athens and London supported by the same data extractor. Start with Manhattan only.
