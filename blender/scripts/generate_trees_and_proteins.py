# blender/scripts/generate_trees_and_proteins.py
# Procedural Generator for Project BIGGER:
# 1. Low-Poly Pine Tree (PineTree)
# 2. Low-Poly Ancient Oak (AncientOak)
# 3. 5 Whey Protein Tub Upgrades (ProteinTub_Standard, ProteinTub_Silver, ProteinTub_Gold, ProteinTub_Diamond, ProteinTub_Emerald)
#
# Generates .blend files in blender/environment/ and blender/upgrades/
# Exports .fbx models to blender/exports/
# Renders high-quality viewport preview images into brain directories

import bpy
import math
import os
import shutil

# Paths
BASE_DIR = r"f:/BIGGER/blender"
EXPORT_DIR = os.path.join(BASE_DIR, "exports")
ENV_DIR = os.path.join(BASE_DIR, "environment")
UPGRADES_DIR = os.path.join(BASE_DIR, "upgrades")

BRAIN_DIRS = [
    r"C:/Users/lorem/.gemini/antigravity/brain/81568fba-bd04-4dfb-a47b-589f316e47b9",
    r"C:/Users/lorem/.gemini/antigravity/brain/fa39dd29-dff9-4e47-8c73-2ea5c34f05ed"
]

for d in [EXPORT_DIR, ENV_DIR, UPGRADES_DIR] + BRAIN_DIRS:
    os.makedirs(d, exist_ok=True)

# -----------------------------------------------------------------------------
# Color and Material Helpers
# -----------------------------------------------------------------------------
def hex_to_linear(hex_str: str) -> tuple[float, float, float, float]:
    hex_clean = hex_str.lstrip('#')
    r, g, b = [int(hex_clean[i:i+2], 16) / 255.0 for i in (0, 2, 4)]
    def srgb_to_lin(c):
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
    return (srgb_to_lin(r), srgb_to_lin(g), srgb_to_lin(b), 1.0)

def hex_to_srgb(hex_str: str) -> tuple[float, float, float, float]:
    hex_clean = hex_str.lstrip('#')
    r, g, b = [int(hex_clean[i:i+2], 16) / 255.0 for i in (0, 2, 4)]
    return (r, g, b, 1.0)

def create_material(
    name: str,
    hex_color: str,
    roughness: float = 0.5,
    metallic: float = 0.0,
    transmission: float = 0.0,
    emission_hex: str = None,
    emission_strength: float = 1.0
) -> bpy.types.Material:
    mat = bpy.data.materials.get(name)
    if mat:
        bpy.data.materials.remove(mat)

    mat = bpy.data.materials.new(name=name)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    nodes.clear()

    output_node = nodes.new(type="ShaderNodeOutputMaterial")
    bsdf_node = nodes.new(type="ShaderNodeBsdfPrincipled")

    # Set base color
    lin_color = hex_to_linear(hex_color)
    bsdf_node.inputs["Base Color"].default_value = lin_color
    bsdf_node.inputs["Roughness"].default_value = roughness

    if "Metallic" in bsdf_node.inputs:
        bsdf_node.inputs["Metallic"].default_value = metallic

    if transmission > 0:
        if "Transmission Weight" in bsdf_node.inputs:
            bsdf_node.inputs["Transmission Weight"].default_value = transmission
        elif "Transmission" in bsdf_node.inputs:
            bsdf_node.inputs["Transmission"].default_value = transmission

    if emission_hex:
        em_color = hex_to_linear(emission_hex)
        if "Emission Color" in bsdf_node.inputs:
            bsdf_node.inputs["Emission Color"].default_value = em_color
        elif "Emission" in bsdf_node.inputs:
            bsdf_node.inputs["Emission"].default_value = em_color
        if "Emission Strength" in bsdf_node.inputs:
            bsdf_node.inputs["Emission Strength"].default_value = emission_strength

    mat.node_tree.links.new(bsdf_node.outputs["BSDF"], output_node.inputs["Surface"])

    # Viewport display color
    srgb_color = hex_to_srgb(emission_hex if emission_hex else hex_color)
    mat.diffuse_color = srgb_color
    mat.roughness = roughness
    mat.metallic = metallic

    return mat

