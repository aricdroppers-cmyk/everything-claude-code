# One source of truth for the store icons: generates Lua (for the game) and JSON (for the preview).
import json, math, sys

def P(shape, size, pos=(0,0,0), rot=(0,0,0), color=(255,255,255), mat="plastic", transp=0):
    return {"shape": shape, "size": list(size), "pos": list(pos), "rot": list(rot), "color": list(color), "mat": mat, "transp": transp}

GOLD, GOLD_LIGHT, GOLD_DARK = (255, 200, 50), (255, 228, 120), (205, 145, 30)

def rotz(x, y, deg):
    a = math.radians(deg)
    return (x*math.cos(a) - y*math.sin(a), x*math.sin(a) + y*math.cos(a))

def coins():
    # a stack of ridged coins, one standing coin with an embossed star, a few loose coins
    parts = []
    for i, (x, z) in enumerate([(0.0, 0.25), (0.1, 0.2), (-0.06, 0.28), (0.08, 0.22), (-0.02, 0.24)]):
        y = -1.2 + i * 0.3
        parts.append(P("cyl", (0.3, 2.0, 2.0), (x, y, z), (0, 0, 90), GOLD_DARK, "metal"))
        parts.append(P("cyl", (0.31, 1.75, 1.75), (x, y + 0.01, z), (0, 0, 90), GOLD, "metal"))
    parts.append(P("cyl", (0.4, 2.2, 2.2), (0.15, 0.6, -0.8), (0, 80, 0), GOLD_DARK, "metal"))
    parts.append(P("cyl", (0.42, 1.85, 1.85), (0.15, 0.6, -0.8), (0, 80, 0), GOLD, "metal"))
    for k in range(5):
        a = k * 72
        x, y = rotz(0, 0.32, a)
        parts.append(P("ell", (0.28, 0.6, 0.1), (0.11 + x * 0.98, 0.6 + y, -1.03), (0, -10, a), GOLD_LIGHT, "neon"))
    for (x, y, z, rx) in [(-1.25, -1.25, -0.6, 70), (1.3, -1.3, -0.3, 110), (-1.0, -1.35, 0.9, 85)]:
        parts.append(P("cyl", (0.25, 1.0, 1.0), (x, y, z), (rx, 20, 90), GOLD, "metal"))
    parts.append(P("ball", (0.35, 0.35, 0.35), (1.0, 1.55, -1.0), (0, 0, 0), (255, 255, 230), "neon"))
    return parts

def clover():
    parts = []
    green, light, dark = (70, 190, 70), (130, 230, 110), (40, 130, 45)
    for k in range(4):
        a = 45 + k * 90
        for side in (-1, 1):
            # heart shape: two lobes per leaf
            lx, ly = rotz(side * 0.28, 1.0, a)
            parts.append(P("ell", (0.8, 1.05, 0.32), (lx, ly + 0.25, 0), (0, 0, a + side * 18), green))
        vx, vy = rotz(0, 0.6, a)
        parts.append(P("ell", (0.08, 0.95, 0.34), (vx, vy + 0.25, -0.02), (0, 0, a), dark))
        hx, hy = rotz(0.12, 0.85, a)
        parts.append(P("ell", (0.22, 0.35, 0.34), (hx, hy + 0.25, -0.04), (0, 0, a), light, "neon"))
    parts.append(P("ball", (0.55, 0.55, 0.55), (0, 0.25, -0.05), (0, 0, 0), dark))
    for i in range(5):
        parts.append(P("ball", (0.22, 0.22, 0.22), (0.12 + i * 0.1, -0.25 - i * 0.32, 0.05), (0, 0, 0), dark))
    parts.append(P("ball", (0.3, 0.3, 0.3), (0.55, 0.9, -0.25), (0, 0, 0), (220, 245, 255), "glass", 0.3))
    return parts

