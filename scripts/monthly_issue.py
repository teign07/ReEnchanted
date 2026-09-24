#!/usr/bin/env python3
"""One tool for a monthly issue, from an empty folder to a signed candidate.

    new SLUG --title T --year Y --month M   scaffold ContentPacks/SLUG from the
                                            validated rehearsal pack
    stage ISSUE_DIR... --output DIR         shelf template + exact sources
    rehearse ISSUE_DIR... [--previous M]    stage, prepare, sign with a throwaway
                                            key, and serve it through the real
                                            Worker code at every window edge
    release ISSUE_DIR... [--previous M]     the same with the publisher key, into
                                            ~/.reenchanted-publishing/releases

Each issue folder carries an issue.json (see ContentPacks/count-unbound). The
delivery windows are read from the pack's own event calendar, never typed in,
so the manifest and the app can't disagree about when an issue is live. The
shelf is every issue passed, in order: a November release names October too,
so its residue and casebook keep being served.

Nothing here uploads. Publish a candidate with scripts/publish_monthly_release.sh.
"""

import argparse
import calendar as months
from datetime import datetime, timedelta, timezone
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile

sys.path.insert(0, str(Path(__file__).parent))
from monthly_pack import RUNTIME_VERSION, check  # noqa: E402
from prepare_monthly_release import prepare  # noqa: E402

REPO = Path(__file__).resolve().parents[1]
CONTENT = REPO / 'ContentPacks'
TEMPLATE = REPO / 'docs/fixtures/monthly-rehearsal/school-door.reenchantedevents.json'
PUBLISHING = Path.home() / '.reenchanted-publishing'
ORIGIN = 'https://reenchanted-physical-books.snow-potions.workers.dev'
KEY_ID = 'reenchanted-publisher-2026-09'
REFERENCE = re.compile(r'\{\{asset-path:([^}]+)\}\}')


class IssueError(ValueError):
    pass


