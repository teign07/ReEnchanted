/* What today actually is, worked out in the reader's own calendar.
 *
 * The almanac keeps 51 days across twelve traditions, so most days have none.
 * The moon always has something, so the leaf falls back to it and changes
 * every day either way.
 *
 * The rules arrive as rules, not dates, because dates go stale. Five kinds are
 * arithmetic. The sixth asks the browser: `Intl` carries the Hebrew, Hijri,
 * Chinese, Coptic, Persian and Ethiopic calendars already, so "the first of
 * Ramadan" is a question it can answer rather than a table I have to maintain.
 */
(() => {
  'use strict';
  const almanac = window.PublicFeastAlmanac;
  if (!almanac || !Array.isArray(almanac.feasts)) return;

  const DAY = 86400000;
  const utc = (date) => Date.UTC(date.getFullYear(), date.getMonth(), date.getDate());

  // Anonymous Gregorian computus.
  function easter(year) {
    const a = year % 19, b = Math.floor(year / 100), c = year % 100;
    const d = Math.floor(b / 4), e = b % 4, f = Math.floor((b + 8) / 25);
    const g = Math.floor((b - f + 1) / 3), h = (19 * a + b - d - g + 15) % 30;
    const i = Math.floor(c / 4), k = c % 4;
    const l = (32 + 2 * e + 2 * i - h - k) % 7;
    const m = Math.floor((a + 11 * h + 22 * l) / 451);
    const month = Math.floor((h + l - 7 * m + 114) / 31);
    return Date.UTC(year, month - 1, ((h + l - 7 * m + 114) % 31) + 1);
  }

  // Meeus's Julian computus, shifted onto the Gregorian calendar.
  function orthodoxEaster(year) {
    const a = year % 4, b = year % 7, c = year % 19;
    const d = (19 * c + 15) % 30;
    const e = (2 * a + 4 * b - d + 34) % 7;
    const month = Math.floor((d + e + 114) / 31);
    const day = ((d + e + 114) % 31) + 1;
    const julian = Date.UTC(year, month - 1, day);
    // The Julian calendar runs 13 days behind for 1900-2099.
    return julian + 13 * DAY;
  }

  // Intl reports Hebrew months by name however you ask, so they need naming
  // back. The numbers are Foundation's, which is what the almanac was written
  // against: Tishri 1 ... Adar I 6, Adar 7, Nisan 8 ... Elul 13.
  const HEBREW = {
    tishri: 1, heshvan: 2, cheshvan: 2, marheshvan: 2, kislev: 3, tevet: 4, shevat: 5,
    'adar i': 6, 'adar ii': 7, adar: 7,
    nisan: 8, iyar: 9, sivan: 10, tamuz: 11, tammuz: 11, av: 12, elul: 13
  };

  const readers = new Map();
  function inCalendar(calendar, when) {
    if (!readers.has(calendar)) {
      try {
        readers.set(calendar, new Intl.DateTimeFormat('en-u-ca-' + calendar,
          { month: 'numeric', day: 'numeric', timeZone: 'UTC' }));
      } catch { readers.set(calendar, null); }
    }
    const reader = readers.get(calendar);
    if (!reader) return null;
    const parts = {};
    for (const part of reader.formatToParts(new Date(when))) parts[part.type] = part.value;
    const month = (parts.month || '').trim();
    if (/^\d+$/.test(month)) return { month: Number(month), day: Number(parts.day) };
    const named = HEBREW[month.toLowerCase()];
    // Anything else — a Chinese leap month reports as "5bis" — is not the
    // month the feast means, and guessing at it would put a day on the wrong
    // date in somebody's calendar.
    if (!named) return null;
    return { month: named, day: Number(parts.day) };
  }

  function falls(rule, when) {
    const date = new Date(when);
    const year = date.getUTCFullYear();
    switch (rule.kind) {
      case 'fixed':
        return date.getUTCMonth() + 1 === rule.month && date.getUTCDate() === rule.day;
      case 'otherCalendar': {
        const there = inCalendar(rule.calendar, when);
        return !!there && there.month === rule.month && there.day === rule.day;
      }
      case 'fromEaster':
        return when === easter(year) + rule.offset * DAY;
      case 'fromOrthodoxEaster':
        return when === orthodoxEaster(year) + rule.offset * DAY;
      case 'nthWeekday': {
        if (date.getUTCMonth() + 1 !== rule.month || date.getUTCDay() !== rule.weekday) return false;
        if (rule.n === -1) return date.getUTCDate() + 7 > new Date(Date.UTC(year, rule.month, 0)).getUTCDate();
        return Math.ceil(date.getUTCDate() / 7) === rule.n;
      }
      case 'table': {
        const entry = rule.table[String(year)];
        return !!entry && date.getUTCMonth() + 1 === entry[0] && date.getUTCDate() === entry[1];
      }
      default:
        return false;
    }
  }

  function moonOn(when) {
    const moon = almanac.moon;
    const age = ((when - Date.parse(moon.epoch)) / DAY) % moon.synodicDays;
    const normalised = age < 0 ? age + moon.synodicDays : age;
    const cycle = normalised / moon.synodicDays;
    const phase = moon.phases[Math.round(cycle * 8) % 8];
    return Object.assign({}, phase, {
      ageDays: normalised,
      illumination: (1 - Math.cos(2 * Math.PI * cycle)) / 2
    });
  }

  function today(when) {
    const day = when === undefined ? utc(new Date()) : when;
    const feasts = almanac.feasts.filter(feast => falls(feast.rule, day));
    // A day of mourning never has to share the leaf with a celebration.
    const grief = feasts.find(feast => feast.carriesGrief);
    return { date: day, feast: grief || feasts[0] || null, feasts, moon: moonOn(day) };
  }

  window.PublicFeastday = { today, moonOn, falls, easter, orthodoxEaster };
})();
