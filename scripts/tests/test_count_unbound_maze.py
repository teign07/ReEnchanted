import json
from pathlib import Path
import struct
import unittest


ROOT = Path(__file__).resolve().parents[2] / 'ContentPacks/count-unbound'


class CountUnboundMazeTests(unittest.TestCase):
    def test_printed_maze_has_an_ordered_unique_solution_and_a_false_chair(self):
        answer = json.loads((ROOT / 'map-the-door-home.answer.json').read_text())
        route = [tuple(map(int, pair.split(','))) for pair in answer['solution'].split(' -> ')]
        self.assertEqual(route[0], (1, 1))
        self.assertEqual(route[-1], (11, 11))
        self.assertEqual(len(route), len(set(route)))
        self.assertTrue(all(abs(x1-x2) + abs(y1-y2) == 1
                            for (x1, y1), (x2, y2) in zip(route, route[1:])))
        self.assertEqual(sorted(route.index(tuple(answer['checkpoints'][name]))
                                for name in ('source', 'invitation', 'claim released')),
                         [route.index(tuple(answer['checkpoints'][name]))
                          for name in ('source', 'invitation', 'claim released')])
        self.assertNotIn(tuple(answer['redChair']), route)
        image = (ROOT / 'map-the-door-home.png').read_bytes()
        self.assertEqual(image[:8], b'\x89PNG\r\n\x1a\n')
        width, height = struct.unpack('>II', image[16:24])
        self.assertGreaterEqual(width, 1500)
        self.assertGreaterEqual(height, 1800)

    def test_both_print_cadences_use_the_same_answered_map(self):
        pack = json.loads((ROOT / 'paper.editionplay.json').read_text())
        route = [tuple(map(int, pair.split(','))) for pair in
                 json.loads((ROOT / 'map-the-door-home.answer.json').read_text())['solution'].split(' -> ')]
        compass = {(1, 0): 'E', (-1, 0): 'W', (0, 1): 'S', (0, -1): 'N'}
        directions = ''.join(compass[(x2-x1, y2-y1)]
                             for (x1, y1), (x2, y2) in zip(route, route[1:]))
        maps = [leaf for leaf in pack['leaves'] if leaf['form'] == 'map']
        self.assertEqual({leaf['cadence'] for leaf in maps}, {'weekly', 'monthly'})
        self.assertTrue(all(leaf['answerKey'] == f'C → {directions} → B' for leaf in maps))
        self.assertEqual(pack['eventStartYear'], 2026)


if __name__ == '__main__':
    unittest.main()
