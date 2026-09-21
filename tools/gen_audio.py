#!/usr/bin/env python3
"""Generates every sound effect and the ambient music loop for Haven."""
import math, random, struct, wave

SR = 22050
OUT = "assets/sfx/"
rnd = random.Random(11)


def save(name, samples):
    peak = max(1e-9, max(abs(s) for s in samples))
    gain = 0.92 / peak if peak > 0.92 else 1.0
    with wave.open(OUT + name + ".wav", "w") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(SR)
        data = b"".join(struct.pack("<h", int(max(-1, min(1, s * gain)) * 32000)) for s in samples)
        f.writeframes(data)
    print(name, len(samples) / SR, "s")


def env(n, a, d, s_level=0.0, r=None):
    """simple attack/decay envelope over n samples, times in samples"""
    out = []
    for i in range(n):
        if i < a:
            out.append(i / max(1, a))
        else:
            t = (i - a) / max(1, d)
            out.append(max(0.0, (1 - t)) if s_level == 0 else max(s_level, 1 - t))
    return out


def expdecay(n, half):
    return [0.5 ** (i / half) for i in range(n)]


def lowpass(sig, cutoff):
    dt = 1.0 / SR
    rc = 1.0 / (2 * math.pi * cutoff)
    a = dt / (rc + dt)
    out = []
    prev = 0.0
    for s in sig:
        prev = prev + a * (s - prev)
        out.append(prev)
    return out


def highpass(sig, cutoff):
    lp = lowpass(sig, cutoff)
    return [s - l for s, l in zip(sig, lp)]


def noise(n):
    return [rnd.uniform(-1, 1) for _ in range(n)]


def tone(n, f0, f1=None, wave_kind="sin", phase0=0.0):
    f1 = f0 if f1 is None else f1
    out = []
    ph = phase0
    for i in range(n):
        t = i / max(1, n - 1)
        f = f0 * (f1 / f0) ** t
        ph += 2 * math.pi * f / SR
        if wave_kind == "sin":
            out.append(math.sin(ph))
        elif wave_kind == "tri":
            out.append(2 / math.pi * math.asin(math.sin(ph)))
        elif wave_kind == "saw":
            out.append(2 * ((ph / (2 * math.pi)) % 1.0) - 1)
        else:  # square
            out.append(1.0 if math.sin(ph) > 0 else -1.0)
    return out


def mix(*sigs):
    n = max(len(s) for s in sigs)
    out = [0.0] * n
    for s in sigs:
        for i, v in enumerate(s):
            out[i] += v
    return out


def mul(a, b):
    return [x * y for x, y in zip(a, b)]


# ------------------------------------------------------------------ step ----
n = int(SR * 0.085)
body = lowpass(noise(n), 520)
thud = tone(n, 130, 70)
save("step", mul(mix([b * 0.9 for b in body], [t * 0.5 for t in thud]), expdecay(n, n * 0.16)))

# ------------------------------------------------------------------ dash ----
n = int(SR * 0.26)
sw = highpass(lowpass(noise(n), 3000), 700)
save("dash", mul(sw, env(n, int(n * 0.08), int(n * 0.92))))

# ----------------------------------------------------------------- flare ----
n = int(SR * 0.55)
burst = mul(lowpass(noise(n), 5200), expdecay(n, n * 0.14))
rise = mul(tone(n, 320, 1400, "tri"), expdecay(n, n * 0.22))
sub = mul(tone(n, 180, 60), expdecay(n, n * 0.2))
save("flare", mix([b * 0.7 for b in burst], [r * 0.55 for r in rise], [s * 0.6 for s in sub]))

# ---------------------------------------------------------------- ignite ----
# beacon catching light: warm swell + a perfect fifth
n = int(SR * 1.0)
e = env(n, int(n * 0.12), int(n * 0.88))
a = mul(tone(n, 220, 330, "tri"), e)
b = mul(tone(n, 330, 494, "sin"), e)
c = mul(lowpass(noise(n), 1800), expdecay(n, n * 0.1))
save("ignite", mix([x * 0.5 for x in a], [x * 0.35 for x in b], [x * 0.35 for x in c]))

