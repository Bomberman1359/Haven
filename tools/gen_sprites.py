#!/usr/bin/env python3
"""Generates every sprite for Haven as pixel-art PNGs."""
import math, random
from PIL import Image, ImageDraw

random.seed(7)
OUT = "assets/sprites/"

PAL = {
    '.': (0, 0, 0, 0),
    'K': (13, 10, 20, 255),      # outline
    'c': (42, 51, 88, 255),      # cloak dark
    'C': (62, 74, 128, 255),     # cloak main
    'H': (95, 111, 174, 255),    # cloak highlight
    'F': (22, 15, 34, 255),      # face shadow
    'E': (255, 217, 138, 255),   # eye glow
    'G': (217, 164, 65, 255),    # gold trim
    'B': (36, 27, 46, 255),      # boot
    'D': (42, 16, 54, 255),      # wraith body
    'd': (23, 8, 31, 255),       # wraith edge
    'R': (255, 61, 94, 255),     # wraith eye
    'r': (255, 154, 168, 255),   # wraith eye glow
    'w': (255, 202, 107, 255),   # lantern glass
    'W': (255, 243, 196, 255),   # lantern core
    'g': (181, 131, 47, 255),    # lantern brass
    'o': (26, 18, 10, 255),      # lantern outline
    'q': (111, 208, 197, 255),   # flask glass
    'Q': (170, 240, 232, 255),   # flask shine
    'i': (255, 183, 77, 255),    # oil
    'I': (255, 226, 160, 255),   # oil bright
}


def from_rows(rows, pal=PAL):
    h = len(rows)
    w = len(rows[0])
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    px = img.load()
    for y, row in enumerate(rows):
        assert len(row) == w, f"row {y} is {len(row)} wide, expected {w}"
        for x, ch in enumerate(row):
            px[x, y] = pal[ch]
    return img


