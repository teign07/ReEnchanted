#!/usr/bin/env python3
"""One-screen App Store Connect status: version, builds, TestFlight, screenshots."""
import os, sys
sys.path.insert(0, os.path.dirname(__file__))
from asc import call, APP_ID

st, v = call("GET", f"/v1/apps/{APP_ID}/appStoreVersions?include=build"
                    "&fields[appStoreVersions]=versionString,appStoreState,build")
for d in v.get("data", []):
    a = d["attributes"]
    build = (d.get("relationships", {}).get("build", {}) or {}).get("data")
    print(f"version {a['versionString']} {a['appStoreState']}  id {d['id']}  build attached: {build['id'] if build else 'none'}")
    st, locs = call("GET", f"/v1/appStoreVersions/{d['id']}/appStoreVersionLocalizations")
    for loc in locs.get("data", []):
        st, sets = call("GET", f"/v1/appStoreVersionLocalizations/{loc['id']}/appScreenshotSets")
        for s in sets.get("data", []):
            st, shots = call("GET", f"/v1/appScreenshotSets/{s['id']}/appScreenshots")
            states = {(x["attributes"].get("assetDeliveryState") or {}).get("state") for x in shots.get("data", [])}
            print(f"  {loc['attributes']['locale']} {s['attributes']['screenshotDisplayType']}: {len(shots.get('data', []))} {sorted(states)}")

st, b = call("GET", f"/v1/builds?filter[app]={APP_ID}&sort=-uploadedDate&limit=5"
                    "&fields[builds]=version,processingState,uploadedDate,expirationDate")
for d in b.get("data", []):
    a = d["attributes"]
    print(f"build {a['version']:>3} {a['processingState']:<10} uploaded {a['uploadedDate'][:10]}  expires {a['expirationDate'][:10]}  id {d['id']}")

st, g = call("GET", f"/v1/apps/{APP_ID}/betaGroups?fields[betaGroups]=name,isInternalGroup")
for d in g.get("data", []):
    print(f"beta group {d['attributes']['name']} internal={d['attributes']['isInternalGroup']}  id {d['id']}")
