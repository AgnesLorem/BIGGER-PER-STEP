# blender/scripts/generate_afk_gym_stations.py
# Procedural 3D Generator V2 for BIGGER GYM AFK Training Stations (Tiers 1-7)
# High-Polish Stylized Chunky Mechanical Edition:
# - Zero floating barbells: Functional chunky J-hooks, clamp collars, and spotter arms
# - Strict rear-half placement (X=0 centered): Leaving front half open as Player Workout Deck
# - 4-bolt baseplate flanges and triangular gussets on all posts
# - Removed all 3D signposts (replaced by Roblox Studio BillboardGui per user direction)
# - Redesigned FIFA/Olympia-style Golden Championship Trophy (no bucket shapes)
# - Highly visible illuminated Holographic Championship Belt Showcase Pillar
# - Zero-regression BasePart floor mats named Table1..Table5, VipTable1, VipTable2

import bpy
import math
import os

PROPS_DIR = r"f:/BIGGER/blender/props"
EXPORTS_DIR = r"f:/BIGGER/blender/exports"
os.makedirs(PROPS_DIR, exist_ok=True)
os.makedirs(EXPORTS_DIR, exist_ok=True)

# -----------------------------------------------------------------------------
# 1. SCENE CLEANUP & UTILITIES
# -----------------------------------------------------------------------------

def clear_scene():
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    for block in bpy.data.meshes:
        bpy.data.meshes.remove(block)
    for block in bpy.data.materials:
        bpy.data.materials.remove(block)

def create_pbr_material(name, base_color, roughness=0.5, metallic=0.0, specular=0.5, emission=(0, 0, 0, 1), emission_strength=0.0):
    mat = bpy.data.materials.new(name=name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = base_color
        bsdf.inputs["Roughness"].default_value = roughness
        bsdf.inputs["Metallic"].default_value = metallic
        if "Specular IOR Level" in bsdf.inputs:
            bsdf.inputs["Specular IOR Level"].default_value = specular
        elif "Specular" in bsdf.inputs:
            bsdf.inputs["Specular"].default_value = specular
        if emission_strength > 0:
            if "Emission Color" in bsdf.inputs:
                bsdf.inputs["Emission Color"].default_value = emission
                bsdf.inputs["Emission Strength"].default_value = emission_strength
            elif "Emission" in bsdf.inputs:
                bsdf.inputs["Emission"].default_value = emission
    return mat

# -----------------------------------------------------------------------------
# 2. MATERIALS INITIALIZATION
# -----------------------------------------------------------------------------

def init_materials():
    mats = {}
    # Rubber Floor & Borders
    mats["rubber_dark"] = create_pbr_material("Mat_GymRubber_Dark", (0.10, 0.11, 0.13, 1.0), roughness=0.85, metallic=0.0)
    mats["rubber_border_yellow"] = create_pbr_material("Mat_Rubber_BorderYellow", (0.95, 0.80, 0.10, 1.0), roughness=0.75, metallic=0.0)
    mats["rubber_border_blue"] = create_pbr_material("Mat_Rubber_BorderBlue", (0.15, 0.50, 0.95, 1.0), roughness=0.75, metallic=0.0)
    mats["rubber_border_orange"] = create_pbr_material("Mat_Rubber_BorderOrange", (0.95, 0.45, 0.05, 1.0), roughness=0.75, metallic=0.0)
    mats["rubber_border_crimson"] = create_pbr_material("Mat_Rubber_BorderCrimson", (0.85, 0.15, 0.15, 1.0), roughness=0.75, metallic=0.0)
    mats["hazard_stripe"] = create_pbr_material("Mat_Hazard_Stripe", (0.95, 0.75, 0.05, 1.0), roughness=0.70, metallic=0.05)
    
    # Steels & Metals
    mats["steel_crimson"] = create_pbr_material("Mat_Steel_Crimson", (0.85, 0.12, 0.14, 1.0), roughness=0.35, metallic=0.55)
    mats["steel_cobalt"] = create_pbr_material("Mat_Steel_Cobalt", (0.12, 0.45, 0.88, 1.0), roughness=0.35, metallic=0.55)
    mats["steel_orange"] = create_pbr_material("Mat_Steel_Orange", (0.95, 0.45, 0.05, 1.0), roughness=0.35, metallic=0.55)
    mats["steel_charcoal"] = create_pbr_material("Mat_Steel_Charcoal", (0.16, 0.18, 0.20, 1.0), roughness=0.40, metallic=0.65)
    mats["bolt_silver"] = create_pbr_material("Mat_Bolt_Silver", (0.75, 0.77, 0.80, 1.0), roughness=0.25, metallic=0.85)
    
    # Chrome, Irons & Upholstery
    mats["chrome_bar"] = create_pbr_material("Mat_Chrome_Polished", (0.88, 0.89, 0.92, 1.0), roughness=0.15, metallic=0.95)
    mats["iron_dark"] = create_pbr_material("Mat_Iron_PlateDark", (0.15, 0.16, 0.18, 1.0), roughness=0.55, metallic=0.75)
    mats["leather_black"] = create_pbr_material("Mat_Leather_Black", (0.12, 0.12, 0.14, 1.0), roughness=0.70, metallic=0.0)
    mats["foam_pad"] = create_pbr_material("Mat_Foam_SquatPad", (0.08, 0.08, 0.09, 1.0), roughness=0.85, metallic=0.0)
    mats["chalk_white"] = create_pbr_material("Mat_Chalk_White", (0.95, 0.95, 0.95, 1.0), roughness=0.95, metallic=0.0)
    
    # Bumper Plates
    mats["plate_red"] = create_pbr_material("Mat_Plate_Red", (0.88, 0.15, 0.15, 1.0), roughness=0.5, metallic=0.1)
    mats["plate_blue"] = create_pbr_material("Mat_Plate_Blue", (0.15, 0.45, 0.90, 1.0), roughness=0.5, metallic=0.1)
    mats["plate_yellow"] = create_pbr_material("Mat_Plate_Yellow", (0.95, 0.85, 0.10, 1.0), roughness=0.5, metallic=0.1)
    mats["plate_green"] = create_pbr_material("Mat_Plate_Green", (0.15, 0.80, 0.30, 1.0), roughness=0.5, metallic=0.1)
    
    # VIP 1 Luxury
    mats["gold_luxury"] = create_pbr_material(
        "Mat_Gold_Luxury", (0.95, 0.78, 0.15, 1.0), 
        roughness=0.18, metallic=0.95, 
        emission=(0.95, 0.78, 0.15, 1.0), emission_strength=0.8
    )
    mats["velvet_royal"] = create_pbr_material("Mat_Velvet_Royal", (0.35, 0.05, 0.45, 1.0), roughness=0.90, metallic=0.0)
    mats["marble_white"] = create_pbr_material("Mat_Marble_Pedestal", (0.92, 0.92, 0.94, 1.0), roughness=0.30, metallic=0.05)
    
    # VIP 2 Cyber Neon
    mats["cyber_obsidian"] = create_pbr_material("Mat_Cyber_Obsidian", (0.06, 0.07, 0.09, 1.0), roughness=0.25, metallic=0.80)
    mats["neon_cyan"] = create_pbr_material(
        "Mat_Cyber_NeonCyan", (0.00, 0.95, 0.90, 1.0), 
        roughness=0.1, metallic=0.0, 
        emission=(0.00, 0.95, 0.90, 1.0), emission_strength=5.0
    )
    mats["neon_magenta"] = create_pbr_material(
        "Mat_Cyber_NeonMagenta", (0.95, 0.05, 0.65, 1.0), 
        roughness=0.1, metallic=0.0, 
        emission=(0.95, 0.05, 0.65, 1.0), emission_strength=5.0
    )
    mats["glass_hologram"] = create_pbr_material(
        "Mat_Glass_Hologram", (0.2, 0.8, 1.0, 0.35), 
        roughness=0.05, metallic=0.1,
        emission=(0.1, 0.9, 1.0, 1.0), emission_strength=2.0
    )
    
    return mats

# -----------------------------------------------------------------------------
# 3. PROCEDURAL HARDWARE HELPERS
# -----------------------------------------------------------------------------

def build_floor_pad(name, width, depth, mat_main, mat_border=None, border_width=0.18):
    """Builds the primary BasePart floor pad centered at Z=0.05, exactly on (0, 0)."""
    thickness = 0.10
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, thickness / 2.0))
    pad = bpy.context.active_object
    pad.name = name
    pad.scale = (width, depth, thickness)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    pad.data.materials.append(mat_main)
    parts = [pad]

    if mat_border:
        h_thick = thickness + 0.01
        # North & South rims
        for sign in [-1, 1]:
            bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, sign * (depth / 2.0 - border_width / 2.0), h_thick / 2.0))
            rim = bpy.context.active_object
            rim.name = f"{name}_RimNS_{sign}"
            rim.scale = (width, border_width, h_thick)
            bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
            rim.data.materials.append(mat_border)
            parts.append(rim)
        # East & West rims
        for sign in [-1, 1]:
            bpy.ops.mesh.primitive_cube_add(size=1.0, location=(sign * (width / 2.0 - border_width / 2.0), 0, h_thick / 2.0))
            rim = bpy.context.active_object
            rim.name = f"{name}_RimEW_{sign}"
            rim.scale = (border_width, depth - border_width * 2, h_thick)
            bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
            rim.data.materials.append(mat_border)
            parts.append(rim)

    return pad, parts

