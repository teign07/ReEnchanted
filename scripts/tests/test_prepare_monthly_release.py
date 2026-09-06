import copy
import hashlib
import json
from pathlib import Path
import shutil
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).parents[1]))
from prepare_monthly_release import prepare


class ReleaseTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.sources = self.root / 'sources'
        fixture = Path(__file__).parents[2] / 'docs/fixtures/monthly-rehearsal'
        self.manifest = json.loads((fixture / 'delivery-manifest.json').read_text())
        self.issue = self.manifest['issues'][0]
        self.asset = self.issue['assets'][0]
        target = self.sources / self.issue['id']
        target.mkdir(parents=True)
        self.source = target / self.asset['fileName']
        shutil.copyfile(fixture / self.asset['fileName'], self.source)
        self.output = self.root / 'release'

    def run_prepare(self, **kwargs):
        return prepare(self.manifest, self.sources, self.output, 'https://shelf.example', **kwargs)

    def test_prepares_exact_bytes_private_routes_and_inventory(self):
        self.asset['sha256'] = 'stale authoring checksum'
        report = self.run_prepare()
        manifest = json.loads((self.output / 'manifest.json').read_text())
        asset = manifest['issues'][0]['assets'][0]
        self.assertEqual(manifest['allowedAssetHosts'], ['shelf.example'])
        self.assertEqual(asset['remoteURL'], f'https://shelf.example/monthly-issues/assets/{asset["id"]}')
        self.assertEqual(asset['sha256'], hashlib.sha256(self.source.read_bytes()).hexdigest())
        self.assertEqual((self.output / 'assets' / asset['id']).read_bytes(), self.source.read_bytes())
        self.assertEqual(report['uploadBytes'], self.source.stat().st_size)
        self.assertTrue((self.output / 'production.csv').is_file())
        self.assertFalse((self.output / 'manifest.envelope.json').exists())
        self.assertEqual(self.asset['sha256'], 'stale authoring checksum')

    def test_unchanged_release_needs_no_asset_upload(self):
        report = self.run_prepare(previous=self.manifest)
        self.assertEqual(report['upload'], [])
        self.assertEqual(len(report['reuse']), 1)

    def test_changed_bytes_need_new_id_and_failure_leaves_no_output(self):
        previous = copy.deepcopy(self.manifest)
        with self.source.open('a') as out:
            out.write('\n')
        with self.assertRaisesRegex(ValueError, 'immutable asset ID'):
            self.run_prepare(previous=previous)
        self.assertFalse(self.output.exists())
        self.assertEqual(list(self.root.glob('.monthly-release-*')), [])
        self.asset['id'] += '-v2'
        report = self.run_prepare(previous=previous)
        self.assertEqual(len(report['upload']), 1)
        self.assertEqual(report['noLongerListed'], ['assets/' + previous['issues'][0]['assets'][0]['id']])

    def test_refuses_overwriting_existing_release(self):
        self.run_prepare()
        original = (self.output / 'manifest.json').read_bytes()
        with self.assertRaisesRegex(ValueError, 'overwrite'):
            self.run_prepare()
        self.assertEqual((self.output / 'manifest.json').read_bytes(), original)

    def test_invalid_origins_are_rejected(self):
        for origin in ('http://shelf.example', 'https://user:secret@shelf.example',
                       'https://shelf.example/path', 'https://shelf.example?query',
                       'https://shelf.example#fragment', 'https://shelf.example:8443'):
            with self.subTest(origin=origin), self.assertRaises(ValueError):
                prepare(self.manifest, self.sources, self.output, origin)

    def test_path_traversal_and_duplicate_ids_rejected(self):
        self.asset['fileName'] = '../outside'
        with self.assertRaisesRegex(ValueError, 'filename'):
            self.run_prepare()
        self.asset['fileName'] = self.source.name
        self.issue['assets'].append(copy.deepcopy(self.asset))
        with self.assertRaisesRegex(ValueError, 'duplicate asset ID'):
            self.run_prepare()

    def test_symlink_outside_source_root_rejected(self):
        outside = self.root / 'outside.json'
        shutil.move(self.source, outside)
        self.source.symlink_to(outside)
        with self.assertRaisesRegex(ValueError, 'outside asset root'):
            self.run_prepare()

    def test_retirement_and_overlapping_lifecycle_rejected(self):
        self.asset['retiresAt'] = self.issue['foreshadowStartsAt']
        with self.assertRaisesRegex(ValueError, 'retirement'):
            self.run_prepare()
        del self.asset['retiresAt']
        other = copy.deepcopy(self.issue)
        other.update(id='overlap', assets=[])
        self.manifest['issues'].append(other)
        with self.assertRaisesRegex(ValueError, 'overlap'):
            self.run_prepare()

    def test_draft_pack_rejected_before_release_directory_is_created(self):
        pack = json.loads(self.source.read_text())
        pack['authoringManifests'][0]['content'][0]['productionStatus'] = 'draft'
        self.source.write_text(json.dumps(pack))
        with self.assertRaises(ValueError):
            self.run_prepare()
        self.assertFalse(self.output.exists())

    def test_missing_media_reference_rejected(self):
        self.source.write_text(self.source.read_text().replace('An isolated Issue Zero rehearsal.',
                                                             '{{asset-path:missing-image}}'))
        with self.assertRaisesRegex(ValueError, 'asset references'):
            self.run_prepare()

    def test_empty_shelf_prepares_retirement_without_deleting_sources(self):
        previous = copy.deepcopy(self.manifest)
        self.manifest['issues'] = []
        report = self.run_prepare(previous=previous)
        self.assertEqual(report['noLongerListed'], ['assets/' + self.asset['id']])
        self.assertEqual(report['uploadBytes'], 0)
        self.assertTrue(self.source.exists())

    def test_referenced_media_must_survive_as_long_as_pack(self):
        self.source.write_text(self.source.read_text().replace('An isolated Issue Zero rehearsal.',
                                                             '{{asset-path:school-image}}'))
        (self.source.parent / 'image.png').write_bytes(b'rehearsal-media-bytes')
        self.issue['assets'].append(dict(id='school-image', fileName='image.png', kind='media',
            scope='runtime', isRequired=True, retiresAt=self.issue['liveEndsAt']))
        with self.assertRaisesRegex(ValueError, 'retires before its pack'):
            self.run_prepare()
        self.issue['assets'][-1]['retiresAt'] = self.issue['residueEndsAt']
        self.assertEqual(len(self.run_prepare()['upload']), 2)


if __name__ == '__main__':
    unittest.main()
