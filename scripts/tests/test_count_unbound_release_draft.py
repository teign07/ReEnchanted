import importlib.util
import json
from pathlib import Path
import sys
import tempfile
import unittest


SCRIPT = Path(__file__).parents[2] / 'ContentPacks/count-unbound/stage_release_draft.py'
SPEC = importlib.util.spec_from_file_location('count_release_draft', SCRIPT)
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)
sys.path.insert(0, str(Path(__file__).parents[1]))
from prepare_monthly_release import prepare


class CountReleaseDraftTests(unittest.TestCase):
    def test_four_came_home_uses_mothlight_recording(self):
        self.assertEqual(
            MODULE.AUDIO['count-unbound.audio.four-came-home'],
            'DJ_mothlight_count_unbound_four_home_01.mp3',
        )
        pack = json.loads(MODULE.PACK.read_text())
        radio = next(item for item in pack['radioBanters']
                     if item['id'] == 'count-unbound.radio.four-came-home')
        self.assertEqual(radio['stationID'], 'mothlight-beats')
        self.assertEqual(radio['banter']['caption'],
                         'The listed names are home. The ribbons are tied. The source is shut. Hold on.')

    def test_draft_names_every_media_file_without_signing_or_uploading(self):
        with tempfile.TemporaryDirectory() as root:
            root = Path(root)
            output = root / 'draft'
            empty_audio = root / 'empty-audio'
            empty_audio.mkdir()
            count, missing = MODULE.stage(output, '2026-09-23T20:00:00Z',
                                          allow_missing_audio=True, audio_root=empty_audio)
            template = json.loads((output / 'delivery-template.json').read_text())
            assets = template['issues'][0]['assets']
            self.assertEqual(template['schemaVersion'], 2)
            self.assertEqual(count, 38)
            self.assertEqual(len(assets), count)
            self.assertEqual(len(missing), 5)
            self.assertEqual({a['kind'] for a in assets}, {'worldEventPack', 'pageArchetypePack', 'editionPlayPack', 'media', 'casebook'})
            self.assertEqual(sum(a['scope'] == 'casebook' for a in assets), 1)
            self.assertEqual(sum(a['scope'] == 'publication' for a in assets), 2)
            self.assertFalse((output / 'manifest.envelope.json').exists())

    def test_release_stage_waits_for_real_recordings(self):
        with tempfile.TemporaryDirectory() as root:
            root = Path(root)
            output = root / 'release'
            empty_audio = root / 'empty-audio'
            empty_audio.mkdir()
            with self.assertRaisesRegex(ValueError, 'Missing recordings'):
                MODULE.stage(output, '2026-09-23T20:00:00Z', audio_root=empty_audio)
            self.assertFalse(output.exists())

    def test_synthetic_clips_exercise_all_38_delivery_routes(self):
        with tempfile.TemporaryDirectory() as root:
            root = Path(root)
            audio = root / 'synthetic-audio'
            audio.mkdir()
            for filename in MODULE.AUDIO.values():
                (audio / filename).write_bytes(b'ID3\x04\x00\x00synthetic-test-only')
            draft = root / 'draft'
            count, missing = MODULE.stage(draft, '2026-09-23T20:00:00Z', audio_root=audio)
            self.assertEqual((count, missing), (38, []))
            template = json.loads((draft / 'delivery-template.json').read_text())
            source_root = draft / 'sources'
            world = source_root / MODULE.ISSUE_ID / 'count-unbound.reenchantedevents.json'
            pack = json.loads(world.read_text())
            for atom in pack['authoringManifests'][0]['content']:
                if atom['channel'] == 'radioBanter':
                    atom['productionStatus'] = 'ready'
            world.write_text(json.dumps(pack))
            release = root / 'prepared'
            report = prepare(template, source_root, release, 'https://shelf.example')
            self.assertEqual(len(report['upload']), 38)
            self.assertEqual(len(json.loads((release / 'manifest.json').read_text())['issues'][0]['assets']), 38)


if __name__ == '__main__':
    unittest.main()
