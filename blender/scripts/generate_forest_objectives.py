# blender/scripts/generate_forest_objectives.py
# Procedural Generator for MVP-007 Forest Objectives & Teleporter Arch
# Targets: Spider, WildBoar, AncientBear, TeleporterArch, and pre-fractured debris pieces
# Maps all models to 256x256 Color Palette Texture Atlas (blender/textures/TextureAtlas.png)
# Guarantees ground-level pivot at Z = 0

import bpy
import math
import os

EXPORT_DIR = r"f:/BIGGER/blender/exports"
OBJECTIVES_DIR = r"f:/BIGGER/blender/objectives"
PROPS_DIR = r"f:/BIGGER/blender/props"
TEXTURE_ATLAS_PATH = r"f:/BIGGER/blender/textures/TextureAtlas.png"

os.makedirs(EXPORT_DIR, exist_ok=True)
os.makedirs(OBJECTIVES_DIR, exist_ok=True)
os.makedirs(PROPS_DIR, exist_ok=True)

# 8x8 Grid Swatch coordinates (col, row) where col in [0..7], row in [0..7]
# Row 0 top (Forest Greens), Row 7 bottom (Atmosphere)
SWATCH_COORDS = {
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

    # Common
    "rock_grey": (2, 2),
    "dirt_brown": (2, 1),
    "moss_green": (2, 0),
    "pure_black": (7, 7),
    "pure_white": (7, 2),
}

def clear_scene():
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    for block in bpy.data.meshes:
        bpy.data.meshes.remove(block)
    for block in bpy.data.materials:
        bpy.data.materials.remove(block)

def get_or_create_atlas_material():
    mat_name = "Mat_TextureAtlas"
    mat = bpy.data.materials.get(mat_name)
    if mat:
        return mat

    mat = bpy.data.materials.new(name=mat_name)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    nodes.clear()

    output_node = nodes.new(type="ShaderNodeOutputMaterial")
    bsdf_node = nodes.new(type="ShaderNodeBsdfPrincipled")
    bsdf_node.inputs["Roughness"].default_value = 0.5

    tex_node = nodes.new(type="ShaderNodeTexImage")
    if os.path.exists(TEXTURE_ATLAS_PATH):
        image = bpy.data.images.load(TEXTURE_ATLAS_PATH)
        tex_node.image = image
        tex_node.interpolation = 'Closest'

    links.new(tex_node.outputs["Color"], bsdf_node.inputs["Base Color"])
    links.new(bsdf_node.outputs["BSDF"], output_node.inputs["Surface"])
    return mat

def create_hitbox_material():
    mat = bpy.data.materials.new(name="Mat_Hitbox")
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = (1.0, 0.2, 0.2, 0.2)
        bsdf.inputs["Roughness"].default_value = 1.0
    return mat

def apply_palette_swatch(obj, swatch_name: str, atlas_mat):
    col, row = SWATCH_COORDS.get(swatch_name, (0, 0))
    # U in [0..1], V in [0..1]
    # Row 0 is at top of texture: V = 1.0 - (row + 0.5) / 8.0
    u = (col + 0.5) / 8.0
    v = 1.0 - (row + 0.5) / 8.0

    if not obj.data.materials:
        obj.data.materials.append(atlas_mat)
    else:
        obj.data.materials[0] = atlas_mat

    mesh = obj.data
    if not mesh.uv_layers:
        mesh.uv_layers.new(name="UVMap")
    uv_layer = mesh.uv_layers.active.data
    for poly in mesh.polygons:
        for loop_index in poly.loop_indices:
            uv_layer[loop_index].uv = (u, v)

def align_ground_pivot(parts, root_empty):
    # Find minimum Z among all mesh parts excluding Hitbox
    min_z = float('inf')
    for p in parts:
        if p.name != "ObjectiveHitbox" and p.name != "TeleporterTouchZone" and p.data and hasattr(p.data, "vertices"):
            bpy.context.view_layer.update()
            mw = p.matrix_world
            for v in p.data.vertices:
                world_z = (mw @ v.co).z
                if world_z < min_z:
                    min_z = world_z

    if min_z != float('inf') and abs(min_z) > 0.001:
        # Offset all parts so min_z becomes 0.0
        offset_z = -min_z
        for p in parts:
            p.location.z += offset_z