def crate():
    wood, dark, metal = (165, 115, 66), (110, 72, 38), (120, 125, 135)
    parts = [P("block", (2.2, 2.0, 2.2), (0, -0.5, 0), (0, 25, 0), wood, "wood")]
    for y in (-1.15, -0.5, 0.15):
        parts.append(P("block", (2.24, 0.06, 2.24), (0, y + 0.3, 0), (0, 25, 0), dark))
    for cx, cz in ((1, 1), (1, -1), (-1, 1), (-1, -1)):
        x, z = cx * 1.07, cz * 1.07
        rx = x * math.cos(math.radians(25)) + z * math.sin(math.radians(25))
        rz = -x * math.sin(math.radians(25)) + z * math.cos(math.radians(25))
        parts.append(P("block", (0.2, 2.1, 0.2), (rx, -0.5, rz), (0, 25, 0), metal, "metal"))
    for i in range(4):
        parts.append(P("block", (0.12, 0.3, 0.2), (0, 0.65 + i * 0.32, 0), (0, i * 90, 0), metal, "metal"))
    parts.append(P("block", (0.18, 0.7, 0.18), (0, 2.0, 0), (0, 0, 0), metal, "metal"))
    parts.append(P("block", (2.8, 0.3, 0.3), (0, 2.35, 0), (0, 0, 0), (255, 175, 40), "metal"))
    parts.append(P("block", (0.25, 0.45, 0.25), (1.3, 2.05, 0), (0, 0, 0), (255, 175, 40), "metal"))
    return parts

def paw():
    pink, dark, shine = (255, 140, 195), (225, 85, 155), (255, 220, 240)
    return [
        P("ell", (1.8, 1.45, 0.55), (0, -0.45, 0), (0, 0, 0), pink),
        P("ell", (0.6, 0.35, 0.2), (-0.35, -0.2, -0.25), (0, 0, 20), shine, "neon"),
        P("ell", (0.75, 0.95, 0.5), (-1.0, 0.55, 0), (0, 0, 20), dark),
        P("ell", (0.75, 0.95, 0.5), (-0.35, 1.0, 0), (0, 0, 5), dark),
        P("ell", (0.75, 0.95, 0.5), (0.35, 1.0, 0), (0, 0, -5), dark),
        P("ell", (0.75, 0.95, 0.5), (1.0, 0.55, 0), (0, 0, -20), dark),
        P("ell", (0.22, 0.28, 0.15), (-0.42, 1.15, -0.22), (0, 0, 0), shine, "neon"),
        P("ell", (0.22, 0.28, 0.15), (0.28, 1.15, -0.22), (0, 0, 0), shine, "neon"),
    ]

def crown():
    velvet = (170, 25, 45)
    parts = [P("ell", (2.1, 1.3, 2.1), (0, 0.15, 0), (0, 0, 0), velvet, "fabric"),
             P("cyl", (0.95, 2.7, 2.7), (0, -0.55, 0), (0, 0, 90), GOLD, "metal"),
             P("cyl", (0.2, 2.85, 2.85), (0, -0.98, 0), (0, 0, 90), GOLD_DARK, "metal"),
             P("cyl", (0.2, 2.85, 2.85), (0, -0.12, 0), (0, 0, 90), GOLD_DARK, "metal"),
             P("ball", (0.42, 0.42, 0.42), (0, 1.0, 0), (0, 0, 0), GOLD_LIGHT, "metal")]
    gems = [(255, 40, 70), (60, 150, 255), (70, 220, 110), (180, 90, 255), (255, 150, 30)]
    for k in range(5):
        a = math.radians(k * 72)
        x, z = math.sin(a) * 1.2, -math.cos(a) * 1.2
        parts.append(P("ell", (0.6, 1.45, 0.32), (x, 0.45, z), (0, -k * 72, 0), GOLD, "metal"))
        parts.append(P("ball", (0.42, 0.42, 0.42), (x * 1.02, 1.25, z * 1.02), (0, 0, 0), GOLD_LIGHT, "metal"))
        parts.append(P("ell", (0.5, 0.42, 0.25), (x * 1.13, -0.55, z * 1.13), (0, -k * 72, 0), gems[k], "neon"))
    for k in range(14):
        a = math.radians(k * (360 / 14))
        parts.append(P("ball", (0.2, 0.2, 0.2), (math.sin(a) * 1.42, -0.98, -math.cos(a) * 1.42), (0, 0, 0), (255, 250, 235)))
    return parts