def strip(frames):
    w, h = frames[0].size
    sheet = Image.new("RGBA", (w * len(frames), h), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        sheet.paste(f, (i * w, 0))
    return sheet


# ---------------------------------------------------------------- player ----
KEEPER = [
    "......KKKKK.....",
    "....KKcccccKK...",
    "...KcCCCCCCCcK..",
    "..KcCCCCCCCCCcK.",
    "..KcCFFFFFFFCcK.",
    "..KcCFEFFFEFCcK.",
    "..KcCFFFFFFFCcK.",
    "..KcCCFFFFFCCcK.",
    "..KcCCCCCCCCCcK.",
    "..KcCCCCGGCCCcK.",
    "..KcCHCCGGCCHcK.",
    "..KcCHCCCCCCHcK.",
    "..KcCCCCCCCCCcK.",
    "..KccCCCCCCCccK.",
    "...KccCCCCCccK..",
    "...KcccCCCcccK..",
    "....KcccccccK...",
    "....KBBKKKBBK...",
    "....KBBK.KBBK...",
    ".....KK...KK....",
]


def keeper_frame(step):
    rows = list(KEEPER)
    # step: 0 = neutral, 1 = left forward, -1 = right forward
    if step == 1:
        rows[17] = "...KBBK..KBBK..."
        rows[18] = "...KBBK...KBBK.."
        rows[19] = "....KK.....KK..."
    elif step == -1:
        rows[17] = "....KBBK..KBBK.."
        rows[18] = "..KBBK.....KBBK."
        rows[19] = "...KK.......KK.."
    rows = [r[:16].ljust(16, '.') for r in rows]
    img = from_rows(rows)
    return img


def bob(img, dy):
    out = Image.new("RGBA", img.size, (0, 0, 0, 0))
    out.paste(img, (0, dy))
    return out


player = strip([
    bob(keeper_frame(0), 0),
    bob(keeper_frame(1), -1),
    bob(keeper_frame(0), 0),
    bob(keeper_frame(-1), -1),
])
player.save(OUT + "player.png")

# --------------------------------------------------------------- lantern ----
LANTERN = [
    "...o...",
    "..ogo..",
    ".ogggo.",
    "ogwwwgo",
    "ogwWwgo",
    "ogwWwgo",
    "ogwwwgo",
    "oggggo.",
    ".oooo..",
]
from_rows([r.ljust(7, '.') for r in LANTERN]).save(OUT + "lantern.png")

# ----------------------------------------------------------------- flask ----
FLASK = [
    "....oo....",
    "....oio...",
    "...oiIio..",
    "..oqIIIqo.",
    ".oqQiiiqo.",
    ".oqiiiiqo.",
    ".oqiiiiqo.",
    ".oqQiiiqo.",
    ".oqiiiiqo.",
    "..oqiiqo..",
    "...oooo...",
]
FLASK2 = [r.replace('Q', 'q') if i % 2 else r for i, r in enumerate(FLASK)]
FLASK2 = [
    "....oo....",
    "....oio...",
    "...oiIio..",
    "..oqIIIqo.",
    ".oqiiiiqo.",
    ".oqQiiiqo.",
    ".oqiiiiqo.",
    ".oqiiiiqo.",
    ".oqQiiiqo.",
    "..oqiiqo..",
    "...oooo...",
]
strip([from_rows(FLASK), from_rows(FLASK2)]).save(OUT + "flask.png")

# ---------------------------------------------------------------- beacon ----
BW, BH = 24, 32
STONE = [(58, 62, 86), (74, 79, 108), (44, 47, 68), (32, 34, 50)]


def beacon_base(lit):
    img = Image.new("RGBA", (BW, BH), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # plinth
    d.rectangle([8, 26, 15, 31], fill=STONE[2] + (255,))
    d.rectangle([6, 28, 17, 31], fill=STONE[0] + (255,))
    d.rectangle([6, 28, 17, 28], fill=STONE[1] + (255,))
    # column
    d.rectangle([9, 18, 14, 27], fill=STONE[0] + (255,))
    d.rectangle([9, 18, 10, 27], fill=STONE[1] + (255,))
    d.rectangle([13, 18, 14, 27], fill=STONE[3] + (255,))
    # bowl
    d.polygon([(4, 16), (19, 16), (16, 23), (7, 23)], fill=STONE[0] + (255,))
    d.polygon([(4, 16), (19, 16), (18, 18), (5, 18)], fill=STONE[1] + (255,))
    d.line([(4, 16), (19, 16)], fill=(28, 30, 46, 255))
    # rim + outline
    for (x, y) in [(3, 15), (20, 15)]:
        d.rectangle([x, y, x + 1, y + 2], fill=STONE[1] + (255,))
    if lit:
        d.rectangle([6, 15, 17, 16], fill=(255, 140, 60, 255))
    else:
        d.rectangle([6, 15, 17, 16], fill=(30, 28, 40, 255))
        # cold ash
        d.rectangle([8, 14, 15, 15], fill=(52, 50, 62, 255))
    return img


FLAME_CORE = (255, 246, 205)
FLAME_MID = (255, 186, 74)
FLAME_OUT = (255, 116, 40)


def flame(img, phase):
    d = ImageDraw.Draw(img)
    cx = 11.5
    h = 11 + int(2 * math.sin(phase * math.pi / 2))
    sway = math.sin(phase * math.pi / 2 + 0.8) * 1.4
    top = 15 - h
    for y in range(top, 16):
        t = (y - top) / max(1, (16 - top))
        half_out = 1.0 + 5.0 * (t ** 0.75)
        wob = math.sin(t * 5.0 + phase * 1.7) * 1.1 + sway * (1 - t)
        x0 = cx - half_out + wob
        x1 = cx + half_out + wob
        d.line([(x0, y), (x1, y)], fill=FLAME_OUT + (255,))
        half_mid = half_out * 0.62
        d.line([(cx - half_mid + wob, y), (cx + half_mid + wob, y)], fill=FLAME_MID + (255,))
        if t > 0.28:
            half_c = half_out * 0.28
            d.line([(cx - half_c + wob, y), (cx + half_c + wob, y)], fill=FLAME_CORE + (255,))
    # sparks
    for i in range(3):
        sx = cx + math.sin(phase * 2.1 + i * 2.3) * 5
        sy = top - 2 - ((phase * 2 + i * 3) % 6)
        if 0 <= sy < BH and 0 <= sx < BW:
            d.point((sx, sy), fill=(255, 205, 120, 255))
    return img


frames = [beacon_base(False)]
for i in range(4):
    frames.append(flame(beacon_base(True), i))
strip(frames).save(OUT + "beacon.png")

# ----------------------------------------------------------- floor / wall ----
TS = 32


def floor_tile(seed):
    rnd = random.Random(seed)
    img = Image.new("RGBA", (TS, TS), (0, 0, 0, 0))
    px = img.load()
    base = (60, 63, 86)
    for y in range(TS):
        for x in range(TS):
            n = rnd.randint(-7, 7)
            c = (base[0] + n, base[1] + n, base[2] + n)
            px[x, y] = c + (255,)
    d = ImageDraw.Draw(img)
    # flagstone seams
    d.line([(0, 0), (TS - 1, 0)], fill=(40, 42, 60, 255))
    d.line([(0, 0), (0, TS - 1)], fill=(40, 42, 60, 255))
    d.line([(0, TS - 1), (TS - 1, TS - 1)], fill=(76, 80, 108, 255))
    if seed % 4 == 1:
        d.line([(0, 16), (TS - 1, 16)], fill=(45, 47, 68, 255))
    if seed % 4 == 2:
        d.line([(16, 0), (16, TS - 1)], fill=(45, 47, 68, 255))
    # debris / moss
    for _ in range(rnd.randint(2, 6)):
        x, y = rnd.randint(2, TS - 3), rnd.randint(2, TS - 3)
        if rnd.random() < 0.35:
            px[x, y] = (76, 128, 98, 255)
            px[x + 1, y] = (62, 106, 80, 255)
        else:
            px[x, y] = (45, 47, 66, 255)
    return img


strip([floor_tile(s) for s in range(4)]).save(OUT + "floor.png")


def wall_tile(seed, face):
    rnd = random.Random(100 + seed)
    img = Image.new("RGBA", (TS, TS), (0, 0, 0, 0))
    px = img.load()
    base = (21, 23, 38)
    for y in range(TS):
        for x in range(TS):
            n = rnd.randint(-5, 5)
            px[x, y] = (base[0] + n, base[1] + n, base[2] + n, 255)
    d = ImageDraw.Draw(img)
    # brick courses
    for row in range(2):
        y = row * 16
        d.line([(0, y), (TS - 1, y)], fill=(18, 20, 34, 255))
        d.line([(0, y + 1), (TS - 1, y + 1)], fill=(34, 37, 58, 255))
        ox = 0 if row % 2 == 0 else 16
        d.line([(ox, y), (ox, y + 15)], fill=(18, 20, 34, 255))
    d.line([(0, 0), (0, TS - 1)], fill=(20, 22, 36, 255))
    for _ in range(rnd.randint(3, 7)):
        x, y = rnd.randint(1, TS - 2), rnd.randint(2, TS - 2)
        px[x, y] = (24, 26, 42, 255)
    if face:
        # sunlit-ish top lip where the wall meets open floor below
        d.rectangle([0, TS - 6, TS - 1, TS - 1], fill=(15, 16, 28, 255))
        d.line([(0, TS - 6), (TS - 1, TS - 6)], fill=(104, 112, 158, 255))
        d.line([(0, TS - 5), (TS - 1, TS - 5)], fill=(66, 72, 108, 255))
    return img


strip([wall_tile(s, s >= 2) for s in range(4)]).save(OUT + "wall.png")

# ----------------------------------------------------------------- light ----
LS = 256
light = Image.new("RGBA", (LS, LS))
px = light.load()
c = (LS - 1) / 2.0
for y in range(LS):
    for x in range(LS):
        r = math.hypot(x - c, y - c) / c
        if r >= 1.0:
            px[x, y] = (255, 255, 255, 0)
        else:
            a = (1.0 - r)
            a = a * a * (3 - 2 * a)      # smoothstep
            a = a ** 1.25
            px[x, y] = (255, 255, 255, int(255 * a))
light.save(OUT + "light.png")

# glow used for the flare ring: hard bright core, quick falloff
flare = Image.new("RGBA", (LS, LS))
px = flare.load()
for y in range(LS):
    for x in range(LS):
        r = math.hypot(x - c, y - c) / c
        a = max(0.0, 1.0 - r) ** 0.95
        px[x, y] = (255, 255, 255, int(255 * a))
flare.save(OUT + "flare.png")

# ---------------------------------------------------------------- spark ------
S = 8
spark = Image.new("RGBA", (S, S))
px = spark.load()
sc = (S - 1) / 2.0
for y in range(S):
    for x in range(S):
        r = math.hypot(x - sc, y - sc) / (sc + 0.5)
        a = max(0.0, 1.0 - r) ** 1.1
        px[x, y] = (255, 255, 255, int(255 * a))
spark.save(OUT + "spark.png")

# ----------------------------------------------------------------- heart -----
HEART = [
    ".RR.RR.",
    "RRRRRRR",
    "RRRRRRR",
    ".RRRRR.",
    "..RRR..",
    "...R...",
]
HPAL = dict(PAL)
HPAL['R'] = (255, 92, 108, 255)
h1 = from_rows(HEART, HPAL)
HPAL2 = dict(PAL)
HPAL2['R'] = (72, 44, 62, 255)
h0 = from_rows(HEART, HPAL2)
strip([h1, h0]).save(OUT + "heart.png")

print("sprites written")


# ============================================================ shadow kinds ===
# One parametric wraith so every shadow reads as the same family of thing.

def wraith(w, h, body, edge, eye, eye_hi, frame, tents=3, eye_row=0.38,
           eye_w=2, eye_h=2, eye_gap=6, horns=0, plates=False):
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    px = img.load()
    cx = (w - 1) / 2.0
    body_h = int(round(h * 0.70))
    maxhw = (w - 2) / 2.0

    for y in range(body_h):
        t = y / max(1, body_h - 1)
        if t < 0.34:
            k = max(0.0, 1.0 - ((0.34 - t) / 0.34) ** 2)
            hw = maxhw * math.sqrt(k)
        else:
            hw = maxhw * (1.0 - 0.07 * (t - 0.34))
        hw *= 1.0 + 0.035 * math.sin(frame * math.pi / 2.0 + t * 2.2)
        x0 = int(round(cx - hw))
        x1 = int(round(cx + hw))
        if x1 < x0:
            continue
        for x in range(x0, x1 + 1):
            if 0 <= x < w:
                px[x, y] = body + (255,)
        for x in (x0, x1):
            if 0 <= x < w:
                px[x, y] = edge + (255,)

    if plates:
        lighter = tuple(min(255, c + 26) for c in body)
        for row in (int(body_h * 0.74), int(body_h * 0.90)):
            for x in range(w):
                if px[x, row][3] > 0 and px[x, row][:3] == body:
                    px[x, row] = lighter + (255,)

    # tattered underside
    tail_h = h - body_h
    span = maxhw * 1.55
    for i in range(tents):
        tx = cx if tents == 1 else cx - span / 2.0 + span * (i / (tents - 1.0))
        ln = int(round(tail_h * (0.40 + 0.55 * (0.5 + 0.5 * math.sin(frame * 1.55 + i * 2.2)))))
        for yy in range(body_h, min(h, body_h + max(1, ln))):
            sway = int(round(math.sin((yy - body_h) * 0.7 + frame * 1.2 + i) * 0.9))
            last = yy >= body_h + ln - 2
            for dx in (-1, 0):
                x = int(round(tx)) + dx + sway
                if 0 <= x < w:
                    px[x, yy] = (edge if last else body) + (255,)

    if horns:
        for side in (-1, 1):
            for k in range(horns + 2):
                x = int(round(cx + side * (maxhw * 0.60 + k * 1.15)))
                y = int(round(body_h * 0.26)) - k * 2
                for yy in (y, y + 1):
                    if 0 <= x < w and 0 <= yy < h:
                        px[x, yy] = edge + (255,)
                    if 0 <= x - side < w and 0 <= yy < h and px[x - side, yy][3] == 0:
                        px[x - side, yy] = body + (255,)

    ey = int(round(h * eye_row))
    for side in (-1, 1):
        left = int(round(cx + side * eye_gap / 2.0))
        if side < 0:
            left -= eye_w - 1
        d.rectangle([left, ey, left + eye_w - 1, ey + eye_h - 1], fill=eye + (255,))
        gx = left if side > 0 else left + eye_w - 1
        if 0 <= gx < w and ey + eye_h - 1 < h:
            px[gx, ey + eye_h - 1] = eye_hi + (255,)
    return img


KINDS = {
    # name:      w   h  body             edge            eye              highlight       tents eye_gap ew eh extras
    "wisp":     (16, 16, (42, 16, 54),   (23, 8, 31),    (255, 61, 94),   (255, 154, 168), 3, 6,  2, 2, {}),
    "husk":     (22, 22, (34, 26, 68),   (17, 12, 38),   (255, 122, 58),  (255, 204, 144), 4, 9,  3, 3, {"plates": True}),
    "stalker":  (14, 20, (19, 21, 42),   (8, 9, 20),     (232, 246, 255), (255, 255, 255), 2, 5,  1, 3, {"eye_row": 0.28}),
    "leech":    (16, 18, (20, 48, 54),   (8, 24, 30),    (122, 255, 212), (224, 255, 244), 5, 5,  2, 2, {"eye_row": 0.34}),
    "splitter": (18, 18, (54, 20, 62),   (28, 8, 34),    (255, 210, 90),  (255, 246, 200), 3, 7,  3, 2, {}),
    "brute":    (28, 26, (44, 15, 22),   (21, 6, 11),    (255, 92, 40),   (255, 192, 122), 4, 12, 4, 3, {"horns": 3, "plates": True}),
}

for nm, (w, h, body, edge, eye, hi, tents, gap, ew, eh, extra) in KINDS.items():
    fr = [wraith(w, h, body, edge, eye, hi, f, tents=tents, eye_gap=gap,
                 eye_w=ew, eye_h=eh, **extra) for f in range(4)]
    strip(fr).save(OUT + "%s.png" % nm)

# ------------------------------------------------------- beacon, mark two ---
BW2, BH2 = 32, 48
STONE2 = [(64, 68, 94), (86, 92, 124), (48, 51, 74), (33, 35, 52)]


def beacon2_base(lit):
    img = Image.new("RGBA", (BW2, BH2), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # stepped plinth
    d.rectangle([4, 42, 27, 47], fill=STONE2[2] + (255,))
    d.rectangle([4, 42, 27, 43], fill=STONE2[1] + (255,))
    d.rectangle([7, 38, 24, 42], fill=STONE2[0] + (255,))
    d.rectangle([7, 38, 24, 39], fill=STONE2[1] + (255,))
    # fluted column
    d.rectangle([11, 24, 20, 39], fill=STONE2[0] + (255,))
    d.rectangle([11, 24, 12, 39], fill=STONE2[1] + (255,))
    d.rectangle([19, 24, 20, 39], fill=STONE2[3] + (255,))
    for y in range(26, 38, 4):
        d.line([(14, y), (17, y)], fill=STONE2[2] + (255,))
    # wide bowl
    d.polygon([(2, 20), (29, 20), (24, 30), (7, 30)], fill=STONE2[0] + (255,))
    d.polygon([(2, 20), (29, 20), (27, 23), (4, 23)], fill=STONE2[1] + (255,))
    d.line([(2, 20), (29, 20)], fill=(30, 32, 48, 255))
    # horns on the rim
    for x in (1, 28):
        d.rectangle([x, 17, x + 2, 21], fill=STONE2[1] + (255,))
        d.rectangle([x, 17, x + 2, 17], fill=STONE2[3] + (255,))
    if lit:
        d.rectangle([5, 18, 26, 20], fill=(255, 146, 62, 255))
    else:
        d.rectangle([5, 18, 26, 20], fill=(32, 30, 44, 255))
        d.rectangle([9, 17, 22, 18], fill=(56, 54, 68, 255))
    return img


def flame2(img, phase):
    d = ImageDraw.Draw(img)
    cx = 15.5
    h = 19 + int(3 * math.sin(phase * math.pi / 2))
    sway = math.sin(phase * math.pi / 2 + 0.8) * 1.8
    top = 19 - h
    for y in range(top, 20):
        t = (y - top) / max(1, (20 - top))
        half = 1.2 + 9.5 * (t ** 0.8)
        wob = math.sin(t * 5.4 + phase * 1.7) * 1.5 + sway * (1 - t)
        d.line([(cx - half + wob, y), (cx + half + wob, y)], fill=FLAME_OUT + (255,))
        d.line([(cx - half * 0.62 + wob, y), (cx + half * 0.62 + wob, y)], fill=FLAME_MID + (255,))
        if t > 0.24:
            d.line([(cx - half * 0.3 + wob, y), (cx + half * 0.3 + wob, y)], fill=FLAME_CORE + (255,))
    for i in range(5):
        sx = cx + math.sin(phase * 2.0 + i * 1.9) * 8
        sy = top - 2 - ((phase * 3 + i * 4) % 10)
        if 0 <= sy < BH2 and 0 <= sx < BW2:
            d.point((sx, sy), fill=(255, 208, 128, 255))
            d.point((sx, sy + 1), fill=(255, 168, 80, 255))
    return img


b2 = [beacon2_base(False)] + [flame2(beacon2_base(True), i) for i in range(4)]
strip(b2).save(OUT + "beacon.png")

# ------------------------------------------------------------------ stair ---
def stair_frame(f):
    img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([2, 2, 29, 29], fill=(14, 15, 26, 255))
    d.rectangle([2, 2, 29, 3], fill=(70, 76, 110, 255))
    for i in range(5):
        y = 6 + i * 5
        inset = 3 + i * 2
        shade = 92 - i * 15
        d.rectangle([inset, y, 31 - inset, y + 3], fill=(shade, shade + 6, shade + 26, 255))
        d.line([(inset, y), (31 - inset, y)], fill=(shade + 34, shade + 40, shade + 62, 255))
    glow = 150 + int(50 * math.sin(f * math.pi / 2))
    d.rectangle([12, 26, 19, 29], fill=(glow // 3, glow // 2, glow, 255))
    d.rectangle([0, 0, 31, 1], fill=(9, 9, 17, 255))
    d.rectangle([0, 30, 31, 31], fill=(9, 9, 17, 255))
    d.rectangle([0, 0, 1, 31], fill=(9, 9, 17, 255))
    d.rectangle([30, 0, 31, 31], fill=(9, 9, 17, 255))
    d.rectangle([2, 2, 2, 29], fill=(46, 50, 76, 255))
    d.rectangle([29, 2, 29, 29], fill=(46, 50, 76, 255))
    return img


strip([stair_frame(f) for f in range(4)]).save(OUT + "stair.png")

print("v2 sprites written")


# ------------------------------------------------------------------ bolt ----
def bolt_frame(f):
    w, h = 12, 6
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    px = img.load()
    cy = (h - 1) / 2.0
    wob = 0.25 * math.sin(f * math.pi)
    for x in range(w):
        t = x / (w - 1.0)                      # 0 = tail, 1 = head
        rad = 0.35 + (2.2 + wob) * (t ** 1.6)
        for y in range(h):
            d = abs(y - cy) / max(0.55, rad)
            if d > 1.0:
                continue
            a = (1.0 - d) ** 0.7
            if t > 0.72:
                c = (255, 247, 214)
            elif t > 0.42:
                c = (255, 206, 120)
            else:
                c = (255, 150, 60)
            px[x, y] = c + (int(255 * a * (0.42 + 0.58 * t)),)
    return img


strip([bolt_frame(f) for f in range(2)]).save(OUT + "bolt.png")
print("bolt written")
