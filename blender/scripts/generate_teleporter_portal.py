import bpy
import math
import os

def clear_scene():
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    for block in bpy.data.meshes:
        bpy.data.meshes.remove(block)
    for block in bpy.data.materials:
        bpy.data.materials.remove(block)

def create_material(name, base_color, roughness=0.8, specular=0.2, emission=(0, 0, 0, 1), emission_strength=0.0):
    mat = bpy.data.materials.new(name=name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = base_color
        bsdf.inputs["Roughness"].default_value = roughness
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

def create_fantasy_portal():
    clear_scene()
    
    scene = bpy.context.scene
    scene.unit_settings.system = 'METRIC'
    scene.unit_settings.scale_length = 1.0
    
    # 1. Materials
    mat_stone_dark = create_material("Mat_AncientStoneDark", (0.16, 0.17, 0.20, 1.0), roughness=0.85)
    mat_stone_light = create_material("Mat_AncientStoneLight", (0.28, 0.30, 0.34, 1.0), roughness=0.75)
    mat_cyan_rune = create_material(
        "Mat_CyanRune", 
        (0.0, 0.95, 0.85, 1.0), 
        roughness=0.1, 
        emission=(0.0, 0.95, 0.85, 1.0), 
        emission_strength=4.0
    )
    mat_vortex = create_material(
        "Mat_PortalVortex", 
        (0.05, 0.88, 0.96, 0.85), 
        roughness=0.15, 
        emission=(0.05, 0.88, 0.96, 1.0), 
        emission_strength=3.2
    )
    
    parts = []
    
    # 2. Base Platform / Stepped Dais
    # Bottom stepped slab
    bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=2.3, depth=0.25, location=(0, 0, 0.125))
    base_step1 = bpy.context.active_object
    base_step1.name = "BaseDais_Bottom"
    bpy.ops.object.shade_flat()
    base_step1.data.materials.append(mat_stone_dark)
    parts.append(base_step1)
    
    # Top stepped slab
    bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=2.0, depth=0.20, location=(0, 0, 0.35))
    base_step2 = bpy.context.active_object
    base_step2.name = "BaseDais_Top"
    bpy.ops.object.shade_flat()
    base_step2.data.materials.append(mat_stone_light)
    parts.append(base_step2)

    # 3. Two Ancient Stone Pillars (Left & Right)
    pillar_dist_x = 1.35  # Half width -> 2.7m between outer pillar centers
    
    for side, sign in [("L", -1), ("R", 1)]:
        # Plinth (Base block of pillar)
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(sign * pillar_dist_x, 0, 0.80))
        plinth = bpy.context.active_object
        plinth.name = f"PillarPlinth_{side}"
        plinth.scale = (0.75, 0.75, 0.70)
        bpy.ops.object.shade_flat()
        plinth.data.materials.append(mat_stone_dark)
        parts.append(plinth)
        
        # Column Segment 1 (Lower)
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(sign * pillar_dist_x, 0, 1.60))
        col1 = bpy.context.active_object
        col1.name = f"PillarCol1_{side}"
        col1.scale = (0.60, 0.60, 0.90)
        bpy.ops.object.shade_flat()
        col1.data.materials.append(mat_stone_light)
        parts.append(col1)
        
        # Column Segment 2 (Upper)
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(sign * (pillar_dist_x - 0.03), 0, 2.50))
        col2 = bpy.context.active_object
        col2.name = f"PillarCol2_{side}"
        col2.scale = (0.58, 0.58, 0.90)
        bpy.ops.object.shade_flat()
        col2.data.materials.append(mat_stone_dark)
        parts.append(col2)
        
        # Capital / Crown bracket of pillar
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(sign * pillar_dist_x, 0, 3.10))
        cap = bpy.context.active_object
        cap.name = f"PillarCapital_{side}"
        cap.scale = (0.78, 0.75, 0.35)
        bpy.ops.object.shade_flat()
        cap.data.materials.append(mat_stone_light)
        parts.append(cap)
        
        # Glowing Rune Glyphs along the front face (-Y)
        for r_idx, r_z in enumerate([1.35, 1.85, 2.35, 2.80]):
            bpy.ops.mesh.primitive_cylinder_add(vertices=4, radius=0.09, depth=0.06, location=(sign * pillar_dist_x, -0.31, r_z))
            rune = bpy.context.active_object
            rune.name = f"Rune_{side}_{r_idx+1}"
            rune.rotation_euler = (math.radians(90), 0, math.radians(45))
            bpy.ops.object.shade_flat()
            rune.data.materials.append(mat_cyan_rune)
            parts.append(rune)

    # 4. Arch Top (Curved low-poly segmented arch)
    arch_angles = [
        ("Arch_L1", -1.0, 3.45, 25),
        ("Arch_L2", -0.5, 3.80, 12),
        ("Arch_Keystone", 0.0, 3.95, 0),  # Central keystone
        ("Arch_R2", 0.5, 3.80, -12),
        ("Arch_R1", 1.0, 3.45, -25),
    ]
    
    for name, x, z, rot_deg in arch_angles:
        is_keystone = "Keystone" in name
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(x, 0, z))
        segment = bpy.context.active_object
        segment.name = name
        if is_keystone:
            segment.scale = (0.65, 0.78, 0.60)
            segment.data.materials.append(mat_stone_light)
        else:
            segment.scale = (0.60, 0.65, 0.45)
            segment.data.materials.append(mat_stone_dark)
        segment.rotation_euler = (0, math.radians(rot_deg), 0)
        bpy.ops.object.shade_flat()
        parts.append(segment)
    
    # Giant Rune Emblem on the Keystone (Front face)
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=0.18, location=(0, -0.40, 3.95))
    keystone_rune = bpy.context.active_object
    keystone_rune.name = "Keystone_Rune"
    keystone_rune.scale = (1.0, 0.35, 1.0)
    bpy.ops.object.shade_flat()
    keystone_rune.data.materials.append(mat_cyan_rune)
    parts.append(keystone_rune)

    # 5. Central Portal Vortex (Vertical Swirling Arcane Membrane)
    # Low-poly vertical disc facing -Y
    bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=1.0, depth=0.08, location=(0, 0, 2.15))
    vortex = bpy.context.active_object
    vortex.name = "PortalVortex"
    vortex.rotation_euler = (math.radians(90), 0, 0)
    bpy.context.view_layer.objects.active = vortex
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
    vortex.scale = (1.05, 0.1, 1.45)
    bpy.ops.object.shade_flat()
    vortex.data.materials.append(mat_vortex)
    parts.append(vortex)

    # 6. InteractionPromptPart (Ground interaction pad in front of portal)
    bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=0.70, depth=0.08, location=(0, -1.25, 0.38))
    prompt_pad = bpy.context.active_object
    prompt_pad.name = "InteractionPromptPart"
    prompt_pad.data.materials.append(mat_stone_light)
    bpy.ops.object.shade_flat()
    parts.append(prompt_pad)
    
    # Inlaid Rune Circle inside the Prompt Pad
    bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=0.48, depth=0.10, location=(0, -1.25, 0.39))
    prompt_rune = bpy.context.active_object
    prompt_rune.name = "PromptRuneCircle"
    prompt_rune.data.materials.append(mat_cyan_rune)
    bpy.ops.object.shade_flat()
    parts.append(prompt_rune)

    # 7. Apply transforms to all parts
    for obj in parts:
        bpy.context.view_layer.objects.active = obj
        obj.select_set(True)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    
    # 8. Create Root Model Parent "TeleporterPortal"
    bpy.ops.object.empty_add(type='PLAIN_AXES', location=(0, 0, 0))
    portal_root = bpy.context.active_object
    portal_root.name = "TeleporterPortal"
    
    for obj in parts:
        obj.parent = portal_root
        
    print(f"[SUCCESS] Built Fantasy Stone Arch Portal with {len(parts)} parts.")
    return portal_root

