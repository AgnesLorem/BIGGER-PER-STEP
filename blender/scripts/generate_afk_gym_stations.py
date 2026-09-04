# blender/scripts/generate_afk_gym_stations.py
# Procedural 3D Generator for BIGGER GYM AFK Training Stations (Tiers 1-7)
# Generates stylized low-poly gym equipment with progressive footprints,
# hybrid PBR materials, VIP championship trophy/belt props, and Roblox-compliant hitboxes.

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
# 2. MATERIAL DEFINITIONS
# -----------------------------------------------------------------------------

def init_materials():
    mats = {}
    # Rubber Floor & Accents
    mats["rubber_dark"] = create_pbr_material("Mat_GymRubber_Dark", (0.10, 0.11, 0.13, 1.0), roughness=0.85, metallic=0.0)
    mats["rubber_border_yellow"] = create_pbr_material("Mat_Rubber_BorderYellow", (0.95, 0.80, 0.10, 1.0), roughness=0.75, metallic=0.0)
    mats["rubber_border_blue"] = create_pbr_material("Mat_Rubber_BorderBlue", (0.15, 0.50, 0.95, 1.0), roughness=0.75, metallic=0.0)
    mats["rubber_border_orange"] = create_pbr_material("Mat_Rubber_BorderOrange", (0.95, 0.45, 0.05, 1.0), roughness=0.75, metallic=0.0)
    mats["hazard_stripe"] = create_pbr_material("Mat_Hazard_Stripe", (0.95, 0.75, 0.05, 1.0), roughness=0.70, metallic=0.05)
    
    # Structural Steels (Powder coated)
    mats["steel_crimson"] = create_pbr_material("Mat_Steel_Crimson", (0.85, 0.12, 0.14, 1.0), roughness=0.35, metallic=0.5)
    mats["steel_cobalt"] = create_pbr_material("Mat_Steel_Cobalt", (0.12, 0.45, 0.88, 1.0), roughness=0.35, metallic=0.5)
    mats["steel_orange"] = create_pbr_material("Mat_Steel_Orange", (0.95, 0.45, 0.05, 1.0), roughness=0.35, metallic=0.5)
    mats["steel_charcoal"] = create_pbr_material("Mat_Steel_Charcoal", (0.18, 0.20, 0.22, 1.0), roughness=0.40, metallic=0.6)
    
    # Chrome, Irons & Leathers
    mats["chrome_bar"] = create_pbr_material("Mat_Chrome_Polished", (0.88, 0.89, 0.92, 1.0), roughness=0.15, metallic=0.95)
    mats["iron_dark"] = create_pbr_material("Mat_Iron_PlateDark", (0.15, 0.16, 0.18, 1.0), roughness=0.55, metallic=0.75)
    mats["iron_rust"] = create_pbr_material("Mat_Iron_Rust", (0.45, 0.25, 0.18, 1.0), roughness=0.75, metallic=0.4)
    mats["leather_black"] = create_pbr_material("Mat_Leather_Black", (0.12, 0.12, 0.14, 1.0), roughness=0.70, metallic=0.0)
    mats["chalk_white"] = create_pbr_material("Mat_Chalk_White", (0.95, 0.95, 0.95, 1.0), roughness=0.95, metallic=0.0)
    
    # Colored Bumper Plates
    mats["plate_red"] = create_pbr_material("Mat_Plate_Red", (0.88, 0.15, 0.15, 1.0), roughness=0.5, metallic=0.1)
    mats["plate_blue"] = create_pbr_material("Mat_Plate_Blue", (0.15, 0.45, 0.90, 1.0), roughness=0.5, metallic=0.1)
    mats["plate_yellow"] = create_pbr_material("Mat_Plate_Yellow", (0.95, 0.85, 0.10, 1.0), roughness=0.5, metallic=0.1)
    mats["plate_green"] = create_pbr_material("Mat_Plate_Green", (0.15, 0.80, 0.30, 1.0), roughness=0.5, metallic=0.1)
    
    # VIP 1 Luxury Materials
    mats["gold_luxury"] = create_pbr_material(
        "Mat_Gold_Luxury", (0.95, 0.78, 0.15, 1.0), 
        roughness=0.18, metallic=0.95, 
        emission=(0.95, 0.78, 0.15, 1.0), emission_strength=0.8
    )
    mats["velvet_royal"] = create_pbr_material("Mat_Velvet_Royal", (0.35, 0.05, 0.45, 1.0), roughness=0.90, metallic=0.0)
    mats["marble_white"] = create_pbr_material("Mat_Marble_Pedestal", (0.92, 0.92, 0.94, 1.0), roughness=0.30, metallic=0.05)
    
    # VIP 2 Cyber Neon Materials
    mats["cyber_obsidian"] = create_pbr_material("Mat_Cyber_Obsidian", (0.06, 0.07, 0.09, 1.0), roughness=0.25, metallic=0.8)
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
        "Mat_Glass_Hologram", (0.2, 0.8, 1.0, 0.4), 
        roughness=0.1, metallic=0.1,
        emission=(0.1, 0.9, 1.0, 1.0), emission_strength=1.5
    )
    
    # Multiplier Sign Text / Badges
    mats["sign_white"] = create_pbr_material(
        "Mat_Sign_White", (0.98, 0.98, 0.98, 1.0), 
        roughness=0.2, metallic=0.0, 
        emission=(0.98, 0.98, 0.98, 1.0), emission_strength=2.0
    )
    mats["sign_gold"] = create_pbr_material(
        "Mat_Sign_Gold", (1.0, 0.85, 0.20, 1.0), 
        roughness=0.2, metallic=0.5, 
        emission=(1.0, 0.85, 0.20, 1.0), emission_strength=3.0
    )
    
    return mats

