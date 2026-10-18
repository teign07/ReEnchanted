import importlib.util
import json
from pathlib import Path
import sys
import tempfile
import unittest

SCRIPTS = Path(__file__).parents[1]
SPEC = importlib.util.spec_from_file_location('monthly_issue', SCRIPTS / 'monthly_issue.py')
tool = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(tool)
sys.path.insert(0, str(SCRIPTS))
from monthly_pack import check  # noqa: E402
from prepare_monthly_release import prepare  # noqa: E402

COUNT = SCRIPTS.parent / 'ContentPacks/count-unbound'


class MonthlyIssueToolTests(unittest.TestCase):
    def setUp(self):
        self.root = Path(tempfile.mkdtemp())
        self.original_content = tool.CONTENT
        tool.CONTENT = self.root / 'ContentPacks'
        tool.CONTENT.mkdir()

    def tearDown(self):
        tool.CONTENT = self.original_content

    def test_windows_come_from_the_pack_calendar(self):
        self.assertEqual(tool.Issue(COUNT).windows(), {
            'foreshadowStartsAt': '2026-09-24T00:00:00Z',
            'liveStartsAt': '2026-10-01T00:00:00Z',
            'liveEndsAt': '2026-11-01T00:00:00Z',
            'residueEndsAt': '2026-11-08T00:00:00Z',
        })

    def test_a_new_month_is_a_valid_draft_with_its_own_calendar(self):
        folder = tool.new('winter-lantern', 'The Winter Lantern', 2026, 12)
        issue = tool.Issue(folder)
        self.assertEqual(issue.issue_id, 'winter-lantern-2026-12')
        self.assertEqual(issue.windows(), {
            'foreshadowStartsAt': '2026-11-24T00:00:00Z',
            'liveStartsAt': '2026-12-01T00:00:00Z',
            'liveEndsAt': '2027-01-01T00:00:00Z',
            'residueEndsAt': '2027-01-08T00:00:00Z',
        })
        pack = issue.pack
        self.assertEqual(check(pack), [])
        self.assertNotIn('school-door', json.dumps(pack))
        statuses = {atom['productionStatus'] for atom in pack['authoringManifests'][0]['content']}
        self.assertEqual(statuses, {'draft'}, 'nothing ships until it is written')
        self.assertTrue((folder / 'README.md').is_file())
        with self.assertRaises(tool.IssueError):
            tool.new('winter-lantern', 'Again', 2026, 12)

    def test_a_shelf_carries_every_issue_in_live_order(self):
        december = tool.new('winter-lantern', 'The Winter Lantern', 2026, 12)
        output = self.root / 'shelf'
        count, missing = tool.stage([december, COUNT], output, '2026-09-23T00:00:00Z')
        template = json.loads((output / 'delivery-template.json').read_text())
        self.assertEqual([issue['id'] for issue in template['issues']],
                         ['count-unbound-2026-10', 'winter-lantern-2026-12'])
        self.assertEqual(missing, [])
        self.assertEqual(count, sum(len(issue['assets']) for issue in template['issues']))
        self.assertEqual(len({asset['id'] for issue in template['issues'] for asset in issue['assets']}), count)
        # The scaffold is all draft, so the release gate refuses the shelf
        # and names what is unfinished; nothing half-written ships.
        with self.assertRaisesRegex(ValueError, 'required content is not ready'):
            prepare(template, output / 'sources', self.root / 'prepared', 'https://shelf.example')

    def test_an_issue_without_a_record_is_refused(self):
        folder = self.root / 'ContentPacks' / 'count-copy'
        import shutil
        shutil.copytree(COUNT, folder, ignore=shutil.ignore_patterns('audio', '*.png', '*.jpg'))
        packfile = folder / 'opening.reenchantedevents.json'
        pack = json.loads(packfile.read_text())
        del pack['events'][0]['record']
        packfile.write_text(json.dumps(pack))
        with self.assertRaisesRegex(tool.IssueError, 'no record'):
            tool.Issue(folder).validate()

    def test_october_story_plates_ship_with_runtime_and_keep_their_print_sources(self):
        issue = tool.Issue(COUNT)
        entry, missing = issue.stage_into(self.root / 'sources')
        self.assertEqual(missing, [])
        assets = {asset['id']: asset for asset in entry['assets']}
        scene_stems = {path.stem for path in (COUNT / 'plates').glob('scene.*.jpg')}
        attached_stems = set()
        for scene in issue.pack['storyScenes']:
            owners = [scene] + scene.get('nodes', [])
            plates = [(index, owner['illustration']) for index, owner in enumerate(owners) if 'illustration' in owner]
            stem = 'scene.' + scene['id']
            if stem not in scene_stems:
                self.assertEqual(plates, [], scene['id'])
                continue
            self.assertEqual(len(plates), 1, scene['id'])
            index, plate = plates[0]
            self.assertEqual(index, 1 if scene.get('nodes') else 0, scene['id'])
            runtime_id = 'count-unbound.story-art.v1.' + stem
            self.assertEqual(plate['reference'], '{{asset-path:' + runtime_id + '}}')
            self.assertEqual(plate['kind'], 'renderedImageFile')
            runtime = assets[runtime_id]
            publication = assets[issue.config['plates']['prefix'] + stem]
            self.assertEqual(runtime['scope'], 'runtime')
            self.assertEqual(publication['scope'], 'publication')
            target = self.root / 'sources' / issue.issue_id
            self.assertEqual((target / runtime['fileName']).read_bytes(), (target / publication['fileName']).read_bytes())
            attached_stems.add(stem)
        self.assertEqual(attached_stems, scene_stems)
        # The runtime adapter reuses the scene gate; artwork adds no story beats
        # or dependencies, and stays out of the unrelated interleave catalogue.
        self.assertEqual(check(issue.pack, release=True), [])
        output = self.root / 'prepared'
        template = dict(schemaVersion=2, generatedAt='2026-10-18T12:00:00Z', issues=[entry])
        prepare(template, self.root / 'sources', output, 'https://shelf.example')


if __name__ == '__main__':
    unittest.main()
