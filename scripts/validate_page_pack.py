#!/usr/bin/env python3
"""Validate a ReEnchanted Page Pack JSON file before shipping it.

Usage: python3 scripts/validate_page_pack.py path/to/pack.reenchantedpack.json
Exits non-zero with readable errors if the pack would be rejected or would
misbehave when dropped into the app's Documents folder.
"""
import json
import re
import sys

KNOWN_AVAILABILITY = {"bundledFree", "patron", "paid", "userImported", "locked"}
KNOWN_RENDER_STYLES = {
    "promptCard", "gentleTranslation", "quoteCard", "loreLetter",
    "illustrationPlate", "illuminatedPhoto", "graphEvent", "archiveReturn",
}
KNOWN_PLACEHOLDERS = {
    "{weather}", "{moon}", "{moonLine}", "{timeOfDay}", "{playerName}",
    "{keptCount}", "{lastKeptPage}", "{season}",
}
PLACEHOLDER_PATTERN = re.compile(r"\{[a-zA-Z]+\}")


def fail(errors):
    for error in errors:
        print(f"  ✗ {error}")
    sys.exit(1)


def check_placeholders(text, where, errors):
    for found in PLACEHOLDER_PATTERN.findall(text or ""):
        if found not in KNOWN_PLACEHOLDERS:
            errors.append(f"{where}: unknown placeholder {found} (known: {', '.join(sorted(KNOWN_PLACEHOLDERS))})")


def main():
    if len(sys.argv) != 2:
        print(__doc__)
        sys.exit(2)
    path = sys.argv[1]
    errors = []

    try:
        with open(path) as handle:
            pack = json.load(handle)
    except (OSError, json.JSONDecodeError) as exc:
        fail([f"could not parse {path}: {exc}"])

    for key in ("id", "displayName", "version", "author", "availability", "archetypes"):
        if key not in pack:
            errors.append(f"pack: missing required key '{key}'")
    if errors:
        fail(errors)

    if pack["availability"] not in KNOWN_AVAILABILITY:
        errors.append(f"pack: availability '{pack['availability']}' not in {sorted(KNOWN_AVAILABILITY)}")
    if not isinstance(pack["version"], int) or pack["version"] < 1:
        errors.append("pack: version must be a positive integer")
    if not isinstance(pack["archetypes"], list) or not pack["archetypes"]:
        errors.append("pack: archetypes must be a non-empty array")
        fail(errors)

    seen_ids = set()
    for index, archetype in enumerate(pack["archetypes"]):
        where = f"archetype[{index}] ({archetype.get('id', '?')})"
        for key in ("id", "title", "headline", "detail", "reason", "bodyTemplate"):
            if not archetype.get(key):
                errors.append(f"{where}: missing or empty '{key}'")
        if archetype.get("id") in seen_ids:
            errors.append(f"{where}: duplicate archetype id")
        seen_ids.add(archetype.get("id"))
        if "score" in archetype and not (1 <= archetype["score"] <= 100):
            errors.append(f"{where}: score must be 1-100")
        if "cadenceHours" in archetype and not (1 <= archetype["cadenceHours"] <= 168):
            errors.append(f"{where}: cadenceHours must be 1-168")
        for hour in archetype.get("activeHours") or []:
            if not (0 <= hour <= 23):
                errors.append(f"{where}: activeHours entry {hour} out of range 0-23")
        style = archetype.get("renderStyleRaw")
        if style and style not in KNOWN_RENDER_STYLES:
            errors.append(f"{where}: renderStyleRaw '{style}' not in {sorted(KNOWN_RENDER_STYLES)}")
        check_placeholders(archetype.get("bodyTemplate"), f"{where} bodyTemplate", errors)
        generation = archetype.get("generation")
        if generation is not None:
            for key in ("instructions", "promptTemplate"):
                if not generation.get(key):
                    errors.append(f"{where}: generation missing '{key}'")
            if "maxTokens" in generation and not (32 <= generation["maxTokens"] <= 1024):
                errors.append(f"{where}: generation.maxTokens must be 32-1024")
            check_placeholders(generation.get("promptTemplate"), f"{where} promptTemplate", errors)

    if errors:
        fail(errors)
    print(f"  ✓ {pack['displayName']} v{pack['version']} — {len(pack['archetypes'])} archetype(s), availability {pack['availability']}: valid")


if __name__ == "__main__":
    main()