# -----------------------------------------------------------------------------
# 3. HELPER BUILDERS
# -----------------------------------------------------------------------------

def build_floor_pad(name, width, depth, mat_main, mat_border=None, border_width=0.15):
    """Builds the primary BasePart ground floor pad centered at Z=0 to Z=0.10."""
    thickness = 0.10
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, thickness / 2.0))
    pad = bpy.context.active_object
    pad.name = name
    pad.scale = (width, depth, thickness)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    pad.data.materials.append(mat_main)
    parts = [pad]

    if mat_border:
        # 4 border rim strips along edges
        h_thick = thickness + 0.01
        # North & South borders
        for sign in [-1, 1]:
            bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, sign * (depth / 2.0 - border_width / 2.0), h_thick / 2.0))
            rim = bpy.context.active_object
            rim.name = f"{name}_RimNS_{sign}"
            rim.scale = (width, border_width, h_thick)
            bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
            rim.data.materials.append(mat_border)
            parts.append(rim)
        # East & West borders
        for sign in [-1, 1]:
            bpy.ops.mesh.primitive_cube_add(size=1.0, location=(sign * (width / 2.0 - border_width / 2.0), 0, h_thick / 2.0))
            rim = bpy.context.active_object
            rim.name = f"{name}_RimEW_{sign}"
            rim.scale = (border_width, depth - border_width * 2, h_thick)
            bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
            rim.data.materials.append(mat_border)
            parts.append(rim)

    return pad, parts

def build_signpost(station_name, text_label, location, mats, is_vip=False):
    """Builds a vertical signboard displaying the multiplier (e.g. 50X, VIP 400X)."""
    parts = []
    x, y, z_base = location
    
    # Post pole
    bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=0.04, depth=1.6, location=(x, y, z_base + 0.8))
    pole = bpy.context.active_object
    pole.name = f"{station_name}_SignPole"
    pole.data.materials.append(mats["steel_charcoal"] if not is_vip else mats["gold_luxury"])
    parts.append(pole)
    
    # Signboard backplate
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(x, y, z_base + 1.6))
    board = bpy.context.active_object
    board.name = f"{station_name}_SignBoard"
    board.scale = (0.75, 0.06, 0.40)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    board.data.materials.append(mats["steel_charcoal"] if not is_vip else mats["velvet_royal"])
    parts.append(board)
    
    # Border / Frame on signboard
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(x, y, z_base + 1.6))
    frame = bpy.context.active_object
    frame.name = f"{station_name}_SignFrame"
    frame.scale = (0.79, 0.07, 0.44)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    frame.data.materials.append(mats["rubber_border_yellow"] if not is_vip else mats["gold_luxury"])
    parts.append(frame)

    # Emissive badge text plate
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(x, y - 0.04, z_base + 1.6))
    badge = bpy.context.active_object
    badge.name = f"{station_name}_SignBadgeText"
    badge.scale = (0.60, 0.02, 0.24)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    badge.data.materials.append(mats["sign_white"] if not is_vip else (mats["neon_cyan"] if "Cyber" in station_name else mats["sign_gold"]))
    parts.append(badge)

    return parts

# -----------------------------------------------------------------------------
# 4. STATION 1: DUMBBELL RACK (Table1 - 50x)
# -----------------------------------------------------------------------------

