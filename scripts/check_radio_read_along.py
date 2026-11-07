#!/usr/bin/env python3
"""Audit bundled radio transcripts and audio identity without building the app."""
import hashlib
import json
import math
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
AUDIO = ROOT / "InsideCoverApp/RadioAudio"


def check():
    sheets = json.loads((AUDIO / "RadioReadAlong.json").read_text())
    song_sources = {s["assetName"]: s for s in json.loads((ROOT / "docs/radio-song-sources.json").read_text())}
    errors = []
    recordings = {p.stem: p for p in AUDIO.iterdir()
                  if p.suffix.lower() in {".m4a", ".mp3", ".wav", ".aac", ".caf", ".aiff"}}
    for name, source in song_sources.items():
        if source["status"] == "lyrics-recovered" and sheets.get(name, {}).get("kind") != "lyrics":
            errors.append(f"{name}: recovered lyrics missing from the app resource")
    for name, path in recordings.items():
        if name.startswith("DJ_") and name not in sheets:
            errors.append(f"{name}: missing DJ transcript")
    for name, sheet in sheets.items():
        path = recordings.get(name)
        if path is None:
            errors.append(f"{name}: recording missing")
            continue
        if hashlib.sha256(path.read_bytes()).hexdigest() != sheet["audioSHA256"]:
            errors.append(f"{name}: recording changed; recheck transcript and timing")
        text = sheet.get("text", "").strip()
        if not text or "Audio-backed clip" in text or "haven't been transcribed" in text:
            errors.append(f"{name}: missing spoken words")
        previous_end = 0
        for cue in sheet.get("cues", []):
            start, end = cue["start"], cue["end"]
            if not (math.isfinite(start) and math.isfinite(end)
                    and previous_end <= start < end <= sheet["durationSeconds"] + 0.1):
                errors.append(f"{name}: invalid cue {start}..{end}")
            previous_end = end
        cues = sheet.get("cues", [])
        spoken = " ".join(c["text"] for c in cues)
        if cues and " ".join(spoken.split()) != " ".join(text.split()):
            errors.append(f"{name}: cue sheet omits transcript text")
        if name.startswith("DJ_") and not cues:
            errors.append(f"{name}: missing DJ timing")
        expected_kind = "transcript" if name.startswith("DJ_") else "lyrics"
        if sheet.get("kind") != expected_kind:
            errors.append(f"{name}: wrong kind of text")
        if expected_kind == "lyrics":
            source = song_sources.get(name, {})
            if (source.get("status") != "lyrics-recovered"
                    or source.get("sourceURL") != sheet.get("source")
                    or source.get("sunoSongID") != sheet.get("sourceSongID")
                    or source.get("audioSHA256") != sheet["audioSHA256"]):
                errors.append(f"{name}: lyric provenance does not match the recording")
            if re.search(r"\[[^\]]+\]|\*\*", text):
                errors.append(f"{name}: production directions remain in the displayed lyrics")
    source = (ROOT / "Shared/WorldSystems.swift").read_text()
    if re.search(r'caption: "Unscheduled|caption: "[^"\n]*Audio-backed clip', source):
        errors.append("WorldSystems.swift: DJ production placeholders remain")
    if errors:
        raise SystemExit("\n".join(errors))
    djs = sum(s["kind"] == "transcript" for s in sheets.values())
    lyrics = sum(s["kind"] == "lyrics" for s in sheets.values())
    print(f"Radio read-along audit passed: {djs} DJ transcripts, {lyrics} lyric sheets; audio hashes and cue coverage match.")


if __name__ == "__main__":
    check()
