import sys, unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import monthly_pack  # noqa: E402


class WonderLineChecks(unittest.TestCase):
    def test_a_good_delivery_passes(self):
        pack = {"wonderLines": [{"id": "oct26-001", "nouns": ["pumpkin"], "line": "The pumpkin had been practising its face for a week."}]}
        self.assertEqual(monthly_pack.check_wonder_lines(pack), [])

    def test_bad_deliveries_say_why(self):
        pack = {"wonderLines": [
            {"id": "a", "nouns": [], "line": "A line about nothing."},
            {"id": "a", "nouns": ["moon"], "line": "The moon was a ritual of the night."},
            {"id": "c", "nouns": ["tree"], "line": "I felt the tree lean toward me."},
            {"id": "d", "nouns": ["door"], "line": "The door had no ending"},
        ]}
        errors = " | ".join(monthly_pack.check_wonder_lines(pack))
        for expected in ("duplicate ids", "needs at least one noun", "banned word", "not the Book", "ending properly"):
            self.assertIn(expected, errors)

    def test_no_wonder_lines_is_fine(self):
        self.assertEqual(monthly_pack.check_wonder_lines({}), [])


if __name__ == "__main__":
    unittest.main()


class NotePromptChecks(unittest.TestCase):
    def test_a_good_delivery_passes(self):
        pack = {"notePrompts": [{"id": "oct26-n1", "kind": "day", "text": "What did the dark come early for tonight?"}]}
        self.assertEqual(monthly_pack.check_note_prompts(pack), [])

    def test_bad_deliveries_say_why(self):
        pack = {"notePrompts": [
            {"id": "a", "kind": "sideways", "text": "Write something down today."},
            {"id": "a", "text": "A ritual for the evening, written down."},
            {"id": "c", "text": "No full stop at all here"},
        ]}
        errors = " | ".join(monthly_pack.check_note_prompts(pack))
        self.assertIn("duplicate ids", errors)
        self.assertIn("kind must be one of", errors)
        self.assertIn("banned word", errors)
        self.assertIn("ending in", errors)