def chest():
    wood, dark, metal = (150, 95, 52), (95, 58, 30), GOLD
    parts = [P("block", (2.7, 1.5, 1.8), (0, -0.55, 0), (0, 20, 0), wood, "wood")]
    for y in (-0.95, -0.45):
        parts.append(P("block", (2.74, 0.05, 1.84), (0, y, 0), (0, 20, 0), dark))
    parts += [
        P("cyl", (2.75, 1.82, 1.82), (0, 0.2, 0), (0, 20, 0), wood, "wood"),
        P("block", (0.25, 2.25, 1.95), (-1.0, -0.15, 0.36), (0, 20, 0), metal, "metal"),
        P("block", (0.25, 2.25, 1.95), (1.0, -0.15, -0.36), (0, 20, 0), metal, "metal"),
        P("block", (0.6, 0.7, 0.22), (-0.32, -0.15, -0.9), (0, 20, 0), GOLD_LIGHT, "metal"),
        P("ball", (0.2, 0.2, 0.2), (-0.34, -0.2, -1.02), (0, 0, 0), (40, 30, 20)),
    ]
    # treasure spilling out of the top
    for (x, y, z, c, m) in [(0.3, 1.15, -0.2, GOLD_LIGHT, "metal"), (-0.4, 1.1, 0.1, (90, 220, 255), "neon"),
                             (0.0, 1.25, 0.2, (255, 60, 90), "neon"), (0.75, 1.0, 0.1, GOLD, "metal"),
                             (-0.8, 1.0, -0.1, GOLD, "metal"), (0.4, 1.3, 0.3, (120, 255, 140), "neon")]:
        parts.append(P("ball", (0.45, 0.45, 0.45), (x, y, z), (0, 0, 0), c, m))
    parts.append(P("cyl", (0.12, 0.6, 0.6), (-0.1, 1.35, -0.3), (40, 20, 90), GOLD, "metal"))
    return parts

def tank():
    frame = (40, 50, 70)
    parts = [
        P("block", (3.0, 2.2, 1.8), (0, 0, 0), (0, 15, 0), (200, 235, 255), "glass", 0.7),
        P("block", (2.85, 1.55, 1.65), (0, -0.3, 0), (0, 15, 0), (60, 150, 240), "plastic", 0.4),
        P("block", (2.85, 0.28, 1.65), (0, -0.95, 0), (0, 15, 0), (235, 215, 150)),
        P("block", (3.1, 0.18, 1.9), (0, 1.12, 0), (0, 15, 0), frame, "metal"),
        P("block", (3.1, 0.18, 1.9), (0, -1.12, 0), (0, 15, 0), frame, "metal"),
    ]
    c, sn = math.cos(math.radians(15)), math.sin(math.radians(15))
    for cx, cz in ((1, 1), (1, -1), (-1, 1), (-1, -1)):
        x, z = cx * 1.48, cz * 0.88
        parts.append(P("block", (0.12, 2.2, 0.12), (x * c + z * sn, 0, -x * sn + z * c), (0, 15, 0), frame, "metal"))
    # little castle + rocks + seaweed + fish + bubbles
    parts += [
        P("block", (0.55, 0.7, 0.45), (0.75, -0.45, 0.2), (0, 15, 0), (170, 170, 185)),
        P("block", (0.25, 0.25, 0.25), (0.62, -0.02, 0.24), (0, 15, 0), (170, 170, 185)),
        P("block", (0.25, 0.25, 0.25), (0.9, -0.02, 0.15), (0, 15, 0), (170, 170, 185)),
        P("ball", (0.45, 0.45, 0.45), (-0.9, -0.8, 0.3), (0, 0, 0), (120, 120, 130)),
        P("ball", (0.3, 0.3, 0.3), (-0.6, -0.85, 0.5), (0, 0, 0), (140, 140, 150)),
        P("ell", (1.0, 0.6, 0.35), (-0.45, -0.05, -0.45), (0, 15, 0), (255, 140, 40)),
        P("ell", (1.02, 0.62, 0.1), (-0.45, -0.05, -0.45), (0, 15, 0), (255, 255, 255)),
        P("block", (0.1, 0.55, 0.4), (-1.0, -0.05, -0.3), (0, 15, 0), (255, 200, 150)),
        P("ell", (0.75, 0.45, 0.28), (0.55, 0.35, -0.2), (0, 195, 0), (60, 230, 210)),
    ]
    for i in range(4):
        parts.append(P("ball", (0.2, 0.2, 0.2), (-1.05 + math.sin(i) * 0.08, -0.7 + i * 0.25, 0.45), (0, 0, 0), (60, 170, 70)))
    for i, (x, y) in enumerate([(0.1, 0.55), (0.25, 0.8), (0.05, 0.98)]):
        parts.append(P("ball", (0.14 + i * 0.03,) * 3, (x, y, -0.5), (0, 0, 0), (230, 250, 255), "glass", 0.35))
    return parts

