"""Generates the minimap shape textures in media/minimap.

Each shape gets three 256x256 32-bit TGAs, white with the shape in the alpha channel:

  mask-<shape>    the minimap's mask: opaque inside the shape, edges anti-aliased
  border-<shape>  a band just inside the edge, tinted in game for the outline
  shadow-<shape>  a soft falloff around the shape, drawn smaller so the falloff fits;
                  the shape spans SHADOW_INNER of the texture, the rest is the falloff

Run from the repo root: py tools/make-minimap-masks.py
"""

import math
import os
import struct

SIZE = 256
BORDER_PX = 3.0
SHADOW_INNER = 200
SHADOW_PX = (SIZE - SHADOW_INNER) / 2

OUT = os.path.join(os.path.dirname(__file__), "..", "media", "minimap")


def sd_circle(x, y):
    return math.hypot(x, y) - 1.0


def sd_rounded(x, y, radius=0.28):
    qx, qy = abs(x) - (1.0 - radius), abs(y) - (1.0 - radius)
    outside = math.hypot(max(qx, 0.0), max(qy, 0.0))
    inside = min(max(qx, qy), 0.0)

    return outside + inside - radius


# A flat-topped hexagon as wide as the texture (after Inigo Quilez's sdHexagon). Its height is
# sqrt(3)/2 of its width, so the map shows a little less top and bottom than side to side.
def sd_hexagon(x, y):
    kx, ky, kz = -0.866025404, 0.5, 0.577350269
    r = 0.866025404

    px, py = abs(x), abs(y)
    d = 2.0 * min(kx * px + ky * py, 0.0)
    px -= d * kx
    py -= d * ky
    px -= max(-kz * r, min(px, kz * r))
    py -= r

    return math.hypot(px, py) * (1.0 if py > 0 else -1.0)


SHAPES = {
    "rounded": sd_rounded,
    "round": sd_circle,
    "hexagon": sd_hexagon,
}


def clamp01(v):
    return 0.0 if v < 0.0 else 1.0 if v > 1.0 else v


def render(sdf, alpha_of, extent):
    """extent: the texture width in shape units (2.0 means the shape fills it)."""
    pixels = bytearray()
    units_per_px = extent / SIZE

    for row in range(SIZE):
        for col in range(SIZE):
            x = (col + 0.5) * units_per_px - extent / 2
            y = extent / 2 - (row + 0.5) * units_per_px
            distance_px = sdf(x, y) / units_per_px
            a = int(round(clamp01(alpha_of(distance_px)) * 255))
            pixels += bytes((255, 255, 255, a))

    return pixels


def write_tga(path, pixels):
    # Uncompressed true color, 32 bits, 8 alpha bits, origin top left.
    header = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, SIZE, SIZE, 32, 0x28)
    bgra = bytearray(pixels)
    bgra[0::4], bgra[2::4] = pixels[2::4], pixels[0::4]

    with open(path, "wb") as f:
        f.write(header + bytes(bgra))


def main():
    os.makedirs(OUT, exist_ok=True)

    for name, sdf in SHAPES.items():
        mask = render(sdf, lambda d: 0.5 - d, 2.0)
        border = render(sdf, lambda d: min(0.5 - d, d + BORDER_PX + 0.5), 2.0)
        shadow = render(sdf, lambda d: max(1.0 - d / SHADOW_PX, 0.0) ** 2 if d > 0 else 1.0,
                        2.0 * SIZE / SHADOW_INNER)

        write_tga(os.path.join(OUT, "mask-%s.tga" % name), mask)
        write_tga(os.path.join(OUT, "border-%s.tga" % name), border)
        write_tga(os.path.join(OUT, "shadow-%s.tga" % name), shadow)

        print("wrote", name)


if __name__ == "__main__":
    main()
