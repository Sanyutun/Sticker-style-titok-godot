#!/usr/bin/env python3
"""Author the sample episode JSON. This script is a development convenience;
the generated episode.json / storyboard.json are the editable source of truth.
"""
from pathlib import Path
import json

ROOT = Path(__file__).resolve().parents[1]
PROJ = ROOT / "projects" / "salt_hypertension"
PROJ.mkdir(parents=True, exist_ok=True)

episode = {
    "schema_version": 1,
    "project_name": "Salt and Blood Pressure",
    "brand_name": "BodyFrame",
    "topic": "How Excess Salt Contributes to Hypertension",
    "width": 1920,
    "height": 1080,
    "fps": 30,
    "duration_seconds": 10.0,
    "background_color": "#E9EEF2",
    "canvas": {"width": 6000, "height": 3000},
    "palette": {
        "primary": "#334B60",
        "secondary": "#F6F3EC",
        "accent": "#FF5A36",
        "blood": "#C84C4C",
        "text": "#263746",
        "muted": "#7A8C99",
        "water": "#7FB9D8",
        "paper": "#FFFFFF"
    },
    "style": {
        "preset_name": "Bold Outline Editorial Explainer",
        "sticker_outline_px": 12,
        "sticker_outline_color": "#FFFFFF",
        "shadow_enabled": True,
        "shadow_blur_px": 14,
        "shadow_offset_x": 0,
        "shadow_offset_y": 12,
        "shadow_color": "#263746",
        "shadow_alpha": 0.17,
        "font_regular": "res://resources/fonts/NotoSans-Regular.ttf",
        "font_bold": "res://resources/fonts/NotoSans-Bold.ttf",
        "font_myanmar": "res://resources/fonts/NotoSansMyanmar-Regular.ttf",
        "font_cjk": "",
        "safe_margin_px": 72,
        "motion_blur": False,
        "motion_blur_samples": 3,
        "motion_blur_shutter": 0.5
    },
    "camera": {"mode": "keyframed", "default_easing": "cubic_in_out"},
    "audio": {"sample_rate": 48000, "integrated_loudness_lufs": -14, "true_peak_limit_dbtp": -1},
    "export": {
        "video_codec": "libx264",
        "pixel_format": "yuv420p",
        "crf": 18,
        "preset": "medium",
        "audio_codec": "aac",
        "audio_bitrate_kbps": 192,
        "video_path": "res://output/video.mp4",
        "frames_dir": "res://output/frames"
    },
    "localization": {
        "default_language": "en",
        "narration": {
            "en": "Too much sodium can make your body hold water. That can raise blood pressure. Over time, it can contribute to hypertension. Cutting back helps.",
            "my": ""
        },
        "notes": {
            "en": "Synthetic scratch narration guide (espeak-ng). Replace with a recorded voice before publication.",
            "my": "Burmese translation pending clinical and linguistic review. No unreviewed Burmese copy is included."
        }
    },
    "assets": [
        {"name": "Salt shaker cutout", "path": "assets/salt_shaker.png", "source": "Original SVG drawn for this project", "creator": "BodyFrame Motion Studio", "license": "Project-owned (CC0)", "attribution": "None required", "modifications": "Rendered to transparent PNG"},
        {"name": "Water droplet cutout", "path": "assets/water_droplet.png", "source": "Original SVG drawn for this project", "creator": "BodyFrame Motion Studio", "license": "Project-owned (CC0)", "attribution": "None required", "modifications": "Rendered to transparent PNG"},
        {"name": "Salt pile cutout", "path": "assets/salt_pile.png", "source": "Original SVG drawn for this project", "creator": "BodyFrame Motion Studio", "license": "Project-owned (CC0)", "attribution": "None required", "modifications": "Rendered to transparent PNG"}
    ]
}

# ---------------------------------------------------------------- helpers
elements = []
tracks = []

def add_el(**kw):
    base = {
        "id": kw["id"], "type": kw["type"], "name": kw.get("name", kw["id"]),
        "scene": kw.get("scene", "hook"), "x": kw.get("x", 0), "y": kw.get("y", 0),
        "width": kw.get("width", 100), "height": kw.get("height", 100),
        "rotation": kw.get("rotation", 0), "scale": kw.get("scale", [1, 1]),
        "opacity": kw.get("opacity", 1), "z": kw.get("z", 10),
        "locked": False, "hidden": False,
    }
    base.update(kw)
    elements.append(base)
    return base

def key(t, v, e="cubic_in_out"):
    return {"time": round(float(t), 5), "value": v, "easing": e}

def track(eid, prop, keys, kind=None):
    d = {"element_id": eid, "property": prop, "keys": keys}
    if kind:
        d["kind"] = kind
    tracks.append(d)