def export_model(root, fbx_path, blend_path):
    bpy.ops.wm.save_as_mainfile(filepath=blend_path)
    bpy.ops.object.select_all(action='DESELECT')
    root.select_set(True)
    for child in root.children:
        child.select_set(True)
        for subchild in child.children:
            subchild.select_set(True)

    bpy.ops.export_scene.fbx(
        filepath=fbx_path,
        use_selection=True,
        axis_forward='-Y',
        axis_up='Z',
        apply_unit_scale=True,
        apply_scale_options='FBX_SCALE_ALL',
        bake_anim=False
    )
    print(f"[EXPORTED FBX] {fbx_path}")

# ==============================================================================
# 1. SPIDER (MAP1)
# ==============================================================================
def build_spider():
    clear_scene()
    atlas_mat = get_or_create_atlas_material()
    mat_hitbox = create_hitbox_material()

    parts = []

    # Head / Cephalothorax
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=0.42, location=(0, 0.25, 0.45))
    head = bpy.context.active_object
    head.name = "Head"
    head.scale = (1.1, 1.0, 0.7)
    bpy.ops.object.shade_flat()
    apply_palette_swatch(head, "spider_chitin_black", atlas_mat)
    parts.append(head)

    # Abdomen
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=0.62, location=(0, -0.60, 0.60))
    abdomen = bpy.context.active_object
    abdomen.name = "Abdomen"
    abdomen.scale = (1.2, 1.45, 0.95)
    bpy.ops.object.shade_flat()
    apply_palette_swatch(abdomen, "spider_abdomen", atlas_mat)
    parts.append(abdomen)

    # Fangs & Eyes
    for side, sign in [("L", -1), ("R", 1)]:
        bpy.ops.mesh.primitive_cone_add(vertices=5, radius1=0.07, radius2=0.01, depth=0.22, location=(sign * 0.14, 0.65, 0.32))
        fang = bpy.context.active_object
        fang.name = f"Fang_{side}"
        fang.rotation_euler = (math.radians(25), sign * math.radians(-15), 0)
        bpy.ops.object.shade_flat()
        apply_palette_swatch(fang, "spider_fangs_crimson", atlas_mat)
        parts.append(fang)

        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=0.07, location=(sign * 0.16, 0.62, 0.54))
        eye = bpy.context.active_object
        eye.name = f"Eye_{side}"
        bpy.ops.object.shade_flat()
        apply_palette_swatch(eye, "spider_eyes_glow", atlas_mat)
        parts.append(eye)

    # 8 Legs (Pre-fractured debris pieces)
    leg_coords = [
        ("FL", 0.35, 0.85, 0.75, 0.72, 1.20, 1.10),
        ("ML1", 0.18, 1.05, 0.30, 0.78, 1.45, 0.40),
        ("ML2", -0.05, 1.05, -0.15, 0.76, 1.45, -0.25),
        ("BL", -0.30, 0.95, -0.65, 0.70, 1.30, -1.00),
    ]
    for suffix, base_y, reach_x, reach_y, knee_z, foot_x, foot_y in leg_coords:
        for side, sign in [("L", -1), ("R", 1)]:
            leg_name = f"Leg_{suffix[0]}{side}" if len(suffix) == 2 else f"Leg_{suffix[:2]}{side}"
            bpy.ops.mesh.primitive_cylinder_add(vertices=6, radius=0.06, depth=0.9, location=(sign * reach_x * 0.5, (base_y + reach_y) * 0.5, (0.42 + knee_z) * 0.5))
            leg_up = bpy.context.active_object
            leg_up.name = f"{leg_name}_Upper"
            bpy.ops.object.shade_flat()
            apply_palette_swatch(leg_up, "spider_chitin_black", atlas_mat)
            parts.append(leg_up)

            bpy.ops.mesh.primitive_cylinder_add(vertices=5, radius=0.04, depth=0.9, location=(sign * (reach_x + foot_x) * 0.5, (reach_y + foot_y) * 0.5, knee_z * 0.5))
            leg_low = bpy.context.active_object
            leg_low.name = f"{leg_name}_Lower"
            bpy.ops.object.shade_flat()
            apply_palette_swatch(leg_low, "spider_joints", atlas_mat)
            parts.append(leg_low)

    # ObjectiveHitbox
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, -0.05, 0.45))
    hitbox = bpy.context.active_object
    hitbox.name = "ObjectiveHitbox"
    hitbox.scale = (2.6, 2.4, 0.9)
    hitbox.display_type = 'WIRE'
    hitbox.data.materials.append(mat_hitbox)
    parts.append(hitbox)

    # Align Ground Pivot Z = 0
    bpy.ops.object.empty_add(type='PLAIN_AXES', location=(0, 0, 0))
    spider_root = bpy.context.active_object
    spider_root.name = "Spider"
    align_ground_pivot(parts, spider_root)

    for p in parts:
        p.parent = spider_root

    export_model(spider_root, os.path.join(EXPORT_DIR, "Spider.fbx"), os.path.join(OBJECTIVES_DIR, "Spider.blend"))

