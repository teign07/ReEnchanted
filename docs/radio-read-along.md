# Radio transcripts and lyrics

The radio uses its existing DJ-caption path, with a bounded reading window on
the Radio Page. A timed line is highlighted from `AVAudioPlayer.currentTime`.
The Reader can switch off **Follow the words** to browse. Pausing keeps the
text available and freezes the playback position; changing stations, static,
interstitials, and stopping clear the previous item's words.

`InsideCoverApp/RadioAudio/RadioReadAlong.json` carries the bundled DJ cue
sheets. Each entry names its recording, records its SHA-256 and duration, and
identifies the text source. The imported Penny, Euphony, and Wicker batches had
89 production placeholders. Their captions now contain local speech
transcriptions, with recognition errors in names and clear homophones corrected.
Other recordings use an existing authored script where it closely matches the
speech; changed recordings use the recognized speech instead of an old draft.

Timing comes from local Whisper base.en sentence segments. These are approximate
line cues, not hand-verified word timings. Text and timing still need a listening
pass and an on-device reading/VoiceOver rehearsal. No app build or device test was
performed for this change.

Lyrics use the same display but remain separate from `RadioTrackMeaning` and
never enter narrative prompts. Original lyrics for 12 songs were recovered on
2026-11-06 from the Suno pages identified by IDs embedded in the audio metadata.
They are now bundled for reading during playback. Section headings, title lines,
and bracketed performance directions are omitted from the displayed text;
authored repetitions and sung parentheticals remain.

These lyric sheets are untimed. No timing was fabricated from line or word
counts. Speech recognition over the music produced false words and repeated
phrases, so none of that recognized text was imported. Song highlighting still
requires a reliable alignment pass against each exact recording.

[Song source records](radio-song-sources.json) preserve the original lyric text,
source URLs, embedded song IDs, recording hashes, and retrieval date. Of the 38
bundled `Radio*` recordings (including static/interstitial audio), 35 had source
IDs: 12 pages carried lyric text and 23 carried none. The other three recordings
had no embedded source ID. A page with no lyric text is not, by itself, proof
that the recording contains no singing.

For a radio pack, provide `lyrics` on a track or `transcript` on a DJ banter:

```json
{
  "text": "First line. Second line.",
  "cues": [
    { "start": 1.2, "end": 3.4, "text": "First line." },
    { "start": 4.0, "end": 6.1, "text": "Second line." }
  ]
}
```

Times are seconds in the exact delivered audio. Include the complete text, in
order, with any repeated sung lines repeated. Silence between cues stays
unhighlighted. Omitting `cues` displays the whole text without highlighting.
Invalid, overlapping, or partial cue sheets also fall back to the complete text.

Downloaded/user recordings can instead have an adjacent
`<audio-filename-without-extension>.readalong.json` with this object. An inline
pack transcript takes precedence. A replacement recording never borrows the
bundled original's lyrics merely because their filenames match. Monthly packs
without timing retain their existing complete captions.

Run `python3 scripts/check_radio_read_along.py` to check DJ coverage, audio hashes,
cue ordering, and complete text coverage without building. The focused
`RadioReadAlongTests` also cover legacy decoding, timing boundaries, silence,
and malformed alignment fallback; those Swift tests require an authorized build
before they can be run.