def fade_in(eid, t0, t1=0.0001):
    if t1 <= t0:
        t1 = t0 + 0.0001
    track(eid, "opacity", [key(t0, 0.0, "cubic_out"), key(t1, 1.0, "cubic_out")], "number")

def opacity_keys(eid, keys):
    track(eid, "opacity", keys, "number")

def pop_scale(eid, t, peak=1.08, e_in="cubic_out"):
    track(eid, "scale", [key(t, [0.001, 0.001], "cubic_out"), key(t+0.18, [peak, peak], "back_out"), key(t+0.32, [1, 1], "cubic_out")], "vector")

# ---------------------------------------------------------------- scene 1: hook
add_el(id="bg_01", type="text", scene="hook", name="Scene mark 01", x=820, y=1940, width=900, height=500,
       text="01", font_size=420, font_weight="bold", color="#334B60", align="center", z=-20, opacity=0.055)
add_el(id="shaker", type="sticker", scene="hook", name="Salt shaker cutout", x=1420, y=1550, width=560, height=808,
       rotation=-6, z=20, asset="assets/salt_shaker.png", outline_width=12)
track("shaker", "position", [key(0, [1420,1550]), key(0.55, [1420,1536], "cubic_out"), key(1.8, [1400,1524], "sine_in_out"), key(2.3, [1380,1516], "cubic_out")], "vector")
track("shaker", "rotation", [key(0, -6), key(0.55, -8, "cubic_out"), key(1.8, -4.5, "sine_in_out"), key(2.3, -11, "cubic_out")], "number")
track("shaker", "scale", [key(0, [1.02, 1.02]), key(0.55, [1, 1], "cubic_out"), key(2.0, [1.035, 1.035], "sine_in_out")], "vector")
opacity_keys("shaker", [key(0, 1), key(1.55, 1), key(1.78, 0, "cubic_in")])

add_el(id="plate", type="shape", scene="hook", name="Plate", x=1560, y=1930, width=620, height=140,
       shape="ellipse", fill="#F6F3EC", border_color="#FFFFFF", border_width=6, shadow=True, z=5, opacity=0.9)
track("plate", "opacity", [key(0, 0.9), key(1.32, 0.9), key(1.55, 0, "cubic_in")], "number")

grains = [
    ("grain_1", 0.14, 1310, 1200, 1480, 1810),
    ("grain_2", 0.24, 1350, 1190, 1540, 1840),
    ("grain_3", 0.33, 1270, 1215, 1430, 1770),
    ("grain_4", 0.42, 1390, 1220, 1600, 1800),
]
for gid, st, x0, y0, x1, y1 in grains:
    add_el(id=gid, type="shape", scene="hook", name="Salt grain", x=x0, y=y0, width=26, height=26,
           shape="polygon", points=[[0, -0.5], [0.5, 0], [0, 0.5], [-0.5, 0]],
           fill="#FFFFFF", border_color="#C9C3B6", border_width=1.5, shadow=True, z=25, opacity=0)
    track(gid, "position", [key(st, [x0, y0], "cubic_in"), key(st+0.28, [x1, y1], "cubic_in")], "vector")
    track(gid, "rotation", [key(st, 0), key(st+0.28, 120, "linear")], "number")
    opacity_keys(gid, [key(st, 0), key(st+0.03, 1, "linear"), key(st+0.22, 1), key(st+0.29, 0, "cubic_in")])

add_el(id="hook_text", type="text", scene="hook", name="Hook headline", x=810, y=1268, width=620, height=500,
       text="TOO\nMUCH\nSALT?", font_size=130, font_weight="bold", color="#263746", align="left", valign="center",
       line_spacing=-18, z=30)
track("hook_text", "position", [key(0, [810, 1302]), key(0.5, [810, 1268], "cubic_out")], "vector")
track("hook_text", "scale", [key(0, [0.94, 0.94]), key(0.48, [1, 1], "back_out")], "vector")
track("hook_text", "reveal", [key(0, 1.0)], "number")
opacity_keys("hook_text", [key(0, 1), key(1.30, 1), key(1.52, 0, "cubic_in")])

add_el(id="hook_rule", type="shape", scene="hook", name="Accent rule", x=850, y=1548, width=430, height=10,
       shape="line", fill="#FF5A36", border_width=9, z=29)
track("hook_rule", "progress", [key(0.14, 0, "cubic_out"), key(0.6, 1, "cubic_out")], "number")
opacity_keys("hook_rule", [key(0, 1), key(1.3, 1), key(1.52, 0, "cubic_in")])

add_el(id="hook_tag", type="text", scene="hook", name="Hook kicker", x=800, y=1602, width=640, height=54,
       text="SODIUM & BLOOD PRESSURE", font_size=27, font_weight="bold", color="#7A8C99", align="left", z=30)