def main():
    root = create_fantasy_portal()
    
    env_dir = r"f:/BIGGER/blender/environment"
    export_dir = r"f:/BIGGER/blender/exports"
    os.makedirs(env_dir, exist_ok=True)
    os.makedirs(export_dir, exist_ok=True)
    
    blend_path = os.path.join(env_dir, "Teleporter_Portal.blend")
    fbx_path = os.path.join(export_dir, "Teleporter_Portal.fbx")
    preview_path = os.path.join(env_dir, "Teleporter_Portal_preview.png")
    
    # Save .blend file
    bpy.ops.wm.save_as_mainfile(filepath=blend_path)
    print(f"[SAVED] Blend file: {blend_path}")
    
    # Select all objects under TeleporterPortal root for export
    bpy.ops.object.select_all(action='DESELECT')
    root.select_set(True)
    for child in root.children:
        child.select_set(True)
    
    # Export FBX for Roblox Studio
    bpy.ops.export_scene.fbx(
        filepath=fbx_path,
        use_selection=True,
        axis_forward='-Y',
        axis_up='Z',
        apply_unit_scale=True,
        apply_scale_options='FBX_SCALE_ALL',
        bake_anim=False
    )
    print(f"[EXPORTED] FBX file: {fbx_path}")
    
    # Setup Camera with Track To constraint aiming at portal center (0, 0, 2.2)
    bpy.ops.object.empty_add(type='PLAIN_AXES', location=(0, 0, 2.2))
    target = bpy.context.active_object
    target.name = "CamTarget"
    
    bpy.ops.object.camera_add(location=(3.8, -5.8, 3.2))
    cam = bpy.context.active_object
    bpy.context.scene.camera = cam
    
    track = cam.constraints.new(type='TRACK_TO')
    track.target = target
    track.track_axis = 'TRACK_NEGATIVE_Z'
    track.up_axis = 'UP_Y'
    
    # Key sun light
    bpy.ops.object.light_add(type='SUN', location=(4, -5, 6), rotation=(math.radians(45), math.radians(20), math.radians(35)))
    bpy.context.active_object.data.energy = 4.5
    
    # Fill point light
    bpy.ops.object.light_add(type='POINT', location=(-3, -3, 3))
    bpy.context.active_object.data.energy = 120.0
    
    bpy.context.scene.render.resolution_x = 960
    bpy.context.scene.render.resolution_y = 640
    bpy.context.scene.render.filepath = preview_path
    bpy.ops.render.render(write_still=True)
    print(f"[RENDERED] Preview image: {preview_path}")

if __name__ == "__main__":
    main()