# ---------------------------------------------------------------- pickup ----
n1 = int(SR * 0.07)
n2 = int(SR * 0.12)
p = mul(tone(n1, 660, 660, "tri"), expdecay(n1, n1 * 0.4)) + \
    mul(tone(n2, 990, 990, "tri"), expdecay(n2, n2 * 0.3))
save("pickup", p)

# ------------------------------------------------------------------ hurt ----
n = int(SR * 0.34)
h = mul(tone(n, 240, 70, "square"), expdecay(n, n * 0.22))
g = mul(lowpass(noise(n), 900), expdecay(n, n * 0.15))
save("hurt", mix([x * 0.55 for x in h], [x * 0.7 for x in g]))

# ---------------------------------------------------------------- shadow ----
n = int(SR * 0.4)
hiss = mul(highpass(noise(n), 1400), expdecay(n, n * 0.18))
fall = mul(tone(n, 520, 90, "tri"), expdecay(n, n * 0.2))
save("shadow", mix([x * 0.75 for x in hiss], [x * 0.4 for x in fall]))

# ------------------------------------------------------------------- win ----
notes = [440.0, 523.25, 659.25, 880.0, 1046.5]
buf = [0.0] * int(SR * 2.0)
for i, f in enumerate(notes):
    start = int(SR * 0.16 * i)
    ln = int(SR * (1.4 - 0.1 * i))
    v = mul(mix(tone(ln, f, f, "tri"), [0.35 * x for x in tone(ln, f * 2, f * 2)]), expdecay(ln, ln * 0.2))
    for j, s in enumerate(v):
        if start + j < len(buf):
            buf[start + j] += s * 0.45
save("win", buf)

# ------------------------------------------------------------------ lose ----
notes = [349.23, 293.66, 261.63, 207.65]
buf = [0.0] * int(SR * 2.0)
for i, f in enumerate(notes):
    start = int(SR * 0.22 * i)
    ln = int(SR * 1.3)
    v = mul(tone(ln, f, f * 0.985, "tri"), expdecay(ln, ln * 0.25))
    for j, s in enumerate(v):
        if start + j < len(buf):
            buf[start + j] += s * 0.5
save("lose", lowpass(buf, 2200))

# ------------------------------------------------------------------ menu ----
n = int(SR * 0.09)
save("blip", mul(tone(n, 520, 780, "tri"), expdecay(n, n * 0.3)))

# ----------------------------------------------------------------- music ----
# 16 s loop, A minor: Am - F - C - G, low drone, sparse bells
LOOP = 16.0
N = int(SR * LOOP)
music = [0.0] * N

CHORDS = [
    (55.00, [220.00, 261.63, 329.63]),   # Am
    (43.65, [174.61, 220.00, 261.63]),   # F
    (65.41, [196.00, 261.63, 329.63]),   # C
    (49.00, [196.00, 246.94, 293.66]),   # G
]

for ci, (bass, chord) in enumerate(CHORDS):
    start = int(SR * 4.0 * ci)
    ln = int(SR * 4.3)
    if start + ln > N:
        ln = N - start
    # pad envelope: slow swell, slow release
    pe = []
    for i in range(ln):
        t = i / ln
        pe.append(min(1.0, t / 0.28) * max(0.0, 1.0 - max(0.0, (t - 0.55) / 0.45)) ** 1.4)
    for f in chord:
        det = mix(tone(ln, f, f, "tri"), [0.7 * x for x in tone(ln, f * 1.004, f * 1.004, "tri", 1.1)])
        det = lowpass(det, 1100)
        for j in range(ln):
            music[start + j] += det[j] * pe[j] * 0.10
    be = expdecay(ln, ln * 0.55)
    low = mix(tone(ln, bass, bass), [0.4 * x for x in tone(ln, bass * 2, bass * 2)])
    for j in range(ln):
        music[start + j] += low[j] * be[j] * 0.20