fade_in("hook_tag", 0.06, 0.3)
track("hook_tag", "position", [key(0.06, [800, 1620]), key(0.4, [800, 1602], "cubic_out")], "vector")
opacity_keys("hook_tag", [key(0.06, 0), key(0.3, 1, "cubic_out"), key(1.3, 1), key(1.52, 0, "cubic_in")])

# ---------------------------------------------------------------- scene 2: sodium & water
add_el(id="bg_02", type="text", scene="sodium_water", name="Scene mark 02", x=2360, y=1990, width=900, height=500,
       text="02", font_size=420, font_weight="bold", color="#334B60", align="center", z=-20, opacity=0.05)
add_el(id="sodium_ghost", type="text", scene="sodium_water", name="Na+ ghost", x=3320, y=1050, width=660, height=400,
       text="Na+", font_size=300, font_weight="bold", color="#334B60", align="center", z=-18, opacity=0.07)

add_el(id="sodium_title", type="text", scene="sodium_water", name="Sodium title", x=2650, y=1058, width=1500, height=132,
       text="SODIUM PULLS WATER", font_size=84, font_weight="bold", color="#263746", align="center", z=30)
fade_in("sodium_title", 1.45, 1.70)
track("sodium_title", "position", [key(1.45, [2650, 1018]), key(1.85, [2650, 1058], "cubic_out")], "vector")
track("sodium_title", "reveal", [key(1.50, 0.0, "smoothstep"), key(1.92, 1.0, "smoothstep")], "number")

add_el(id="sodium_rule", type="shape", scene="sodium_water", name="Title rule", x=2650, y=1142, width=360, height=8,
       shape="line", fill="#FF5A36", border_width=7, z=29)
track("sodium_rule", "progress", [key(1.62, 0, "cubic_out"), key(1.98, 1, "cubic_out")], "number")

add_el(id="sodium_sub", type="text", scene="sodium_water", name="Sodium subtitle", x=2650, y=1198, width=1180, height=56,
       text="For many people, the body holds on to fluid.", font_size=34, font_weight="regular", color="#334B60", align="center", z=30)
fade_in("sodium_sub", 1.70, 1.98)
track("sodium_sub", "position", [key(1.70, [2650, 1214]), key(2.04, [2650, 1198], "cubic_out")], "vector")

add_el(id="body", type="character", scene="sodium_water", name="Simplified body", x=2360, y=1590, width=370, height=610,
       mode="torso", water_level=0.0, sodium_count=9, label="SIMPLIFIED BODY", label_size=19, z=12)
fade_in("body", 1.60, 1.88)
track("body", "position", [key(1.60, [2360, 1620]), key(1.96, [2360, 1590], "cubic_out")], "vector")
track("body", "water_level", [key(2.5, 0.0, "cubic_in_out"), key(3.7, 0.62, "cubic_out"), key(4.1, 0.66, "sine_in_out")], "number")
opacity_keys("body", [key(1.60, 0), key(1.88, 1, "cubic_out"), key(4.18, 1), key(4.42, 0, "cubic_in")])

drop_specs = [
    ("drop_1", 2.56, 2760, 1450, 150, 175, -8),
    ("drop_2", 2.74, 2890, 1580, 196, 229, 7),
    ("drop_3", 2.92, 2720, 1660, 126, 147, -3),
]
for did, st, x, y, w, h, rot in drop_specs:
    add_el(id=did, type="sticker", scene="sodium_water", name="Water droplet cutout", x=x, y=y, width=w, height=h,
           rotation=rot, asset="assets/water_droplet.png", outline_width=8, z=22)
    pop_scale(did, st, 1.12)
    track(did, "rotation", [key(st, rot-10), key(st+0.35, rot, "cubic_out")], "number")
    track(did, "position", [key(st, [x, y+18]), key(st+0.35, [x, y], "cubic_out")], "vector")
    opacity_keys(did, [key(st, 0), key(st+0.18, 1, "cubic_out"), key(4.18, 1), key(4.42, 0, "cubic_in")])

ion_specs = [
    ("na_1", 2.36, 3000, 1290),
    ("na_2", 2.52, 3150, 1430),
    ("na_3", 2.68, 3010, 1580),
]
for iid, st, x, y in ion_specs:
    add_el(id=iid, type="text", scene="sodium_water", name="Sodium ion badge", x=x, y=y, width=124, height=124,
           text="Na+", font_size=42, font_weight="bold", color="#FFFFFF", align="center", valign="center",
           bg_style="circle", bg_color="#FF5A36", bg_border="#FFFFFF", bg_border_width=3, z=24)
    pop_scale(iid, st, 1.14)
    track(iid, "position", [key(st, [x, y-26]), key(st+0.34, [x, y], "cubic_out")], "vector")
    opacity_keys(iid, [key(st, 0), key(st+0.16, 1, "cubic_out"), key(4.18, 1), key(4.42, 0, "cubic_in")])

