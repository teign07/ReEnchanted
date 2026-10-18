"""Pack authoring checks; these run without building the app."""
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


VALIDATOR = Path(__file__).resolve().parents[1] / "validate_page_pack.py"


class LeafPresentationPackTests(unittest.TestCase):
    def validate(self, **changes):
        pack = {
            "id": "proof", "displayName": "Proof", "version": 1,
            "author": "The Book", "availability": "bundledFree", "archetypes": [],
            "interleafIllustrations": [{
                "id": "door", "assetName": "{{asset-path:proof.door.v1}}",
                "title": "The door", "tags": ["door"],
                "placementTrigger": {"months": [10], "issueYear": 2026,
                                     "worldEventPhases": ["BUILDUP"]},
            }],
        }
        pack.update(changes)
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "proof.reenchantedpack.json"
            path.write_text(json.dumps(pack))
            return subprocess.run([sys.executable, str(VALIDATOR), str(path)], capture_output=True, text=True)

    def test_illustration_only_pack_and_managed_asset_reference_are_valid(self):
        result = self.validate()
        self.assertEqual(result.returncode, 0, result.stdout)

    def test_invalid_gate_is_rejected(self):
        result = self.validate(interleafIllustrations=[{
            "id": "door", "assetName": "Door", "title": "Door", "tags": [],
            "placementTrigger": {"months": [13], "issueYear": "2026"},
        }])
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("months", result.stdout)
        self.assertIn("issueYear", result.stdout)

    def test_duplicate_plate_is_rejected(self):
        plate = {"id": "door", "assetName": "Door", "title": "Door", "tags": []}
        result = self.validate(interleafIllustrations=[plate, plate])
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("duplicate illustration", result.stdout)

    def test_invalid_density_is_rejected(self):
        result = self.validate(archetypes=[{
            "id": "proof", "title": "Proof", "headline": "Proof", "detail": "Proof",
            "reason": "Proof", "bodyTemplate": "Proof", "leafMarginaliaDensity": "chaos",
        }])
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("leafMarginaliaDensity", result.stdout)


if __name__ == "__main__":
    unittest.main()
