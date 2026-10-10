#!/usr/bin/env python3
"""Run the already-built app's isolated sample export. Never builds the app."""
import argparse
import json
import shutil
import subprocess
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BUNDLE = 'com.openclaw.enchantify.insidecover'

def sim(*args):
    return subprocess.check_output(['xcrun', 'simctl', *args], text=True).strip()

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--device', required=True, help='Booted QA simulator UUID')
    parser.add_argument('--app', type=Path, help='Optional already-built app to install')
    parser.add_argument('--input', type=Path, default=ROOT / 'output/sample-editions/input')
    parser.add_argument('--output', type=Path, default=ROOT / 'output/pdf/public-samples')
    args = parser.parse_args()
    if args.app:
        sim('install', args.device, str(args.app))
    documents = Path(sim('get_app_container', args.device, BUNDLE, 'data')) / 'Documents'
    target = documents / 'edition-proof-input'
    shutil.copytree(args.input, target, dirs_exist_ok=True)
    proof = documents / 'public-sample-editions'
    status = proof / 'status.txt'
    if status.exists():
        status.unlink()
    print(sim('launch', '--terminate-running-process', args.device, BUNDLE, '--public-sample-editions'), flush=True)
    end = time.monotonic() + 240
    last = ''
    while time.monotonic() < end:
        if status.exists():
            value = status.read_text()
            if value != last:
                print(value, flush=True); last = value
            if value.startswith('FAILED'):
                raise SystemExit(value)
            if value.startswith('OK public samples:'):
                args.output.mkdir(parents=True, exist_ok=True)
                for item in proof.iterdir():
                    if item.suffix in ['.pdf', '.png', '.json', '.txt']:
                        shutil.copy2(item, args.output / item.name)
                print(json.dumps({'proofDirectory': str(args.output)}, indent=2), flush=True)
                return
        time.sleep(1)
    raise SystemExit('Sample export timed out: ' + last)

if __name__ == '__main__':
    main()