def clear_scene():
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    for block in list(bpy.data.meshes):
        bpy.data.meshes.remove(block)
    for block in list(bpy.data.materials):
        bpy.data.materials.remove(block)
    for block in list(bpy.data.lights):
        bpy.data.lights.remove(block)
    for block in list(bpy.data.cameras):
        bpy.data.cameras.remove(block)

def setup_studio_environment(cam_loc=(0, -8.0, 3.5), target_loc=(0, 0, 1.8)):
    # Camera
    cam_data = bpy.data.cameras.new(name="RenderCam")
    cam_obj = bpy.data.objects.new(name="RenderCam", object_data=cam_data)
    bpy.context.scene.collection.objects.link(cam_obj)
    bpy.context.scene.camera = cam_obj
    cam_obj.location = cam_loc

    # Look at target
    dx = target_loc[0] - cam_loc[0]
    dy = target_loc[1] - cam_loc[1]
    dz = target_loc[2] - cam_loc[2]
    dist_xy = math.sqrt(dx*dx + dy*dy)
    pitch = math.pi/2 - math.atan2(dz, dist_xy)
    yaw = math.atan2(dx, -dy)
    cam_obj.rotation_euler = (pitch, 0, yaw)

    # Key Sun Light
    sun_data = bpy.data.lights.new(name="SunKey", type='SUN')
    sun_data.energy = 4.0
    sun_obj = bpy.data.objects.new(name="SunKey", object_data=sun_data)
    bpy.context.scene.collection.objects.link(sun_obj)
    sun_obj.location = (4.0, -5.0, 8.0)
    sun_obj.rotation_euler = (0.7, 0.3, -0.6)

    # Fill Light
    fill_data = bpy.data.lights.new(name="FillLight", type='POINT')
    fill_data.energy = 250.0
    fill_obj = bpy.data.objects.new(name="FillLight", object_data=fill_data)
    bpy.context.scene.collection.objects.link(fill_obj)
    fill_obj.location = (-4.0, -4.0, 4.0)

    # Rim Light
    rim_data = bpy.data.lights.new(name="RimLight", type='POINT')
    rim_data.energy = 300.0
    rim_obj = bpy.data.objects.new(name="RimLight", object_data=rim_data)
    bpy.context.scene.collection.objects.link(rim_obj)
    rim_obj.location = (0.0, 5.0, 5.0)

def render_preview(filename: str, extra_dest_dir: str = None):
    bpy.context.scene.render.resolution_x = 768
    bpy.context.scene.render.resolution_y = 768
    bpy.context.scene.render.image_settings.file_format = 'PNG'

    temp_render = os.path.join(BRAIN_DIRS[0], filename)
    bpy.context.scene.render.filepath = temp_render
    bpy.ops.render.render(write_still=True)

    # Copy to other brain dir and extra dest dir
    for bdir in BRAIN_DIRS:
        target = os.path.join(bdir, filename)
        if target != temp_render and os.path.exists(temp_render):
            shutil.copyfile(temp_render, target)

    if extra_dest_dir and os.path.exists(temp_render):
        shutil.copyfile(temp_render, os.path.join(extra_dest_dir, filename))

    print(f"[RENDER PREVIEW] Saved {filename} to brain directories.")

def align_and_export(root_obj: bpy.types.Object, parts: list[bpy.types.Object], blend_path: str, fbx_path: str):
    # Ensure all parts have minimum Z at 0.0
    min_z = float('inf')
    bpy.context.view_layer.update()
    for p in parts:
        if p.data and hasattr(p.data, "vertices"):
            mw = p.matrix_world
            for v in p.data.vertices:
                wz = (mw @ v.co).z
                if wz < min_z:
                    min_z = wz

    if min_z != float('inf') and abs(min_z) > 0.0001:
        offset_z = -min_z
        for p in parts:
            p.location.z += offset_z

    bpy.context.view_layer.update()

    for p in parts:
        p.parent = root_obj

    # Save Blend file
    bpy.ops.wm.save_as_mainfile(filepath=blend_path)
    print(f"[SAVED BLEND] {blend_path}")

    # Export FBX
    bpy.ops.object.select_all(action='DESELECT')
    root_obj.select_set(True)
    for child in root_obj.children:
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

