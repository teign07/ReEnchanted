"""Offline November Cast contracts; no app compiler, install or publication."""
import importlib.util
import json
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
GUEST = 'visitor-the-guest'
ASSET = 'LabyrinthCharacterTheGuest'


class GuestContentTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.pack = json.loads((ROOT / 'ContentPacks/the-guest/november.reenchantedevents.json').read_text())
        cls.scenes = {s['id'].removeprefix('the-guest.scene.'): s for s in cls.pack['storyScenes']}

    def test_eight_scenes_have_his_own_witness(self):
        main = ['the-knock', 'three-nights', 'flat', 'the-rescue', 'the-offer',
                'stir-up-sunday', 'a-place-at-the-table', 'the-bowl']
        for key in main:
            scene = self.scenes[key]
            self.assertEqual(scene['castIDs'].count(GUEST), 1, key)
            own = [m for n in scene['nodes'] for m in n.get('castMemories', []) if m['entityID'] == GUEST]
            self.assertEqual(len(own), 1, key)
            self.assertTrue(own[0]['memory'].strip())

    def test_later_moments_wait_for_their_actual_node(self):
        for scene_id, expected in [('flat', '.kitchens'), ('the-rescue', '.min-seo')]:
            scene = self.scenes[scene_id]
            nodes = [n for n in scene['nodes'] if any(m['entityID'] == GUEST for m in n.get('castMemories', []))]
            self.assertEqual(len(nodes), 1)
            self.assertTrue(nodes[0]['id'].endswith(expected))

    def test_every_ending_is_free_and_only_stay_names_him(self):
        node = next(n for n in self.scenes['the-bowl']['nodes'] if n['id'].endswith('.home-or-not'))
        self.assertEqual({c['id'] for c in node['choices']}, {'send-home', 'ask-to-stay', 'let-it-go-back'})
        for choice in node['choices']:
            self.assertNotIn('gate', choice)
            own = [m for m in choice['castMemories'] if m['entityID'] == GUEST]
            self.assertEqual(len(own), 1)
            self.assertEqual('Aiken Drum' in own[0]['memory'], choice['id'] == 'ask-to-stay')
            self.assertEqual('Aiken Drum' in choice['result'], choice['id'] == 'ask-to-stay')

    def test_no_public_record_or_shared_scene_memory_reveals_the_name(self):
        for entry in self.pack['events'][0]['record']['entries']:
            for m in entry.get('castMemories', []):
                self.assertNotIn('Aiken', m['memory'])
                if m['entityID'] == GUEST:
                    self.assertNotIn('.bowl.stayed', m['key'])
        for scene in self.pack['storyScenes']:
            for node in scene.get('nodes', []):
                for m in node.get('castMemories', []):
                    if m['entityID'] == GUEST:
                        self.assertNotIn('Aiken', m['memory'])

    def test_staging_and_cast_keep_one_identity(self):
        placements = [p for phase in self.pack['events'][0]['phases'] for p in phase.get('staging', [])]
        guests = [p for p in placements if p.get('name') == 'The Guest']
        self.assertTrue(guests)
        self.assertEqual({p['castID'] for p in guests}, {GUEST})
        for scene in self.pack['storyScenes']:
            self.assertNotIn('aiken-drum', scene.get('castIDs', []))
        # The December recall can contain him only on the Stay branch. It must
        # not freeze a shared memory pretending he was there on Home/Court.
        self.assertNotIn(GUEST, self.scenes['the-first-of-december']['castIDs'])

    def test_the_offer_keeps_both_answers_distinct(self):
        entry = self.scenes['the-offer']['nodes'][0]
        memories = {c['id']: [m['key'] for m in c['castMemories'] if m['entityID'] == GUEST] for c in entry['choices']}
        self.assertEqual(memories['take-it'], ['the-guest.offer.taken'])
        self.assertEqual(memories['keep-night'], ['the-guest.offer.kept'])

    def test_plate_has_a_real_bundled_file_and_no_name_spoiler(self):
        library = json.loads((ROOT / 'Shared/BookReferenceLibrary.json').read_text())
        profiles = [p for p in library['characterIllustrations'] if p['slug'] == GUEST]
        self.assertEqual(len(profiles), 1)
        self.assertEqual(profiles[0]['characterName'], 'The Guest')
        self.assertEqual(profiles[0]['assetName'], ASSET)
        self.assertNotIn('Aiken', json.dumps(profiles[0]))
        folder = ROOT / 'InsideCoverApp/Assets.xcassets' / (ASSET + '.imageset')
        contents = json.loads((folder / 'Contents.json').read_text())
        for image in contents['images']:
            path = folder / image['filename']
            self.assertTrue(path.is_file())
            self.assertLess(path.stat().st_size, 2 * 1024 * 1024)
            self.assertTrue(path.read_bytes().startswith(b'\xff\xd8'))

    def test_pack_app_and_publishing_tools_agree_on_required_runtime(self):
        swift = (ROOT / 'Shared/WorldEvents.swift').read_text()
        native = int(re.search(r'static let runtimeVersion = (\d+)', swift)[1])
        spec = importlib.util.spec_from_file_location('guest_pack_preflight', ROOT / 'scripts/monthly_pack.py')
        tool = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(tool)
        self.assertEqual(self.pack['minimumRuntimeVersion'], native)
        self.assertEqual(tool.RUNTIME_VERSION, native)
        self.assertEqual(tool.check(self.pack, release=True), [])


if __name__ == '__main__':
    unittest.main()
