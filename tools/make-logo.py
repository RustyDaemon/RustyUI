"""
Draws RustyUI's logo, the project avatar for CurseForge: a rusted pixel "R" on the kit's dark
panel, with RUSTY UI under it in Rusty Pixel. Everything is laid out on a 50x50 grid and scaled
up with no smoothing, so the pixels stay square.

    pip install pillow
    python tools/make-logo.py     # writes assets/logo.png (400x400) and assets/logo-800.png
"""

import os
import random

from PIL import Image

GRID = 50
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# The kit's palette (kit/Palette.lua), as 0-255.
def rgb(r, g, b):
    return (round(r * 255), round(g * 255), round(b * 255))

WINDOW = rgb(0.043, 0.047, 0.055)
PANEL = rgb(0.082, 0.086, 0.098)
BORDER = rgb(0.176, 0.188, 0.216)
BORDER_LIGHT = rgb(0.239, 0.255, 0.290)
TEXT_DIM = rgb(0.596, 0.620, 0.678)
GOLD = rgb(1.000, 0.820, 0.300)
RUST = rgb(0.945, 0.522, 0.298)
RUST_DIM = rgb(0.580, 0.298, 0.157)
RUST_LIT = rgb(0.240, 0.118, 0.059)
DARK_RUST = (92, 40, 20)

# Rusty Pixel's glyphs (MyLootHistory/tools/font/build_font.py), the letters the logo uses.
GLYPHS = {
    "R": ["####.", "#...#", "#...#", "####.", "#.#..", "#..#.", "#...#"],
    "U": ["#...#", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
    "S": [".###.", "#...#", "#....", ".###.", "....#", "#...#", ".###."],
    "T": ["#####", "..#..", "..#..", "..#..", "..#..", "..#..", "..#.."],
    "Y": ["#...#", "#...#", ".#.#.", "..#..", "..#..", "..#..", "..#.."],
    "I": ["###", ".#.", ".#.", ".#.", ".#.", ".#.", "###"],
    " ": ["..."] * 7,
}

# The logo's own R, two blocks thick, so its leg steps down as one piece instead of loose corners.
BIG_R = [
    "######.",
    "##...##",
    "##...##",
    "######.",
    "##.##..",
    "##..##.",
    "##...##",
]


def mix(a, b, t):
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))


def text_width(text):
    return sum(len(GLYPHS[c][0]) for c in text) + len(text) - 1


def main():
    random.seed(7)  # the same rust spots every time
    img = Image.new("RGB", (GRID, GRID), WINDOW)
    px = img.load()

    def put(x, y, color):
        if 0 <= x < GRID and 0 <= y < GRID:
            px[x, y] = color

    # A warm glow behind the letter: the accent's lit shade, fading out from the middle.
    cx, cy = 24.5, 19
    for y in range(GRID):
        for x in range(GRID):
            d = ((x - cx) ** 2 + (y - cy) ** 2) ** 0.5
            t = max(0.0, 1 - d / 26)
            px[x, y] = mix(WINDOW, RUST_LIT, t * t * 0.9)

    # The kit's window edge: a light one-pixel border with a dark rim inside it.
    for i in range(GRID):
        for x, y in ((i, 0), (i, GRID - 1), (0, i), (GRID - 1, i)):
            put(x, y, BORDER_LIGHT)
        for x, y in ((i, 1), (i, GRID - 2), (1, i), (GRID - 2, i)):
            if 1 <= x <= GRID - 2 and 1 <= y <= GRID - 2:
                put(x, y, (0, 0, 0))

    # The big R: each glyph pixel a 4x4 block, beveled, shaded gold at the top to rust at the foot.
    scale, top = 4, 6
    rows = BIG_R
    left = (GRID - len(rows[0]) * scale) // 2
    height = len(rows) * scale

    ink = {(gx, gy) for gy, row in enumerate(rows) for gx, c in enumerate(row) if c == "#"}

    # Shadow first, one pixel down and right of every block.
    for gx, gy in ink:
        for dy in range(scale):
            for dx in range(scale):
                put(left + gx * scale + dx + 1, top + gy * scale + dy + 1, (0, 0, 0))

    for gx, gy in ink:
        for dy in range(scale):
            for dx in range(scale):
                x, y = left + gx * scale + dx, top + gy * scale + dy
                t = (y - top) / (height - 1)
                color = mix(GOLD, RUST, t * 1.6) if t < 0.62 else mix(RUST, RUST_DIM, (t - 0.62) / 0.38)

                # Bevel: light top-left edges, dark bottom-right, where a block has no neighbour.
                if dy == 0 and (gx, gy - 1) not in ink or dx == 0 and (gx - 1, gy) not in ink:
                    color = mix(color, (255, 236, 190), 0.45)
                elif dy == scale - 1 and (gx, gy + 1) not in ink or dx == scale - 1 and (gx + 1, gy) not in ink:
                    color = mix(color, DARK_RUST, 0.55)

                put(x, y, color)

    # Rust spots, more of them lower down, never on a bevel's light edge.
    for gx, gy in ink:
        for dy in range(1, scale):
            for dx in range(1, scale):
                x, y = left + gx * scale + dx, top + gy * scale + dy
                if random.random() < 0.05 + 0.18 * (gy / len(rows)):
                    put(x, y, mix(px[x, y], DARK_RUST, 0.6))

    # RUSTY UI under it, one pixel per glyph pixel.
    label = "RUSTY UI"
    x = (GRID - text_width(label)) // 2
    y0 = top + height + 6

    for c in label:
        glyph = GLYPHS[c]
        for gy, row in enumerate(glyph):
            for gx, cell in enumerate(row):
                if cell == "#":
                    put(x + gx + 1, y0 + gy + 1, (0, 0, 0))
                    put(x + gx, y0 + gy, TEXT_DIM)
        x += len(glyph[0]) + 1

    # An accent rule between the letter and the name, like the kit's section headings.
    rule_y = top + height + 3
    for x in range(14, GRID - 14):
        put(x, rule_y, mix(RUST_DIM, WINDOW, abs(x - 24.5) / 12))

    out = os.path.join(ROOT, "assets")
    os.makedirs(out, exist_ok=True)

    for size, name in ((400, "logo.png"), (800, "logo-800.png")):
        img.resize((size, size), Image.NEAREST).save(os.path.join(out, name))
        print("wrote assets/" + name)


if __name__ == "__main__":
    main()
