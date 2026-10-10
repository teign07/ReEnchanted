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
    reissue ISSUE_DIR --year Y              fork a finished issue to run again
                                            next year, with new identity

Each issue folder carries an issue.json (see ContentPacks/count-unbound). The
delivery windows are read from the pack's own event calendar, never typed in,
so the manifest and the app can't disagree about when an issue is live. The
shelf is every issue passed, in order: a November release names October too,
so its residue keeps being served.

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
        return {
            'foreshadowStartsAt': iso(start - timedelta(days=cal.get('foreshadowDays', 0))),
            'liveStartsAt': iso(start),
            'liveEndsAt': iso(live_end),
            'residueEndsAt': iso(residue_end),
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
        # The Record binds into the month's edition, so a release without one
        # would print a month whose story has no account of itself.
        record = (pack['events'][0].get('record') or {}) if pack.get('events') else {}
        if not record.get('historySentence') or not record.get('entries'):
            raise IssueError(f'{self.issue_id}: the event has no record (historySentence and entries)')
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

        for entry in self.config['files']:
            add(entry['id'], entry['kind'], entry.get('scope', 'runtime'),
                self.directory / entry['source'], entry['fileName'])
        for asset_id, scope in sorted(self.reference_scopes().items()):
            source, suffix = self.media_source(asset_id, audio_directory)
            add(asset_id, 'media', scope, source, asset_id + suffix)
        # The month's print plates: illustrations named by what they are for
        # (frontispiece, scene.<id>, cast.<slug>, or any other name). They are
        # read by file name at binding, so no pack file has to mention them.
        plates = self.config.get('plates')
        if plates:
            for source in sorted((self.directory / plates['directory']).glob('*.png')):
                asset_id = plates['prefix'] + source.stem
                add(asset_id, 'media', 'publication', source, asset_id + '.png')
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
    event = pack['events'][0]
    event['id'] = slug
    event['title'] = title
    event['calendar'] = {
        'startMonth': month, 'startDay': 1, 'durationDays': days, 'recurrence': 'oneShot', 'startYear': year,
        'foreshadowDays': foreshadow_days, 'residueDays': residue_days,
    }
    # Example material like the rest of the scaffold: write the real account of
    # the run before releasing. The edition binds it as The Record.
    event['record'] = {
        'historySentence': 'REPLACE: one sentence on how the run ended, in the Academy\'s voice.',
        'entries': [{'id': f'{slug}.record.opening', 'title': 'REPLACE: what happened first',
                     'account': 'REPLACE: a third-person account. Never claim a Reader was present.'}],
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
4. Write the event's `record`: the Academy's own account of the run
   (`historySentence`, optional `outcomeTitle`, and `entries`). It binds into the
   month's edition as The Record, so a release refuses an issue without one.
5. `python3 scripts/monthly_issue.py rehearse ContentPacks/<every issue on the shelf>`
6. Swift: `swift test --filter MonthlyIssue`
7. `python3 scripts/monthly_issue.py release ... --previous <last published manifest.json>`
8. `scripts/publish_monthly_release.sh <candidate>` (dry run), then `--publish`.
""")
    return directory


WEEKDAYS = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday']
YEAR_TOKEN = re.compile(r'[A-Za-z][A-Za-z0-9_.:-]*{year}[A-Za-z0-9_.:-]*')
MONTH_YEAR = re.compile(r'\b(January|February|March|April|May|June|July|August|September|October|November|December) {year}\b')
REISSUE_SKIP = ('.DS_Store', '__pycache__')


def reissue(source, year, output=None):
    """Fork a finished issue to run again in another year.

    A monthly issue is one authored run, so next October is a new issue with new
    identity, not a replay: the issue, run, pack and receipt-scope IDs, the
    shelf's asset IDs (changed bytes need new ones) and the calendar year all
    change, and nothing else is touched. What a script can't judge is printed:
    every year left in the text, and the weekday drift between the two years.
    The fork is a draft until `rehearse` and the Swift suite pass on it."""
    source = Path(source).resolve()
    issue = Issue(source)
    event = issue.pack['events'][0]['calendar']
    old = event.get('startYear')
    if old is None or year <= old:
        raise IssueError(f'{source.name} runs in {old}; reissue needs a later year, not {year}')
    base = source.name
    slug = f'{base}-{year}'
    target = Path(output).resolve() if output else CONTENT / slug
    if target.exists():
        raise IssueError(f'{target} already exists')
    year_token = re.compile(YEAR_TOKEN.pattern.replace('{year}', str(old)))
    month_year = re.compile(MONTH_YEAR.pattern.replace('{year}', str(old)))

    def fix_text(text):
        text = text.replace(f'asset-path:{base}.', f'asset-path:{slug}.')
        text = year_token.sub(lambda m: m.group(0).replace(str(old), str(year)), text)
        for key in ('issueYear', 'eventStartYear'):
            text = text.replace(f'"{key}": {old}', f'"{key}": {year}')
        return month_year.sub(lambda m: f'{m.group(1)} {year}', text)

    def fix_issue_json(config):
        """Asset IDs only: scene and beat IDs keep their names."""
        def retarget(value):
            return slug + value[len(base):] if value.startswith(base + '.') else value
        for entry in config['files']:
            entry['id'] = retarget(entry['id'])
        for rule in config.get('media', []):
            rule['prefix'] = retarget(rule['prefix'])
        if config.get('plates'):
            config['plates']['prefix'] = retarget(config['plates']['prefix'])
        if config.get('audio'):
            config['audio']['files'] = {retarget(k): v for k, v in config['audio']['files'].items()}
        return config

    shutil.copytree(source, target, ignore=shutil.ignore_patterns(*REISSUE_SKIP))
    for path in sorted(target.rglob('*'), key=lambda p: len(p.parts), reverse=True):
        renamed = fix_text(path.name)
        if renamed != path.name:
            path.rename(path.with_name(renamed))
    for path in sorted(target.rglob('*.json')):
        text = path.read_text()
        if path.name == 'issue.json':
            text = json.dumps(fix_issue_json(json.loads(text)), ensure_ascii=False, indent=2) + '\n'
        path.write_text(fix_text(text))
    pack_path = next(target.glob('*.reenchantedevents.json'))
    pack = json.loads(pack_path.read_text())
    pack['events'][0]['calendar']['startYear'] = year
    pack_path.write_text(json.dumps(pack, ensure_ascii=False, indent=2) + '\n')
    readme = target / 'README.md'
    banner = (f'> Forked from `{source.name}` ({old}) by `monthly_issue.py reissue`. Everything below describes the\n'
              f'> {old} run; check each claim against this {year} fork before relying on it.\n\n')
    readme.write_text(banner + (readme.read_text() if readme.exists() else ''))

    print(f'Forked {source.name} ({old}) to {target} ({year}).')
    leftovers = []
    for path in sorted(target.rglob('*')):
        # Shipped data only; the .md logs and .py generators are history and tooling.
        if path.is_file() and path.suffix == '.json':
            for number, line in enumerate(path.read_text().splitlines(), 1):
                if str(old) in line:
                    leftovers.append(f'  {path.relative_to(target)}:{number}: {line.strip()[:110]}')
    print(f'{len(leftovers)} lines of shipped JSON still mention {old}. Judge each; dates may be correct as they stand.')
    scripts = [p.name for p in sorted(target.glob('*.py')) if str(old) in p.read_text()]
    if scripts:
        print(f'  Generators that hardcode {old} (rerun them only if you regenerate art): ' + ', '.join(scripts))
    for line in leftovers[:40]:
        print(line)
    first_old = datetime(old, event['startMonth'], event['startDay']).weekday()
    first_new = datetime(year, event['startMonth'], event['startDay']).weekday()
    length = event['durationDays']

    def count(y, weekday):
        start = datetime(y, event['startMonth'], event['startDay'])
        return sum((start + timedelta(days=d)).weekday() == weekday for d in range(length))
    print(f'Weekday drift: day 1 is a {WEEKDAYS[first_old]} in {old} and a {WEEKDAYS[first_new]} in {year}.')
    for weekday in range(7):
        if count(old, weekday) != count(year, weekday):
            print(f'  {WEEKDAYS[weekday]}s in the run: {count(old, weekday)} -> {count(year, weekday)}')
    mentions = {}
    for path in target.glob('*.reenchantedevents.json'):
        for day in WEEKDAYS:
            n = len(re.findall(rf'\b{day}s?\b', path.read_text()))
            if n:
                mentions[day] = mentions.get(day, 0) + n
    print('  Weekday names in the story text (each is pinned to a date that moved): '
          + (', '.join(f'{d} x{n}' for d, n in mentions.items()) or 'none'))
    print(f'Next: python3 scripts/monthly_issue.py rehearse {target}  then  swift test --filter MonthlyIssue')
    return target


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest='command', required=True)
    make = sub.add_parser('new')
    make.add_argument('slug')
    make.add_argument('--title', required=True)
    make.add_argument('--year', type=int, required=True)
    make.add_argument('--month', type=int, required=True)
    again = sub.add_parser('reissue')
    again.add_argument('issue', type=Path)
    again.add_argument('--year', type=int, required=True)
    again.add_argument('--output', type=Path, help='default: ContentPacks/<name>-<year>')
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
        elif args.command == 'reissue':
            reissue(args.issue, args.year, args.output)
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
