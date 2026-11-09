#!/usr/bin/env python3
"""Replace the en-US App Store screenshots with marketing/app-store-screenshots/out.

Clears each set first, then uploads out/phone (6.9" iPhone) and out/pad (13" iPad)
in filename order. Re-render with marketing/app-store-screenshots/render.sh first.
Only works while version 1.0 is editable (PREPARE_FOR_SUBMISSION etc.).
"""
import glob, hashlib, json, os, sys, time, urllib.request
sys.path.insert(0, os.path.dirname(__file__))
from asc import call

LOC = "b900a110-e904-4405-a526-f0748c323724"
ROOT = os.path.join(os.path.dirname(__file__), "..", "..", "marketing", "app-store-screenshots", "out")
SETS = {"APP_IPHONE_67": f"{ROOT}/phone", "APP_IPAD_PRO_3GEN_129": f"{ROOT}/pad"}


def ensure_set(display):
    st, s = call("GET", f"/v1/appStoreVersionLocalizations/{LOC}/appScreenshotSets")
    for d in s.get("data", []):
        if d["attributes"]["screenshotDisplayType"] == display:
            return d["id"]
    st, o = call("POST", "/v1/appScreenshotSets", {"data": {"type": "appScreenshotSets",
        "attributes": {"screenshotDisplayType": display},
        "relationships": {"appStoreVersionLocalization": {"data": {"type": "appStoreVersionLocalizations", "id": LOC}}}}})
    if st != 201:
        sys.exit(f"set {display}: {st} {json.dumps(o)[:400]}")
    return o["data"]["id"]


def upload(set_id, path):
    data = open(path, "rb").read()
    st, o = call("POST", "/v1/appScreenshots", {"data": {"type": "appScreenshots",
        "attributes": {"fileName": os.path.basename(path), "fileSize": len(data)},
        "relationships": {"appScreenshotSet": {"data": {"type": "appScreenshotSets", "id": set_id}}}}})
    if st != 201:
        return f"reserve {st} {json.dumps(o)[:300]}"
    shot = o["data"]
    for op in shot["attributes"]["uploadOperations"]:
        chunk = data[op["offset"]: op["offset"] + op["length"]]
        req = urllib.request.Request(op["url"], data=chunk, method=op["method"])
        for h in op.get("requestHeaders", []):
            req.add_header(h["name"], h["value"])
        urllib.request.urlopen(req).read()
    st, o = call("PATCH", f"/v1/appScreenshots/{shot['id']}", {"data": {"type": "appScreenshots", "id": shot["id"],
        "attributes": {"uploaded": True, "sourceFileChecksum": hashlib.md5(data).hexdigest()}}})
    return "ok" if st == 200 else f"commit {st} {json.dumps(o)[:300]}"


def clear(set_id):
    st, s = call("GET", f"/v1/appScreenshotSets/{set_id}/appScreenshots?limit=50")
    for d in s.get("data", []):
        call("DELETE", f"/v1/appScreenshots/{d['id']}")


if __name__ != "__main__":
    raise SystemExit
for display, folder in SETS.items():
    set_id = ensure_set(display)
    clear(set_id)
    for path in sorted(glob.glob(f"{folder}/*.png")):
        print(display, os.path.basename(path), upload(set_id, path), flush=True)

time.sleep(20)
for display in SETS:
    sid = ensure_set(display)
    st, s = call("GET", f"/v1/appScreenshotSets/{sid}/appScreenshots")
    print(display, [(d["attributes"]["fileName"], (d["attributes"].get("assetDeliveryState") or {}).get("state")) for d in s.get("data", [])])