def build_bolted_foot(x, y, z_base, mat_flange, mat_bolt, size=0.28):
    """Builds a square baseplate flange with 4 visible hex bolts."""
    parts = []
    # Baseplate
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(x, y, z_base + 0.025))
    flange = bpy.context.active_object
    flange.scale = (size, size, 0.05)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    flange.data.materials.append(mat_flange)
    parts.append(flange)

    # 4 Hex Bolts
    b_off = size * 0.35
    for bx in [-b_off, b_off]:
        for by in [-b_off, b_off]:
            bpy.ops.mesh.primitive_cylinder_add(vertices=6, radius=0.016, depth=0.03, location=(x + bx, y + by, z_base + 0.055))
            bolt = bpy.context.active_object
            bolt.data.materials.append(mat_bolt)
            parts.append(bolt)

    return parts

def build_j_hook(x, y, z, facing_y_sign, mat_hook, width=0.08):
    """Builds a realistic chunky J-hook bracket that wraps column and cradles barbell."""
    parts = []
    # Wrap-around bracket collar
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(x, y, z))
    collar = bpy.context.active_object
    collar.scale = (width + 0.04, 0.16, 0.14)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    collar.data.materials.append(mat_hook)
    parts.append(collar)

    # Horizontal arm extending out
    arm_len = 0.14
    arm_y = y + facing_y_sign * (0.08 + arm_len / 2.0)
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(x, arm_y, z - 0.02))
    arm = bpy.context.active_object
    arm.scale = (width, arm_len, 0.04)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    arm.data.materials.append(mat_hook)
    parts.append(arm)

    # Upward retaining lip (the 'J' catch that prevents bar from rolling off)
    lip_y = y + facing_y_sign * (0.08 + arm_len)
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(x, lip_y, z + 0.03))
    lip = bpy.context.active_object
    lip.scale = (width, 0.03, 0.08)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    lip.data.materials.append(mat_hook)
    parts.append(lip)

    return parts

def build_spring_collar(x, y, z, mat_collar, radius=0.045):
    """Builds a barbell clamp collar with spring handles."""
    parts = []
    bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=radius, depth=0.04, location=(x, y, z))
    collar = bpy.context.active_object
    collar.rotation_euler = (0, math.radians(90), 0)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    collar.data.materials.append(mat_collar)
    parts.append(collar)

    # Spring squeeze handles
    bpy.ops.mesh.primitive_cylinder_add(vertices=6, radius=0.008, depth=0.08, location=(x, y, z + radius + 0.03))
    handle = bpy.context.active_object
    handle.data.materials.append(mat_collar)
    parts.append(handle)

    return parts

# -----------------------------------------------------------------------------
# 4. STATION 1: DUMBBELL RACK (Table1 - 50x)
# -----------------------------------------------------------------------------

