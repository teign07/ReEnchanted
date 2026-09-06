#!/usr/bin/env python3
"""Offline monthly pack preflight, migration audit, and production inventory.
Does not install, sign, publish, or invoke the Swift compiler.
"""
import argparse
import csv
import hashlib
import json
from pathlib import Path

RUNTIME_VERSION = 2
CHANNELS = {'storyScene': 'storyScenes', 'radioBanter': 'radioBanters',
            'bleedArticle': 'bleedArticles', 'marginalia': 'marginalia'}


def check(pack, release=False):
    errors = []
    if not pack.get('id'):
        errors.append('pack: missing id')
    if pack.get('minimumRuntimeVersion', 1) > RUNTIME_VERSION:
        errors.append('pack: unsupported minimumRuntimeVersion')
    events = {x['id']: x for x in pack.get('events', [])}
    if release and not events:
        errors.append('pack: no events')
    natives = {}
    for kind, array in CHANNELS.items():
        items = pack.get(array, [])
        natives[kind] = {x['id']: x for x in items}
        if len(natives[kind]) != len(items):
            errors.append(f'{array}: duplicate native ids')
    for manifest in pack.get('authoringManifests', []):
        atoms = manifest.get('content', [])
        by_id = {x['id']: x for x in atoms}
        if len(by_id) != len(atoms):
            errors.append(f'{manifest["id"]}: duplicate content ids')
        if manifest.get('eventPackID') != pack['id'] or manifest.get('eventID') not in events:
            errors.append(f'{manifest["id"]}: missing or mismatched event')
        requirements = manifest.get('coverageRequirements', [])
        if not requirements:
            errors.append(f'{manifest["id"]}: missing production-count coverage requirements')
        coverage_ids = set()
        for requirement in requirements:
            identity = requirement.get('id', '').strip()
            minimum, maximum = requirement.get('minimumReady'), requirement.get('maximumReady')
            if not identity or identity in coverage_ids:
                errors.append(f'{manifest["id"]}: empty or duplicate coverage id')
            coverage_ids.add(identity)
            if (not requirement.get('label', '').strip() or type(minimum) is not int or minimum < 0
                    or (maximum is not None and (type(maximum) is not int or maximum < minimum))):
                errors.append(f'{identity}: invalid coverage counts or label')
                continue
            def matches(atom):
                placement = atom.get('placement', {})
                return (atom.get('productionStatus') in ('ready', 'reuse')
                    and all(requirement.get(key) is None or requirement[key] == value for key, value in (
                        ('channel', atom.get('channel')), ('lifecycleStage', placement.get('lifecycleStage')),
                        ('phaseRole', placement.get('phaseRole'))))
                    and all(not requirement.get(key) or value in requirement[key] for key, value in (
                        ('priorities', atom.get('priority')), ('interactions', atom.get('interaction'))))
                    and {tag.strip().lower() for tag in requirement.get('tagsAll', [])}
                        <= {tag.strip().lower() for tag in atom.get('tags', [])})
            count = sum(matches(atom) for atom in atoms)
            if release and (count < minimum or (maximum is not None and count > maximum)):
                errors.append(f'{identity}: {count} ready, outside declared coverage {minimum}..{maximum}')
        allowed_dependencies = set(by_id) | set(manifest.get('externalContentIDs', []))
        for atom in atoms:
            name = atom['id']
            if name == 'issue-conclusion':
                errors.append('issue-conclusion: reserved runtime receipt id')
            if release and atom.get('isRequired', True) and atom.get('productionStatus') not in ('ready', 'reuse'):
                errors.append(f'{name}: required content is not ready')
            for dependency in atom.get('dependencies', []):
                if dependency['contentID'] not in allowed_dependencies:
                    errors.append(f'{name}: unknown dependency {dependency["contentID"]}')
            ref = atom['reference']
            if ref['kind'] in natives and ref['id'] not in natives[ref['kind']]:
                errors.append(f'{name}: missing native {ref["id"]}')
            if atom.get('missionReturn'):
                if atom.get('interaction') != 'fieldMission' or atom.get('occurrence', {}).get('kind') != 'untilResolved':
                    errors.append(f'{name}: mission return requires fieldMission/untilResolved')
                if atom['missionReturn']['placement']['lifecycleStage'] != 'live':
                    errors.append(f'{name}: mission return must close during live play')
            scene = natives['storyScene'].get(ref['id']) if ref['kind'] == 'storyScene' else None
            if scene and scene.get('nodes') is not None:
                if pack.get('minimumRuntimeVersion', 1) < 2 or atom.get('occurrence', {}).get('kind') != 'untilResolved':
                    errors.append(f'{name}: node scenes require runtime 2/untilResolved')
                nodes = scene['nodes']
                if not isinstance(nodes, list) or any(not isinstance(n, dict) or not n.get('id') for n in nodes):
                    errors.append(f'{name}: nodes must be objects with nonempty ids')
                    continue
                index = {n['id']: n for n in nodes}
                if not nodes or len(index) != len(nodes):
                    errors.append(f'{name}: empty or duplicate nodes')
                edges = {}
                for node in nodes:
                    choices = node.get('choices', [])
                    if len({c['id'] for c in choices}) != len(choices):
                        errors.append(f'{name}/{node["id"]}: duplicate choices')
                    if not node.get('body', '').strip():
                        errors.append(f'{name}/{node["id"]}: empty body')
                    edges[node['id']] = [x for x in [node.get('nextNodeID')] + [c.get('nextNodeID') for c in choices] if x]
                    for target in edges[node['id']]:
                        if target not in index:
                            errors.append(f'{name}/{node["id"]}: missing target {target}')
                visited, active = set(), set()
                def walk(node_id):
                    if node_id in active:
                        errors.append(f'{name}: node cycle at {node_id}')
                        return
                    if node_id in visited:
                        return
                    visited.add(node_id)
                    active.add(node_id)
                    for child in edges.get(node_id, []):
                        walk(child)
                    active.remove(node_id)
                if nodes:
                    walk(nodes[0]['id'])
                for missing in set(index) - visited:
                    errors.append(f'{name}: unreachable node {missing}')
        edges = {a['id']: [d['contentID'] for d in a.get('dependencies', []) if d['contentID'] in by_id] for a in atoms}
        visited, active = set(), set()
        def visit(atom_id):
            if atom_id in active:
                errors.append(f'{manifest["id"]}: dependency cycle at {atom_id}')
                return
            if atom_id in visited:
                return
            visited.add(atom_id)
            active.add(atom_id)
            for dep in edges.get(atom_id, []):
                visit(dep)
            active.remove(atom_id)
        for atom_id in edges:
            visit(atom_id)
    if release and not pack.get('authoringManifests'):
        errors.append('pack: monthly release requires authoringManifests')
    return errors