add_el(id="fluid_arrow", type="arrow", scene="sodium_water", name="Water annotation", x=2850, y=1800, width=470, height=250,
       **{"from": [0.38, 0.30], "to": [-0.18, -0.30]}, bend=-0.10, label="FLUID RETAINED", label_offset=[0.05, 0.47],
       label_size=20, label_width=300, label_height=42, stroke=4, head_size=18, z=25, hand_drawn=True, color="#FF5A36")
track("fluid_arrow", "progress", [key(3.35, 0, "cubic_out"), key(3.8, 1, "cubic_out")], "number")
opacity_keys("fluid_arrow", [key(3.3, 0), key(3.45, 1, "cubic_out"), key(4.18, 1), key(4.42, 0, "cubic_in")])

add_el(id="fluid_chart", type="chart", scene="sodium_water", name="Fluid balance chart", x=3320, y=1750, width=500, height=360,
       chart_type="bar", title="FLUID BALANCE", values=[["usual", 62], ["excess sodium", 78]], max_value=100,
       show_values=False, axes=True, caption="ILLUSTRATIVE RELATIONSHIP — NOT A MEASUREMENT", values_colors=True,
       label_size=21, title_size=24, caption_size=15, z=18)
fade_in("fluid_chart", 2.9, 3.2)
track("fluid_chart", "progress", [key(3.05, 0, "cubic_out"), key(3.8, 1, "cubic_out")], "number")
opacity_keys("fluid_chart", [key(2.9, 0), key(3.2, 1, "cubic_out"), key(4.18, 1), key(4.42, 0, "cubic_in")])

add_el(id="sodium_note", type="text", scene="sodium_water", name="Responsible note", x=2650, y=2000, width=1500, height=46,
       text="Illustrative. Individual responses vary.", font_size=24, font_weight="regular", color="#7A8C99", align="center", z=30)
fade_in("sodium_note", 2.75, 3.05)
opacity_keys("sodium_note", [key(2.75, 0), key(3.05, 0.95, "cubic_out"), key(4.18, 0.95), key(4.42, 0, "cubic_in")])

# ---------------------------------------------------------------- scene 3/4: vessel + hero
add_el(id="bg_03", type="text", scene="blood_volume", name="Scene mark 03", x=4060, y=1040, width=720, height=500,
       text="03", font_size=420, font_weight="bold", color="#334B60", align="center", z=-20, opacity=0.05)

add_el(id="vessel", type="blood_vessel", scene="blood_volume", name="Blood vessel diagram", x=4320, y=1540, width=1030, height=500,
       flow=0, bulge=0, flow_speed=0.085, cell_count=20, z=12)
fade_in("vessel", 4.02, 4.32)
track("vessel", "flow", [key(0, 0, "linear"), key(10, 36, "linear")], "number")
track("vessel", "bulge", [key(4.68, 0, "cubic_in_out"), key(6.2, 0.22, "cubic_out"), key(8.4, 0.18, "sine_in_out")], "number")
opacity_keys("vessel", [key(4.02, 0), key(4.32, 1, "cubic_out"), key(8.0, 1), key(8.24, 0, "cubic_in")])

add_el(id="vessel_label", type="text", scene="blood_volume", name="Volume label", x=4340, y=1810, width=620, height=54,
       text="BLOOD VOLUME", font_size=28, font_weight="bold", color="#334B60", align="left", z=30)
fade_in("vessel_label", 4.82, 5.08)
track("vessel_label", "position", [key(4.82, [4340, 1824]), key(5.12, [4340, 1810], "cubic_out")], "vector")
opacity_keys("vessel_label", [key(4.82, 0), key(5.08, 1, "cubic_out"), key(7.32, 1), key(7.52, 0, "cubic_in")])

add_el(id="gauge", type="pressure_gauge", scene="hero", name="Pressure gauge", x=5080, y=1360, width=520, height=560,
       value=0.12, title="", caption="ILLUSTRATIVE INDICATOR", card=True, z=20)
fade_in("gauge", 4.72, 4.98)
track("gauge", "value", [key(4.75, 0.12, "quint_in_out"), key(6.3, 0.78, "quint_in_out"), key(8.0, 0.78, "sine_in_out")], "number")
track("gauge", "position", [key(4.72, [5130, 1410]), key(6.3, [5080, 1360], "cubic_out")], "vector")
track("gauge", "scale", [key(4.72, [0.94, 0.94]), key(6.3, [1, 1], "cubic_out")], "vector")
opacity_keys("gauge", [key(4.72, 0), key(4.98, 1, "cubic_out"), key(7.28, 1), key(7.52, 0, "cubic_in")])

add_el(id="gauge_note", type="text", scene="hero", name="Gauge disclaimer", x=5080, y=1678, width=520, height=52,
       text="Simplified diagram — not a measurement.", font_size=20, font_weight="regular", color="#7A8C99", align="center", z=30)
