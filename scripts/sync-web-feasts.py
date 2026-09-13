#!/usr/bin/env python3
"""Export the app's world feast almanac and moon phases for the website.

`WorldFeastAlmanac` keeps 51 days across twelve traditions, each with the words
the Book says about it. `MoonPhaseCalendar` keeps eight phases and their lines.
Between them the site can show a leaf that is true about today, every day: a
feast when there is one, and the moon when there is not.

The rules come across as data rather than dates, because dates go stale. All six
kinds the almanac uses can be evaluated in a browser: `Intl` already carries the
Hebrew, Hijri, Chinese, Coptic, Persian and Ethiopic calendars, and Easter,
fixed days and nth-weekdays are arithmetic.

Eight of these days carry grief rather than celebration. That flag comes across
too: the Book lowers its voice for those, and the website has to as well.

No app build is performed. The deploy script runs this before publishing.
"""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CATALOGUE = ROOT / 'LandingPage/feast-catalogue.js'

world = (ROOT / 'Shared/WorldSystems.swift').read_text()

# Foundation's calendar identifiers, in the spelling Intl wants.
CALENDARS = {
    'islamicUmmAlQura': 'islamic-umalqura',
    'hebrew': 'hebrew',
    'chinese': 'chinese',
    'coptic': 'coptic',
    'persian': 'persian',
    'ethiopicAmeteMihret': 'ethiopic',
}


def blocks(source, opener):
    """Every parenthesised block starting at `opener`, balanced."""
    found = []
    for match in re.finditer(re.escape(opener), source):
        depth, i = 0, match.end() - 1
        while i < len(source):
            if source[i] == '(':
                depth += 1
            elif source[i] == ')':
                depth -= 1
                if depth == 0:
                    found.append(source[match.end():i])
                    break
            i += 1
    return found


def text(body, field):
    match = re.search(field + r':\s*"((?:[^"\\]|\\.)*)"', body)
    return match.group(1).replace('\\"', '"').replace('\\n', '\n') if match else None


def rule_of(body):
    where = re.search(r'rule:\s*\.(\w+)\(', body)
    if not where:
        return None
    kind = where.group(1)
    tail = body[where.end() - 1:]
    depth, i = 0, 0
    while i < len(tail):
        if tail[i] == '(':
            depth += 1
        elif tail[i] == ')':
            depth -= 1
            if depth == 0:
                break
        i += 1
    args = tail[1:i]

    def number(name):
        found = re.search(name + r':\s*(-?\d+)', args)
        return int(found.group(1)) if found else None

    if kind == 'otherCalendar':
        calendar = re.search(r'\.(\w+)', args).group(1)
        if calendar not in CALENDARS:
            raise ValueError('Unmapped calendar: ' + calendar)
        return dict(kind=kind, calendar=CALENDARS[calendar],
                    month=number('month'), day=number('day'))
    if kind == 'fixed':
        return dict(kind=kind, month=number('month'), day=number('day'))
    if kind in ('fromEaster', 'fromOrthodoxEaster'):
        return dict(kind=kind, offset=int(re.search(r'-?\d+', args).group(0)))
    if kind == 'nthWeekday':
        # Foundation counts Sunday as 1; the browser counts it as 0.
        return dict(kind=kind, n=number('n'), weekday=number('weekday') - 1, month=number('month'))
    if kind == 'table':
        # The table is written positionally: `2026: (11, 8)`.
        table = {int(y): [int(m), int(d)] for y, m, d in
                 re.findall(r'(\d{4}):\s*\((\d+),\s*(\d+)\)', args)}
        if not table:
            raise ValueError('Empty feast table; the literal changed shape.')
        return dict(kind=kind, table=table)
    raise ValueError('Unknown rule: ' + kind)


feasts = []
for body in blocks(world[world.index('private static let feasts: [FeastDef] = ['):], 'FeastDef('):
    identifier = text(body, 'id')
    if not identifier:
        continue
    rule = rule_of(body)
    if not rule:
        raise ValueError('Feast without a rule: ' + identifier)
    tradition = re.search(r'tradition:\s*\.(\w+)', body)
    feasts.append(dict(
        id=identifier,
        tradition=tradition.group(1) if tradition else 'folk',
        rule=rule,
        commonName=text(body, 'commonName'),
        academyTitle=text(body, 'academyTitle'),
        blurb=text(body, 'blurb'),
        invitationTitle=text(body, 'invitationTitle'),
        invitation=text(body, 'invitation'),
        accent=text(body, 'accent'),
        carriesGrief='carriesGrief: true' in body))

if len(feasts) < 40:
    raise ValueError('Feast almanac changed shape; found %d days.' % len(feasts))
missing = [f['id'] for f in feasts if not f['blurb'] or not f['commonName']]
if missing:
    raise ValueError('Feasts missing their words: ' + ', '.join(missing))

# ── the moon, with the app's own lines ──
moon = []
phases = world[world.index('enum MoonPhaseCalendar'):]
# The eighth arm of the switch is `default:`, not `case 7:`.
for index, (name, _symbol, line) in enumerate(re.findall(
        r'(?:case \d|default):\s*\n\s*\(name, symbolName, line\) = \(\s*\n\s*"([^"]*)",\s*\n\s*"([^"]*)",\s*\n\s*"((?:[^"\\]|\\.)*)"', phases[:6000])):
    moon.append(dict(index=index, name=name, line=line.replace('\\"', '"')))
if len(moon) != 8:
    raise ValueError('Moon phase copy changed shape; found %d phases.' % len(moon))

synodic = re.search(r'synodicMonthDays\s*=\s*([\d.]+)', phases)
catalogue = {
    'feasts': feasts,
    'moon': {'phases': moon,
             'synodicDays': float(synodic.group(1)),
             # 2000-01-06 18:14 UTC, the epoch the app reckons from.
             'epoch': '2000-01-06T18:14:00Z'},
}
CATALOGUE.write_text(
    '// Generated from Shared/WorldSystems.swift by scripts/sync-web-feasts.py.\n'
    'window.PublicFeastAlmanac=' + json.dumps(catalogue, indent=1, ensure_ascii=False) + ';\n')

kinds = {}
for feast in feasts:
    kinds[feast['rule']['kind']] = kinds.get(feast['rule']['kind'], 0) + 1
print('Synced %d feast days (%s), %d carrying grief, and %d moon phases. No app build.'
      % (len(feasts), ', '.join('%s %d' % kv for kv in sorted(kinds.items())),
         sum(1 for f in feasts if f['carriesGrief']), len(moon)))