# ==============================================================================
# 2. WILD BOAR (MAP2)
# ==============================================================================
def build_wild_boar():
    clear_scene()
    atlas_mat = get_or_create_atlas_material()
    mat_hitbox = create_hitbox_material()

    parts = []

    # 1. Main Torso
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 1.25))
    torso = bpy.context.active_object
    torso.name = "Torso"
    torso.scale = (1.2, 2.0, 1.2)
    bpy.ops.object.shade_flat()
    apply_palette_swatch(torso, "boar_fur_brown", atlas_mat)
    parts.append(torso)

    # 2. Spiky Mane Chunks (Pre-fractured debris pieces)
    for i in range(4):
        bpy.ops.mesh.primitive_cone_add(vertices=5, radius1=0.25, depth=0.6, location=(0, -0.6 + i * 0.45, 1.95))
        mane = bpy.context.active_object
        mane.name = f"Mane_Chunk_{i+1}"
        mane.rotation_euler = (math.radians(-15 + i * 5), 0, 0)
        bpy.ops.object.shade_flat()
        apply_palette_swatch(mane, "boar_spikes_grey", atlas_mat)
        parts.append(mane)

    # 3. Head
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 1.45, 1.35))
    head = bpy.context.active_object
    head.name = "Head"
    head.scale = (0.9, 1.1, 0.9)
    head.rotation_euler = (math.radians(-20), 0, 0)
    bpy.ops.object.shade_flat()
    apply_palette_swatch(head, "boar_fur_brown", atlas_mat)
    parts.append(head)

    # 4. Snout
    bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=0.3, depth=0.35, location=(0, 2.1, 1.15))
    snout = bpy.context.active_object
    snout.name = "Snout"
    snout.rotation_euler = (math.radians(70), 0, 0)
    bpy.ops.object.shade_flat()
    apply_palette_swatch(snout, "boar_snout", atlas_mat)
    parts.append(snout)

    # 5. Tusks (L & R lower tusks)
    for side, sign in [("L", -1), ("R", 1)]:
        bpy.ops.mesh.primitive_cone_add(vertices=6, radius1=0.1, radius2=0.01, depth=0.65, location=(sign * 0.42, 1.95, 1.2))
        tusk = bpy.context.active_object
        tusk.name = f"Tusk_{side}"
        tusk.rotation_euler = (math.radians(-35), sign * math.radians(45), sign * math.radians(25))
        bpy.ops.object.shade_flat()
        apply_palette_swatch(tusk, "boar_tusks_ivory", atlas_mat)
        parts.append(tusk)

        # Upper smaller tusks
        bpy.ops.mesh.primitive_cone_add(vertices=5, radius1=0.06, depth=0.35, location=(sign * 0.38, 1.85, 1.45))
        tusk_up = bpy.context.active_object
        tusk_up.name = f"Tusk_Up_{side}"
        tusk_up.rotation_euler = (math.radians(35), sign * math.radians(20), 0)
        bpy.ops.object.shade_flat()
        apply_palette_swatch(tusk_up, "boar_tusks_ivory", atlas_mat)
        parts.append(tusk_up)

        # Eyes
        bpy.ops.mesh.primitive_cube_add(size=0.12, location=(sign * 0.42, 1.55, 1.62))
        eye = bpy.context.active_object
        eye.name = f"Eye_{side}"
        bpy.ops.object.shade_flat()
        apply_palette_swatch(eye, "boar_eyes_red", atlas_mat)
        parts.append(eye)

    # 6. Legs (4 Sturdy Legs)
    leg_pos = [
        ("FL", -0.45, 0.75, 0.6),
        ("FR", 0.45, 0.75, 0.6),
        ("BL", -0.45, -0.75, 0.6),
        ("BR", 0.45, -0.75, 0.6),
    ]
    for name, lx, ly, lz in leg_pos:
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(lx, ly, lz))
        leg = bpy.context.active_object
        leg.name = f"Leg_{name}"
        leg.scale = (0.45, 0.55, 1.2)
        bpy.ops.object.shade_flat()
        apply_palette_swatch(leg, "boar_fur_brown", atlas_mat)
        parts.append(leg)

        # Hooves
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(lx, ly + 0.05, lz - 0.55))
        hoof = bpy.context.active_object
        hoof.name = f"Hoof_{name}"
        hoof.scale = (0.48, 0.58, 0.25)
        bpy.ops.object.shade_flat()
        apply_palette_swatch(hoof, "boar_hooves", atlas_mat)
        parts.append(hoof)

    # ObjectiveHitbox
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0.2, 1.25))
    hitbox = bpy.context.active_object
    hitbox.name = "ObjectiveHitbox"
    hitbox.scale = (2.2, 3.2, 2.0)
    hitbox.display_type = 'WIRE'
    hitbox.data.materials.append(mat_hitbox)
    parts.append(hitbox)

    # Align Ground Pivot Z = 0
    bpy.ops.object.empty_add(type='PLAIN_AXES', location=(0, 0, 0))
    boar_root = bpy.context.active_object
    boar_root.name = "WildBoar"
    align_ground_pivot(parts, boar_root)

    for p in parts:
        p.parent = boar_root

    export_model(boar_root, os.path.join(EXPORT_DIR, "WildBoar.fbx"), os.path.join(OBJECTIVES_DIR, "WildBoar.blend"))

