# One source of truth for the store icons: generates Lua (for the game) and JSON (for the preview).
import json, math, sys

def P(shape, size, pos=(0,0,0), rot=(0,0,0), color=(255,255,255), mat="plastic", transp=0):
    return {"shape": shape, "size": list(size), "pos": list(pos), "rot": list(rot), "color": list(color), "mat": mat, "transp": transp}

GOLD, GOLD_LIGHT, GOLD_DARK = (255, 200, 50), (255, 228, 120), (205, 145, 30)

def rotz(x, y, deg):
    a = math.radians(deg)
    return (x*math.cos(a) - y*math.sin(a), x*math.sin(a) + y*math.cos(a))

def coins():
    # a stack of flat coins with one coin standing up in front
    parts = []
    for i, (x, z) in enumerate([(0.0, 0.2), (0.12, 0.15), (-0.08, 0.22), (0.05, 0.18)]):
        parts.append(P("cyl", (0.34, 2.0, 2.0), (x, -1.15 + i * 0.36, z), (0, 0, 90), GOLD if i % 2 == 0 else GOLD_DARK, "metal"))
    parts.append(P("cyl", (0.4, 2.1, 2.1), (0.15, 0.55, -0.75), (0, 80, 0), GOLD, "metal"))
    parts.append(P("cyl", (0.08, 1.45, 1.45), (0.12, 0.55, -0.97), (0, 80, 0), GOLD_LIGHT, "neon"))
    parts.append(P("block", (0.28, 0.75, 0.1), (0.09, 0.55, -1.03), (0, -10, 0), GOLD_DARK, "metal"))
    return parts

def clover():
    parts = []
    for k in range(4):
        a = 45 + k * 90
        x, y = rotz(0, 0.78, a)
        parts.append(P("ell", (1.15, 1.45, 0.4), (x, y + 0.2, 0), (0, 0, a), (95, 205, 75)))
        x2, y2 = rotz(0, 0.95, a)
        parts.append(P("ell", (0.25, 0.9, 0.42), (x2 * 0.8, y2 * 0.8 + 0.2, -0.02), (0, 0, a), (150, 240, 120)))
    parts.append(P("ball", (0.7, 0.7, 0.7), (0, 0.2, -0.05), (0, 0, 0), (60, 160, 50)))
    parts.append(P("block", (0.22, 1.5, 0.22), (0.35, -1.3, 0), (0, 0, -20), (60, 150, 50)))
    return parts

def crate():
    wood, dark = (160, 112, 64), (95, 62, 34)
    return [
        P("block", (2.2, 2.0, 2.2), (0, -0.5, 0), (0, 25, 0), wood),
        P("block", (2.3, 0.3, 2.3), (0, 0.2, 0), (0, 25, 0), dark),
        P("block", (2.3, 0.3, 2.3), (0, -1.2, 0), (0, 25, 0), dark),
        P("block", (2.25, 0.3, 0.3), (0, -0.5, 0), (0, 25, 45), (255, 205, 70), "neon"),
        P("block", (0.25, 1.4, 0.25), (0, 1.25, 0), (0, 0, 0), (110, 115, 125), "metal"),
        P("ball", (0.55, 0.55, 0.55), (0, 0.55, 0), (0, 0, 0), (140, 145, 155), "metal"),
        P("block", (2.6, 0.3, 0.3), (0, 2.0, 0), (0, 0, 0), (255, 175, 40), "metal"),
    ]

def paw():
    pink, dark = (255, 140, 195), (225, 85, 155)
    return [
        P("ell", (1.8, 1.45, 0.55), (0, -0.45, 0), (0, 0, 0), pink),
        P("ell", (0.75, 0.95, 0.5), (-1.0, 0.55, 0), (0, 0, 20), dark),
        P("ell", (0.75, 0.95, 0.5), (-0.35, 1.0, 0), (0, 0, 5), dark),
        P("ell", (0.75, 0.95, 0.5), (0.35, 1.0, 0), (0, 0, -5), dark),
        P("ell", (0.75, 0.95, 0.5), (1.0, 0.55, 0), (0, 0, -20), dark),
    ]

