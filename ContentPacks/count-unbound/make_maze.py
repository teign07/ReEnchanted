#!/usr/bin/env python3
"""Draw and verify October's printable door maze. No random content at runtime."""
from collections import deque
from pathlib import Path
import json
import random

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parent
SIDE = 11
randomizer = random.Random(20261028)
neighbors = {(x, y): set() for y in range(SIDE) for x in range(SIDE)}
visited = {(0, 0)}
stack = [(0, 0)]
while stack:
    x, y = stack[-1]
    choices = [(nx, ny) for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1))
               if 0 <= nx < SIDE and 0 <= ny < SIDE and (nx, ny) not in visited]
    if not choices:
        stack.pop()
        continue
    next_cell = randomizer.choice(choices)
    neighbors[(x, y)].add(next_cell)
    neighbors[next_cell].add((x, y))
    visited.add(next_cell)
    stack.append(next_cell)

start, finish = (0, 0), (SIDE - 1, SIDE - 1)
queue = deque([start])
previous = {start: None}
while queue:
    cell = queue.popleft()
    for next_cell in neighbors[cell]:
        if next_cell not in previous:
            previous[next_cell] = cell
            queue.append(next_cell)
path = []
cursor = finish
while cursor is not None:
    path.append(cursor)
    cursor = previous[cursor]
path.reverse()
assert path[0] == start and path[-1] == finish and len(path) >= 20
checkpoints = [path[len(path) * fraction // 4] for fraction in (1, 2, 3)]
assert len(set(checkpoints)) == 3
assert [path.index(cell) for cell in checkpoints] == sorted(path.index(cell) for cell in checkpoints)
chair = next(cell for cell, adjacent in neighbors.items()
             if len(adjacent) == 1 and cell not in path and cell != start)

width, height = 1700, 1930
image = Image.new("RGB", (width, height), "#fffdf7")
draw = ImageDraw.Draw(image)
font_path = "/System/Library/Fonts/Supplemental/Arial.ttf"
font = ImageFont.truetype(font_path, 41)
small = ImageFont.truetype(font_path, 33)
bold = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial Bold.ttf", 43)
left, top, cell_size = 155, 190, 126
ink = "#211b1a"
draw.text((left, 40), "THE DOOR HOME", font=bold, fill=ink)
draw.text((left, 101), "Begin at COUNT. Find BOOK. Visit 1, 2, 3 in order.", font=small, fill=ink)
for y in range(SIDE):
    for x in range(SIDE):
        cx, cy = left + x * cell_size, top + y * cell_size
        cell = (x, y)
        if y == 0 or (x, y - 1) not in neighbors[cell]:
            draw.line((cx, cy, cx + cell_size, cy), fill=ink, width=10)
        if x == 0 or (x - 1, y) not in neighbors[cell]:
            draw.line((cx, cy, cx, cy + cell_size), fill=ink, width=10)
        if y == SIDE - 1:
            draw.line((cx, cy + cell_size, cx + cell_size, cy + cell_size), fill=ink, width=10)
        if x == SIDE - 1:
            draw.line((cx + cell_size, cy, cx + cell_size, cy + cell_size), fill=ink, width=10)

def mark(cell, label, fill="#f2e4bd"):
    x, y = cell
    cx = left + (x + .5) * cell_size
    cy = top + (y + .5) * cell_size
    radius = 42
    draw.ellipse((cx-radius, cy-radius, cx+radius, cy+radius), fill=fill, outline=ink, width=5)
    bounds = draw.textbbox((0, 0), label, font=bold)
    draw.text((cx-(bounds[2]-bounds[0])/2, cy-(bounds[3]-bounds[1])/2-bounds[1]),
              label, font=bold, fill=ink)

mark(start, "C")
mark(finish, "B")
for number, cell in enumerate(checkpoints, 1):
    mark(cell, str(number))
mark(chair, "R", "#f4d9d6")
legend_y = top + SIDE * cell_size + 40
for line in ("C  COUNT     1  SOURCE     2  INVITATION",
             "3  THE CLAIM RELEASED     B  OPEN BOOK",
             "R  THE RED CHAIR IS A DISTRACTION"):
    draw.text((left, legend_y), line, font=small, fill=ink)
    legend_y += 72
image.save(ROOT / "map-the-door-home.png", optimize=True)

answer = " -> ".join(f"{x+1},{y+1}" for x, y in path)
(ROOT / "map-the-door-home.answer.json").write_text(json.dumps({
    "solution": answer,
    "checkpoints": {label: [x+1, y+1] for label, (x, y) in zip(
        ("source", "invitation", "claim released"), checkpoints)},
    "redChair": [chair[0]+1, chair[1]+1],
}, indent=2) + "\n")
print(f"Verified {len(path)}-cell unique path; {len(visited)} maze cells; chair is off the solution")