# ==============================================================================
# 3. ANCIENT BEAR (MAP3)
# ==============================================================================
def build_ancient_bear():
    clear_scene()
    atlas_mat = get_or_create_atlas_material()
    mat_hitbox = create_hitbox_material()

    parts = []

    # 1. Colossal Bear Torso
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 2.2))
    torso = bpy.context.active_object
    torso.name = "Torso"
    torso.scale = (2.0, 2.8, 2.2)
    bpy.ops.object.shade_flat()
    apply_palette_swatch(torso, "bear_fur_grizzly", atlas_mat)
    parts.append(torso)

    # 2. Stone Armor Shoulder Plates (Pre-fractured debris pieces)
    for side, sign in [("L", -1), ("R", 1)]:
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=0.9, location=(sign * 1.3, 0.4, 2.6))
        plate = bpy.context.active_object
        plate.name = f"StonePlate_Shoulder_{side}"
        plate.scale = (0.7, 1.2, 0.8)
        bpy.ops.object.shade_flat()
        apply_palette_swatch(plate, "bear_stone_armor", atlas_mat)
        parts.append(plate)

        # Golden Runes on Stone
        bpy.ops.mesh.primitive_cone_add(vertices=4, radius1=0.2, depth=0.1, location=(sign * 1.6, 0.4, 2.7))
        rune = bpy.context.active_object
        rune.name = f"Rune_Shoulder_{side}"
        rune.rotation_euler = (0, sign * math.radians(90), 0)
        bpy.ops.object.shade_flat()
        apply_palette_swatch(rune, "bear_rune_gold", atlas_mat)
        parts.append(rune)

    # 3. Head & Snout
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 1.9, 2.4))
    head = bpy.context.active_object
    head.name = "Head"
    head.scale = (1.4, 1.5, 1.4)
    bpy.ops.object.shade_flat()
    apply_palette_swatch(head, "bear_fur_grizzly", atlas_mat)
    parts.append(head)

    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 2.7, 2.05))
    snout = bpy.context.active_object
    snout.name = "Snout"
    snout.scale = (0.8, 1.0, 0.7)
    bpy.ops.object.shade_flat()
    apply_palette_swatch(snout, "bear_fur_chest", atlas_mat)
    parts.append(snout)

    # 4. Bear Ears & Eyes
    for side, sign in [("L", -1), ("R", 1)]:
        bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=0.28, depth=0.15, location=(sign * 0.7, 1.6, 3.2))
        ear = bpy.context.active_object
        ear.name = f"Ear_{side}"
        ear.rotation_euler = (math.radians(30), sign * math.radians(35), 0)
        bpy.ops.object.shade_flat()
        apply_palette_swatch(ear, "bear_fur_grizzly", atlas_mat)
        parts.append(ear)

        bpy.ops.mesh.primitive_cube_add(size=0.15, location=(sign * 0.55, 2.3, 2.55))
        eye = bpy.context.active_object
        eye.name = f"Eye_{side}"
        bpy.ops.object.shade_flat()
        apply_palette_swatch(eye, "bear_eyes_amber", atlas_mat)
        parts.append(eye)

    # 5. 4 Thick Bear Paws
    paw_coords = [
        ("FL", -0.85, 0.9, 0.8),
        ("FR", 0.85, 0.9, 0.8),
        ("BL", -0.85, -0.9, 0.8),
        ("BR", 0.85, -0.9, 0.8),
    ]
    for name, px, py, pz in paw_coords:
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(px, py, pz))
        paw = bpy.context.active_object
        paw.name = f"Paw_{name}"
        paw.scale = (0.6, 0.7, 1.6)
        bpy.ops.object.shade_flat()
        apply_palette_swatch(paw, "bear_fur_grizzly", atlas_mat)
        parts.append(paw)

        # Claws
        for c_idx in range(3):
            bpy.ops.mesh.primitive_cone_add(vertices=4, radius1=0.06, depth=0.3, location=(px + (c_idx - 1) * 0.15, py + 0.4, 0.15))
            claw = bpy.context.active_object
            claw.name = f"Claw_{name}_{c_idx+1}"
            claw.rotation_euler = (math.radians(45), 0, 0)
            bpy.ops.object.shade_flat()
            apply_palette_swatch(claw, "bear_claws", atlas_mat)
            parts.append(claw)

    # ObjectiveHitbox
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0.3, 1.8))
    hitbox = bpy.context.active_object
    hitbox.name = "ObjectiveHitbox"
    hitbox.scale = (3.2, 4.2, 3.6)
    hitbox.display_type = 'WIRE'
    hitbox.data.materials.append(mat_hitbox)
    parts.append(hitbox)

    # Align Ground Pivot Z = 0
    bpy.ops.object.empty_add(type='PLAIN_AXES', location=(0, 0, 0))
    bear_root = bpy.context.active_object
    bear_root.name = "AncientBear"
    align_ground_pivot(parts, bear_root)

    for p in parts:
        p.parent = bear_root

    export_model(bear_root, os.path.join(EXPORT_DIR, "AncientBear.fbx"), os.path.join(OBJECTIVES_DIR, "AncientBear.blend"))