BELLS = [
    (0.8, 659.25), (2.3, 880.00), (3.4, 783.99), (5.1, 523.25),
    (6.6, 659.25), (8.2, 587.33), (9.4, 783.99), (11.0, 523.25),
    (12.4, 440.00), (13.6, 659.25), (14.8, 587.33),
]
for t0, f in BELLS:
    start = int(SR * t0)
    ln = min(int(SR * 2.4), N - start)
    if ln <= 0:
        continue
    v = mix(tone(ln, f, f),
            [0.30 * x for x in tone(ln, f * 2.01, f * 2.01)],
            [0.12 * x for x in tone(ln, f * 3.02, f * 3.02)])
    d = expdecay(ln, ln * 0.13)
    for j in range(ln):
        music[start + j] += v[j] * d[j] * 0.085

# breathy air underneath
air = lowpass(noise(N), 340)
for i in range(N):
    music[i] += air[i] * 0.05 * (0.6 + 0.4 * math.sin(2 * math.pi * i / SR / 7.0))

# crossfade the seam so the loop is clean
fade = int(SR * 0.35)
for i in range(fade):
    g = i / fade
    music[i] *= g
    music[N - 1 - i] *= g

save("music", music)
print("audio written")


# ---------------------------------------------------------------- vigil -----
# low horn swell: the dark noticing you
n = int(SR * 1.3)
e = env(n, int(n * 0.22), int(n * 0.78))
v = mix(mul(tone(n, 98.0, 82.0, "saw"), e),
        [0.6 * x for x in mul(tone(n, 49.0, 41.0), e)],
        [0.35 * x for x in mul(tone(n, 147.0, 123.0, "tri"), e)])
save("vigil", lowpass(v, 900))

# -------------------------------------------------------------- descend -----
n = int(SR * 1.4)
air = mul(lowpass(noise(n), 1600), env(n, int(n * 0.1), int(n * 0.9)))
swoop = mul(tone(n, 420, 60, "tri"), expdecay(n, n * 0.3))
bell = mul(mix(tone(n, 110, 110), [0.3 * x for x in tone(n, 221, 221)]), expdecay(n, n * 0.18))
save("descend", mix([x * 0.5 for x in air], [x * 0.55 for x in swoop], [x * 0.5 for x in bell]))

# ----------------------------------------------------------------- boon -----
buf = [0.0] * int(SR * 0.9)
for i, f in enumerate([523.25, 659.25, 880.0]):
    start = int(SR * 0.07 * i)
    ln = int(SR * 0.8)
    v = mul(mix(tone(ln, f, f, "tri"), [0.3 * x for x in tone(ln, f * 2, f * 2)]),
            expdecay(ln, ln * 0.16))
    for j, sm in enumerate(v):
        if start + j < len(buf):
            buf[start + j] += sm * 0.5
save("boon", buf)
print("v2 audio written")


# ----------------------------------------------------------------- shoot ----
n = int(SR * 0.13)
zap = mul(tone(n, 1500, 420, "tri"), expdecay(n, n * 0.16))
tick = mul(highpass(noise(n), 2200), expdecay(n, n * 0.07))
save("shoot", mix([x * 0.55 for x in zap], [x * 0.4 for x in tick]))

# -------------------------------------------------------------- discover ----
# a shadow enters the bestiary: two cold notes and a breath
buf = [0.0] * int(SR * 1.1)
for i, f in enumerate([392.0, 523.25]):
    start = int(SR * 0.16 * i)
    ln = int(SR * 0.9)
    v = mul(mix(tone(ln, f, f), [0.35 * x for x in tone(ln, f * 1.5, f * 1.5, "tri")]),
            expdecay(ln, ln * 0.2))
    for j, sm in enumerate(v):
        if start + j < len(buf):
            buf[start + j] += sm * 0.45
wash = mul(lowpass(noise(len(buf)), 1200), expdecay(len(buf), len(buf) * 0.22))
save("discover", mix(buf, [x * 0.22 for x in wash]))
print("v3 audio written")
