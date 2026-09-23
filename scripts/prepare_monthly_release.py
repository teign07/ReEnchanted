#!/usr/bin/env python3
"""Prepare an offline monthly shelf for the existing Ed25519 signer. No uploads."""
import argparse
import copy
import csv
from datetime import datetime
import hashlib
import json
from pathlib import Path
import re
import shutil
import tempfile
from urllib.parse import urlsplit

from monthly_pack import check, inventory

SUFFIXES = {
    'worldEventPack': '.reenchantedevents.json',
    'pageArchetypePack': '.reenchantedpack.json',
    'storyFormPack': '.storyforms.json',
    'storyConsequencePack': '.storyconsequences.json',
    'radioStationPack': '.reenchantedradio.json',
    'sentenceBuilderPack': '.sentencepack.json',
    'casebook': '.reenchantedcasebook.json',
    'media': '',
}


def require(condition, message):
    if not condition:
        raise ValueError(message)


def date(value):
    parsed = datetime.fromisoformat(value.replace('Z', '+00:00'))
    require(parsed.tzinfo is not None, 'Dates must include a timezone')
    return parsed


def identity(value):
    # Media references in native packs use dotted namespaces. Each dot must
    # separate nonempty safe segments, so an ID can never be '.' or '..'.
    return (isinstance(value, str) and len(value) <= 160
            and re.fullmatch(r'[A-Za-z0-9_-]+(?:\.[A-Za-z0-9_-]+)*', value))