def build_station_1(mats):
    parts = []
    width, depth = 3.36, 3.36  # 12x12 studs
    pad, pad_parts = build_floor_pad("Table1", width, depth, mats["rubber_dark"], mats["rubber_border_yellow"])
    parts.extend(pad_parts)

    # Dual-tier Angled Dumbbell Rack Frame
    rack_y = -0.9
    rack_length = 2.4
    
    # 2 Side A-frame uprights
    for sign in [-1, 1]:
        x_pos = sign * (rack_length / 2.0)
        # Rear upright
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(x_pos, rack_y - 0.25, 0.65))
        post_r = bpy.context.active_object
        post_r.scale = (0.08, 0.08, 1.1)
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        post_r.data.materials.append(mats["steel_crimson"])
        parts.append(post_r)
        
        # Front diagonal brace
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(x_pos, rack_y + 0.1, 0.55))
        brace = bpy.context.active_object
        brace.scale = (0.08, 0.08, 1.0)
        brace.rotation_euler = (math.radians(-25), 0, 0)
        bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
        brace.data.materials.append(mats["steel_crimson"])
        parts.append(brace)
        
        # Bottom foot
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(x_pos, rack_y, 0.15))
        foot = bpy.context.active_object
        foot.scale = (0.12, 0.8, 0.08)
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        foot.data.materials.append(mats["steel_charcoal"])
        parts.append(foot)

    # 2 Horizontal Shelves / Angle-iron Rails
    for z_shelf, y_shelf, angle in [(0.55, rack_y + 0.05, -15), (0.95, rack_y - 0.12, -15)]:
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, y_shelf, z_shelf))
        shelf = bpy.context.active_object
        shelf.scale = (rack_length + 0.1, 0.35, 0.06)
        shelf.rotation_euler = (math.radians(angle), 0, 0)
        bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
        shelf.data.materials.append(mats["steel_charcoal"])
        parts.append(shelf)

    # Dumbbells on lower and upper tiers
    pairs = [
        # (x_pos, mat_plate, size)
        (-0.85, mats["plate_red"], 0.11),
        (-0.30, mats["plate_blue"], 0.13),
        (0.25, mats["plate_yellow"], 0.15),
        (0.80, mats["plate_green"], 0.17),
    ]
    for tier_z, tier_y in [(0.62, rack_y + 0.06), (1.02, rack_y - 0.10)]:
        for x_p, p_mat, r_sz in pairs:
            # Chrome handle
            bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=0.022, depth=0.26, location=(x_p, tier_y, tier_z))
            handle = bpy.context.active_object
            handle.rotation_euler = (math.radians(90), 0, 0)
            bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
            handle.data.materials.append(mats["chrome_bar"])
            parts.append(handle)
            # Hexagonal weight ends
            for s_y in [-0.11, 0.11]:
                bpy.ops.mesh.primitive_cylinder_add(vertices=6, radius=r_sz, depth=0.06, location=(x_p, tier_y + s_y, tier_z))
                weight = bpy.context.active_object
                weight.rotation_euler = (math.radians(90), 0, 0)
                bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
                weight.data.materials.append(p_mat)
                parts.append(weight)

    # Signpost
    parts.extend(build_signpost("Table1", "50X", (1.2, -1.2, 0.1), mats, is_vip=False))

    return pad, parts

# -----------------------------------------------------------------------------
# 5. STATION 2: CALISTHENICS PULL-UP & DIP RIG (Table2 - 100x)
# -----------------------------------------------------------------------------

def build_station_2(mats):
    parts = []
    width, depth = 3.36, 3.36
    pad, pad_parts = build_floor_pad("Table2", width, depth, mats["rubber_dark"], mats["rubber_border_blue"])
    parts.extend(pad_parts)

    rig_y = -0.4
    rig_w = 2.0
    rig_d = 1.4
    rig_h = 2.8

    # 4 Main Vertical Posts
    for sx in [-1, 1]:
        for sy in [-1, 1]:
            px = sx * (rig_w / 2.0)
            py = rig_y + sy * (rig_d / 2.0)
            bpy.ops.mesh.primitive_cube_add(size=1.0, location=(px, py, rig_h / 2.0))
            post = bpy.context.active_object
            post.scale = (0.12, 0.12, rig_h)
            bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
            post.data.materials.append(mats["steel_cobalt"])
            parts.append(post)
            
            # Post Base Flange
            bpy.ops.mesh.primitive_cube_add(size=1.0, location=(px, py, 0.13))
            base_f = bpy.context.active_object
            base_f.scale = (0.24, 0.24, 0.05)
            bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
            base_f.data.materials.append(mats["steel_charcoal"])
            parts.append(base_f)

    # Top Crossbeams (X axis)
    for sy in [-1, 1]:
        py = rig_y + sy * (rig_d / 2.0)
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, py, rig_h - 0.06))
        beam = bpy.context.active_object
        beam.scale = (rig_w + 0.12, 0.10, 0.12)
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        beam.data.materials.append(mats["steel_cobalt"])
        parts.append(beam)

    # Multi-Grip Pull-Up Bars (High crossbar)
    for r_y in [-0.3, 0.0, 0.3]:
        bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=0.025, depth=rig_w, location=(0, rig_y + r_y, rig_h - 0.05))
        bar = bpy.context.active_object
        bar.rotation_euler = (0, math.radians(90), 0)
        bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
        bar.data.materials.append(mats["chrome_bar"])
        parts.append(bar)

    # Forward Protruding Dip Station Bars
    dip_h = 1.25
    for sx in [-0.45, 0.45]:
        bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=0.03, depth=0.9, location=(sx, rig_y + 0.9, dip_h))
        dip = bpy.context.active_object
        dip.rotation_euler = (math.radians(90), 0, 0)
        bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
        dip.data.materials.append(mats["chrome_bar"])
        parts.append(dip)
        # Foam grip
        bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=0.04, depth=0.45, location=(sx, rig_y + 1.0, dip_h))
        grip = bpy.context.active_object
        grip.rotation_euler = (math.radians(90), 0, 0)
        bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
        grip.data.materials.append(mats["leather_black"])
        parts.append(grip)

    # Hanging Gymnastics Rings
    for sx in [-0.3, 0.3]:
        # Strap
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(sx, rig_y, rig_h - 0.5))
        strap = bpy.context.active_object
        strap.scale = (0.03, 0.02, 0.8)
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        strap.data.materials.append(mats["leather_black"])
        parts.append(strap)
        # Ring (Torus)
        bpy.ops.mesh.primitive_torus_add(major_radius=0.10, minor_radius=0.018, location=(sx, rig_y, rig_h - 0.9))
        ring = bpy.context.active_object
        ring.rotation_euler = (math.radians(90), 0, 0)
        bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
        ring.data.materials.append(mats["steel_charcoal"])
        parts.append(ring)

    # Chalk Bucket Stand on Left
    bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=0.03, depth=0.85, location=(-1.15, 0.75, 0.50))
    cb_stand = bpy.context.active_object
    cb_stand.data.materials.append(mats["steel_charcoal"])
    parts.append(cb_stand)
    
    bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=0.18, depth=0.22, location=(-1.15, 0.75, 0.95))
    cb_bowl = bpy.context.active_object
    cb_bowl.data.materials.append(mats["steel_charcoal"])
    parts.append(cb_bowl)
    
    bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=0.16, depth=0.08, location=(-1.15, 0.75, 1.02))
    chalk = bpy.context.active_object
    chalk.data.materials.append(mats["chalk_white"])
    parts.append(chalk)

    # Signpost
    parts.extend(build_signpost("Table2", "100X", (1.2, -1.2, 0.1), mats, is_vip=False))

    return pad, parts