def build_station_1(mats):
    parts = []
    width, depth = 3.36, 3.36  # 12x12 studs
    pad, pad_parts = build_floor_pad("Table1", width, depth, mats["rubber_dark"], mats["rubber_border_yellow"])
    parts.extend(pad_parts)

    # Placed in the rear half: Y center at -0.70m (leaving front Y > 0 completely clear)
    rack_y = -0.70
    rack_len = 2.30
    rack_w = 0.55

    # 2 Side A-Frame Uprights
    for sx in [-1, 1]:
        px = sx * (rack_len / 2.0)
        # Base foot
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(px, rack_y, 0.15))
        foot = bpy.context.active_object
        foot.scale = (0.12, 0.70, 0.08)
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        foot.data.materials.append(mats["steel_charcoal"])
        parts.append(foot)
        parts.extend(build_bolted_foot(px, rack_y - 0.25, 0.10, mats["steel_charcoal"], mats["bolt_silver"], size=0.18))
        parts.extend(build_bolted_foot(px, rack_y + 0.25, 0.10, mats["steel_charcoal"], mats["bolt_silver"], size=0.18))

        # Rear vertical post
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(px, rack_y - 0.22, 0.65))
        post_r = bpy.context.active_object
        post_r.scale = (0.08, 0.08, 1.0)
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        post_r.data.materials.append(mats["steel_crimson"])
        parts.append(post_r)

        # Diagonal strut
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(px, rack_y + 0.08, 0.60))
        strut = bpy.context.active_object
        strut.scale = (0.08, 0.08, 0.95)
        strut.rotation_euler = (math.radians(-26), 0, 0)
        bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
        strut.data.materials.append(mats["steel_crimson"])
        parts.append(strut)

    # 2 Solid Angled Trays with Dumbbell Saddles
    shelves = [
        # (z, y, angle)
        (0.55, rack_y + 0.06, -18),
        (0.92, rack_y - 0.12, -18)
    ]
    for sz, sy, sang in shelves:
        # Tray channel
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, sy, sz))
        tray = bpy.context.active_object
        tray.scale = (rack_len + 0.05, 0.32, 0.05)
        tray.rotation_euler = (math.radians(sang), 0, 0)
        bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
        tray.data.materials.append(mats["steel_charcoal"])
        parts.append(tray)

    # 4 Pairs of Hex Dumbbells securely seated in saddles
    pairs = [
        (-0.80, mats["plate_red"], 0.10, 0.05),
        (-0.28, mats["plate_blue"], 0.12, 0.06),
        (0.28, mats["plate_yellow"], 0.14, 0.07),
        (0.80, mats["plate_green"], 0.16, 0.08),
    ]
    for sz, sy, sang in shelves:
        dz = sz + 0.06
        for px, pmat, pr, pthick in pairs:
            # Handle
            bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=0.020, depth=0.22, location=(px, sy, dz))
            handle = bpy.context.active_object
            handle.rotation_euler = (math.radians(90 + sang), 0, 0)
            bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
            handle.data.materials.append(mats["chrome_bar"])
            parts.append(handle)

            # Hex Heads
            for hy_off in [-0.10, 0.10]:
                bpy.ops.mesh.primitive_cylinder_add(vertices=6, radius=pr, depth=pthick, location=(px, sy + hy_off, dz))
                head = bpy.context.active_object
                head.rotation_euler = (math.radians(90 + sang), 0, 0)
                bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
                head.data.materials.append(pmat)
                parts.append(head)

    # Front Workout Deck Grip Lines (in front half)
    for gy in [0.4, 0.8, 1.2]:
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, gy, 0.105))
        gline = bpy.context.active_object
        gline.scale = (2.4, 0.05, 0.01)
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        gline.data.materials.append(mats["rubber_border_yellow"])
        parts.append(gline)

    return pad, parts

# -----------------------------------------------------------------------------
# 5. STATION 2: CALISTHENICS PULL-UP & DIP RIG (Table2 - 100x)
# -----------------------------------------------------------------------------

def build_station_2(mats):
    parts = []
    width, depth = 3.36, 3.36  # 12x12 studs
    pad, pad_parts = build_floor_pad("Table2", width, depth, mats["rubber_dark"], mats["rubber_border_blue"])
    parts.extend(pad_parts)

    # Strictly centered on X=0, positioned in rear half: Y center at -0.70m
    rig_y = -0.70
    rig_w = 1.90
    rig_d = 1.20
    rig_h = 2.70

    # 4 Cobalt Blue Steel Columns with 4-Bolt Flanges
    for sx in [-1, 1]:
        for sy in [-1, 1]:
            px = sx * (rig_w / 2.0)
            py = rig_y + sy * (rig_d / 2.0)
            bpy.ops.mesh.primitive_cube_add(size=1.0, location=(px, py, rig_h / 2.0))
            col = bpy.context.active_object
            col.scale = (0.12, 0.12, rig_h)
            bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
            col.data.materials.append(mats["steel_cobalt"])
            parts.append(col)

            # Bolted Footplate
            parts.extend(build_bolted_foot(px, py, 0.10, mats["steel_charcoal"], mats["bolt_silver"], size=0.26))

    # Top Structural Beams & Triangular Gusset Brackets
    for sy in [-1, 1]:
        py = rig_y + sy * (rig_d / 2.0)
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, py, rig_h - 0.06))
        beam = bpy.context.active_object
        beam.scale = (rig_w + 0.12, 0.12, 0.12)
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        beam.data.materials.append(mats["steel_cobalt"])
        parts.append(beam)

        # Gusset plates in corners
        for sx in [-1, 1]:
            gx = sx * (rig_w / 2.0 - 0.12)
            bpy.ops.mesh.primitive_cube_add(size=1.0, location=(gx, py, rig_h - 0.18))
            gusset = bpy.context.active_object
            gusset.scale = (0.12, 0.03, 0.12)
            bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
            gusset.data.materials.append(mats["steel_charcoal"])
            parts.append(gusset)

    # Multi-Grip Pull-Up Bars Across Top Ladder
    for ry in [-0.35, 0.0, 0.35]:
        bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=0.024, depth=rig_w, location=(0, rig_y + ry, rig_h - 0.05))
        bar = bpy.context.active_object
        bar.rotation_euler = (0, math.radians(90), 0)
        bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
        bar.data.materials.append(mats["chrome_bar"])
        parts.append(bar)

    # Ergonomic Dip Horns Extending Forward from the Front Posts
    dip_z = 1.25
    for sx in [-0.55, 0.55]:
        front_y = rig_y + (rig_d / 2.0)
        bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=0.028, depth=0.75, location=(sx, front_y + 0.35, dip_z))
        dip_bar = bpy.context.active_object
        dip_bar.rotation_euler = (math.radians(90), 0, 0)
        bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
        dip_bar.data.materials.append(mats["chrome_bar"])
        parts.append(dip_bar)

        # Thick Contoured Foam Grip
        bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=0.040, depth=0.42, location=(sx, front_y + 0.42, dip_z))
        grip = bpy.context.active_object
        grip.rotation_euler = (math.radians(90), 0, 0)
        bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
        grip.data.materials.append(mats["foam_pad"])
        parts.append(grip)

    # Chalk Bucket Stand Safely on Rear-Left Corner
    cb_x, cb_y = -1.25, -1.15
    bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=0.03, depth=0.85, location=(cb_x, cb_y, 0.52))
    cb_stand = bpy.context.active_object
    cb_stand.data.materials.append(mats["steel_charcoal"])
    parts.append(cb_stand)
    parts.extend(build_bolted_foot(cb_x, cb_y, 0.10, mats["steel_charcoal"], mats["bolt_silver"], size=0.20))

    bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=0.18, depth=0.18, location=(cb_x, cb_y, 0.95))
    cb_bowl = bpy.context.active_object
    cb_bowl.data.materials.append(mats["steel_charcoal"])
    parts.append(cb_bowl)

    bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=0.16, depth=0.06, location=(cb_x, cb_y, 1.00))
    chalk = bpy.context.active_object
    chalk.data.materials.append(mats["chalk_white"])
    parts.append(chalk)

    # Front Workout Deck Grip Lines
    for gy in [0.4, 0.8, 1.2]:
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, gy, 0.105))
        gline = bpy.context.active_object
        gline.scale = (2.2, 0.05, 0.01)
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        gline.data.materials.append(mats["rubber_border_blue"])
        parts.append(gline)

    return pad, parts