fade_in("gauge_note", 4.92, 5.16)
opacity_keys("gauge_note", [key(4.92, 0), key(5.16, 1, "cubic_out"), key(7.28, 1), key(7.52, 0, "cubic_in")])

add_el(id="hero_title", type="text", scene="hero", name="Hero pressure title", x=4450, y=1112, width=700, height=120,
       text="PRESSURE", font_size=88, font_weight="bold", color="#263746", align="left", z=30)
fade_in("hero_title", 4.90, 5.15)
track("hero_title", "position", [key(4.90, [4450, 1150]), key(5.32, [4450, 1112], "cubic_out")], "vector")
track("hero_title", "reveal", [key(4.93, 0, "smoothstep"), key(5.30, 1, "smoothstep")], "number")
opacity_keys("hero_title", [key(4.90, 0), key(5.15, 1, "cubic_out"), key(6.85, 1), key(7.05, 0, "cubic_in")])

add_el(id="hero_rule", type="shape", scene="hero", name="Hero accent rule", x=4480, y=1188, width=250, height=8,
       shape="line", fill="#FF5A36", border_width=7, z=29)
track("hero_rule", "progress", [key(4.98, 0, "cubic_out"), key(5.36, 1, "cubic_out")], "number")
opacity_keys("hero_rule", [key(4.96, 0), key(5.16, 1), key(6.85, 1), key(7.05, 0, "cubic_in")])

# ---------------------------------------------------------------- practical message
add_el(id="practical_text", type="text", scene="practical", name="Practical message", x=4700, y=1935, width=1200, height=130,
       text="CUT BACK ON EXCESS SODIUM.", font_size=62, font_weight="bold", color="#263746", align="left", z=30)
fade_in("practical_text", 7.32, 7.62)
track("practical_text", "position", [key(7.32, [4700, 1970]), key(7.72, [4700, 1935], "cubic_out")], "vector")
opacity_keys("practical_text", [key(7.32, 0), key(7.62, 1, "cubic_out"), key(8.24, 1), key(8.34, 0, "cubic_in")])

add_el(id="practical_rule", type="shape", scene="practical", name="Practical accent rule", x=4720, y=2015, width=470, height=8,
       shape="line", fill="#FF5A36", border_width=7, z=29)
track("practical_rule", "progress", [key(7.35, 0, "cubic_out"), key(7.82, 1, "cubic_out")], "number")
opacity_keys("practical_rule", [key(7.33, 0), key(7.55, 1), key(8.24, 1), key(8.34, 0, "cubic_in")])

add_el(id="practical_shaker", type="sticker", scene="practical", name="Shaker exit animation", x=5470, y=1815, width=290, height=419,
       rotation=8, asset="assets/salt_shaker.png", outline_width=9, z=22)
fade_in("practical_shaker", 7.28, 7.58)
track("practical_shaker", "rotation", [key(7.28, 20, "cubic_out"), key(7.72, 5, "cubic_out")], "number")
track("practical_shaker", "position", [key(7.28, [5520, 1865]), key(7.72, [5470, 1815], "cubic_out")], "vector")
track("practical_shaker", "scale", [key(7.28, [0.84, 0.84]), key(7.72, [1, 1], "cubic_out")], "vector")
opacity_keys("practical_shaker", [key(7.28, 0), key(7.58, 1, "cubic_out"), key(8.24, 1), key(8.34, 0, "cubic_in")])

# ---------------------------------------------------------------- scene 6: end card
add_el(id="bg_04", type="text", scene="end", name="Scene mark 04", x=5400, y=2690, width=620, height=500,
       text="04", font_size=380, font_weight="bold", color="#334B60", align="center", z=-20, opacity=0.055)

add_el(id="end_block", type="shape", scene="end", name="End card", x=5000, y=2220, width=1320, height=760,
       shape="rounded_rect", radius=26, fill="#F6F3EC", border_color="#FFFFFF", border_width=2, shadow=True, z=10)
fade_in("end_block", 8.30, 8.54)
track("end_block", "position", [key(8.30, [5000, 2280]), key(8.74, [5000, 2220], "cubic_out")], "vector")
track("end_block", "scale", [key(8.30, [0.965, 0.965]), key(8.74, [1, 1], "cubic_out")], "vector")

add_el(id="end_brand", type="text", scene="end", name="Brand name", x=4750, y=1932, width=720, height=34,
       text="{{brand_name}}", uppercase=True, font_size=24, font_weight="bold", color="#FF5A36", align="left", z=30)
fade_in("end_brand", 8.36, 8.50)
track("end_brand", "position", [key(8.36, [4750, 1945]), key(8.61, [4750, 1932], "cubic_out")], "vector")

add_el(id="end_rule", type="shape", scene="end", name="End brand rule", x=4750, y=1980, width=126, height=7,
       shape="line", fill="#334B60", border_width=6, z=29)