def iso(moment):
    return moment.astimezone(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')


def parse(value):
    return datetime.fromisoformat(value.replace('Z', '+00:00'))


class Issue:
    """An issue folder and its issue.json, resolved."""

    def __init__(self, directory):
        self.directory = Path(directory).resolve()
        path = self.directory / 'issue.json'
        if not path.is_file():
            raise IssueError(f'{self.directory.name}: missing issue.json')
        self.config = json.loads(path.read_text())
        self.issue_id = self.config['issueID']
        self.audio = self.config.get('audio', {}).get('files', {})
        self.audio_directory = self.directory / self.config.get('audio', {}).get('directory', 'audio')

    def file(self, kind):
        return next((entry for entry in self.config['files'] if entry['kind'] == kind), None)

    def json(self, entry):
        return json.loads((self.directory / entry['source']).read_text())

    @property
    def pack(self):
        entry = self.file('worldEventPack')
        if entry is None:
            raise IssueError(f'{self.issue_id}: issue.json names no worldEventPack')
        return self.json(entry)

    def windows(self):
        """Lifecycle edges from the pack's event calendar: the same numbers
        the app uses to decide what is live."""
        events = self.pack.get('events') or []
        if len(events) != 1:
            raise IssueError(f'{self.issue_id}: expected exactly one event, found {len(events)}')
        cal = events[0]['calendar']
        start = datetime(cal['startYear'], cal['startMonth'], cal['startDay'], tzinfo=timezone.utc)
        live_end = start + timedelta(days=cal['durationDays'])
        residue_end = live_end + timedelta(days=cal.get('residueDays', 0))
        casebook = residue_end + timedelta(days=cal.get('casebookDelayDays', 0))
        casebook_entry = self.file('casebook')
        if casebook_entry is not None:
            published = parse(self.json(casebook_entry)['publishedAt'])
            # The casebook's own date wins, but it must fall on the day the
            # calendar says, or the app and the shelf disagree about it.
            if not casebook <= published < casebook + timedelta(days=1):
                raise IssueError(f'{self.issue_id}: casebook publishedAt {iso(published)} is not '
                                 f'on the calendar day {iso(casebook)[:10]}')
            casebook = published
        return {
            'foreshadowStartsAt': iso(start - timedelta(days=cal.get('foreshadowDays', 0))),
            'liveStartsAt': iso(start),
            'liveEndsAt': iso(live_end),
            'residueEndsAt': iso(residue_end),
            'casebookAvailableAt': iso(casebook),
        }

    def references(self):
        return set(self.reference_scopes())

    def reference_scopes(self):
        refs = {}
        for entry in self.config['files']:
            scope = entry.get('scope', 'runtime')
            for asset_id in REFERENCE.findall((self.directory / entry['source']).read_text()):
                if asset_id in refs and refs[asset_id] != scope:
                    raise IssueError(f'{self.issue_id}: media {asset_id} referenced across scopes')
                refs[asset_id] = scope
        return refs

    def media_source(self, asset_id, audio_directory=None):
        if asset_id in self.audio:
            return Path(audio_directory or self.audio_directory) / self.audio[asset_id], '.mp3'
        for rule in self.config.get('media', []):
            if asset_id.startswith(rule['prefix']):
                name = asset_id.removeprefix(rule['prefix']) + rule['suffix']
                return self.directory / rule['directory'] / name, rule['suffix']
        raise IssueError(f'{self.issue_id}: unmapped media ID {asset_id}')

    def validate(self):
        pack = self.pack
        errors = check(pack)
        if errors:
            raise IssueError(f'{self.issue_id}: ' + '; '.join(errors))
        casebook_entry = self.file('casebook')
        if casebook_entry is not None:
            casebook = self.json(casebook_entry)
            if casebook.get('packID') != pack['id'] or casebook.get('runID') != self.config.get('runID'):
                raise IssueError(f'{self.issue_id}: casebook does not match the pack and run')
        audio_refs = {ref for ref in self.references() if ref in self.audio}
        if audio_refs != set(self.audio):
            raise IssueError(f'{self.issue_id}: Radio media references differ from the recording sheet')

    def stage_into(self, sources, allow_missing_audio=False, audio_directory=None):
        """Copy exact sources into sources/<issueID>/ and return the issue's
        manifest entry and the recordings still missing."""
        self.validate()
        target = Path(sources) / self.issue_id
        target.mkdir(parents=True)
        assets, missing = [], []

        def add(asset_id, kind, scope, source, file_name):
            if source.is_file():
                shutil.copyfile(source, target / file_name)
            elif asset_id in self.audio:
                # Collected, then refused together unless drafting allows it.
                missing.append(asset_id)
            else:
                raise IssueError(f'Missing source for {asset_id}: {source}')
            assets.append(dict(id=asset_id, kind=kind, scope=scope, fileName=file_name, isRequired=True))

        packs = [entry for entry in self.config['files'] if entry['kind'] != 'casebook']
        for entry in packs:
            add(entry['id'], entry['kind'], entry.get('scope', 'runtime'),
                self.directory / entry['source'], entry['fileName'])
        for asset_id, scope in sorted(self.reference_scopes().items()):
            source, suffix = self.media_source(asset_id, audio_directory)
            add(asset_id, 'media', scope, source, asset_id + suffix)
        casebook = self.file('casebook')
        if casebook is not None:
            add(casebook['id'], 'casebook', 'casebook', self.directory / casebook['source'], casebook['fileName'])
        if missing and not allow_missing_audio:
            raise IssueError('Missing recordings: ' + ', '.join(missing))
        entry = {'id': self.issue_id, 'packID': self.pack['id'], 'title': self.config['title']}
        entry.update(self.windows())
        entry['assets'] = assets
        return entry, missing


def stage(issue_dirs, output, generated_at, allow_missing_audio=False, audio_directories=None):
    """Write <output>/delivery-template.json, sources/ and
    missing-recordings.json for a shelf of one or more issues. Atomic."""
    output = Path(output).absolute()
    if output.exists() or output.is_symlink():
        raise IssueError(f'Refusing to overwrite {output}')
    if not output.parent.is_dir():
        raise IssueError(f'Missing output parent: {output.parent}')
    issues = [Issue(directory) for directory in issue_dirs]
    if len({issue.issue_id for issue in issues}) != len(issues):
        raise IssueError('An issue appears twice on the shelf')
    work = Path(tempfile.mkdtemp(prefix='.monthly-stage-', dir=output.parent))
    try:
        entries, missing = [], []
        for index, issue in enumerate(issues):
            audio = (audio_directories or [None] * len(issues))[index]
            entry, gaps = issue.stage_into(work / 'sources', allow_missing_audio, audio)
            entries.append(entry)
            missing += gaps
        entries.sort(key=lambda entry: entry['liveStartsAt'])
        template = {'schemaVersion': 2, 'generatedAt': generated_at, 'allowedAssetHosts': [], 'issues': entries}
        (work / 'delivery-template.json').write_text(json.dumps(template, ensure_ascii=False, indent=2) + '\n')
        (work / 'missing-recordings.json').write_text(json.dumps(missing, indent=2) + '\n')
        work.rename(output)
    except BaseException:
        shutil.rmtree(work, ignore_errors=True)
        raise
    return sum(len(entry['assets']) for entry in entries), missing


def swift_signer(*args):
    subprocess.run(['xcrun', 'swift', str(REPO / 'scripts/sign_monthly_issue_manifest.swift'), *map(str, args)],
                   check=True, stdout=subprocess.PIPE)


def build(issue_dirs, output, key, key_id, previous=None, origin=ORIGIN):
    """stage -> prepare -> sign, into `output` (a new directory)."""
    now = iso(datetime.now(timezone.utc))
    scratch = Path(tempfile.mkdtemp(prefix='monthly-build-'))
    try:
        staged = scratch / 'staged'
        count, _ = stage(issue_dirs, staged, now)
        template = json.loads((staged / 'delivery-template.json').read_text())
        prior = json.loads(Path(previous).read_text()) if previous else None
        report = prepare(template, staged / 'sources', output, origin, prior)
        swift_signer('sign', output / 'manifest.json', key, key_id, output / 'manifest.envelope.json')
        return count, report
    finally:
        shutil.rmtree(scratch, ignore_errors=True)


def rehearse(issue_dirs, previous=None):
    """The whole pipeline with a throwaway key, then the real Worker code
    serving it at every window edge. Proves structure, not taste."""
    scratch = Path(tempfile.mkdtemp(prefix='monthly-rehearsal-'))
    try:
        private, public = scratch / 'rehearsal.key', scratch / 'rehearsal.pub'
        swift_signer('generate-key', private, public)
        release = scratch / 'release'
        count, report = build(issue_dirs, release, private, 'rehearsal-only', previous)
        print(f'Prepared and signed {count} assets ({len(report["upload"])} new) with a throwaway key.')
        probe = REPO / 'docs/physical-book-backend/rehearse-release.mjs'
        subprocess.run(['node', str(probe), str(release), public.read_text().strip()], check=True)
    finally:
        shutil.rmtree(scratch, ignore_errors=True)


def release(issue_dirs, previous=None):
    key = PUBLISHING / 'monthly-issue-private.key'
    if not key.is_file():
        raise IssueError(f'No publisher key at {key}')
    names = '+'.join(Issue(directory).issue_id for directory in issue_dirs)
    output = PUBLISHING / 'releases' / f'{datetime.now(timezone.utc):%Y-%m-%d}-{names}-candidate'
    if output.exists():
        raise IssueError(f'{output} already exists; move it aside first')
    output.parent.mkdir(parents=True, exist_ok=True)
    count, report = build(issue_dirs, output, key, KEY_ID, previous)
    print(f'Signed candidate: {output}\n{count} assets, {len(report["upload"])} to upload, '
          f'{len(report["reuse"])} already published.\n'
          f'Dry run:  scripts/publish_monthly_release.sh "{output}"')


def new(slug, title, year, month, foreshadow_days=7, residue_days=7):
    """A new issue folder from the rehearsal pack, which the native suite
    validates. Its story content is example material to replace; every atom
    starts as draft so a release refuses it until each one is finished."""
    if not re.fullmatch(r'[a-z0-9]+(?:-[a-z0-9]+)*', slug):
        raise IssueError('Slug must be lowercase words joined by hyphens')
    directory = CONTENT / slug
    if directory.exists():
        raise IssueError(f'{directory} already exists')
    issue_id = f'{slug}-{year}-{month:02d}'
    text = TEMPLATE.read_text().replace('school-door', slug)
    pack = json.loads(text)
    pack['id'] = slug
    pack['displayName'] = title
    pack['version'] = 1
    pack['minimumRuntimeVersion'] = RUNTIME_VERSION
    days = months.monthrange(year, month)[1]
    live_end = datetime(year, month, 1, tzinfo=timezone.utc) + timedelta(days=days)
    residue_end = live_end + timedelta(days=residue_days)
    next_month = datetime(residue_end.year + residue_end.month // 12, residue_end.month % 12 + 1, 1, tzinfo=timezone.utc)
    event = pack['events'][0]
    event['id'] = slug
    event['title'] = title
    event['calendar'] = {
        'startMonth': month, 'startDay': 1, 'durationDays': days, 'recurrence': 'oneShot', 'startYear': year,
        'foreshadowDays': foreshadow_days, 'residueDays': residue_days,
        'casebookDelayDays': (next_month - residue_end).days,
    }
    for manifest in pack.get('authoringManifests', []):
        manifest.update(id=issue_id, publicationKind='monthly', title=title, eventPackID=slug, eventID=slug)
        for atom in manifest.get('content', []):
            atom['productionStatus'] = 'draft'
    directory.mkdir(parents=True)
    for folder in ('marginalia', 'audio'):
        (directory / folder).mkdir()
    (directory / f'{slug}.reenchantedevents.json').write_text(json.dumps(pack, ensure_ascii=False, indent=2) + '\n')
    (directory / 'issue.json').write_text(json.dumps({
        'issueID': issue_id, 'title': title, 'runID': f'{slug}:{year}',
        'files': [{'id': f'{slug}.runtime.v1', 'kind': 'worldEventPack',
                   'source': f'{slug}.reenchantedevents.json', 'fileName': f'{slug}.reenchantedevents.json'}],
        'media': [{'prefix': f'{slug}.mark.', 'directory': 'marginalia', 'suffix': '.png'}],
        'audio': {'directory': 'audio', 'files': {}},
    }, indent=2) + '\n')
    (directory / 'README.md').write_text(f"""# {title}

Issue `{issue_id}`, live {year}-{month:02d}-01 for {days} days. Scaffolded from the
rehearsal pack (`docs/fixtures/monthly-rehearsal`): the story content is example
material. Replace it, then mark each atom `ready` in the authoring manifest.

1. Write the issue: events, story scenes, Bleed articles, marginalia and radio in
   `{slug}.reenchantedevents.json`. Keep the event `calendar`; it defines the
   delivery windows.
2. Art goes in `marginalia/` as `<name>.png`, referenced as
   `{{{{asset-path:{slug}.mark.<name>}}}}`. Add more `media` rules to `issue.json`
   for other folders.
3. Radio: add each recording to `issue.json` `audio.files` and put the file in
   `audio/`.
4. Optional: a public casebook (`kind: casebook`) in `issue.json`, with a
   `publishedAt` on the calendar's casebook day.
5. `python3 scripts/monthly_issue.py rehearse ContentPacks/<every issue on the shelf>`
6. Swift: `swift test --filter MonthlyIssue`
7. `python3 scripts/monthly_issue.py release ... --previous <last published manifest.json>`
8. `scripts/publish_monthly_release.sh <candidate>` (dry run), then `--publish`.
""")
    return directory


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest='command', required=True)
    make = sub.add_parser('new')
    make.add_argument('slug')
    make.add_argument('--title', required=True)
    make.add_argument('--year', type=int, required=True)
    make.add_argument('--month', type=int, required=True)
    staging = sub.add_parser('stage')
    staging.add_argument('issues', nargs='+', type=Path)
    staging.add_argument('--output', type=Path, required=True)
    staging.add_argument('--allow-missing-audio', action='store_true')
    for name in ('rehearse', 'release'):
        command = sub.add_parser(name)
        command.add_argument('issues', nargs='+', type=Path)
        command.add_argument('--previous', type=Path, help='the last published manifest.json')
    args = parser.parse_args()
    try:
        if args.command == 'new':
            print(f'Scaffolded {new(args.slug, args.title, args.year, args.month)}')
        elif args.command == 'stage':
            count, missing = stage(args.issues, args.output, iso(datetime.now(timezone.utc)), args.allow_missing_audio)
            print(f'Staged {count} assets. Missing recordings: {len(missing)}. Nothing signed or uploaded.')
        elif args.command == 'rehearse':
            rehearse(args.issues, args.previous)
        else:
            release(args.issues, args.previous)
    except (IssueError, OSError, KeyError, subprocess.CalledProcessError) as error:
        parser.exit(1, f'monthly_issue {args.command} refused: {error}\n')


if __name__ == '__main__':
    main()