# =============================================================================
# 1. PINE TREE (PineTree)
# =============================================================================
def build_pine_tree():
    clear_scene()

    mat_trunk = create_material("Mat_PineTrunk", "#472914", roughness=0.85)
    mat_needle_dark = create_material("Mat_PineFoliageDark", "#14421F", roughness=0.6)
    mat_needle_light = create_material("Mat_PineFoliageLight", "#1E612E", roughness=0.55)

    parts = []

    # 8-sided tapered trunk
    # Base radius 0.45m, top radius 0.22m, height 4.5m
    bpy.ops.mesh.primitive_cone_add(vertices=8, radius1=0.45, radius2=0.22, depth=4.5, location=(0, 0, 2.25))
    trunk = bpy.context.active_object
    trunk.name = "Trunk"
    bpy.ops.object.shade_flat()
    trunk.data.materials.append(mat_trunk)
    parts.append(trunk)

    # 4 tiers of faceted cones with alternating rotations
    tiers = [
        # (tier_idx, radius, depth, z_center, rot_deg, mat)
        (1, 2.30, 2.00, 2.70, 0.0, mat_needle_dark),
        (2, 1.80, 1.80, 3.70, 22.5, mat_needle_light),
        (3, 1.30, 1.60, 4.70, 0.0, mat_needle_dark),
        (4, 0.80, 1.40, 5.60, 22.5, mat_needle_light),
    ]

    for idx, r, d, z, rot, mat in tiers:
        bpy.ops.mesh.primitive_cone_add(vertices=8, radius1=r, radius2=0.0, depth=d, location=(0, 0, z))
        tier_obj = bpy.context.active_object
        tier_obj.name = f"Foliage_Tier_{idx}"
        tier_obj.rotation_euler = (0, 0, math.radians(rot))
        bpy.ops.object.shade_flat()
        tier_obj.data.materials.append(mat)
        parts.append(tier_obj)

    # Root Empty
    bpy.ops.object.empty_add(type='PLAIN_AXES', location=(0, 0, 0))
    root = bpy.context.active_object
    root.name = "PineTree"

    blend_path = os.path.join(ENV_DIR, "PineTree.blend")
    fbx_path = os.path.join(EXPORT_DIR, "PineTree.fbx")
    align_and_export(root, parts, blend_path, fbx_path)

    # Preview render
    setup_studio_environment(cam_loc=(0, -10.0, 4.0), target_loc=(0, 0, 3.2))
    render_preview("PineTree_preview.png", ENV_DIR)