track("end_rule", "progress", [key(8.40, 0, "cubic_out"), key(8.70, 1, "cubic_out")], "number")
opacity_keys("end_rule", [key(8.40, 0), key(8.56, 1), key(9.9, 1)])

add_el(id="end_title1", type="text", scene="end", name="End headline", x=4950, y=2104, width=1080, height=142,
       text="LESS EXCESS SALT.", font_size=100, font_weight="bold", color="#263746", align="left", z=30)
fade_in("end_title1", 8.38, 8.52)
track("end_title1", "position", [key(8.38, [4950, 2134]), key(8.74, [4950, 2104], "cubic_out")], "vector")
track("end_title1", "reveal", [key(8.40, 0, "smoothstep"), key(8.62, 1, "smoothstep")], "number")
track("end_title1", "scale", [key(9.5, [1, 1]), key(10, [1.004, 1.004], "sine_in_out")], "vector")

add_el(id="end_title2", type="text", scene="end", name="End support line", x=4950, y=2294, width=1080, height=76,
       text="HELP MANAGE BLOOD PRESSURE.", font_size=54, font_weight="bold", color="#334B60", align="left", z=30)
fade_in("end_title2", 8.50, 8.64)
track("end_title2", "position", [key(8.50, [4950, 2320]), key(8.82, [4950, 2294], "cubic_out"), key(9.6, [4950, 2294]), key(10, [4950, 2290], "sine_in_out")], "vector")
track("end_title2", "reveal", [key(8.52, 0, "smoothstep"), key(8.74, 1, "smoothstep")], "number")

add_el(id="end_note", type="text", scene="end", name="End disclaimer", x=4950, y=2466, width=1080, height=60,
       text="Dietary change supports — and does not replace — prescribed care.", font_size=20, font_weight="regular",
       color="#7A8C99", align="left", z=30)
fade_in("end_note", 8.64, 8.78)

add_el(id="end_badge", type="text", scene="end", name="End accent badge", x=5440, y=2180, width=152, height=152,
       text="Na+", font_size=44, font_weight="bold", color="#FFFFFF", align="center", valign="center",
       bg_style="circle", bg_color="#FF5A36", bg_border="#FFFFFF", bg_border_width=3, z=25)
pop_scale("end_badge", 8.52, 1.12)
opacity_keys("end_badge", [key(8.52, 0), key(8.66, 1, "cubic_out"), key(9.9, 1)])
track("end_badge", "rotation", [key(8.52, -8, "cubic_out"), key(8.85, 0, "back_out")], "number")

# ---------------------------------------------------------------- camera
track("@camera", "position", [
    key(0, [1250, 1520], "cubic_in_out"),
    key(0.55, [1280, 1530], "cubic_in_out"),
    key(1.15, [1380, 1510], "sine_in_out"),
    key(2.05, [2600, 1490], "cubic_in_out"),
    key(2.28, [2650, 1490], "smoothstep"),
    key(3.5, [2680, 1510], "smoothstep"),
    key(4.05, [3350, 1580], "cubic_in_out"),
    key(4.55, [4240, 1520], "cubic_in_out"),
    key(4.8, [4380, 1510], "cubic_out"),
    key(5.3, [4450, 1495], "smoothstep"),
    key(6.55, [4680, 1460], "cubic_in_out"),
    key(7.15, [4720, 1470], "smoothstep"),
    key(7.55, [4800, 1610], "cubic_in_out"),
    key(7.95, [4900, 1810], "cubic_in_out"),
    key(8.75, [4930, 2200], "cubic_in_out"),
    key(10.0, [5020, 2250], "sine_in_out"),
], "vector")
track("@camera", "zoom", [
    key(0, 1.06), key(0.55, 1.12, "cubic_out"), key(1.15, 1.08, "sine_in_out"), key(2.05, 0.96, "cubic_in_out"),
    key(2.28, 0.95, "smoothstep"), key(3.5, 1.0, "smoothstep"), key(4.05, 0.86, "cubic_in_out"),
    key(4.55, 1.0, "cubic_in_out"), key(4.8, 0.98, "cubic_out"), key(5.3, 1.06, "smoothstep"),
    key(6.55, 1.27, "cubic_in_out"), key(7.15, 1.28, "smoothstep"),
    key(7.55, 1.14, "cubic_in_out"), key(7.95, 1.03, "cubic_in_out"),
    key(8.75, 0.95, "cubic_in_out"), key(10.0, 0.98, "sine_in_out"),
], "number")
track("@camera", "rotation", [
    key(0, 0), key(2.28, -0.7, "sine_in_out"), key(3.5, 0.4, "sine_in_out"),
    key(4.65, -0.5, "sine_in_out"), key(6.55, 0.3, "sine_in_out"), key(7.95, 0.0, "sine_in_out"),
    key(8.75, 0, "sine_in_out"),
], "number")

