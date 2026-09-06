import copy
import importlib.util
import json
import hashlib
import unittest
from pathlib import Path

spec = importlib.util.spec_from_file_location('monthly_pack', Path(__file__).parents[1] / 'monthly_pack.py')
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)


def fixture():
    return dict(id='specimen', version=1, minimumRuntimeVersion=2,
        events=[dict(id='specimen-event')],
        storyScenes=[dict(id='scene', nodes=[
            dict(id='entry', body='The door opens.', choices=[dict(id='enter', nextNodeID='end')]),
            dict(id='end', body='The door closes.')])],
        authoringManifests=[dict(id='issue', eventPackID='specimen', eventID='specimen-event',
            coverageRequirements=[dict(id='scenes', label='Scenes', channel='storyScene', minimumReady=1)], content=[
            dict(id='scene-atom', reference=dict(kind='storyScene', id='scene'), channel='storyScene',
                productionStatus='ready', placement=dict(lifecycleStage='live'), occurrence=dict(kind='untilResolved'))])])


class PreflightTests(unittest.TestCase):
    def test_valid_graph(self):
        self.assertEqual(m.check(fixture(), release=True), [])

    def test_native_required_coverage_cannot_be_omitted(self):
        pack = fixture()
        pack['authoringManifests'][0]['coverageRequirements'] = []
        self.assertTrue(any('coverage requirements' in error for error in m.check(pack, release=True)))

    def test_coverage_counts_only_matching_ready_atoms(self):
        pack = fixture()
        requirement = pack['authoringManifests'][0]['coverageRequirements'][0]
        requirement['phaseRole'] = 'climax'
        self.assertTrue(any('0 ready' in error for error in m.check(pack, release=True)))
        pack['authoringManifests'][0]['content'][0]['placement']['phaseRole'] = 'climax'
        self.assertEqual(m.check(pack, release=True), [])
        requirement['minimumReady'] = 2
        self.assertTrue(any('1 ready' in error for error in m.check(pack, release=True)))

    def test_missing_and_cyclic_nodes(self):
        pack = fixture()
        pack['storyScenes'][0]['nodes'][1]['nextNodeID'] = 'entry'
        self.assertTrue(any('cycle' in x for x in m.check(pack)))
        pack['storyScenes'][0]['nodes'][1]['nextNodeID'] = 'missing'
        self.assertTrue(any('missing target' in x for x in m.check(pack)))

    def test_release_refuses_missing_native_and_draft(self):
        pack = fixture()
        atom = pack['authoringManifests'][0]['content'][0]
        atom['reference']['id'] = 'missing'
        atom['productionStatus'] = 'draft'
        errors = m.check(pack, release=True)
        self.assertTrue(any('missing native' in x for x in errors))
        self.assertTrue(any('not ready' in x for x in errors))

    def test_migration_protects_receipt_identity(self):
        old = fixture()
        new = copy.deepcopy(old)
        new['version'] = 2
        new['storyScenes'][0]['nodes'][0]['choices'][0]['id'] = 'different'
        self.assertTrue(any('removed durable identity: choice:' in x for x in m.migration(old, new)))

    def test_migration_detects_rerouting_an_existing_choice(self):
        old = fixture()
        new = copy.deepcopy(old)
        new['version'] = 2
        new['storyScenes'][0]['nodes'][0]['choices'][0]['nextNodeID'] = 'different-end'
        self.assertTrue(any('changed committed route' in x for x in m.migration(old, new)))

    def test_mission_return_requires_acceptance_and_live_window(self):
        pack = fixture()
        atom = pack['authoringManifests'][0]['content'][0]
        atom['missionReturn'] = dict(placement=dict(lifecycleStage='residue'))
        errors = m.check(pack)
        self.assertTrue(any('fieldMission/untilResolved' in x for x in errors))
        self.assertTrue(any('must close during live play' in x for x in errors))

    def test_newer_runtime_is_rejected(self):
        pack = fixture()
        pack['minimumRuntimeVersion'] = 3
        self.assertIn('pack: unsupported minimumRuntimeVersion', m.check(pack))

    def test_rehearsal_pack_and_delivery_hash_agree(self):
        root = Path(__file__).parents[2] / 'docs/fixtures/monthly-rehearsal'
        source = (root / 'school-door.reenchantedevents.json').read_bytes()
        pack = json.loads(source)
        self.assertEqual(m.check(pack, release=True), [])
        asset = json.loads((root / 'delivery-manifest.json').read_text())['issues'][0]['assets'][0]
        self.assertEqual(asset['byteCount'], len(source))
        self.assertEqual(asset['sha256'], hashlib.sha256(source).hexdigest())
        self.assertEqual(len(m.inventory(pack)), 7)
        self.assertEqual(len(json.loads((root / 'personas.json').read_text())), 6)

    def test_malformed_node_is_reported_without_crashing(self):
        pack = fixture()
        pack['storyScenes'][0]['nodes'] = [None]
        self.assertTrue(any('nodes must be objects' in x for x in m.check(pack)))

    def test_inventory_keeps_gates_and_full_caption(self):
        pack = fixture()
        row = m.inventory(pack)[0]
        self.assertEqual(row['content'], 'scene-atom')
        self.assertIn('gates', row)
        self.assertIn('transcript', row)


if __name__ == '__main__':
    unittest.main()