# -----------------------------------------------------------------------------
# 6. STATION 3: OLYMPIC BENCH PRESS (Table3 - 150x)
# -----------------------------------------------------------------------------

def build_station_3(mats):
    parts = []
    width, depth = 3.36, 3.36  # 12x12 studs
    pad, pad_parts = build_floor_pad("Table3", width, depth, mats["rubber_dark"], mats["rubber_border_orange"])
    parts.extend(pad_parts)

    bench_y = -0.55
    rack_w = 1.15
    hook_z = 1.08  # Barbell resting height

    # 2 Upright Barbell Supports with J-Hooks
    for sx in [-1, 1]:
        px = sx * (rack_w / 2.0)
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(px, bench_y - 0.45, 0.65))
        upright = bpy.context.active_object
        upright.scale = (0.10, 0.10, 1.15)
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        upright.data.materials.append(mats["steel_orange"])
        parts.append(upright)

        # Flange Feet
        parts.extend(build_bolted_foot(px, bench_y - 0.45, 0.10, mats["steel_charcoal"], mats["bolt_silver"], size=0.22))

        # Heavy J-Hook holding the bar
        parts.extend(build_j_hook(px, bench_y - 0.45, hook_z, facing_y_sign=1, mat_hook=mats["steel_charcoal"]))

    # Solid Bench Press Frame (Box tube)
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, bench_y, 0.22))
    spine = bpy.context.active_object
    spine.scale = (0.12, 1.40, 0.10)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    spine.data.materials.append(mats["steel_orange"])
    parts.append(spine)

    # Bench cross-feet
    for ly in [bench_y - 0.45, bench_y + 0.60]:
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, ly, 0.20))
        c_foot = bpy.context.active_object
        c_foot.scale = (0.65, 0.10, 0.22)
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        c_foot.data.materials.append(mats["steel_orange"])
        parts.append(c_foot)
        parts.extend(build_bolted_foot(-0.25, ly, 0.10, mats["steel_charcoal"], mats["bolt_silver"], size=0.14))
        parts.extend(build_bolted_foot(0.25, ly, 0.10, mats["steel_charcoal"], mats["bolt_silver"], size=0.14))

    # Contoured Leather Bench Cushion
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, bench_y + 0.10, 0.48))
    cushion = bpy.context.active_object
    cushion.scale = (0.36, 1.25, 0.09)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    cushion.data.materials.append(mats["leather_black"])
    parts.append(cushion)

    # Olympic Barbell Resting DIRECTLY ON the J-Hooks!
    bar_y = bench_y - 0.33  # Directly inside the cradle of the J-hook
    bar_z = hook_z + 0.03
    bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=0.024, depth=2.20, location=(0, bar_y, bar_z))
    bar = bpy.context.active_object
    bar.rotation_euler = (0, math.radians(90), 0)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    bar.data.materials.append(mats["chrome_bar"])
    parts.append(bar)

    # Olympic Bumper Plates & Spring Collars
    plates_def = [
        (0.66, 0.24, 0.045, mats["plate_red"]),
        (0.72, 0.24, 0.045, mats["plate_blue"]),
        (0.78, 0.22, 0.040, mats["plate_yellow"]),
        (0.83, 0.20, 0.035, mats["plate_green"]),
    ]
    for sx in [-1, 1]:
        for ox, pr, pd, pmat in plates_def:
            bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=pr, depth=pd, location=(sx * ox, bar_y, bar_z))
            plate = bpy.context.active_object
            plate.rotation_euler = (0, math.radians(90), 0)
            bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
            plate.data.materials.append(pmat)
            parts.append(plate)
        # Spring clamp collar
        parts.extend(build_spring_collar(sx * 0.88, bar_y, bar_z, mats["steel_charcoal"]))

    # Weight Plate Tree on Side
    tree_x, tree_y = 1.15, -0.65
    bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=0.04, depth=1.10, location=(tree_x, tree_y, 0.65))
    tree = bpy.context.active_object
    tree.data.materials.append(mats["steel_charcoal"])
    parts.append(tree)
    parts.extend(build_bolted_foot(tree_x, tree_y, 0.10, mats["steel_charcoal"], mats["bolt_silver"], size=0.24))

    for tz, pr, pmat in [(0.38, 0.24, mats["plate_red"]), (0.68, 0.22, mats["plate_blue"]), (0.95, 0.18, mats["plate_yellow"])]:
        bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=pr, depth=0.08, location=(tree_x, tree_y, tz))
        w_plate = bpy.context.active_object
        w_plate.data.materials.append(pmat)
        parts.append(w_plate)

    # Front Workout Deck Grip Lines
    for gy in [0.4, 0.8, 1.2]:
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, gy, 0.105))
        gline = bpy.context.active_object
        gline.scale = (2.2, 0.05, 0.01)
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        gline.data.materials.append(mats["rubber_border_orange"])
        parts.append(gline)

    return pad, parts

# -----------------------------------------------------------------------------
# 7. STATION 4: HEAVY SQUAT POWER RACK (Table4 - 200x)
# -----------------------------------------------------------------------------