# ==============================================================================
# 4. TELEPORTER ARCH (LOBBY MASTER PORTAL)
# ==============================================================================
def build_teleporter_arch():
    clear_scene()
    atlas_mat = get_or_create_atlas_material()
    mat_trigger = create_hitbox_material()

    parts = []

    # 1. Pedestal Base
    bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=3.2, depth=0.4, location=(0, 0, 0.2))
    base = bpy.context.active_object
    base.name = "Pedestal_Base"
    bpy.ops.object.shade_flat()
    apply_palette_swatch(base, "teleporter_stone_dark", atlas_mat)
    parts.append(base)

    # 2. Pillars (Left & Right)
    for side, sign in [("L", -1), ("R", 1)]:
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(sign * 2.2, 0, 2.6))
        pillar = bpy.context.active_object
        pillar.name = f"Pillar_{side}"
        pillar.scale = (0.9, 0.9, 4.4)
        bpy.ops.object.shade_flat()
        apply_palette_swatch(pillar, "teleporter_stone_mid", atlas_mat)
        parts.append(pillar)

        # Gold Trim
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(sign * 2.2, 0, 4.85))
        trim = bpy.context.active_object
        trim.name = f"Trim_{side}"
        trim.scale = (1.05, 1.05, 0.3)
        bpy.ops.object.shade_flat()
        apply_palette_swatch(trim, "teleporter_gold_trim", atlas_mat)
        parts.append(trim)

    # 3. Lintel Arch Top
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 5.2))
    lintel = bpy.context.active_object
    lintel.name = "Arch_Top"
    lintel.scale = (5.3, 1.1, 0.8)
    bpy.ops.object.shade_flat()
    apply_palette_swatch(lintel, "teleporter_stone_dark", atlas_mat)
    parts.append(lintel)

    # Capstone Rune
    bpy.ops.mesh.primitive_cone_add(vertices=6, radius1=0.6, depth=0.7, location=(0, 0, 5.9))
    capstone = bpy.context.active_object
    capstone.name = "Rune_Capstone"
    capstone.rotation_euler = (math.radians(180), 0, 0)
    bpy.ops.object.shade_flat()
    apply_palette_swatch(capstone, "teleporter_cyan_rune", atlas_mat)
    parts.append(capstone)

    # 4. Swirling Portal Vortex Disk
    bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=1.6, depth=0.15, location=(0, 0, 2.7))
    vortex = bpy.context.active_object
    vortex.name = "PortalVisual"
    vortex.rotation_euler = (math.radians(90), 0, 0)
    bpy.ops.object.shade_flat()
    apply_palette_swatch(vortex, "teleporter_portal_glow", atlas_mat)
    parts.append(vortex)

    # 5. Floor Touch Trigger
    bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=2.2, depth=0.8, location=(0, 0, 0.6))
    trigger = bpy.context.active_object
    trigger.name = "TeleporterTouchZone"
    trigger.display_type = 'WIRE'
    trigger.data.materials.append(mat_trigger)
    parts.append(trigger)

    # Align Ground Pivot Z = 0
    bpy.ops.object.empty_add(type='PLAIN_AXES', location=(0, 0, 0))
    arch_root = bpy.context.active_object
    arch_root.name = "TeleporterArch"
    align_ground_pivot(parts, arch_root)

    for p in parts:
        p.parent = arch_root

    export_model(arch_root, os.path.join(EXPORT_DIR, "TeleporterArch.fbx"), os.path.join(PROPS_DIR, "TeleporterArch.blend"))

def main():
    print("=== STARTING FOREST OBJECTIVES GENERATION ===")
    build_spider()
    build_wild_boar()
    build_ancient_bear()
    build_teleporter_arch()
    print("=== ALL 4 ASSETS SUCCESSFULLY GENERATED AND EXPORTED WITH TEXTURE ATLAS ===")

if __name__ == "__main__":
    main()