# ---------------------------------------------------------------- scenes
scenes = [
    {"id": "hook", "name": "Hook", "start": 0.0, "end": 1.45,
     "purpose": "Immediately establish salt as the subject; first frame is never empty.",
     "camera_target": [1250, 1520], "narration": "en",
     "cues": [{"time": 0.12, "label": "Salt pour", "type": "sfx"}, {"time": 0.55, "label": "UI tick", "type": "sfx"}]},
    {"id": "sodium_water", "name": "Sodium & water", "start": 1.45, "end": 4.3,
     "purpose": "Explain water retention with a simplified sodium/fluid diagram.",
     "camera_target": [2650, 1490], "narration": "en",
     "cues": [{"time": 1.35, "label": "Camera whoosh", "type": "sfx"}, {"time": 2.6, "label": "Water drip", "type": "sfx"}, {"time": 2.95, "label": "Narration 2", "type": "narration"}]},
    {"id": "blood_volume", "name": "Blood volume", "start": 4.3, "end": 4.95,
     "purpose": "Connect fluid balance to blood volume and pressure using a vessel diagram.",
     "camera_target": [4320, 1540], "narration": "en",
     "cues": [{"time": 4.05, "label": "Camera exit", "type": "sfx"}, {"time": 4.28, "label": "Riser", "type": "sfx"}, {"time": 4.7, "label": "Narration 3", "type": "narration"}]},
    {"id": "hero", "name": "Hero pressure moment", "start": 4.95, "end": 7.25,
     "purpose": "Largest composition: vessel cross-section and pressure indicator.",
     "camera_target": [4700, 1470], "narration": "en",
     "cues": [{"time": 4.72, "label": "Gauge accent", "type": "sfx"}]},
    {"id": "practical", "name": "Practical message", "start": 7.25, "end": 8.2,
     "purpose": "Turn explanation into a simple, responsible action.",
     "camera_target": [4880, 1770], "narration": "en",
     "cues": [{"time": 7.2, "label": "Practical transition", "type": "sfx"}, {"time": 7.45, "label": "Narration 4", "type": "narration"}]},
    {"id": "end", "name": "End frame", "start": 8.2, "end": 10.0,
     "purpose": "Typography-led closing card with a 1.2s hold and micro-motion.",
     "camera_target": [4980, 2230], "narration": "en",
     "cues": [{"time": 8.3, "label": "End transition", "type": "sfx"}, {"time": 8.58, "label": "Stamp", "type": "sfx"}, {"time": 8.82, "label": "Final accent", "type": "sfx"}]},
]

subtitles_en = [
    {"start": 0.35, "end": 2.85, "text": "Too much sodium can make your body hold water."},
    {"start": 2.95, "end": 4.72, "text": "That can raise blood pressure."},
    {"start": 4.80, "end": 7.43, "text": "Over time, it can contribute to hypertension."},
    {"start": 7.45, "end": 8.78, "text": "Cutting back helps."},
]