# =============================================================================
# 2. ANCIENT OAK (AncientOak)
# =============================================================================
def build_ancient_oak():
    clear_scene()

    mat_bark = create_material("Mat_OakBark", "#523824", roughness=0.85)
    mat_foliage_lush = create_material("Mat_OakFoliageLush", "#245C1A", roughness=0.6)
    mat_foliage_vibrant = create_material("Mat_OakFoliageVibrant", "#388026", roughness=0.55)

    parts = []

    # 10-sided gnarled ancient trunk
    bpy.ops.mesh.primitive_cylinder_add(vertices=10, radius=0.80, depth=3.2, location=(0, 0, 1.6))
    trunk = bpy.context.active_object
    trunk.name = "Trunk"
    bpy.ops.object.shade_flat()
    trunk.data.materials.append(mat_bark)
    parts.append(trunk)

    # 4 Surface Root Flares radiating at 0, 90, 180, 270 deg
    for i, deg in enumerate([0, 90, 180, 270]):
        rad = math.radians(deg)
        dist = 0.95
        x = dist * math.cos(rad)
        y = dist * math.sin(rad)
        # Wedge flare: tapered cone/prism along ground
        bpy.ops.mesh.primitive_cone_add(vertices=4, radius1=0.45, radius2=0.15, depth=0.8, location=(x, y, 0.4))
        flare = bpy.context.active_object
        flare.name = f"RootFlare_{i+1}"
        flare.rotation_euler = (0, 0, rad + math.radians(45))
        bpy.ops.object.shade_flat()
        flare.data.materials.append(mat_bark)
        parts.append(flare)

    # 3 Spreading Angular Branches
    branches = [
        # (name, azimuth_deg, pitch_deg, length, radius, base_z)
        ("Branch_1", 30, 45, 1.8, 0.28, 2.7),
        ("Branch_2", 150, 50, 1.9, 0.28, 2.8),
        ("Branch_3", 270, 45, 1.7, 0.28, 2.6),
    ]
    for bname, az_deg, pt_deg, length, radius, base_z in branches:
        az_rad = math.radians(az_deg)
        pt_rad = math.radians(pt_deg)
        half_len = length / 2.0
        bx = half_len * math.sin(pt_rad) * math.cos(az_rad)
        by = half_len * math.sin(pt_rad) * math.sin(az_rad)
        bz = base_z + half_len * math.cos(pt_rad)

        bpy.ops.mesh.primitive_cylinder_add(vertices=6, radius=radius, depth=length, location=(bx, by, bz))
        branch = bpy.context.active_object
        branch.name = bname
        branch.rotation_euler = (pt_rad * math.sin(az_rad), -pt_rad * math.cos(az_rad), az_rad)
        bpy.ops.object.shade_flat()
        branch.data.materials.append(mat_bark)
        parts.append(branch)

    # 5 Puffy Faceted Foliage Cloud Clusters (icospheres, flat shaded)
    clusters = [
        # (name, radius, loc, mat)
        ("CanopyCluster_Center", 1.85, (0.0, 0.0, 4.4), mat_foliage_lush),
        ("CanopyCluster_Branch1", 1.45, (1.5, 0.8, 3.9), mat_foliage_vibrant),
        ("CanopyCluster_Branch2", 1.50, (-1.4, 0.9, 4.1), mat_foliage_lush),
        ("CanopyCluster_Branch3", 1.35, (0.0, -1.5, 3.7), mat_foliage_vibrant),
        ("CanopyCluster_TopCrown", 1.25, (0.15, 0.2, 5.3), mat_foliage_vibrant),
    ]
    for cname, cradius, cloc, cmat in clusters:
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=cradius, location=cloc)
        cloud = bpy.context.active_object
        cloud.name = cname
        bpy.ops.object.shade_flat()
        cloud.data.materials.append(cmat)
        parts.append(cloud)

    # Root Empty
    bpy.ops.object.empty_add(type='PLAIN_AXES', location=(0, 0, 0))
    root = bpy.context.active_object
    root.name = "AncientOak"

    blend_path = os.path.join(ENV_DIR, "AncientOak.blend")
    fbx_path = os.path.join(EXPORT_DIR, "AncientOak.fbx")
    align_and_export(root, parts, blend_path, fbx_path)

    # Preview render
    setup_studio_environment(cam_loc=(0, -11.0, 4.5), target_loc=(0, 0, 3.0))
    render_preview("AncientOak_preview.png", ENV_DIR)