def migration(old, new):
    """Removed IDs can strand durable receipts, so publication must review them."""
    warnings = []
    if old['id'] != new['id']:
        warnings.append('pack identity changed; this is a new pack, not an update')
    if new.get('version', 0) <= old.get('version', 0):
        warnings.append('pack version must increase')
    def ids(pack):
        result = set()
        for manifest in pack.get('authoringManifests', []):
            result.add('issue:' + manifest['id'])
            for atom in manifest.get('content', []):
                result.add('content:' + atom['id'])
        for scene in pack.get('storyScenes', []):
            for node in scene.get('nodes') or []:
                result.add(f'node:{scene["id"]}/{node["id"]}')
                for choice in node.get('choices', []):
                    result.add(f'choice:{scene["id"]}/{node["id"]}/{choice["id"]}')
        return result
    warnings += [f'removed durable identity: {x}' for x in sorted(ids(old) - ids(new))]
    def routes(pack):
        result = {}
        for scene in pack.get('storyScenes', []):
            for node in scene.get('nodes') or []:
                key = f'{scene["id"]}/{node["id"]}'
                result[key] = (node.get('nextNodeID'), node.get('jumpAction'))
                for choice in node.get('choices', []):
                    result[key + '/' + choice['id']] = (
                        choice.get('nextNodeID', node.get('nextNodeID')),
                        choice.get('jumpAction', node.get('jumpAction')))
        return result
    old_routes, new_routes = routes(old), routes(new)
    warnings += [f'changed committed route: {key}' for key in sorted(old_routes.keys() & new_routes.keys())
                 if old_routes[key] != new_routes[key]]
    return warnings


def inventory(pack):
    rows = []
    for manifest in pack.get('authoringManifests', []):
        for atom in manifest['content']:
            payloads = pack.get(CHANNELS.get(atom['reference']['kind'], ''), [])
            native = next((x for x in payloads if x['id'] == atom['reference']['id']), {})
            rows.append(dict(issue=manifest['id'], content=atom['id'], channel=atom['channel'],
                lifecycle=atom['placement']['lifecycleStage'], phase=atom['placement'].get('phaseID', ''),
                status=atom.get('productionStatus', 'planned'), station=native.get('stationID', ''),
                asset=native.get('banter', {}).get('assetName', native.get('assetID', '')),
                transcript=native.get('banter', {}).get('caption', ''),
                occurrence=json.dumps(atom.get('occurrence', {}), sort_keys=True),
                mission_return=json.dumps(atom.get('missionReturn'), sort_keys=True),
                concludes_run=atom.get('concludesRun', False),
                gates=json.dumps(atom.get('gate', {}), sort_keys=True),
                dependencies=json.dumps(atom.get('dependencies', []), sort_keys=True)))
    return rows


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='command', required=True)
    validate = sub.add_parser('check')
    validate.add_argument('pack', type=Path)
    validate.add_argument('--release', action='store_true')
    diff = sub.add_parser('migration')
    diff.add_argument('old', type=Path)
    diff.add_argument('new', type=Path)
    export = sub.add_parser('inventory')
    export.add_argument('pack', type=Path)
    export.add_argument('--output', type=Path, required=True)
    digest = sub.add_parser('asset')
    digest.add_argument('file', type=Path)
    args = parser.parse_args()
    if args.command == 'asset':
        data = args.file.read_bytes()
        print(json.dumps(dict(fileName=args.file.name, sha256=hashlib.sha256(data).hexdigest(), byteCount=len(data)), indent=2))
        return
    if args.command == 'migration':
        errors = migration(json.loads(args.old.read_text()), json.loads(args.new.read_text()))
    else:
        pack = json.loads(args.pack.read_text())
        errors = check(pack, getattr(args, 'release', False))
        if args.command == 'inventory' and not errors:
            rows = inventory(pack)
            if not rows:
                raise SystemExit('No content atoms to export')
            with args.output.open('w', newline='') as out:
                writer = csv.DictWriter(out, fieldnames=rows[0].keys())
                writer.writeheader()
                writer.writerows(rows)
            print(f'Wrote {len(rows)} content rows to {args.output}')
            return
    for error in errors:
        print(error)
    if errors:
        raise SystemExit(1)
    print('Preflight passed. Native Swift release validation and app QA are still required.')


if __name__ == '__main__':
    main()