# -----------------------------------------------------------------------------
# 6. STATION 3: OLYMPIC BENCH PRESS (Table3 - 150x)
# -----------------------------------------------------------------------------

def build_station_3(mats):
    parts = []
    width, depth = 3.36, 3.36
    pad, pad_parts = build_floor_pad("Table3", width, depth, mats["rubber_dark"], mats["rubber_border_orange"])
    parts.extend(pad_parts)

    bench_y = -0.3
    
    # Bench Press Steel Base Spine
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, bench_y, 0.20))
    spine = bpy.context.active_object
    spine.scale = (0.12, 1.4, 0.08)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    spine.data.materials.append(mats["steel_orange"])
    parts.append(spine)
    
    # 2 Upright Barbell Supports
    rack_w = 1.15
    for sx in [-1, 1]:
        px = sx * (rack_w / 2.0)
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(px, bench_y - 0.45, 0.65))
        upright = bpy.context.active_object
        upright.scale = (0.10, 0.10, 1.1)
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        upright.data.materials.append(mats["steel_orange"])
        parts.append(upright)
        
        # J-Hooks
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(px, bench_y - 0.40, 1.10))
        jhook = bpy.context.active_object
        jhook.scale = (0.12, 0.14, 0.06)
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        jhook.data.materials.append(mats["chrome_bar"])
        parts.append(jhook)

    # Leather Padded Bench
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, bench_y + 0.1, 0.48))
    cushion = bpy.context.active_object
    cushion.scale = (0.35, 1.25, 0.10)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    cushion.data.materials.append(mats["leather_black"])
    parts.append(cushion)
    
    # Bench Support Legs
    for ly in [bench_y - 0.4, bench_y + 0.6]:
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, ly, 0.25))
        leg = bpy.context.active_object
        leg.scale = (0.50, 0.08, 0.35)
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        leg.data.materials.append(mats["steel_orange"])
        parts.append(leg)

    # Loaded Olympic Barbell
    bar_y = bench_y - 0.40
    bar_z = 1.16
    bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=0.024, depth=2.2, location=(0, bar_y, bar_z))
    bar = bpy.context.active_object
    bar.rotation_euler = (0, math.radians(90), 0)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    bar.data.materials.append(mats["chrome_bar"])
    parts.append(bar)
    
    # Bumper Plates on both ends
    plates_def = [
        # (offset_x, radius, depth, mat)
        (0.68, 0.24, 0.045, mats["plate_red"]),
        (0.74, 0.24, 0.045, mats["plate_blue"]),
        (0.80, 0.22, 0.040, mats["plate_yellow"]),
        (0.85, 0.20, 0.035, mats["plate_green"]),
        (0.90, 0.04, 0.030, mats["chrome_bar"]), # collar
    ]
    for sx in [-1, 1]:
        for ox, pr, pd, pmat in plates_def:
            bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=pr, depth=pd, location=(sx * ox, bar_y, bar_z))
            plate = bpy.context.active_object
            plate.rotation_euler = (0, math.radians(90), 0)
            bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
            plate.data.materials.append(pmat)
            parts.append(plate)

    # Free-standing Weight Plate Tree on Right
    tree_x = 1.05
    tree_y = 0.5
    bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=0.04, depth=1.2, location=(tree_x, tree_y, 0.65))
    tree = bpy.context.active_object
    tree.data.materials.append(mats["steel_charcoal"])
    parts.append(tree)
    
    for tz, pr, pmat in [(0.4, 0.24, mats["plate_red"]), (0.7, 0.22, mats["plate_blue"]), (1.0, 0.18, mats["plate_yellow"])]:
        bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=pr, depth=0.08, location=(tree_x, tree_y, tz))
        w_tree = bpy.context.active_object
        w_tree.data.materials.append(pmat)
        parts.append(w_tree)

    # Signpost
    parts.extend(build_signpost("Table3", "150X", (-1.2, -1.2, 0.1), mats, is_vip=False))

    return pad, parts