# =============================================================================
# 3-7. 5 WHEY PROTEIN TUBS
# =============================================================================
def build_protein_tub(variant_key: str):
    clear_scene()

    TUB_CONFIGS = {
        "ProteinTub_Standard": {
            "body_color": "#1F1F24",
            "body_rough": 0.4,
            "body_metal": 0.0,
            "label_color": "#D91E1E",
            "label_rough": 0.3,
            "label_metal": 0.0,
            "cap_color": "#18181C",
            "cap_rough": 0.4,
            "cap_metal": 0.0,
            "emission_color": None,
            "transmission": 0.0,
            "has_star": False,
            "has_shards": False,
            "has_runes": False,
        },
        "ProteinTub_Silver": {
            "body_color": "#C7D1DC",
            "body_rough": 0.22,
            "body_metal": 0.95,
            "label_color": "#00A3E6",
            "label_rough": 0.20,
            "label_metal": 0.75,
            "cap_color": "#DDE4EC",
            "cap_rough": 0.20,
            "cap_metal": 0.95,
            "emission_color": None,
            "transmission": 0.0,
            "has_star": False,
            "has_shards": False,
            "has_runes": False,
        },
        "ProteinTub_Gold": {
            "body_color": "#FFC81E",
            "body_rough": 0.18,
            "body_metal": 0.95,
            "label_color": "#161616",
            "label_rough": 0.25,
            "label_metal": 0.50,
            "cap_color": "#FFC81E",
            "cap_rough": 0.18,
            "cap_metal": 0.95,
            "emission_color": None,
            "transmission": 0.0,
            "has_star": True,
            "has_shards": False,
            "has_runes": False,
        },
        "ProteinTub_Diamond": {
            "body_color": "#33D9FA",
            "body_rough": 0.10,
            "body_metal": 0.10,
            "label_color": "#80EFFF",
            "label_rough": 0.15,
            "label_metal": 0.20,
            "cap_color": "#00F2FF",
            "cap_rough": 0.10,
            "cap_metal": 0.10,
            "emission_color": "#00F2FF",
            "emission_strength": 1.5,
            "transmission": 0.65,
            "has_star": False,
            "has_shards": True,
            "has_runes": False,
        },
        "ProteinTub_Emerald": {
            "body_color": "#0F9947",
            "body_rough": 0.20,
            "body_metal": 0.30,
            "label_color": "#0A6B32",
            "label_rough": 0.25,
            "label_metal": 0.20,
            "cap_color": "#0F9947",
            "cap_rough": 0.20,
            "cap_metal": 0.30,
            "emission_color": None,
            "transmission": 0.0,
            "has_star": False,
            "has_shards": False,
            "has_runes": True,
        }
    }

    cfg = TUB_CONFIGS[variant_key]

    mat_body = create_material(
        f"Mat_{variant_key}_Body",
        cfg["body_color"],
        roughness=cfg["body_rough"],
        metallic=cfg["body_metal"],
        transmission=cfg["transmission"]
    )

    mat_label = create_material(
        f"Mat_{variant_key}_Label",
        cfg["label_color"],
        roughness=cfg["label_rough"],
        metallic=cfg["label_metal"]
    )

    mat_cap = create_material(
        f"Mat_{variant_key}_Cap",
        cfg["cap_color"],
        roughness=cfg["cap_rough"],
        metallic=cfg["cap_metal"],
        emission_hex=cfg["emission_color"],
        emission_strength=cfg.get("emission_strength", 1.0)
    )

    mat_gold = create_material(f"Mat_{variant_key}_GoldAccent", "#FFD700", roughness=0.18, metallic=0.95)
    mat_crystal_shard = create_material(f"Mat_{variant_key}_Shard", "#00F2FF", roughness=0.1, metallic=0.1, emission_hex="#00F2FF", emission_strength=2.0)
    mat_emerald_jewel = create_material(f"Mat_{variant_key}_Jewel", "#1AF273", roughness=0.1, metallic=0.2, emission_hex="#1AF273", emission_strength=2.5)

    parts = []

    # 1. Main Cylinder Body (16 vertices, radius=0.42, depth=0.62)
    bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=0.42, depth=0.62, location=(0, 0, 0.31))
    body = bpy.context.active_object
    body.name = "TubBody"
    bpy.ops.object.shade_flat()
    body.data.materials.append(mat_body)
    parts.append(body)

    # 2. Tapered Shoulder / Neck (radius=0.34, depth=0.10)
    bpy.ops.mesh.primitive_cone_add(vertices=16, radius1=0.42, radius2=0.34, depth=0.10, location=(0, 0, 0.67))
    neck = bpy.context.active_object
    neck.name = "TubNeck"
    bpy.ops.object.shade_flat()
    neck.data.materials.append(mat_body)
    parts.append(neck)

    # 3. Waist Label Band (slightly embossed ring around waist, radius=0.428, depth=0.36)
    bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=0.428, depth=0.36, location=(0, 0, 0.31))
    label = bpy.context.active_object
    label.name = "WaistBand"
    bpy.ops.object.shade_flat()
    label.data.materials.append(mat_label)
    parts.append(label)

    # 4. Screw Cap (16-sided, radius=0.37, depth=0.14)
    bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=0.37, depth=0.14, location=(0, 0, 0.79))
    cap = bpy.context.active_object
    cap.name = "TubCap"
    bpy.ops.object.shade_flat()
    cap.data.materials.append(mat_cap)
    parts.append(cap)

    # 5. Cap Grip Ridges (12 vertical ribs around cap perimeter)
    for i in range(12):
        angle = math.radians(i * (360 / 12))
        rx = 0.375 * math.cos(angle)
        ry = 0.375 * math.sin(angle)
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(rx, ry, 0.79))
        ridge = bpy.context.active_object
        ridge.name = f"CapRidge_{i+1}"
        ridge.scale = (0.025, 0.04, 0.12)
        ridge.rotation_euler = (0, 0, angle)
        bpy.ops.object.shade_flat()
        ridge.data.materials.append(mat_cap)
        parts.append(ridge)

    # Variant specific decorations
    if cfg["has_star"]:
        # Gold Star Emblem on top of Cap
        bpy.ops.mesh.primitive_cylinder_add(vertices=6, radius=0.12, depth=0.035, location=(0, 0, 0.88))
        star = bpy.context.active_object
        star.name = "CapStarEmblem"
        bpy.ops.object.shade_flat()
        star.data.materials.append(mat_gold)
        parts.append(star)

    if cfg["has_shards"]:
        # 4 Protruding Diamond Shards on shoulders
        for i, deg in enumerate([45, 135, 225, 315]):
            rad = math.radians(deg)
            sx = 0.40 * math.cos(rad)
            sy = 0.40 * math.sin(rad)
            sz = 0.60
            bpy.ops.mesh.primitive_cone_add(vertices=4, radius1=0.08, radius2=0.0, depth=0.28, location=(sx, sy, sz))
            shard = bpy.context.active_object
            shard.name = f"CrystalShard_{i+1}"
            shard.rotation_euler = (math.radians(-35) * math.sin(rad), math.radians(35) * math.cos(rad), rad)
            bpy.ops.object.shade_flat()
            shard.data.materials.append(mat_crystal_shard)
            parts.append(shard)

    if cfg["has_runes"]:
        # 2 Gold Runic Accent Rings (upper and lower borders of label band)
        for r_name, r_z in [("GoldTrim_Upper", 0.48), ("GoldTrim_Lower", 0.14)]:
            bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=0.432, depth=0.035, location=(0, 0, r_z))
            trim = bpy.context.active_object
            trim.name = r_name
            bpy.ops.object.shade_flat()
            trim.data.materials.append(mat_gold)
            parts.append(trim)

        # Crown Jewel on Cap: Faceted Hexagonal Emerald Jewel
        bpy.ops.mesh.primitive_cylinder_add(vertices=6, radius=0.14, depth=0.10, location=(0, 0, 0.91))
        jewel = bpy.context.active_object
        jewel.name = "EmeraldCapJewel"
        bpy.ops.object.shade_flat()
        jewel.data.materials.append(mat_emerald_jewel)
        parts.append(jewel)

    # Root Empty
    bpy.ops.object.empty_add(type='PLAIN_AXES', location=(0, 0, 0))
    root = bpy.context.active_object
    root.name = variant_key

    blend_path = os.path.join(UPGRADES_DIR, f"{variant_key}.blend")
    fbx_path = os.path.join(EXPORT_DIR, f"{variant_key}.fbx")
    align_and_export(root, parts, blend_path, fbx_path)

    # Preview render
    setup_studio_environment(cam_loc=(0, -2.5, 1.2), target_loc=(0, 0, 0.5))
    render_preview(f"{variant_key}_preview.png", UPGRADES_DIR)