audio_tracks = [
    {"id": "music", "name": "Music bed — 'Quiet Pressure'", "type": "music", "file": "audio/music_bed.wav",
     "start": 0.0, "duration": 10.2, "gain": 0.55, "fade_in": 0.35, "fade_out": 0.8, "mute": False, "solo": False,
     "cues": [{"time": 4.55, "label": "Musical lift"}, {"time": 8.8, "label": "Final accent"}]},
    {"id": "narration_1", "name": "Narration 01 — water", "type": "narration", "file": "audio/narration_01.wav",
     "start": 0.35, "duration": 2.53, "gain": 1.0, "fade_in": 0.05, "fade_out": 0.12, "mute": False, "solo": False,
     "cues": [{"time": 0.35, "label": "Too much sodium..."}]},
    {"id": "narration_2", "name": "Narration 02 — pressure", "type": "narration", "file": "audio/narration_02.wav",
     "start": 2.95, "duration": 1.798, "gain": 1.0, "fade_in": 0.05, "fade_out": 0.15, "mute": False, "solo": False,
     "cues": [{"time": 2.95, "label": "That can raise..."}]},
    {"id": "narration_3", "name": "Narration 03 — hypertension", "type": "narration", "file": "audio/narration_03.wav",
     "start": 4.70, "duration": 2.733, "gain": 1.0, "fade_in": 0.05, "fade_out": 0.18, "mute": False, "solo": False,
     "cues": [{"time": 4.70, "label": "Over time..."}]},
    {"id": "narration_4", "name": "Narration 04 — cutting back", "type": "narration", "file": "audio/narration_04.wav",
     "start": 7.45, "duration": 1.332, "gain": 1.0, "fade_in": 0.05, "fade_out": 0.15, "mute": False, "solo": False,
     "cues": [{"time": 7.45, "label": "Cutting back helps."}]},
    {"id": "sfx_pour", "name": "SFX — Salt pour", "type": "sfx", "file": "audio/sfx_salt_pour.wav",
     "start": 0.10, "duration": 0.95, "gain": 0.55, "fade_in": 0.01, "fade_out": 0.15, "mute": False, "solo": False, "cues": []},
    {"id": "sfx_tick_1", "name": "SFX — UI tick 1", "type": "sfx", "file": "audio/sfx_tick.wav",
     "start": 0.55, "duration": 0.12, "gain": 0.35, "fade_in": 0.0, "fade_out": 0.02, "mute": False, "solo": False, "cues": []},
    {"id": "sfx_whoosh_1", "name": "SFX — Camera whoosh", "type": "sfx", "file": "audio/sfx_whoosh_in.wav",
     "start": 1.35, "duration": 0.9, "gain": 0.38, "fade_in": 0.05, "fade_out": 0.1, "mute": False, "solo": False, "cues": []},
    {"id": "sfx_drip_1", "name": "SFX — Water drip 1", "type": "sfx", "file": "audio/sfx_drip.wav",
     "start": 2.62, "duration": 0.8, "gain": 0.28, "fade_in": 0.0, "fade_out": 0.05, "mute": False, "solo": False, "cues": []},
    {"id": "sfx_drip_2", "name": "SFX — Water drip 2", "type": "sfx", "file": "audio/sfx_drip.wav",
     "start": 3.18, "duration": 0.8, "gain": 0.2, "fade_in": 0.0, "fade_out": 0.05, "mute": False, "solo": False, "cues": []},
    {"id": "sfx_whoosh_2", "name": "SFX — Camera exit", "type": "sfx", "file": "audio/sfx_whoosh_out.wav",
     "start": 4.05, "duration": 0.8, "gain": 0.32, "fade_in": 0.02, "fade_out": 0.08, "mute": False, "solo": False, "cues": []},
    {"id": "sfx_riser", "name": "SFX — Hero riser", "type": "sfx", "file": "audio/sfx_riser.wav",
     "start": 4.28, "duration": 1.5, "gain": 0.3, "fade_in": 0.1, "fade_out": 0.25, "mute": False, "solo": False, "cues": []},
    {"id": "sfx_accent_1", "name": "SFX — Hero accent", "type": "sfx", "file": "audio/sfx_accent.wav",
     "start": 4.72, "duration": 1.8, "gain": 0.38, "fade_in": 0.0, "fade_out": 0.4, "mute": False, "solo": False, "cues": []},
    {"id": "sfx_whoosh_3", "name": "SFX — Practical transition", "type": "sfx", "file": "audio/sfx_whoosh_out.wav",
     "start": 7.2, "duration": 0.8, "gain": 0.28, "fade_in": 0.02, "fade_out": 0.1, "mute": False, "solo": False, "cues": []},
    {"id": "sfx_whoosh_4", "name": "SFX — End transition", "type": "sfx", "file": "audio/sfx_whoosh_in.wav",
     "start": 8.3, "duration": 0.9, "gain": 0.3, "fade_in": 0.03, "fade_out": 0.12, "mute": False, "solo": False, "cues": []},
    {"id": "sfx_stamp", "name": "SFX — End stamp", "type": "sfx", "file": "audio/sfx_stamp.wav",
     "start": 8.58, "duration": 0.7, "gain": 0.45, "fade_in": 0.0, "fade_out": 0.15, "mute": False, "solo": False, "cues": []},
    {"id": "sfx_accent_2", "name": "SFX — Final accent", "type": "sfx", "file": "audio/sfx_accent.wav",
     "start": 8.82, "duration": 1.18, "gain": 0.28, "fade_in": 0.0, "fade_out": 0.5, "mute": False, "solo": False, "cues": []},
]

# Keep one track per element/property; later definitions are the refined ones.
_dedup = {}
for _tr in tracks:
    _dedup[(_tr["element_id"], _tr["property"])] = _tr
tracks = list(_dedup.values())

storyboard = {
    "schema_version": 1,
    "canvas_note": "6000×3000 logical composition. The 1920×1080 camera samples this world.",
    "camera": {"position": [1250, 1520], "zoom": 1.06, "rotation": 0},
    "scenes": scenes,
    "elements": elements,
    "tracks": tracks,
    "audio": {"tracks": audio_tracks},
    "subtitles": {"en": subtitles_en, "my": [], "my_status": "needs_localization"},
    "burn_subtitles": True,
    "camera_path_notes": "Slow lateral pan across the world; settle before each information reveal. No cuts.",
}

(PROJ / "episode.json").write_text(json.dumps(episode, indent=2, ensure_ascii=False) + "\n")
(PROJ / "storyboard.json").write_text(json.dumps(storyboard, indent=2, ensure_ascii=False) + "\n")
print("elements", len(elements), "tracks", len(tracks), "audio", len(audio_tracks))
