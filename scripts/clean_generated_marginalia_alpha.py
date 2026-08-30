#!/usr/bin/env python3
"""Remove generator haze from a transparent marginalia sheet."""

from pathlib import Path
from PIL import Image


SOURCE = Path("Art/Generated/academy-marginalia-tips-sprite-sheet-v1.png")
OUTPUT = Path("Art/Generated/academy-marginalia-tips-sprite-sheet-v2.png")
PREVIEW = Path("/private/tmp/academy-marginalia-tips-preview.png")


image = Image.open(SOURCE).convert("RGBA")
red, green, blue, alpha = image.split()

# Generated transparent art sometimes carries a faint full-canvas veil. Keep
# confident ink and remap its antialiasing band; discard everything beneath it.
alpha = alpha.point(lambda value: 0 if value < 150 else min(255, (value - 150) * 3))
clean = Image.merge("RGBA", (red, green, blue, alpha))
clean.save(OUTPUT)

paper = Image.new("RGBA", clean.size, (246, 240, 222, 255))
paper.alpha_composite(clean)
paper.convert("RGB").save(PREVIEW)