# =============================================================================
# 8. SHOWCASE LINEUP (All 7 models together)
# =============================================================================
def build_showcase():
    clear_scene()

    # Back Row: Pine Tree and Ancient Oak
    # Rebuild Pine Tree at (-3.2, 3.5, 0)
    mat_pine_trunk = create_material("Showcase_PineTrunk", "#472914", roughness=0.85)
    mat_pine_dark = create_material("Showcase_PineDark", "#14421F", roughness=0.6)
    mat_pine_light = create_material("Showcase_PineLight", "#1E612E", roughness=0.55)

    bpy.ops.mesh.primitive_cone_add(vertices=8, radius1=0.45, radius2=0.22, depth=4.5, location=(-3.2, 3.5, 2.25))
    t1 = bpy.context.active_object
    bpy.ops.object.shade_flat()
    t1.data.materials.append(mat_pine_trunk)

    tiers = [
        (2.30, 2.00, 2.70, 0.0, mat_pine_dark),
        (1.80, 1.80, 3.70, 22.5, mat_pine_light),
        (1.30, 1.60, 4.70, 0.0, mat_pine_dark),
        (0.80, 1.40, 5.60, 22.5, mat_pine_light),
    ]
    for r, d, z, rot, mat in tiers:
        bpy.ops.mesh.primitive_cone_add(vertices=8, radius1=r, radius2=0.0, depth=d, location=(-3.2, 3.5, z))
        c = bpy.context.active_object
        c.rotation_euler = (0, 0, math.radians(rot))
        bpy.ops.object.shade_flat()
        c.data.materials.append(mat)

    # Ancient Oak at (3.2, 3.5, 0)
    mat_oak_bark = create_material("Showcase_OakBark", "#523824", roughness=0.85)
    mat_oak_lush = create_material("Showcase_OakLush", "#245C1A", roughness=0.6)
    mat_oak_vibrant = create_material("Showcase_OakVibrant", "#388026", roughness=0.55)

    bpy.ops.mesh.primitive_cylinder_add(vertices=10, radius=0.80, depth=3.2, location=(3.2, 3.5, 1.6))
    t2 = bpy.context.active_object
    bpy.ops.object.shade_flat()
    t2.data.materials.append(mat_oak_bark)

    oak_clusters = [
        (1.85, (3.2, 3.5, 4.4), mat_oak_lush),
        (1.45, (4.7, 4.3, 3.9), mat_oak_vibrant),
        (1.50, (1.8, 4.4, 4.1), mat_oak_lush),
        (1.35, (3.2, 2.0, 3.7), mat_oak_vibrant),
        (1.25, (3.35, 3.7, 5.3), mat_oak_vibrant),
    ]
    for cradius, cloc, cmat in oak_clusters:
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=cradius, location=cloc)
        cl = bpy.context.active_object
        bpy.ops.object.shade_flat()
        cl.data.materials.append(cmat)

    # Front Row: 5 Protein Tubs from X = -2.8 to +2.8 at Y = 0.0
    tub_data = [
        ("Standard", -2.8, "#1F1F24", "#D91E1E", "#18181C", None, False, False, False),
        ("Silver",   -1.4, "#C7D1DC", "#00A3E6", "#DDE4EC", None, False, False, False),
        ("Gold",      0.0, "#FFC81E", "#161616", "#FFC81E", None, True,  False, False),
        ("Diamond",   1.4, "#33D9FA", "#80EFFF", "#00F2FF", "#00F2FF", False, True, False),
        ("Emerald",   2.8, "#0F9947", "#0A6B32", "#0F9947", None, False, False, True),
    ]

    for name, x, bcol, lcol, ccol, ecol, star, shard, rune in tub_data:
        m_body = create_material(f"SC_{name}_Body", bcol, roughness=0.2 if "Silver" in name or "Gold" in name else 0.4, metallic=0.9 if "Silver" in name or "Gold" in name else 0.0, transmission=0.65 if "Diamond" in name else 0.0)
        m_label = create_material(f"SC_{name}_Label", lcol, roughness=0.25)
        m_cap = create_material(f"SC_{name}_Cap", ccol, roughness=0.2, metallic=0.9 if "Silver" in name or "Gold" in name else 0.0, emission_hex=ecol, emission_strength=1.5 if ecol else 1.0)
        m_gold = create_material(f"SC_{name}_Gold", "#FFD700", roughness=0.18, metallic=0.95)

        # Body
        bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=0.42, depth=0.62, location=(x, 0, 0.31))
        b = bpy.context.active_object
        bpy.ops.object.shade_flat()
        b.data.materials.append(m_body)

        # Neck
        bpy.ops.mesh.primitive_cone_add(vertices=16, radius1=0.42, radius2=0.34, depth=0.10, location=(x, 0, 0.67))
        nk = bpy.context.active_object
        bpy.ops.object.shade_flat()
        nk.data.materials.append(m_body)

        # Label
        bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=0.428, depth=0.36, location=(x, 0, 0.31))
        lb = bpy.context.active_object
        bpy.ops.object.shade_flat()
        lb.data.materials.append(m_label)

        # Cap
        bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=0.37, depth=0.14, location=(x, 0, 0.79))
        cp = bpy.context.active_object
        bpy.ops.object.shade_flat()
        cp.data.materials.append(m_cap)

        if star:
            bpy.ops.mesh.primitive_cylinder_add(vertices=6, radius=0.12, depth=0.035, location=(x, 0, 0.88))
            st = bpy.context.active_object
            bpy.ops.object.shade_flat()
            st.data.materials.append(m_gold)

        if shard:
            m_crys = create_material(f"SC_{name}_Shard", "#00F2FF", emission_hex="#00F2FF", emission_strength=2.0)
            for deg in [45, 135, 225, 315]:
                rad = math.radians(deg)
                bpy.ops.mesh.primitive_cone_add(vertices=4, radius1=0.08, radius2=0.0, depth=0.28, location=(x + 0.40 * math.cos(rad), 0.40 * math.sin(rad), 0.60))
                sh = bpy.context.active_object
                sh.rotation_euler = (math.radians(-35) * math.sin(rad), math.radians(35) * math.cos(rad), rad)
                bpy.ops.object.shade_flat()
                sh.data.materials.append(m_crys)

        if rune:
            for r_z in [0.48, 0.14]:
                bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=0.432, depth=0.035, location=(x, 0, r_z))
                tr = bpy.context.active_object
                bpy.ops.object.shade_flat()
                tr.data.materials.append(m_gold)
            m_jewel = create_material(f"SC_{name}_Jewel", "#1AF273", emission_hex="#1AF273", emission_strength=2.5)
            bpy.ops.mesh.primitive_cylinder_add(vertices=6, radius=0.14, depth=0.10, location=(x, 0, 0.91))
            jw = bpy.context.active_object
            bpy.ops.object.shade_flat()
            jw.data.materials.append(m_jewel)

    # Wide camera for showcase
    setup_studio_environment(cam_loc=(0, -7.5, 3.2), target_loc=(0, 1.2, 1.8))
    render_preview("All_7_Assets_Showcase_preview.png", BASE_DIR)

def main():
    print("=== STARTING GENERATION: 2 TREES AND 5 PROTEIN TUBS ===")
    
    # 1. Pine Tree
    print("\n--- Generating PineTree ---")
    build_pine_tree()

    # 2. Ancient Oak
    print("\n--- Generating AncientOak ---")
    build_ancient_oak()

    # 3-7. 5 Whey Protein Tubs
    tub_variants = [
        "ProteinTub_Standard",
        "ProteinTub_Silver",
        "ProteinTub_Gold",
        "ProteinTub_Diamond",
        "ProteinTub_Emerald"
    ]
    for variant in tub_variants:
        print(f"\n--- Generating {variant} ---")
        build_protein_tub(variant)

    # 8. Showcase Lineup Render
    print("\n--- Generating Showcase Lineup ---")
    build_showcase()

    print("\n=== ALL 7 ASSETS SUCCESSFULLY GENERATED, EXPORTED AND RENDERED ===")

if __name__ == "__main__":
    main()
