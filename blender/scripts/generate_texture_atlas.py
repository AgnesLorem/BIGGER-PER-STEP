# blender/scripts/generate_texture_atlas.py
# Generates the authoritative 256x256 Color Palette Texture Atlas for Project BIGGER (Forest Zone & Objectives)
# Architecture: 8x8 grid (64 color swatches, 32x32 pixels each)

import os
from PIL import Image, ImageDraw

OUTPUT_PATH = r"f:/BIGGER/blender/textures/TextureAtlas.png"
os.makedirs(os.path.dirname(OUTPUT_PATH), exist_ok=True)

# 8x8 Palette Grid (Row 0 top, Row 7 bottom)
PALETTE_GRID = [
    # Row 0: Forest Greens
    [(24, 48, 24), (34, 75, 34), (45, 110, 48), (68, 155, 60), (95, 205, 75), (140, 230, 80), (60, 90, 50), (90, 130, 90)],
    # Row 1: Woods & Earth
    [(35, 22, 14), (55, 35, 20), (82, 50, 28), (115, 72, 40), (150, 98, 55), (185, 130, 80), (130, 105, 75), (95, 75, 55)],
    # Row 2: Stones & Greys
    [(18, 20, 24), (32, 36, 44), (52, 58, 70), (78, 86, 102), (115, 125, 145), (160, 172, 192), (210, 218, 230), (250, 252, 255)],
    # Row 3: Beast & Fur Tones (Boar & Bear)
    [(42, 28, 20), (62, 40, 28), (88, 56, 38), (120, 80, 55), (160, 115, 80), (200, 155, 115), (230, 215, 195), (250, 245, 235)],
    # Row 4: Neon Accents & VFX
    [(255, 30, 30), (255, 90, 20), (255, 180, 20), (255, 230, 40), (32, 255, 120), (30, 200, 255), (60, 120, 255), (180, 60, 255)],
    # Row 5: Spider Chitin & Arachnid
    [(15, 15, 20), (25, 22, 35), (45, 25, 45), (70, 20, 35), (180, 20, 40), (240, 40, 60), (20, 20, 25), (40, 45, 55)],
    # Row 6: Metallics & Stone Trim (Ancient Runes & Teleporter)
    [(40, 45, 60), (70, 80, 100), (105, 120, 145), (145, 160, 185), (200, 215, 235), (212, 175, 55), (245, 200, 70), (255, 230, 120)],
    # Row 7: Foliage & Atmosphere
    [(12, 28, 20), (20, 45, 30), (30, 70, 50), (45, 105, 75), (80, 160, 120), (130, 210, 170), (190, 240, 210), (10, 12, 18)],
]

# Coordinate map for unwrapping: name -> (u, v)
SWATCH_MAP = {
    # Spider (Row 5 & 4)
    "spider_chitin_black": (0, 5),
    "spider_chitin_purple": (1, 5),
    "spider_abdomen": (2, 5),
    "spider_fangs_crimson": (4, 5),
    "spider_eyes_glow": (5, 5),
    "spider_joints": (6, 5),

    # Wild Boar (Row 3 & 1)
    "boar_hide_dark": (0, 3),
    "boar_fur_brown": (1, 3),
    "boar_spikes_grey": (1, 2),
    "boar_snout": (3, 3),
    "boar_tusks_ivory": (6, 3),
    "boar_eyes_red": (0, 4),
    "boar_hooves": (2, 2),

    # Ancient Bear (Row 3 & 6)
    "bear_fur_grizzly": (1, 3),
    "bear_fur_chest": (2, 3),
    "bear_stone_armor": (2, 2),
    "bear_stone_slate": (3, 2),
    "bear_rune_gold": (5, 6),
    "bear_claws": (0, 2),
    "bear_eyes_amber": (2, 4),

    # Teleporter Arch (Row 2 & 6 & 4)
    "teleporter_stone_dark": (1, 2),
    "teleporter_stone_mid": (3, 2),
    "teleporter_stone_light": (4, 2),
    "teleporter_gold_trim": (5, 6),
    "teleporter_cyan_rune": (5, 4),
    "teleporter_portal_glow": (6, 4),

    # Generic & Debris
    "rock_grey": (2, 2),
    "dirt_brown": (2, 1),
    "moss_green": (2, 0),
    "pure_black": (7, 7),
    "pure_white": (7, 2),
}

def generate_texture_atlas():
    img = Image.new("RGB", (256, 256), color=(0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    cell_size = 32
    for row_idx, row in enumerate(PALETTE_GRID):
        for col_idx, color in enumerate(row):
            x0 = col_idx * cell_size
            y0 = row_idx * cell_size
            x1 = x0 + cell_size
            y1 = y0 + cell_size
            draw.rectangle([x0, y0, x1, y1], fill=color)

    img.save(OUTPUT_PATH, format="PNG")
    print(f"[SUCCESS] Texture atlas generated at: {OUTPUT_PATH} (256x256)")

def get_uv_for_swatch(swatch_name: str) -> tuple[float, float]:
    col, row = SWATCH_MAP.get(swatch_name, (0, 0))
    # UV coordinates: U in [0, 1], V in [0, 1] (in Blender V=0 is bottom, V=1 is top)
    # Since row 0 is top of image, V = 1.0 - (row + 0.5) / 8.0
    u = (col + 0.5) / 8.0
    v = 1.0 - (row + 0.5) / 8.0
    return (u, v)

if __name__ == "__main__":
    generate_texture_atlas()
