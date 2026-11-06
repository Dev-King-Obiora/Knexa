import math, os
from PIL import Image, ImageDraw

NAVY, DEEP = (29, 53, 87), (10, 23, 41)
GOLD, CREAM = (215, 181, 115), (241, 234, 216)
os.makedirs("icons", exist_ok=True)

def make(size, maskable):
    s = size * 4                      # supersample for smooth edges
    img = Image.new("RGBA", (s, s))
    d = ImageDraw.Draw(img)
    for y in range(s):
        t = y / (s - 1)
        d.line([(0, y), (s, y)], fill=tuple(round(NAVY[i] * (1 - t) + DEEP[i] * t) for i in range(3)) + (255,))
    cx = cy = s / 2
    R = s * (0.30 if maskable else 0.34)   # maskable glyph stays inside the 80% safe zone
    pts = [(cx + R * math.cos(math.radians(a)), cy + R * math.sin(math.radians(a))) for a in range(-90, 270, 60)]
    d.line(pts + [pts[0]], fill=GOLD, width=int(s * 0.018), joint="curve")
    k = int(s * 0.04)
    d.line([(cx - 0.22 * R, cy - 0.5 * R), (cx - 0.22 * R, cy + 0.5 * R)], fill=CREAM, width=k)
    d.line([(cx + 0.3 * R, cy - 0.5 * R), (cx - 0.2 * R, cy)], fill=CREAM, width=k)
    d.line([(cx - 0.2 * R, cy), (cx + 0.3 * R, cy + 0.5 * R)], fill=CREAM, width=k)
    if not maskable:
        mask = Image.new("L", (s, s), 0)
        ImageDraw.Draw(mask).rounded_rectangle([0, 0, s - 1, s - 1], radius=int(s * 0.22), fill=255)
        img.putalpha(mask)
    name = "icon-maskable-512" if maskable else f"icon-{size}"
    img.resize((size, size), Image.LANCZOS).save(f"icons/{name}.png")

make(192, False)
make(512, False)
make(512, True)
print("Icons written to ./icons")