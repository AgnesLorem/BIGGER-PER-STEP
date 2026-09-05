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

def create_material(name, base_color, roughness=0.4, specular=0.5, emission=(0, 0, 0, 1), emission_strength=0.0):
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

def create_lowpoly_spider():
    clear_scene()
    
    scene = bpy.context.scene
    scene.unit_settings.system = 'METRIC'
    scene.unit_settings.scale_length = 1.0
    
    # 1. Materials
    mat_black = create_material("Mat_SpiderBody", (0.12, 0.12, 0.14, 1.0), roughness=0.35)
    mat_abdomen = create_material("Mat_SpiderAbdomen", (0.08, 0.08, 0.10, 1.0), roughness=0.45)
    mat_fangs = create_material("Mat_SpiderFangs", (0.85, 0.15, 0.15, 1.0), roughness=0.2)
    mat_eye_white = create_material("Mat_EyeWhite", (0.96, 0.96, 0.96, 1.0), roughness=0.2)
    mat_eye_red = create_material("Mat_EyeRed", (0.95, 0.05, 0.05, 1.0), roughness=0.1, emission=(0.95, 0.05, 0.05, 1.0), emission_strength=2.5)
    mat_hitbox = create_material("Mat_Hitbox", (1.0, 0.2, 0.2, 0.1), roughness=1.0)
    
    parts = []
    
    # 2. Cephalothorax / Head
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=0.42, location=(0, 0.25, 0.45))
    head = bpy.context.active_object
    head.name = "Head"
    head.scale = (1.1, 1.0, 0.7)
    bpy.ops.object.shade_flat()
    head.data.materials.append(mat_black)
    parts.append(head)
    
    # 3. Abdomen
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=0.62, location=(0, -0.60, 0.60))
    abdomen = bpy.context.active_object
    abdomen.name = "Abdomen"
    abdomen.scale = (1.2, 1.45, 0.95)
    bpy.ops.object.shade_flat()
    abdomen.data.materials.append(mat_abdomen)
    parts.append(abdomen)
    
    # 4. Fangs / Chelicerae
    for side, sign in [("L", -1), ("R", 1)]:
        bpy.ops.mesh.primitive_cone_add(vertices=5, radius1=0.07, radius2=0.01, depth=0.22, location=(sign * 0.14, 0.65, 0.32))
        fang = bpy.context.active_object
        fang.name = f"Fang_{side}"
        fang.rotation_euler = (math.radians(25), sign * math.radians(-15), 0)
        bpy.ops.object.shade_flat()
        fang.data.materials.append(mat_fangs)
        parts.append(fang)

    # 5. Eyes (Cartoon big eyes + pupils)
    for side, sign in [("L", -1), ("R", 1)]:
        # Sclera (White)
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=0.11, location=(sign * 0.16, 0.60, 0.54))
        eye_w = bpy.context.active_object
        eye_w.name = f"EyeWhite_{side}"
        eye_w.scale = (1.0, 0.7, 1.0)
        bpy.ops.object.shade_flat()
        eye_w.data.materials.append(mat_eye_white)
        parts.append(eye_w)
        
        # Pupil (Glowing Red)
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=0.06, location=(sign * 0.16, 0.67, 0.54))
        pupil = bpy.context.active_object
        pupil.name = f"Pupil_{side}"
        pupil.scale = (1.0, 0.4, 1.0)
        bpy.ops.object.shade_flat()
        pupil.data.materials.append(mat_eye_red)
        parts.append(pupil)
        
        # Secondary small lateral eyes
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=0.045, location=(sign * 0.28, 0.54, 0.50))
        small_eye = bpy.context.active_object
        small_eye.name = f"EyeSmall_{side}"
        bpy.ops.object.shade_flat()
        small_eye.data.materials.append(mat_eye_red)
        parts.append(small_eye)

    # 6. 8 Legs (4 Left, 4 Right)
    leg_configs = [
        # name_suffix, base_y, reach_x, reach_y, knee_z, foot_x, foot_y
        ("FL",  0.35,  0.85,  0.75, 0.72,  1.20,  1.10),
        ("ML1", 0.18,  1.05,  0.30, 0.78,  1.45,  0.40),
        ("ML2", -0.05, 1.05, -0.15, 0.76,  1.45, -0.25),
        ("BL",  -0.30, 0.95, -0.65, 0.70,  1.30, -1.00),
    ]
    
    for suffix, base_y, reach_x, reach_y, knee_z, foot_x, foot_y in leg_configs:
        for side, sign in [("L", -1), ("R", 1)]:
            leg_name = f"Leg_{suffix[0]}{side}" if len(suffix) == 2 else f"Leg_{suffix[:2]}{side}"
            
            hip_pos = (sign * 0.32, base_y, 0.42)
            knee_pos = (sign * reach_x, reach_y, knee_z)
            foot_pos = (sign * foot_x, foot_y, 0.0)
            
            mesh = bpy.data.meshes.new(leg_name)
            obj = bpy.data.objects.new(leg_name, mesh)
            bpy.context.collection.objects.link(obj)
            
            v_hip = [hip_pos[0], hip_pos[1], hip_pos[2]]
            v_knee = [knee_pos[0], knee_pos[1], knee_pos[2]]
            v_foot = [foot_pos[0], foot_pos[1], foot_pos[2]]
            
            sides = 5
            r_hip = 0.065
            r_knee = 0.048
            r_foot = 0.022
            
            def make_ring(center, radius, normal_dir):
                up = (0, 0, 1) if abs(normal_dir[2]) < 0.9 else (1, 0, 0)
                tx = (normal_dir[1] * up[2] - normal_dir[2] * up[1])
                ty = (normal_dir[2] * up[0] - normal_dir[0] * up[2])
                tz = (normal_dir[0] * up[1] - normal_dir[1] * up[0])
                mag = math.sqrt(tx*tx + ty*ty + tz*tz) or 1.0
                tx, ty, tz = tx/mag, ty/mag, tz/mag
                bx = (normal_dir[1] * tz - normal_dir[2] * ty)
                by = (normal_dir[2] * tx - normal_dir[0] * tz)
                bz = (normal_dir[0] * ty - normal_dir[1] * tx)
                
                ring = []
                for i in range(sides):
                    th = 2 * math.pi * i / sides
                    rx = center[0] + radius * (math.cos(th) * tx + math.sin(th) * bx)
                    ry = center[1] + radius * (math.cos(th) * ty + math.sin(th) * by)
                    rz = center[2] + radius * (math.cos(th) * tz + math.sin(th) * bz)
                    ring.append((rx, ry, rz))
                return ring
            
            dir_upper = (v_knee[0]-v_hip[0], v_knee[1]-v_hip[1], v_knee[2]-v_hip[2])
            dir_lower = (v_foot[0]-v_knee[0], v_foot[1]-v_knee[1], v_foot[2]-v_knee[2])
            
            ring_hip = make_ring(v_hip, r_hip, dir_upper)
            ring_knee = make_ring(v_knee, r_knee, dir_upper)
            ring_foot = make_ring(v_foot, r_foot, dir_lower)
            
            verts = []
            faces = []
            verts.extend(ring_hip)   # 0..4
            verts.extend(ring_knee)  # 5..9
            verts.extend(ring_foot)  # 10..14
            verts.append((v_foot[0], v_foot[1], v_foot[2])) # 15: tip
            
            for i in range(sides):
                next_i = (i + 1) % sides
                faces.append((i, next_i, next_i + sides, i + sides))
            for i in range(sides):
                next_i = (i + 1) % sides
                faces.append((i + sides, next_i + sides, next_i + 2 * sides, i + 2 * sides))
            tip_idx = 15
            for i in range(sides):
                next_i = (i + 1) % sides
                faces.append((i + 2 * sides, next_i + 2 * sides, tip_idx))
            faces.append(tuple(reversed(range(sides))))
            
            mesh.from_pydata(verts, [], faces)
            mesh.update()
            obj.data.materials.append(mat_black)
            bpy.context.view_layer.objects.active = obj
            bpy.ops.object.shade_flat()
            parts.append(obj)

    # 7. ObjectiveHitbox (Required by DestructionService)
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, -0.05, 0.45))
    hitbox = bpy.context.active_object
    hitbox.name = "ObjectiveHitbox"
    hitbox.scale = (2.6, 2.4, 0.9)
    hitbox.display_type = 'WIRE'
    hitbox.hide_render = True  # Invisible in preview renders, but present in FBX/Blend!
    hitbox.data.materials.append(mat_hitbox)
    parts.append(hitbox)
    
    # 8. Apply transforms to all parts
    for obj in parts:
        bpy.context.view_layer.objects.active = obj
        obj.select_set(True)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    
    # 9. Create Root Model Parent "Spider"
    bpy.ops.object.empty_add(type='PLAIN_AXES', location=(0, 0, 0))
    spider_root = bpy.context.active_object
    spider_root.name = "Spider"
    
    for obj in parts:
        obj.parent = spider_root
        
    print(f"[SUCCESS] Built Spider Model with {len(parts)} parts and ObjectiveHitbox.")
    return spider_root