def build_station_4(mats):
    parts = []
    width, depth = 3.92, 3.92  # 14x14 studs
    pad, pad_parts = build_floor_pad("Table4", width, depth, mats["rubber_dark"], mats["rubber_border_crimson"])
    parts.extend(pad_parts)

    # Centered on X=0, seated in rear half: Y center at -0.65m
    cage_y = -0.65
    cage_w = 1.60
    cage_d = 1.30
    cage_h = 2.65
    hook_z = 1.50  # Barbell resting height

    # 4 Steel Columns with 4-Bolt Flanges
    for sx in [-1, 1]:
        for sy in [-1, 1]:
            cx = sx * (cage_w / 2.0)
            cy = cage_y + sy * (cage_d / 2.0)
            bpy.ops.mesh.primitive_cube_add(size=1.0, location=(cx, cy, cage_h / 2.0))
            col = bpy.context.active_object
            col.scale = (0.12, 0.12, cage_h)
            bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
            col.data.materials.append(mats["steel_charcoal"])
            parts.append(col)

            parts.extend(build_bolted_foot(cx, cy, 0.10, mats["steel_crimson"], mats["bolt_silver"], size=0.25))

    # Top Crossbeams & Corner Gussets
    for sy in [-1, 1]:
        cy = cage_y + sy * (cage_d / 2.0)
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, cy, cage_h - 0.06))
        beam = bpy.context.active_object
        beam.scale = (cage_w + 0.12, 0.10, 0.12)
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        beam.data.materials.append(mats["steel_crimson"])
        parts.append(beam)

    # Side Safety Spotter Bars Running Front-to-Back at Z=0.90m
    spot_z = 0.90
    for sx in [-1, 1]:
        cx = sx * (cage_w / 2.0)
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(cx, cage_y, spot_z))
        spot = bpy.context.active_object
        spot.scale = (0.08, cage_d + 0.10, 0.08)
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        spot.data.materials.append(mats["chrome_bar"])
        parts.append(spot)

    # Chunky J-Hooks Mounted on the Two Rear Posts Facing Forward (+Y)
    for sx in [-1, 1]:
        cx = sx * (cage_w / 2.0)
        cy = cage_y - (cage_d / 2.0)
        parts.extend(build_j_hook(cx, cy, hook_z, facing_y_sign=1, mat_hook=mats["steel_crimson"]))

    # Barbell Resting DIRECTLY ON the J-Hooks!
    bar_y = cage_y - (cage_d / 2.0) + 0.12
    bar_z = hook_z + 0.03
    bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=0.026, depth=2.40, location=(0, bar_y, bar_z))
    bar = bpy.context.active_object
    bar.rotation_euler = (0, math.radians(90), 0)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    bar.data.materials.append(mats["chrome_bar"])
    parts.append(bar)

    # Thick Squat Foam Neck Pad in Center of Bar
    bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=0.055, depth=0.45, location=(0, bar_y, bar_z))
    neck_pad = bpy.context.active_object
    neck_pad.rotation_euler = (0, math.radians(90), 0)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    neck_pad.data.materials.append(mats["foam_pad"])
    parts.append(neck_pad)

    # Colossal 45lb Black Iron Plates & Spring Collars
    for sx in [-1, 1]:
        for p_idx, ox in enumerate([0.72, 0.79, 0.86, 0.93]):
            bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=0.25, depth=0.055, location=(sx * ox, bar_y, bar_z))
            plate = bpy.context.active_object
            plate.rotation_euler = (0, math.radians(90), 0)
            bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
            plate.data.materials.append(mats["iron_dark"])
            parts.append(plate)
        # Barbell collar
        parts.extend(build_spring_collar(sx * 0.98, bar_y, bar_z, mats["steel_crimson"]))

    # Front Workout Deck Grip Lines
    for gy in [0.4, 0.9, 1.4]:
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, gy, 0.105))
        gline = bpy.context.active_object
        gline.scale = (2.6, 0.06, 0.01)
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        gline.data.materials.append(mats["rubber_border_crimson"])
        parts.append(gline)

    return pad, parts

# -----------------------------------------------------------------------------
# 8. STATION 5: MONSTER TIRE DEADLIFT (Table5 - 250x)
# -----------------------------------------------------------------------------

def build_station_5(mats):
    parts = []
    width, depth = 3.92, 3.92  # 14x14 studs
    pad, pad_parts = build_floor_pad("Table5", width, depth, mats["rubber_dark"], mats["hazard_stripe"], border_width=0.22)
    parts.extend(pad_parts)

    # Positioned in rear half: Y center at -0.60m
    deadlift_y = -0.60
    tire_r = 0.48
    bar_z = tire_r + 0.05  # Resting naturally on the floor via the tires!

    # Heavy Steel Diamond-Plate Drop Platforms under tires
    for sx in [-1, 1]:
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(sx * 1.05, deadlift_y, 0.14))
        drop_pad = bpy.context.active_object
        drop_pad.scale = (0.85, 1.40, 0.08)
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        drop_pad.data.materials.append(mats["steel_charcoal"])
        parts.append(drop_pad)

    # Extra-Thick Steel Axle Barbell
    bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=0.038, depth=2.80, location=(0, deadlift_y, bar_z))
    axle = bpy.context.active_object
    axle.rotation_euler = (0, math.radians(90), 0)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    axle.data.materials.append(mats["iron_dark"])
    parts.append(axle)

    # Knurled Center Grip Sections
    for sx in [-0.25, 0.25]:
        bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=0.040, depth=0.25, location=(sx, deadlift_y, bar_z))
        knurl = bpy.context.active_object
        knurl.rotation_euler = (0, math.radians(90), 0)
        bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
        knurl.data.materials.append(mats["chrome_bar"])
        parts.append(knurl)

    # 4 Giant Monster Truck Tractor Tires Resting Directly on the Floor
    for sx in [-1, 1]:
        for t_idx, ox in enumerate([0.88, 1.16]):
            # Tire Tread
            bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=tire_r, depth=0.22, location=(sx * ox, deadlift_y, bar_z))
            tire = bpy.context.active_object
            tire.rotation_euler = (0, math.radians(90), 0)
            bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
            tire.data.materials.append(mats["iron_dark"])
            parts.append(tire)

            # Central Heavy Hub & Rim Plate
            bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=0.24, depth=0.25, location=(sx * ox, deadlift_y, bar_z))
            hub = bpy.context.active_object
            hub.rotation_euler = (0, math.radians(90), 0)
            bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
            hub.data.materials.append(mats["steel_charcoal"])
            parts.append(hub)

        # Heavy Steel Chains Pooling Down to Platform
        for cx in [0.55, 0.65]:
            bpy.ops.mesh.primitive_cylinder_add(vertices=6, radius=0.024, depth=0.40, location=(sx * cx, deadlift_y, 0.28))
            chain = bpy.context.active_object
            chain.data.materials.append(mats["iron_dark"])
            parts.append(chain)

    # Front Workout Deck Grip Lines
    for gy in [0.4, 0.9, 1.4]:
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, gy, 0.105))
        gline = bpy.context.active_object
        gline.scale = (2.6, 0.06, 0.01)
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        gline.data.materials.append(mats["hazard_stripe"])
        parts.append(gline)

    return pad, parts