# -----------------------------------------------------------------------------
# 7. STATION 4: HEAVY SQUAT POWER RACK (Table4 - 200x)
# -----------------------------------------------------------------------------

def build_station_4(mats):
    parts = []
    width, depth = 3.92, 3.92  # 14x14 studs
    pad, pad_parts = build_floor_pad("Table4", width, depth, mats["rubber_dark"], mats["steel_crimson"])
    parts.extend(pad_parts)

    cage_y = -0.3
    cage_w = 1.6
    cage_d = 1.4
    cage_h = 2.6

    # 4 Steel Cage Columns
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
            
            # Base brackets
            bpy.ops.mesh.primitive_cube_add(size=1.0, location=(cx, cy, 0.14))
            base_b = bpy.context.active_object
            base_b.scale = (0.22, 0.22, 0.06)
            bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
            base_b.data.materials.append(mats["steel_crimson"])
            parts.append(base_b)

    # Top Structural Crossbeams
    for sy in [-1, 1]:
        cy = cage_y + sy * (cage_d / 2.0)
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, cy, cage_h - 0.06))
        beam = bpy.context.active_object
        beam.scale = (cage_w + 0.12, 0.10, 0.12)
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        beam.data.materials.append(mats["steel_crimson"])
        parts.append(beam)

    # Side Safety Spotter Bars (Horizontal front to back)
    spot_z = 0.95
    for sx in [-1, 1]:
        cx = sx * (cage_w / 2.0)
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(cx, cage_y, spot_z))
        spot = bpy.context.active_object
        spot.scale = (0.08, cage_d + 0.10, 0.08)
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        spot.data.materials.append(mats["chrome_bar"])
        parts.append(spot)

    # Squat Olympic Barbell (Resting high on J-hooks at 1.55m)
    bar_z = 1.55
    bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=0.025, depth=2.4, location=(0, cage_y, bar_z))
    bar = bpy.context.active_object
    bar.rotation_euler = (0, math.radians(90), 0)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    bar.data.materials.append(mats["chrome_bar"])
    parts.append(bar)

    # Colossal Cast-Iron 45lb Plates (3 deep on each side)
    for sx in [-1, 1]:
        for p_idx, ox in enumerate([0.72, 0.79, 0.86, 0.93]):
            bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=0.25, depth=0.055, location=(sx * ox, cage_y, bar_z))
            plate = bpy.context.active_object
            plate.rotation_euler = (0, math.radians(90), 0)
            bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
            plate.data.materials.append(mats["iron_dark"])
            parts.append(plate)
        # Barbell collar
        bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=0.045, depth=0.035, location=(sx * 0.98, cage_y, bar_z))
        collar = bpy.context.active_object
        collar.rotation_euler = (0, math.radians(90), 0)
        bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
        collar.data.materials.append(mats["steel_crimson"])
        parts.append(collar)

    # Signpost
    parts.extend(build_signpost("Table4", "200X", (1.4, -1.4, 0.1), mats, is_vip=False))

    return pad, parts

# -----------------------------------------------------------------------------
# 8. STATION 5: MONSTER TIRE DEADLIFT (Table5 - 250x)
# -----------------------------------------------------------------------------

