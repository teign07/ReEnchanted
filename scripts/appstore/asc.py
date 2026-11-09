#!/usr/bin/env python3
"""Tiny App Store Connect API client. Never prints the key.

Reads the key id and issuer from ~/.appstoreconnect/reenchanted.env (kept off
the public repo) and the private key from
~/.appstoreconnect/private_keys/AuthKey_<id>.p8. Needs `cryptography`.

    python3 scripts/appstore/asc.py GET /v1/apps/6832290089
    python3 scripts/appstore/asc.py PATCH /v1/... '{"data": {...}}'
"""
import base64, json, os, sys, time, urllib.request, urllib.error
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import ec, utils

ENV_PATH = os.path.expanduser("~/.appstoreconnect/reenchanted.env")


def _env():
    values = {}
    if os.path.exists(ENV_PATH):
        for line in open(ENV_PATH):
            if "=" in line and not line.lstrip().startswith("#"):
                key, value = line.strip().split("=", 1)
                values[key] = value
    for key in ("ASC_KEY_ID", "ASC_ISSUER_ID", "ASC_APP_ID"):
        if os.environ.get(key):
            values[key] = os.environ[key]
    return values


ENV = _env()
KEY_ID = ENV.get("ASC_KEY_ID", "")
ISSUER = ENV.get("ASC_ISSUER_ID", "")
APP_ID = ENV.get("ASC_APP_ID", "6832290089")
KEY_PATH = os.path.expanduser(f"~/.appstoreconnect/private_keys/AuthKey_{KEY_ID}.p8")
BASE = "https://api.appstoreconnect.apple.com"


def b64(b):
    return base64.urlsafe_b64encode(b).rstrip(b"=").decode()


def token():
    if not KEY_ID or not ISSUER:
        sys.exit(f"Missing ASC_KEY_ID / ASC_ISSUER_ID in {ENV_PATH}")
    key = serialization.load_pem_private_key(open(KEY_PATH, "rb").read(), None)
    now = int(time.time())
    head = b64(json.dumps({"alg": "ES256", "kid": KEY_ID, "typ": "JWT"}).encode())
    body = b64(json.dumps({"iss": ISSUER, "iat": now, "exp": now + 1000, "aud": "appstoreconnect-v1"}).encode())
    der = key.sign(f"{head}.{body}".encode(), ec.ECDSA(hashes.SHA256()))
    r, s = utils.decode_dss_signature(der)
    sig = b64(r.to_bytes(32, "big") + s.to_bytes(32, "big"))
    return f"{head}.{body}.{sig}"


def call(method, path, payload=None):
    data = json.dumps(payload).encode() if payload is not None else None
    req = urllib.request.Request(BASE + path, data=data, method=method)
    req.add_header("Authorization", "Bearer " + token())
    if data is not None:
        req.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(req) as r:
            raw = r.read()
            return r.status, (json.loads(raw) if raw else {})
    except urllib.error.HTTPError as e:
        raw = e.read()
        try:
            return e.code, json.loads(raw or b"{}")
        except ValueError:
            return e.code, {"raw": raw.decode(errors="replace")}


if __name__ == "__main__":
    method, path = sys.argv[1], sys.argv[2]
    payload = json.loads(sys.argv[3]) if len(sys.argv) > 3 else None
    status, out = call(method, path, payload)
    print(status)
    print(json.dumps(out, indent=1)[:6000])