# -----------------------------------------------------------------------------
# 9. VIP STATION 1: ROYAL GOLD BARBELL & TRUE CHAMPIONSHIP TROPHY (VipTable1 - 300x)
# -----------------------------------------------------------------------------

def build_station_vip_1(mats):
    parts = []
    width, depth = 4.48, 4.48  # 16x16 studs
    pad, pad_parts = build_floor_pad("VipTable1", width, depth, mats["rubber_dark"], mats["gold_luxury"], border_width=0.25)
    parts.extend(pad_parts)

    bench_y = -0.60
    rack_w = 1.25
    hook_z = 1.10

    # Mirror Gold Frame Columns with Golden J-Hooks
    for sx in [-1, 1]:
        px = sx * (rack_w / 2.0)
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(px, bench_y - 0.45, 0.70))
        post = bpy.context.active_object
        post.scale = (0.12, 0.12, 1.25)
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        post.data.materials.append(mats["gold_luxury"])
        parts.append(post)

        parts.extend(build_bolted_foot(px, bench_y - 0.45, 0.10, mats["gold_luxury"], mats["gold_luxury"], size=0.24))
        # Golden J-Hook
        parts.extend(build_j_hook(px, bench_y - 0.45, hook_z, facing_y_sign=1, mat_hook=mats["gold_luxury"]))

    # Royal Purple Velvet Padded Bench on Gold Base
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, bench_y + 0.12, 0.48))
    bench = bpy.context.active_object
    bench.scale = (0.42, 1.35, 0.10)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    bench.data.materials.append(mats["velvet_royal"])
    parts.append(bench)

    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, bench_y + 0.12, 0.22))
    b_base = bpy.context.active_object
    b_base.scale = (0.48, 1.40, 0.20)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    b_base.data.materials.append(mats["gold_luxury"])
    parts.append(b_base)

    # Gold Barbell Resting DIRECTLY in Golden J-Hooks
    bar_y = bench_y - 0.33
    bar_z = hook_z + 0.03
    bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=0.025, depth=2.40, location=(0, bar_y, bar_z))
    bar = bpy.context.active_object
    bar.rotation_euler = (0, math.radians(90), 0)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    bar.data.materials.append(mats["gold_luxury"])
    parts.append(bar)

    for sx in [-1, 1]:
        for ox in [0.72, 0.80, 0.88]:
            bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=0.25, depth=0.06, location=(sx * ox, bar_y, bar_z))
            g_plate = bpy.context.active_object
            g_plate.rotation_euler = (0, math.radians(90), 0)
            bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
            g_plate.data.materials.append(mats["gold_luxury"])
            parts.append(g_plate)
        parts.extend(build_spring_collar(sx * 0.94, bar_y, bar_z, mats["gold_luxury"]))

    # Golden Stanchions Framing Rear and Sides
    for px, py in [(-1.8, -1.8), (1.8, -1.8), (-1.8, 0.0), (1.8, 0.0)]:
        bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=0.04, depth=0.95, location=(px, py, 0.55))
        stanch = bpy.context.active_object
        stanch.data.materials.append(mats["gold_luxury"])
        parts.append(stanch)
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=0.08, location=(px, py, 1.05))
        s_ball = bpy.context.active_object
        s_ball.data.materials.append(mats["gold_luxury"])
        parts.append(s_ball)

    # 🏆 REAL OLYMPIA / FIFA STYLE GOLDEN CHAMPIONSHIP TROPHY (Rear-Right Corner)
    trop_x, trop_y = 1.35, -1.15
    
    # 1. Tiered Marble Pedestal Base
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(trop_x, trop_y, 0.40))
    ped_base = bpy.context.active_object
    ped_base.scale = (0.70, 0.70, 0.65)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    ped_base.data.materials.append(mats["marble_white"])
    parts.append(ped_base)

    # Engraved Gold Nameplate on Pedestal Face
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(trop_x, trop_y + 0.36, 0.42))
    nameplate = bpy.context.active_object
    nameplate.scale = (0.42, 0.02, 0.18)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    nameplate.data.materials.append(mats["gold_luxury"])
    parts.append(nameplate)

    # 2. Golden Tiered Plinth (Stepped foot of the cup)
    bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=0.24, depth=0.06, location=(trop_x, trop_y, 0.75))
    tr_foot1 = bpy.context.active_object
    tr_foot1.data.materials.append(mats["gold_luxury"])
    parts.append(tr_foot1)

    bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=0.18, depth=0.06, location=(trop_x, trop_y, 0.81))
    tr_foot2 = bpy.context.active_object
    tr_foot2.data.materials.append(mats["gold_luxury"])
    parts.append(tr_foot2)

    # 3. Fluted Stem with Central Node Ring
    bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=0.06, depth=0.18, location=(trop_x, trop_y, 0.93))
    tr_stem = bpy.context.active_object
    tr_stem.data.materials.append(mats["gold_luxury"])
    parts.append(tr_stem)

    bpy.ops.mesh.primitive_torus_add(major_radius=0.09, minor_radius=0.025, location=(trop_x, trop_y, 0.93))
    tr_node = bpy.context.active_object
    tr_node.data.materials.append(mats["gold_luxury"])
    parts.append(tr_node)

    # 4. Chalice Cup Body (Hemisphere base + elegant flared upper bell, NO bucket cone!)
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=0.18, location=(trop_x, trop_y, 1.10))
    cup_base = bpy.context.active_object
    cup_base.scale = (1.0, 1.0, 0.8)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    cup_base.data.materials.append(mats["gold_luxury"])
    parts.append(cup_base)

    bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=0.22, depth=0.24, location=(trop_x, trop_y, 1.25))
    cup_body = bpy.context.active_object
    cup_body.data.materials.append(mats["gold_luxury"])
    parts.append(cup_body)

    # Flared Upper Rim Lip
    bpy.ops.mesh.primitive_torus_add(major_radius=0.23, minor_radius=0.025, location=(trop_x, trop_y, 1.37))
    tr_rim = bpy.context.active_object
    tr_rim.data.materials.append(mats["gold_luxury"])
    parts.append(tr_rim)

    # 5. Two Sweeping Regal Winged Handles (Arched C-curves)
    for sign in [-1, 1]:
        bpy.ops.mesh.primitive_torus_add(major_radius=0.16, minor_radius=0.028, location=(trop_x + sign * 0.26, trop_y, 1.22))
        handle = bpy.context.active_object
        handle.rotation_euler = (math.radians(90), 0, 0)
        bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
        handle.data.materials.append(mats["gold_luxury"])
        parts.append(handle)

    # Front Workout Deck Grip Lines
    for gy in [0.5, 1.1, 1.7]:
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, gy, 0.105))
        gline = bpy.context.active_object
        gline.scale = (3.2, 0.06, 0.01)
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        gline.data.materials.append(mats["gold_luxury"])
        parts.append(gline)

    return pad, parts