def swords():
    parts = [P("ball", (1.7, 1.7, 1.7), (0, 0.25, 0.6), (0, 0, 0), (255, 140, 40), "neon", 0.5)]
    for deg in (40, -40):
        z0 = -0.1 if deg > 0 else 0.1
        def at(x, y):
            rx, ry = rotz(x, y, deg)
            return (rx, ry + 0.2, z0)
        parts.append(P("block", (0.32, 2.4, 0.1), at(0, 0.35), (0, 0, deg), (220, 228, 240), "metal"))
        parts.append(P("block", (0.06, 2.0, 0.12), at(0, 0.3), (0, 0, deg), (160, 170, 190), "metal"))  # fuller
        parts.append(P("block", (0.23, 0.23, 0.1), at(0, 1.58), (0, 0, deg + 45), (220, 228, 240), "metal"))  # tip
        parts.append(P("block", (1.15, 0.2, 0.22), at(0, -0.92), (0, 0, deg), GOLD, "metal"))
        parts.append(P("ball", (0.28, 0.28, 0.28), at(-0.58, -0.92), (0, 0, 0), GOLD_LIGHT, "metal"))
        parts.append(P("ball", (0.28, 0.28, 0.28), at(0.58, -0.92), (0, 0, 0), GOLD_LIGHT, "metal"))
        for i in range(3):
            parts.append(P("block", (0.24, 0.18, 0.24), at(0, -1.12 - i * 0.2), (0, 0, deg), (95, 50, 30) if i % 2 == 0 else (60, 30, 18)))
        parts.append(P("ball", (0.36, 0.36, 0.36), at(0, -1.78), (0, 0, 0), (255, 50, 70), "neon"))
    return parts

def star():
    parts = [P("ball", (1.1, 1.1, 0.6), (0, 0, 0), (0, 0, 0), (255, 220, 70))]
    for k in range(5):
        a = k * 72
        x, y = rotz(0, 0.85, a)
        parts.append(P("ell", (0.75, 1.5, 0.45), (x, y, 0), (0, 0, a), (255, 210, 50)))
    parts.append(P("ball", (0.5, 0.5, 0.3), (0, 0, -0.3), (0, 0, 0), (255, 245, 180), "neon"))
    return parts

def bolt():
    y = (255, 230, 60)
    return [
        P("block", (0.55, 1.7, 0.35), (0.3, 0.85, 0), (0, 0, -28), y, "neon"),
        P("block", (1.4, 0.42, 0.35), (0.0, 0.0, 0), (0, 0, 0), y, "neon"),
        P("block", (0.55, 1.7, 0.35), (-0.3, -0.85, 0), (0, 0, -28), y, "neon"),
        P("ball", (1.8, 1.8, 1.8), (0, 0, 0.6), (0, 0, 0), (255, 170, 40), "neon", 0.6),
    ]

def arrow():
    g = (90, 220, 90)
    return [
        P("block", (0.75, 1.7, 0.4), (0, -0.55, 0), (0, 0, 0), g),
        P("block", (0.55, 1.6, 0.42), (-0.5, 0.55, 0), (0, 0, -45), g),
        P("block", (0.55, 1.6, 0.42), (0.5, 0.55, 0), (0, 0, 45), g),
        P("ball", (0.5, 0.5, 0.5), (0, 1.12, 0), (0, 0, 0), (150, 255, 150), "neon"),
    ]