def prepare(template, source_root, output, origin, previous=None):
    """Stage exact bytes, then publish the directory atomically after validation.

    Sources are SOURCE_ROOT/ISSUE_ID/fileName. Previous is the last published
    decoded manifest, not a newly edited template. None means the first release.
    """
    url = urlsplit(origin)
    require(url.scheme == 'https' and url.hostname and not url.username and not url.password
            and url.path in ('', '/') and not url.query and not url.fragment,
            'Origin must be an HTTPS origin without credentials, path, query, or fragment')
    require(url.port in (None, 443), 'Use the Worker HTTPS origin on port 443')
    origin = 'https://' + url.hostname.lower()
    manifest = copy.deepcopy(template)
    require(manifest.get('schemaVersion') in (1, 2) and isinstance(manifest.get('issues'), list),
            'Expected delivery manifest schemaVersion 1 or 2 and issues array')
    date(manifest['generatedAt'])
    manifest['allowedAssetHosts'] = [url.hostname.lower()]
    old_assets = {}
    if previous is not None:
        require(previous.get('schemaVersion') in (1, 2) and isinstance(previous.get('issues'), list),
                'Previous must be the decoded published manifest')
        for issue in previous['issues']:
            for asset in issue['assets']:
                require(asset['id'] not in old_assets, 'Duplicate previous asset ID')
                old_assets[asset['id']] = asset

    source_root, output = Path(source_root).resolve(), Path(output).absolute()
    require(not output.exists() and not output.is_symlink(), 'Refusing to overwrite release directory')
    require(output.parent.is_dir(), 'Output parent must already exist')
    issue_ids, asset_ids, intervals, files = set(), set(), [], []
    for issue in manifest['issues']:
        issue_id = issue['id']
        require(identity(issue_id) and issue_id not in issue_ids, 'Unsafe or duplicate issue ID')
        issue_ids.add(issue_id)
        require(issue.get('packID') and issue.get('title'), 'Missing issue packID or title')
        bounds = [date(issue[key]) for key in ('foreshadowStartsAt', 'liveStartsAt',
                  'liveEndsAt', 'residueEndsAt', 'casebookAvailableAt')]
        require(bounds == sorted(bounds) and bounds[1] < bounds[2], 'Invalid issue lifecycle dates')
        intervals.append((bounds[1], bounds[2]))
        destinations = set()
        for asset in issue['assets']:
            asset_id, filename = asset['id'], asset['fileName']
            require(identity(asset_id) and asset_id not in asset_ids, 'Unsafe or duplicate asset ID')
            asset_ids.add(asset_id)
            require(isinstance(filename, str) and re.fullmatch(r'[A-Za-z0-9_-][A-Za-z0-9._-]*', filename)
                    and filename not in destinations, 'Unsafe or duplicate destination filename')
            destinations.add(filename)
            kind, scope = asset['kind'], asset['scope']
            require(kind in SUFFIXES and filename.endswith(SUFFIXES[kind]), 'Unknown kind or wrong file suffix')
            require(scope in ('runtime', 'casebook') and (kind != 'casebook' or scope == 'casebook'),
                    'Invalid asset scope')
            require(type(asset.get('isRequired')) is bool, 'Asset isRequired must be explicit')
            if asset.get('retiresAt') is not None:
                require(scope == 'runtime' and bounds[0] < date(asset['retiresAt']) <= bounds[3],
                        'Invalid asset retirement date')
            source = (source_root / issue_id / filename).resolve()
            require(source.is_relative_to(source_root) and source.is_file(),
                    f'Missing asset or source outside asset root: {issue_id}/{filename}')
            files.append((issue, asset, source))
    intervals.sort()
    require(all(a[1] <= b[0] for a, b in zip(intervals, intervals[1:])), 'Live issue intervals overlap')

    stage = Path(tempfile.mkdtemp(prefix='.monthly-release-', dir=output.parent))
    rows, upload, reuse = [], [], []
    try:
        (stage / 'assets').mkdir()
        for issue, asset, source in files:
            destination = stage / 'assets' / asset['id']
            limit = (2 if asset['scope'] == 'casebook' else 180) * 1024 * 1024
            digest, size = hashlib.sha256(), 0
            with source.open('rb') as incoming, destination.open('xb') as outgoing:
                while chunk := incoming.read(1024 * 1024):
                    size += len(chunk)
                    require(size <= limit, f'Asset exceeds size ceiling: {asset["id"]}')
                    digest.update(chunk)
                    outgoing.write(chunk)
            require(size > 0, f'Empty asset: {asset["id"]}')
            asset.update(sha256=digest.hexdigest(), byteCount=size,
                         remoteURL=f'{origin}/monthly-issues/assets/{asset["id"]}')
            old = old_assets.get(asset['id'])
            if old:
                require(old['sha256'] == asset['sha256'] and old['byteCount'] == size,
                        f'Changed bytes reuse immutable asset ID {asset["id"]}; assign a new asset ID')
            (reuse if old else upload).append(dict(key=f'assets/{asset["id"]}', byteCount=size,
                                                  sha256=asset['sha256']))
            if asset['kind'] != 'media':
                text = destination.read_text(encoding='utf-8')
                pack = json.loads(text)
                refs = re.findall(r'\{\{asset-path:([^}]+)\}\}', text)
                # Every dependency must travel in the same issue and scope.
                siblings = {a['id']: a for a in issue['assets'] if a['scope'] == asset['scope']}
                require(set(refs) <= siblings.keys(), f'Missing or cross-issue asset references in {asset["id"]}')
                require('{{asset-path:' not in re.sub(r'\{\{asset-path:([^}]+)\}\}', '', text),
                        f'Malformed asset reference in {asset["id"]}')
                if asset['scope'] == 'runtime':
                    closes = date(asset.get('retiresAt') or issue['residueEndsAt'])
                    require(all(date(siblings[ref].get('retiresAt') or issue['residueEndsAt']) >= closes
                                for ref in refs), f'Referenced media retires before its pack: {asset["id"]}')
                if asset['kind'] == 'worldEventPack':
                    require(pack.get('id') == issue['packID'], 'World-event packID does not match issue')
                    errors = check(pack, release=True)
                    require(not errors, '\n'.join(errors))
                    require(pack.get('minimumRuntimeVersion', 1) < 2 or pack.get('authoringManifests'),
                            'Runtime 2 needs an authoring manifest')
                    rows.extend(inventory(pack))
        payload = (json.dumps(manifest, indent=2, ensure_ascii=False) + '\n').encode('utf-8')
        # Leave room for base64, signature, and envelope formatting under 2 MiB.
        require(len(payload) * 4 // 3 + 2048 <= 2 * 1024 * 1024, 'Manifest exceeds signed envelope ceiling')
        (stage / 'manifest.json').write_bytes(payload)
        report = dict(upload=upload, reuse=reuse,
                      noLongerListed=sorted(f'assets/{key}' for key in old_assets.keys() - asset_ids),
                      uploadBytes=sum(a['byteCount'] for a in upload),
                      reusedBytes=sum(a['byteCount'] for a in reuse))
        (stage / 'release-report.json').write_text(json.dumps(report, indent=2) + '\n')
        if rows:
            with (stage / 'production.csv').open('w', newline='') as out:
                writer = csv.DictWriter(out, fieldnames=rows[0].keys())
                writer.writeheader()
                writer.writerows(rows)
        require(not output.exists() and not output.is_symlink(), 'Release directory appeared during preparation')
        stage.rename(output)
        return report
    except BaseException:
        shutil.rmtree(stage)
        raise


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('manifest', type=Path)
    parser.add_argument('--asset-root', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--origin', required=True)
    history = parser.add_mutually_exclusive_group(required=True)
    history.add_argument('--previous', type=Path, help='Last published decoded manifest.json')
    history.add_argument('--first-release', action='store_true')
    args = parser.parse_args()
    try:
        report = prepare(json.loads(args.manifest.read_text()), args.asset_root, args.output,
                         args.origin, json.loads(args.previous.read_text()) if args.previous else None)
    except (ValueError, OSError, KeyError, TypeError, AttributeError) as error:
        parser.exit(1, f'Monthly release refused: {error}\n')
    print(f'Prepared {len(report["upload"])} uploads ({report["uploadBytes"]} bytes); '
          f'{len(report["reuse"])} unchanged files. Nothing uploaded or deleted.')
    print('Run native validation and rehearsal, then sign manifest.json with the existing signer.')


if __name__ == '__main__':
    main()