def main():
    root = create_lowpoly_spider()
    
    blend_dir = r"f:/BIGGER/blender/objectives"
    export_dir = r"f:/BIGGER/blender/exports"
    os.makedirs(blend_dir, exist_ok=True)
    os.makedirs(export_dir, exist_ok=True)
    
    blend_path = os.path.join(blend_dir, "Spider.blend")
    fbx_path = os.path.join(export_dir, "Spider.fbx")
    preview_path = os.path.join(blend_dir, "Spider_preview.png")
    
    # Save .blend file
    bpy.ops.wm.save_as_mainfile(filepath=blend_path)
    print(f"[SAVED] Blend file: {blend_path}")
    
    # Select all objects under Spider root for export
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
    
    # Setup Camera & Light for high quality preview render
    # Camera front-quarter 3/4 view
    bpy.ops.object.camera_add(location=(2.2, 2.5, 1.8), rotation=(math.radians(65), 0, math.radians(140)))
    cam = bpy.context.active_object
    bpy.context.scene.camera = cam
    
    # Key sun light
    bpy.ops.object.light_add(type='SUN', location=(3, 3, 5), rotation=(math.radians(45), math.radians(15), math.radians(45)))
    bpy.context.active_object.data.energy = 4.0
    
    # Fill light
    bpy.ops.object.light_add(type='POINT', location=(-2, -2, 2))
    bpy.context.active_object.data.energy = 80.0
    
    bpy.context.scene.render.resolution_x = 960
    bpy.context.scene.render.resolution_y = 640
    bpy.context.scene.render.filepath = preview_path
    bpy.ops.render.render(write_still=True)
    print(f"[RENDERED] Preview image: {preview_path}")

if __name__ == "__main__":
    main()