def build_station_5(mats):
    parts = []
    width, depth = 3.92, 3.92  # 14x14 studs
    pad, pad_parts = build_floor_pad("Table5", width, depth, mats["rubber_dark"], mats["hazard_stripe"], border_width=0.22)
    parts.extend(pad_parts)

    deadlift_y = 0.0
    bar_z = 0.52
    
    # Extra Thick Steel Axle Barbell
    bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=0.035, depth=2.8, location=(0, deadlift_y, bar_z))
    axle = bpy.context.active_object
    axle.rotation_euler = (0, math.radians(90), 0)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    axle.data.materials.append(mats["iron_dark"])
    parts.append(axle)

    # 4 Giant Monster Truck Tractor Tires (2 pairs on left and right)
    tire_radius = 0.50
    tire_depth = 0.22
    for sx in [-1, 1]:
        for t_idx, ox in enumerate([0.85, 1.12]):
            # Tire outer torus / cylinder
            bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=tire_radius, depth=tire_depth, location=(sx * ox, deadlift_y, bar_z))
            tire = bpy.context.active_object
            tire.rotation_euler = (0, math.radians(90), 0)
            bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
            tire.data.materials.append(mats["iron_dark"])
            parts.append(tire)
            
            # Tire Rim Hub (Steel hub in center)
            bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=0.22, depth=tire_depth + 0.02, location=(sx * ox, deadlift_y, bar_z))
            hub = bpy.context.active_object
            hub.rotation_euler = (0, math.radians(90), 0)
            bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
            hub.data.materials.append(mats["iron_rust"])
            parts.append(hub)
            
        # Heavy Steel Chains draped from bar to platform
        for chain_x in [0.55, 0.65]:
            bpy.ops.mesh.primitive_cylinder_add(vertices=6, radius=0.02, depth=0.45, location=(sx * chain_x, deadlift_y, 0.28))
            chain = bpy.context.active_object
            chain.data.materials.append(mats["iron_dark"])
            parts.append(chain)

    # Steel Diamond-Plate Deadlift Drop Blocks
    for sx in [-1, 1]:
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(sx * 0.98, deadlift_y, 0.15))
        block = bpy.context.active_object
        block.scale = (0.75, 1.2, 0.18)
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        block.data.materials.append(mats["steel_charcoal"])
        parts.append(block)

    # Signpost
    parts.extend(build_signpost("Table5", "250X", (1.4, -1.4, 0.1), mats, is_vip=False))

    return pad, parts

# -----------------------------------------------------------------------------
# 9. VIP STATION 1: ROYAL GOLD BARBELL & CHAMPIONSHIP TROPHY (VipTable1 - 300x)
# -----------------------------------------------------------------------------

def build_station_vip_1(mats):
    parts = []
    width, depth = 4.48, 4.48  # 16x16 studs
    pad, pad_parts = build_floor_pad("VipTable1", width, depth, mats["rubber_dark"], mats["gold_luxury"], border_width=0.25)
    parts.extend(pad_parts)

    bench_y = -0.2
    
    # Mirror Gold Frame Uprights
    for sx in [-1, 1]:
        px = sx * 0.65
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(px, bench_y - 0.45, 0.70))
        post = bpy.context.active_object
        post.scale = (0.12, 0.12, 1.25)
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        post.data.materials.append(mats["gold_luxury"])
        parts.append(post)
        
        # Golden Crown Finials atop posts
        bpy.ops.mesh.primitive_cone_add(vertices=6, radius1=0.10, depth=0.14, location=(px, bench_y - 0.45, 1.40))
        finial = bpy.context.active_object
        finial.data.materials.append(mats["gold_luxury"])
        parts.append(finial)

    # Royal Purple Velvet Padded Bench
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, bench_y + 0.15, 0.50))
    bench = bpy.context.active_object
    bench.scale = (0.42, 1.35, 0.14)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    bench.data.materials.append(mats["velvet_royal"])
    parts.append(bench)
    
    # Golden Bench Base
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, bench_y + 0.15, 0.24))
    b_base = bpy.context.active_object
    b_base.scale = (0.48, 1.40, 0.20)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    b_base.data.materials.append(mats["gold_luxury"])
    parts.append(b_base)

    # Mirror Gold Olympic Barbell & Plates
    bar_y = bench_y - 0.45
    bar_z = 1.18
    bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=0.025, depth=2.4, location=(0, bar_y, bar_z))
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

    # Stanchion Posts & Velvet Ropes
    for px, py in [(-1.8, -1.8), (1.8, -1.8), (-1.8, 1.8), (1.8, 1.8), (-1.8, 0.0), (1.8, 0.0)]:
        bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=0.04, depth=0.95, location=(px, py, 0.55))
        stanch = bpy.context.active_object
        stanch.data.materials.append(mats["gold_luxury"])
        parts.append(stanch)
        # Golden Ball on top
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=0.08, location=(px, py, 1.05))
        s_ball = bpy.context.active_object
        s_ball.data.materials.append(mats["gold_luxury"])
        parts.append(s_ball)

    # 🏆 GOLDEN CHAMPIONSHIP TROPHY & MARBLE PEDESTAL (Rear-Right Corner)
    trop_x, trop_y = 1.35, 1.2
    
    # Tiered Marble Pedestal
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(trop_x, trop_y, 0.40))
    ped_base = bpy.context.active_object
    ped_base.scale = (0.70, 0.70, 0.65)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    ped_base.data.materials.append(mats["marble_white"])
    parts.append(ped_base)
    
    # Velvet Top Inset on Pedestal
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(trop_x, trop_y, 0.74))
    ped_velvet = bpy.context.active_object
    ped_velvet.scale = (0.62, 0.62, 0.04)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    ped_velvet.data.materials.append(mats["velvet_royal"])
    parts.append(ped_velvet)

    # Golden Trophy: Base Plinth
    bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=0.18, depth=0.12, location=(trop_x, trop_y, 0.82))
    tr_plinth = bpy.context.active_object
    tr_plinth.data.materials.append(mats["gold_luxury"])
    parts.append(tr_plinth)
    
    # Trophy: Stem
    bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=0.06, depth=0.22, location=(trop_x, trop_y, 0.98))
    tr_stem = bpy.context.active_object
    tr_stem.data.materials.append(mats["gold_luxury"])
    parts.append(tr_stem)
    
    # Trophy: Giant Cup Body
    bpy.ops.mesh.primitive_cone_add(vertices=12, radius1=0.26, radius2=0.12, depth=0.36, location=(trop_x, trop_y, 1.24))
    tr_cup = bpy.context.active_object
    tr_cup.data.materials.append(mats["gold_luxury"])
    parts.append(tr_cup)

    # Trophy: 2 Curved Handles
    for sign in [-1, 1]:
        bpy.ops.mesh.primitive_torus_add(major_radius=0.14, minor_radius=0.024, location=(trop_x + sign * 0.28, trop_y, 1.25))
        tr_h = bpy.context.active_object
        tr_h.rotation_euler = (math.radians(90), 0, 0)
        bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
        tr_h.data.materials.append(mats["gold_luxury"])
        parts.append(tr_h)

    # Signpost
    parts.extend(build_signpost("VipTable1", "VIP 300X", (-1.5, -1.5, 0.1), mats, is_vip=True))

    return pad, parts