# -----------------------------------------------------------------------------
# 10. VIP STATION 2: CYBER NEON STATION & BELT SHOWCASE (VipTable2 - 400x)
# -----------------------------------------------------------------------------

def build_station_vip_2(mats):
    parts = []
    width, depth = 4.48, 4.48  # 16x16 studs
    pad, pad_parts = build_floor_pad("VipTable2", width, depth, mats["cyber_obsidian"], mats["neon_cyan"], border_width=0.25)
    parts.extend(pad_parts)

    # Glowing Neon Grid Inlays on Floor Pad
    for gx in [-1.4, 0.0, 1.4]:
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(gx, 0, 0.105))
        grid_l = bpy.context.active_object
        grid_l.scale = (0.03, depth - 0.6, 0.01)
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        grid_l.data.materials.append(mats["neon_magenta"])
        parts.append(grid_l)

    cage_y = -0.65
    cage_w = 1.75
    cage_d = 1.30
    cage_h = 2.70
    hook_z = 1.45

    # 4 Matte Obsidian Columns with Neon Cyan Light Strips
    for sx in [-1, 1]:
        for sy in [-1, 1]:
            cx = sx * (cage_w / 2.0)
            cy = cage_y + sy * (cage_d / 2.0)
            bpy.ops.mesh.primitive_cube_add(size=1.0, location=(cx, cy, cage_h / 2.0))
            col = bpy.context.active_object
            col.scale = (0.13, 0.13, cage_h)
            bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
            col.data.materials.append(mats["cyber_obsidian"])
            parts.append(col)

            parts.extend(build_bolted_foot(cx, cy, 0.10, mats["cyber_obsidian"], mats["neon_cyan"], size=0.25))

            # Neon strip along post
            bpy.ops.mesh.primitive_cube_add(size=1.0, location=(cx, cy + sy * 0.07, cage_h / 2.0))
            strip = bpy.context.active_object
            strip.scale = (0.04, 0.02, cage_h - 0.20)
            bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
            strip.data.materials.append(mats["neon_cyan"])
            parts.append(strip)

    # Top Crossbeams & Neon Magenta Conduits
    for sy in [-1, 1]:
        cy = cage_y + sy * (cage_d / 2.0)
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, cy, cage_h - 0.06))
        beam = bpy.context.active_object
        beam.scale = (cage_w + 0.14, 0.12, 0.12)
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        beam.data.materials.append(mats["cyber_obsidian"])
        parts.append(beam)

        # Neon Magenta Glow Conduit
        bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=0.025, depth=cage_w, location=(0, cy, cage_h - 0.06))
        conduit = bpy.context.active_object
        conduit.rotation_euler = (0, math.radians(90), 0)
        bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
        conduit.data.materials.append(mats["neon_magenta"])
        parts.append(conduit)

    # Cyber J-Hooks Mounted on Rear Columns
    for sx in [-1, 1]:
        cx = sx * (cage_w / 2.0)
        cy = cage_y - (cage_d / 2.0)
        parts.extend(build_j_hook(cx, cy, hook_z, facing_y_sign=1, mat_hook=mats["cyber_obsidian"]))

    # Straight, Sturdy Cybernetic Bench (Level & Perfectly Centered on X=0)
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, cage_y, 0.48))
    c_bench = bpy.context.active_object
    c_bench.scale = (0.42, 1.40, 0.10)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    c_bench.data.materials.append(mats["cyber_obsidian"])
    parts.append(c_bench)

    # Bench Neon Accent Strip
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, cage_y, 0.42))
    b_stripe = bpy.context.active_object
    b_stripe.scale = (0.44, 1.42, 0.03)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    b_stripe.data.materials.append(mats["neon_cyan"])
    parts.append(b_stripe)

    # Barbell Resting DIRECTLY on Cyber J-Hooks
    bar_y = cage_y - (cage_d / 2.0) + 0.12
    bar_z = hook_z + 0.03
    bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=0.028, depth=2.40, location=(0, bar_y, bar_z))
    bar = bpy.context.active_object
    bar.rotation_euler = (0, math.radians(90), 0)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    bar.data.materials.append(mats["chrome_bar"])
    parts.append(bar)

    # Dual Glowing Neon Energy Rings
    for sx in [-1, 1]:
        for ox, n_mat in [(0.72, mats["neon_cyan"]), (0.80, mats["neon_magenta"]), (0.88, mats["neon_cyan"])]:
            bpy.ops.mesh.primitive_torus_add(major_radius=0.25, minor_radius=0.035, location=(sx * ox, bar_y, bar_z))
            ring = bpy.context.active_object
            ring.rotation_euler = (0, math.radians(90), 0)
            bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
            ring.data.materials.append(n_mat)
            parts.append(ring)
        parts.extend(build_spring_collar(sx * 0.94, bar_y, bar_z, mats["cyber_obsidian"]))

    # 🌌 HIGHLY VISIBLE HOLOGRAPHIC CHAMPIONSHIP BELT SHOWCASE (Rear-Left Corner)
    case_x, case_y = -1.40, -1.20

    # 1. Hexagonal Obsidian Base
    bpy.ops.mesh.primitive_cylinder_add(vertices=6, radius=0.48, depth=0.60, location=(case_x, case_y, 0.40))
    ped = bpy.context.active_object
    ped.data.materials.append(mats["cyber_obsidian"])
    parts.append(ped)

    # Holographic Projector Emitter Ring
    bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=0.42, depth=0.05, location=(case_x, case_y, 0.72))
    emitter = bpy.context.active_object
    emitter.data.materials.append(mats["neon_cyan"])
    parts.append(emitter)

    # 2. Transparent Crystal Containment Tube
    bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=0.40, depth=0.95, location=(case_x, case_y, 1.22))
    tube = bpy.context.active_object
    tube.data.materials.append(mats["glass_hologram"])
    parts.append(tube)

    # Top Cap
    bpy.ops.mesh.primitive_cylinder_add(vertices=6, radius=0.45, depth=0.10, location=(case_x, case_y, 1.72))
    top_cap = bpy.context.active_object
    top_cap.data.materials.append(mats["cyber_obsidian"])
    parts.append(top_cap)

    # 3. 🥇 THE PROMINENT CHAMPIONSHIP BELT (Floating inside)
    # Curved Heavy Leather Strap
    belt_z = 1.20
    bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=0.24, depth=0.20, location=(case_x, case_y, belt_z))
    strap = bpy.context.active_object
    strap.scale = (1.0, 0.85, 1.0)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    strap.data.materials.append(mats["leather_black"])
    parts.append(strap)

    # Giant Gold Center Emblem Plate
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(case_x, case_y + 0.22, belt_z))
    c_plate = bpy.context.active_object
    c_plate.scale = (0.24, 0.03, 0.20)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    c_plate.data.materials.append(mats["gold_luxury"])
    parts.append(c_plate)

    # Emissive Glowing Eagle / Star Medallion in Center
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=0.06, location=(case_x, case_y + 0.24, belt_z))
    gem = bpy.context.active_object
    gem.data.materials.append(mats["neon_cyan"])
    parts.append(gem)

    # 2 Golden Side Plates on Belt
    for ss in [-1, 1]:
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(case_x + ss * 0.18, case_y + 0.16, belt_z))
        s_plate = bpy.context.active_object
        s_plate.scale = (0.08, 0.02, 0.12)
        s_plate.rotation_euler = (0, 0, math.radians(-ss * 35))
        bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
        s_plate.data.materials.append(mats["gold_luxury"])
        parts.append(s_plate)

    # Front Workout Deck Grip Lines
    for gy in [0.5, 1.1, 1.7]:
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, gy, 0.105))
        gline = bpy.context.active_object
        gline.scale = (3.2, 0.06, 0.01)
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        gline.data.materials.append(mats["neon_cyan"])
        parts.append(gline)

    return pad, parts

