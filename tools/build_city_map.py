#!/usr/bin/env python3
"""SHIFTWORLD 3D: free OpenStreetMap road/building extractor.
Usage: python tools/build_city_map.py manhattan
No API key, no paid service. OSM attribution and ODbL apply.
"""
import json, math, pathlib, sys, urllib.parse, urllib.request
CITIES = {
 "manhattan": {"name":"Manhattan, New York", "lat":40.7580,"lon":-73.9855,"radius_m":650},
 "athens": {"name":"Athens, Greece", "lat":37.9755,"lon":23.7348,"radius_m":650},
 "london": {"name":"London, UK", "lat":51.5074,"lon":-0.1278,"radius_m":650},
}
OUTPUT = pathlib.Path(__file__).resolve().parents[1] / "data" / "cities"
def make_map(key):
 c=CITIES[key]; lat,lon,r=c["lat"],c["lon"],c["radius_m"]
 dy=r/111320; dx=r/(111320*math.cos(math.radians(lat)))
 bbox=f"{lat-dy:.6f},{lon-dx:.6f},{lat+dy:.6f},{lon+dx:.6f}"
 query=f'[out:json][timeout:90];(way["highway"~"^(motorway|trunk|primary|secondary|tertiary|residential|living_street|service|unclassified)$"]({bbox});way["building"]({bbox}););out geom;'
 body=urllib.parse.urlencode({"data":query}).encode()
 headers={"User-Agent":"SHIFTWORLD3D-prototype/0.1 (OpenStreetMap ODbL)","Content-Type":"application/x-www-form-urlencoded"}
 raw=None
 for endpoint in ("https://overpass.kumi.systems/api/interpreter","https://overpass-api.de/api/interpreter"):
  try:
   req=urllib.request.Request(endpoint,data=body,headers=headers)
   with urllib.request.urlopen(req,timeout=120) as resp: raw=json.load(resp)
   break
  except (OSError,ValueError) as exc:
   print(f"Map endpoint unavailable: {endpoint}: {exc}",file=sys.stderr)
 if raw is None:raise RuntimeError("All map endpoints unavailable; retry later")
 roads=[]; buildings=[]
 for e in raw.get("elements",[]):
  if e.get("type")!="way" or len(e.get("geometry",[]))<2:continue
  tags=e.get("tags",{})
  points=[[round((p["lon"]-lon)*111320*math.cos(math.radians(lat)),2),round(-(p["lat"]-lat)*111320,2)] for p in e["geometry"]]
  if "highway" in tags:
   roads.append({"id":e["id"],"type":tags["highway"],"name":tags.get("name",""),"points":points})
  elif "building" in tags and len(points)>=4:
   levels=tags.get("building:levels","")
   try: height=float(tags.get("height","").replace(" m","")) if tags.get("height") else float(levels)*3.2 if levels else 11.0
   except ValueError:height=11.0
   buildings.append({"id":e["id"],"height":max(3,min(180,height)),"points":points})
 if not roads:raise RuntimeError("No roads returned; refusing to create empty map")
 OUTPUT.mkdir(parents=True,exist_ok=True)
 path=OUTPUT/(key+".json")
 path.write_text(json.dumps({"name":c["name"],"center":[lat,lon],"radius_m":r,"source":"© OpenStreetMap contributors (ODbL)","roads":roads,"buildings":buildings},separators=(",",":")),encoding="utf-8")
 print(f"{path}: {len(roads)} roads, {len(buildings)} buildings")
if __name__=="__main__":
 if len(sys.argv)!=2 or sys.argv[1] not in CITIES:
  raise SystemExit("Usage: python tools/build_city_map.py manhattan|athens|london")
 make_map(sys.argv[1])