# -----------------------------------------------------------------------------
# 10. VIP STATION 2: CYBER NEON STATION & BELT SHOWCASE (VipTable2 - 400x)
# -----------------------------------------------------------------------------

def build_station_vip_2(mats):
    parts = []
    width, depth = 4.48, 4.48  # 16x16 studs
    pad, pad_parts = build_floor_pad("VipTable2", width, depth, mats["cyber_obsidian"], mats["neon_cyan"], border_width=0.25)
    parts.extend(pad_parts)

    # Cyber Grid Line Accents on Pad
    for g_pos in [-1.2, 0.0, 1.2]:
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, g_pos, 0.11))
        grid_l = bpy.context.active_object
        grid_l.scale = (width - 0.6, 0.04, 0.02)
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        grid_l.data.materials.append(mats["neon_magenta"])
        parts.append(grid_l)

    cage_y = -0.3
    cage_w = 1.8
    cage_d = 1.4
    cage_h = 2.7

    # 4 Angular Cyber Obsidian Columns
    for sx in [-1, 1]:
        for sy in [-1, 1]:
            cx = sx * (cage_w / 2.0)
            cy = cage_y + sy * (cage_d / 2.0)
            bpy.ops.mesh.primitive_cube_add(size=1.0, location=(cx, cy, cage_h / 2.0))
            col = bpy.context.active_object
            col.scale = (0.14, 0.14, cage_h)
            bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
            col.data.materials.append(mats["cyber_obsidian"])
            parts.append(col)
            
            # Neon Cyan Light Strips along columns
            bpy.ops.mesh.primitive_cube_add(size=1.0, location=(cx, cy + sy * 0.08, cage_h / 2.0))
            strip = bpy.context.active_object
            strip.scale = (0.04, 0.02, cage_h - 0.2)
            bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
            strip.data.materials.append(mats["neon_cyan"])
            parts.append(strip)

    # Top Crossbeams with Neon Energy Conduit
    for sy in [-1, 1]:
        cy = cage_y + sy * (cage_d / 2.0)
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, cy, cage_h - 0.06))
        beam = bpy.context.active_object
        beam.scale = (cage_w + 0.16, 0.12, 0.12)
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        beam.data.materials.append(mats["cyber_obsidian"])
        parts.append(beam)
        
        # Conduit
        bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=0.03, depth=cage_w, location=(0, cy, cage_h - 0.06))
        conduit = bpy.context.active_object
        conduit.rotation_euler = (0, math.radians(90), 0)
        bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
        conduit.data.materials.append(mats["neon_magenta"])
        parts.append(conduit)

    # Cybernetic Bench Inside
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, cage_y, 0.50))
    c_bench = bpy.context.active_object
    c_bench.scale = (0.42, 1.4, 0.12)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    c_bench.data.materials.append(mats["cyber_obsidian"])
    parts.append(c_bench)

    # Barbell with Glowing Energy Rings
    bar_z = 1.45
    bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=0.028, depth=2.4, location=(0, cage_y, bar_z))
    bar = bpy.context.active_object
    bar.rotation_euler = (0, math.radians(90), 0)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    bar.data.materials.append(mats["chrome_bar"])
    parts.append(bar)

    for sx in [-1, 1]:
        for ox, n_mat in [(0.72, mats["neon_cyan"]), (0.80, mats["neon_magenta"]), (0.88, mats["neon_cyan"])]:
            bpy.ops.mesh.primitive_torus_add(major_radius=0.26, minor_radius=0.035, location=(sx * ox, cage_y, bar_z))
            ring = bpy.context.active_object
            ring.rotation_euler = (0, math.radians(90), 0)
            bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
            ring.data.materials.append(n_mat)
            parts.append(ring)

    # 🌌 HOLOGRAPHIC CHAMPIONSHIP BELT SHOWCASE (Rear-Left Corner)
    case_x, case_y = -1.35, 1.2
    
    # Hexagonal Obsidian Pedestal Base
    bpy.ops.mesh.primitive_cylinder_add(vertices=6, radius=0.45, depth=0.60, location=(case_x, case_y, 0.40))
    ped = bpy.context.active_object
    ped.data.materials.append(mats["cyber_obsidian"])
    parts.append(ped)
    
    # Glowing Ring on Pedestal Base
    bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=0.42, depth=0.04, location=(case_x, case_y, 0.72))
    ring_base = bpy.context.active_object
    ring_base.data.materials.append(mats["neon_cyan"])
    parts.append(ring_base)

    # Transparent Containment Cylinder
    bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=0.38, depth=0.85, location=(case_x, case_y, 1.15))
    glass = bpy.context.active_object
    glass.data.materials.append(mats["glass_hologram"])
    parts.append(glass)

    # Top Cap
    bpy.ops.mesh.primitive_cylinder_add(vertices=6, radius=0.42, depth=0.10, location=(case_x, case_y, 1.62))
    top_cap = bpy.context.active_object
    top_cap.data.materials.append(mats["cyber_obsidian"])
    parts.append(top_cap)

    # Holographic Championship Belt Inside
    # Belt Strap (curved black/leather strip)
    bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=0.22, depth=0.18, location=(case_x, case_y, 1.15))
    belt_strap = bpy.context.active_object
    belt_strap.data.materials.append(mats["leather_black"])
    parts.append(belt_strap)

    # Center Emblem Plate (Gold & Neon Cyan Glow)
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(case_x, case_y - 0.23, 1.15))
    center_plate = bpy.context.active_object
    center_plate.scale = (0.16, 0.02, 0.16)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    center_plate.data.materials.append(mats["gold_luxury"])
    parts.append(center_plate)

    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=0.045, location=(case_x, case_y - 0.25, 1.15))
    gem = bpy.context.active_object
    gem.data.materials.append(mats["neon_cyan"])
    parts.append(gem)

    # Signpost
    parts.extend(build_signpost("VipTable2", "VIP 400X", (1.5, -1.5, 0.1), mats, is_vip=True))

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

    print("[INFO] Building 7 AFK Gym Training Stations...")

    for name, build_fn, origin_offset in stations_config:
        pad, parts = build_fn(mats)
        
        # Apply transforms to all parts
        for p in parts:
            bpy.context.view_layer.objects.active = p
            p.select_set(True)
        bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)

        # Create Station Empty Root
        bpy.ops.object.empty_add(type='PLAIN_AXES', location=(0, 0, 0))
        root = bpy.context.active_object
        root.name = name

        for p in parts:
            p.parent = root

        # Export isolated FBX at local origin (0, 0, 0)
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

        # In master scene, move root to its showcase showcase position
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

    bpy.ops.object.camera_add(location=(0, -26.0, 15.0))
    cam = bpy.context.active_object
    cam.data.lens = 45.0
    scene.camera = cam

    track = cam.constraints.new(type='TRACK_TO')
    track.target = cam_target
    track.track_axis = 'TRACK_NEGATIVE_Z'
    track.up_axis = 'UP_Y'

    # 3-Point Lighting
    # Key Sun Light
    bpy.ops.object.light_add(type='SUN', location=(12, -20, 22), rotation=(math.radians(50), math.radians(15), math.radians(30)))
    sun = bpy.context.active_object
    sun.data.energy = 4.5

    # Fill Area Light
    bpy.ops.object.light_add(type='AREA', location=(-15, -12, 10))
    fill = bpy.context.active_object
    fill.data.energy = 1500.0
    fill.data.size = 10.0

    # Rim Back Light
    bpy.ops.object.light_add(type='AREA', location=(0, 15, 12))
    rim = bpy.context.active_object
    rim.data.energy = 2000.0
    rim.data.size = 15.0

    # Render Preview Image
    preview_path = os.path.join(PROPS_DIR, "AFK_Gym_Stations_preview.png")
    scene.render.resolution_x = 1920
    scene.render.resolution_y = 1080
    scene.render.filepath = preview_path
    bpy.ops.render.render(write_still=True)
    print(f"[RENDERED] Preview image: {preview_path}")

    print("[SUCCESS] All 7 AFK Gym Stations built and exported successfully!")

if __name__ == "__main__":
    main()