def rebirth():
    o = (255, 145, 50)
    parts = []
    for k in range(13):
        a = 30 + k * 24
        x, yy = rotz(0, 1.15, a)
        parts.append(P("block", (0.5, 0.42, 0.38), (x, yy, 0), (0, 0, a), o))
    hx, hy = rotz(0, 1.15, 18)
    parts.append(P("block", (0.9, 0.3, 0.4), (hx + 0.15, hy + 0.25, 0), (0, 0, -30), (255, 200, 80), "neon"))
    parts.append(P("block", (0.9, 0.3, 0.4), (hx + 0.2, hy - 0.2, 0), (0, 0, 40), (255, 200, 80), "neon"))
    parts.append(P("ball", (0.8, 0.8, 0.8), (0, 0, 0), (0, 0, 0), (255, 220, 120), "neon"))
    return parts

def ticket():
    return [
        P("block", (2.9, 1.6, 0.25), (0, 0, 0), (0, 0, 12), GOLD),
        P("block", (2.95, 0.3, 0.28), (0, 0.3, 0), (0, 0, 12), GOLD_DARK),
        P("cyl", (0.3, 0.55, 0.55), (-1.45, -0.3, 0), (0, 90, 0), (40, 50, 80)),
        P("cyl", (0.3, 0.55, 0.55), (1.45, 0.3, 0), (0, 90, 0), (40, 50, 80)),
        P("ball", (0.6, 0.6, 0.3), (0.2, -0.3, -0.15), (0, 0, 0), (255, 245, 200), "neon"),
    ]

def crystal():
    return [
        P("ball", (2.3, 2.3, 2.3), (0, 0.35, 0), (0, 0, 0), (205, 160, 255), "glass", 0.45),
        P("ball", (1.1, 1.1, 1.1), (0, 0.35, 0), (0, 0, 0), (255, 110, 240), "neon"),
        P("cyl", (0.5, 1.7, 1.7), (0, -0.95, 0), (0, 0, 90), GOLD, "metal"),
        P("cyl", (0.3, 2.1, 2.1), (0, -1.25, 0), (0, 0, 90), GOLD_DARK, "metal"),
        P("ball", (0.3, 0.3, 0.3), (0.9, 1.3, -0.3), (0, 0, 0), (255, 255, 255), "neon"),
        P("ball", (0.22, 0.22, 0.22), (-1.0, 1.0, -0.2), (0, 0, 0), (255, 255, 255), "neon"),
    ]

ICONS = {
    "DoubleCoins": coins(), "BoostCoins": coins(),
    "LuckyDiver": clover(), "BoostLuck": clover(),
    "AutoHaul": crate(), "PetSlots": paw(), "VIP": crown(),
    "BigStorage": chest(), "BigTank": tank(), "DoubleDamage": swords(),
    "BoostXP": star(), "RebirthRush": bolt(), "LevelPack": arrow(),
    "InstantRebirth": rebirth(), "SeasonPremium": ticket(), "SeasonMystic": crystal(),
}

def lua():
    out = ["-- Store icons (generated from icons.py; same data drives the preview page)", "Models.Icons = {"]
    for key, parts in ICONS.items():
        out.append("\t%s = {" % key)
        for p in parts:
            out.append("\t\t{ %s, { %s }, { %s }, { %s }, { %s }, %s, %s }," % (
                json.dumps(p["shape"]), ", ".join("%g" % v for v in p["size"]), ", ".join("%g" % round(v, 3) for v in p["pos"]),
                ", ".join("%g" % v for v in p["rot"]), ", ".join(str(v) for v in p["color"]), json.dumps(p["mat"]), "%g" % p["transp"]))
        out.append("\t},")
    out.append("}")
    return "\n".join(out)

if sys.argv[1] == "lua":
    print(lua())
else:
    print(json.dumps(ICONS, separators=(",", ":")))