def crown():
    parts = [P("cyl", (0.9, 2.7, 2.7), (0, -0.55, 0), (0, 0, 90), GOLD, "metal"),
             P("cyl", (0.92, 2.2, 2.2), (0, -0.55, 0), (0, 0, 90), GOLD_DARK, "metal")]
    gems = [(255, 60, 80), (80, 170, 255), (90, 230, 120), (190, 100, 255), (255, 160, 40)]
    for k in range(5):
        a = math.radians(k * 72)
        x, z = math.sin(a) * 1.15, -math.cos(a) * 1.15
        parts.append(P("block", (0.55, 1.2, 0.3), (x, 0.4, z), (0, -k * 72, 0), GOLD, "metal"))
        parts.append(P("ball", (0.45, 0.45, 0.45), (x, 1.1, z), (0, 0, 0), GOLD_LIGHT, "metal"))
        parts.append(P("ball", (0.42, 0.42, 0.42), (x * 1.08, -0.55, z * 1.08), (0, 0, 0), gems[k], "neon"))
    return parts

def chest():
    wood, dark = (150, 95, 52), (110, 66, 34)
    return [
        P("block", (2.7, 1.5, 1.8), (0, -0.55, 0), (0, 20, 0), wood),
        P("cyl", (2.75, 1.82, 1.82), (0, 0.2, 0), (0, 20, 0), dark),
        P("block", (0.25, 2.1, 1.9), (-1.0, -0.2, 0.35), (0, 20, 0), GOLD, "metal"),
        P("block", (0.25, 2.1, 1.9), (1.0, -0.2, -0.35), (0, 20, 0), GOLD, "metal"),
        P("block", (0.55, 0.6, 0.2), (-0.32, -0.1, -0.88), (0, 20, 0), GOLD_LIGHT, "metal"),
        P("ball", (0.5, 0.5, 0.5), (0.3, 1.15, -0.2), (0, 0, 0), GOLD_LIGHT, "neon"),
        P("ball", (0.4, 0.4, 0.4), (-0.4, 1.1, 0.1), (0, 0, 0), (90, 220, 255), "neon"),
    ]

def tank():
    return [
        P("block", (3.0, 2.2, 1.8), (0, 0, 0), (0, 15, 0), (200, 235, 255), "glass", 0.65),
        P("block", (2.85, 1.55, 1.65), (0, -0.3, 0), (0, 15, 0), (60, 150, 240), "plastic", 0.35),
        P("block", (2.85, 0.25, 1.65), (0, -0.95, 0), (0, 15, 0), (235, 215, 150)),
        P("ell", (1.0, 0.6, 0.35), (-0.5, -0.1, -0.4), (0, 15, 0), (255, 140, 40)),
        P("block", (0.1, 0.5, 0.4), (-1.05, -0.1, -0.25), (0, 15, 0), (255, 220, 200)),
        P("ell", (0.8, 0.5, 0.3), (0.6, 0.3, -0.1), (0, 195, 0), (60, 230, 210)),
        P("block", (0.15, 1.2, 0.15), (0.9, -0.35, 0.3), (0, 0, 10), (70, 180, 70)),
        P("block", (0.15, 0.9, 0.15), (-1.0, -0.5, 0.4), (0, 0, -10), (70, 180, 70)),
        P("block", (3.05, 0.2, 1.85), (0, 1.12, 0), (0, 15, 0), (40, 50, 70), "metal"),
    ]

def swords():
    parts = [P("ball", (1.6, 1.6, 1.6), (0, 0.2, 0.6), (0, 0, 0), (255, 140, 40), "neon", 0.45)]
    for deg in (40, -40):
        def at(x, y):
            rx, ry = rotz(x, y, deg)
            return (rx, ry + 0.2, -0.1 if deg > 0 else 0.1)
        parts.append(P("block", (0.3, 2.6, 0.12), at(0, 0.45), (0, 0, deg), (225, 230, 240), "metal"))
        parts.append(P("block", (1.1, 0.22, 0.22), at(0, -0.9), (0, 0, deg), GOLD, "metal"))
        parts.append(P("block", (0.22, 0.7, 0.22), at(0, -1.3), (0, 0, deg), (110, 60, 35)))
        parts.append(P("ball", (0.35, 0.35, 0.35), at(0, -1.7), (0, 0, 0), GOLD, "metal"))
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