# -----------------------------------------------------------------------------
# 11. MASTER BUILDER & EXPORTER
# -----------------------------------------------------------------------------

def main():
    clear_scene()

    scene = bpy.context.scene
    scene.unit_settings.system = 'METRIC'
    scene.unit_settings.scale_length = 1.0

    mats = init_materials()

    stations_config = [
        ("Table1_DumbbellRack", build_station_1, (-7.0, -3.5, 0)),
        ("Table2_PullUpBar", build_station_2, (0.0, -3.5, 0)),
        ("Table3_BenchPress", build_station_3, (7.0, -3.5, 0)),
        ("Table4_SquatRack", build_station_4, (-4.5, 3.5, 0)),
        ("Table5_TireDeadlift", build_station_5, (4.5, 3.5, 0)),
        ("VipTable1_RoyalGold", build_station_vip_1, (-10.5, 3.5, 0)),
        ("VipTable2_CyberNeon", build_station_vip_2, (10.5, 3.5, 0)),
    ]

    all_station_roots = []

    print("[INFO] Building High-Polish Mechanical 7 AFK Gym Stations V2...")

    for name, build_fn, origin_offset in stations_config:
        pad, parts = build_fn(mats)

        # Freeze all transforms on all parts
        for p in parts:
            bpy.context.view_layer.objects.active = p
            p.select_set(True)
        bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)

        # Create Station Root Empty at (0, 0, 0)
        bpy.ops.object.empty_add(type='PLAIN_AXES', location=(0, 0, 0))
        root = bpy.context.active_object
        root.name = name

        for p in parts:
            p.parent = root

        # Export isolated FBX centered at (0, 0, 0)
        bpy.ops.object.select_all(action='DESELECT')
        root.select_set(True)
        for child in root.children:
            child.select_set(True)

        fbx_path = os.path.join(EXPORTS_DIR, f"{name}.fbx")
        bpy.ops.export_scene.fbx(
            filepath=fbx_path,
            use_selection=True,
            axis_forward='-Y',
            axis_up='Z',
            apply_unit_scale=True,
            apply_scale_options='FBX_SCALE_ALL',
            bake_anim=False
        )
        print(f"[EXPORTED] {fbx_path} ({len(parts)} parts)")

        # Move to showcase position in master scene
        root.location = origin_offset
        all_station_roots.append(root)

    # Save Master Blend Scene
    blend_path = os.path.join(PROPS_DIR, "AFK_Gym_Stations.blend")
    bpy.ops.wm.save_as_mainfile(filepath=blend_path)
    print(f"[SAVED] Master Blend file: {blend_path}")

    # Set up Camera & Lighting for Showcase Preview
    bpy.ops.object.empty_add(type='PLAIN_AXES', location=(0, 0, 1.2))
    cam_target = bpy.context.active_object
    cam_target.name = "CamTarget"

    bpy.ops.object.camera_add(location=(0, -25.0, 16.0))
    cam = bpy.context.active_object
    cam.data.lens = 45.0
    scene.camera = cam

    track = cam.constraints.new(type='TRACK_TO')
    track.target = cam_target
    track.track_axis = 'TRACK_NEGATIVE_Z'
    track.up_axis = 'UP_Y'

    # 3-Point Lighting
    bpy.ops.object.light_add(type='SUN', location=(12, -20, 22), rotation=(math.radians(50), math.radians(15), math.radians(30)))
    sun = bpy.context.active_object
    sun.data.energy = 5.0

    bpy.ops.object.light_add(type='AREA', location=(-15, -12, 10))
    fill = bpy.context.active_object
    fill.data.energy = 1600.0
    fill.data.size = 10.0

    bpy.ops.object.light_add(type='AREA', location=(0, 15, 12))
    rim = bpy.context.active_object
    rim.data.energy = 2200.0
    rim.data.size = 15.0

    # Render Preview Image
    preview_path = os.path.join(PROPS_DIR, "AFK_Gym_Stations_preview.png")
    scene.render.resolution_x = 1920
    scene.render.resolution_y = 1080
    scene.render.filepath = preview_path
    bpy.ops.render.render(write_still=True)
    print(f"[RENDERED] Preview image: {preview_path}")

    print("[SUCCESS] All 7 AFK Gym Stations V2 rebuilt and exported cleanly!")

if __name__ == "__main__":
    main()
