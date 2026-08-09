"""Build a deterministic, animated Paperwing for the shared Outer Stacks web prototype.

The asset is intentionally stylized and low-poly.  It is a movement instrument,
not a close-up digital human: rigid pieces follow a reusable armature, manuscript
wings hold the focal silhouette, and all player verbs live in named glTF clips.
"""

import argparse
import math
import os
import sys

import bpy
from mathutils import Matrix, Vector


def arguments():
    raw = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", required=True)
    parser.add_argument("--preview")
    parser.add_argument("--blend")
    parser.add_argument("--seed", type=int, default=1189)
    return parser.parse_args(raw)


def clean_scene():
    bpy.ops.object.mode_set(mode="OBJECT") if bpy.context.object and bpy.context.object.mode != "OBJECT" else None
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for datablocks in (bpy.data.meshes, bpy.data.curves, bpy.data.armatures, bpy.data.materials, bpy.data.cameras, bpy.data.lights):
        for datablock in tuple(datablocks):
            if datablock.users == 0:
                datablocks.remove(datablock)


def material(name, color, metallic=0.0, roughness=0.6, emission=None, alpha=1.0):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, alpha)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, alpha)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Alpha"].default_value = alpha
    if emission:
        if "Emission Color" in bsdf.inputs:
            bsdf.inputs["Emission Color"].default_value = (*emission, 1.0)
            bsdf.inputs["Emission Strength"].default_value = 3.0
        elif "Emission" in bsdf.inputs:
            bsdf.inputs["Emission"].default_value = (*emission, 1.0)
            bsdf.inputs["Emission Strength"].default_value = 3.0
    if alpha < 1:
        mat.surface_render_method = "DITHERED"
        mat.use_transparency_overlap = False
    return mat


def smooth(object_):
    if object_.type == "MESH":
        for polygon in object_.data.polygons:
            polygon.use_smooth = True
    return object_


def rigid_parent(object_, armature, bone_name):
    world = object_.matrix_world.copy()
    object_.parent = armature
    object_.parent_type = "BONE"
    object_.parent_bone = bone_name
    object_.matrix_world = world
    return object_


def sphere(name, location, scale, mat, armature, bone, segments=16, rings=8):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings, location=location)
    object_ = bpy.context.object
    object_.name = name
    object_.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    object_.data.materials.append(mat)
    smooth(object_)
    return rigid_parent(object_, armature, bone)


def cone(name, location, radius1, radius2, depth, mat, armature, bone, rotation=(0, 0, 0), vertices=12):
    bpy.ops.mesh.primitive_cone_add(
        vertices=vertices,
        radius1=radius1,
        radius2=radius2,
        depth=depth,
        location=location,
        rotation=rotation,
    )
    object_ = bpy.context.object
    object_.name = name
    object_.data.materials.append(mat)
    return rigid_parent(object_, armature, bone)


def cylinder_between(name, start, end, radius, mat, armature, bone, vertices=10):
    start_vector = Vector(start)
    end_vector = Vector(end)
    delta = end_vector - start_vector
    midpoint = (start_vector + end_vector) * 0.5
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=delta.length, location=midpoint)
    object_ = bpy.context.object
    object_.name = name
    object_.rotation_mode = "QUATERNION"
    object_.rotation_quaternion = delta.to_track_quat("Z", "Y")
    object_.data.materials.append(mat)
    smooth(object_)
    return rigid_parent(object_, armature, bone)


def wing_mesh(name, side, upper, parchment, ink, armature, bone):
    sign = -1 if side == "L" else 1
    if upper:
        points = [
            (0.00, 0.11, 1.58),
            (0.34 * sign, 0.14, 1.92),
            (0.78 * sign, 0.16, 2.31),
            (1.22 * sign, 0.18, 2.52),
            (1.08 * sign, 0.17, 2.16),
            (1.33 * sign, 0.18, 2.08),
            (0.96 * sign, 0.16, 1.80),
            (1.08 * sign, 0.16, 1.60),
            (0.55 * sign, 0.13, 1.48),
        ]
    else:
        points = [
            (0.00, 0.12, 1.43),
            (0.43 * sign, 0.15, 1.38),
            (0.96 * sign, 0.18, 1.43),
            (1.20 * sign, 0.18, 1.24),
            (0.89 * sign, 0.17, 1.05),
            (1.04 * sign, 0.16, 0.82),
            (0.52 * sign, 0.14, 0.94),
            (0.30 * sign, 0.13, 0.72),
        ]
    vertices = points + [(x, y + 0.025, z) for x, y, z in points]
    count = len(points)
    faces = [tuple(range(count)), tuple(range(count, count * 2))]
    for index in range(count):
        next_index = (index + 1) % count
        faces.append((index, next_index, count + next_index, count + index))
    mesh = bpy.data.meshes.new(f"{name}Mesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.materials.append(parchment)
    mesh.update()
    object_ = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(object_)
    rigid_parent(object_, armature, bone)

    # The first web mesh keeps the manuscript marks abstract and material-led.
    # Thin rigid vein rods read as cage bars at the target camera distance; a
    # later authored decal can add ink without weakening the silhouette.
    return object_


def build_armature():
    armature_data = bpy.data.armatures.new("PaperwingRig")
    armature = bpy.data.objects.new("PaperwingRig", armature_data)
    bpy.context.collection.objects.link(armature)
    bpy.context.view_layer.objects.active = armature
    armature.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")

    bones = {
        "Root": ((0, 0, 0), (0, 0, 0.22), None),
        "Pelvis": ((0, 0, 0.62), (0, 0, 0.98), "Root"),
        "Spine": ((0, 0, 0.9), (0, 0, 1.58), "Pelvis"),
        "Head": ((0, 0, 1.5), (0, 0, 2.2), "Spine"),
        "UpperArm.L": ((-0.18, 0, 1.48), (-0.49, 0, 1.19), "Spine"),
        "Forearm.L": ((-0.49, 0, 1.19), (-0.64, -0.02, 0.88), "UpperArm.L"),
        "UpperArm.R": ((0.18, 0, 1.48), (0.49, 0, 1.19), "Spine"),
        "Forearm.R": ((0.49, 0, 1.19), (0.64, -0.02, 0.88), "UpperArm.R"),
        "Thigh.L": ((-0.17, 0, 0.78), (-0.2, 0, 0.42), "Pelvis"),
        "Shin.L": ((-0.2, 0, 0.42), (-0.2, -0.015, 0.08), "Thigh.L"),
        "Thigh.R": ((0.17, 0, 0.78), (0.2, 0, 0.42), "Pelvis"),
        "Shin.R": ((0.2, 0, 0.42), (0.2, -0.015, 0.08), "Thigh.R"),
        "WingUpper.L": ((-0.06, 0.08, 1.53), (-0.62, 0.12, 2.02), "Spine"),
        "WingUpper.R": ((0.06, 0.08, 1.53), (0.62, 0.12, 2.02), "Spine"),
        "WingLower.L": ((-0.05, 0.09, 1.42), (-0.58, 0.13, 1.18), "Spine"),
        "WingLower.R": ((0.05, 0.09, 1.42), (0.58, 0.13, 1.18), "Spine"),
    }
    for name, (head, tail, parent) in bones.items():
        bone = armature_data.edit_bones.new(name)
        bone.head = head
        bone.tail = tail
        if parent:
            bone.parent = armature_data.edit_bones[parent]
    bpy.ops.object.mode_set(mode="POSE")
    for pose_bone in armature.pose.bones:
        pose_bone.rotation_mode = "XYZ"
    bpy.ops.object.mode_set(mode="OBJECT")
    armature.select_set(False)
    return armature


def build_character(armature):
    ink = material("Ink_Cloth", (0.018, 0.025, 0.024), roughness=0.74)
    ink_soft = material("Ink_Hair", (0.012, 0.02, 0.022), roughness=0.5)
    skin = material("Outside_Warmth", (0.22, 0.145, 0.105), roughness=0.82)
    parchment = material("Manuscript_Wing", (0.71, 0.56, 0.31), roughness=0.78, alpha=0.9)
    wing_ink = material("Wing_Ink", (0.055, 0.035, 0.018), roughness=0.66)
    brass = material("Clasp_Brass", (0.32, 0.17, 0.045), metallic=0.72, roughness=0.4)
    eye = material("Reader_Eyes", (0.72, 0.73, 0.66), roughness=0.2, emission=(0.72, 0.8, 0.72))

    objects = []
    objects.append(cone("Paperwing_Robe", (0, 0, 1.02), 0.43, 0.23, 0.92, ink, armature, "Spine", vertices=16))
    objects.append(cone("Paperwing_Collar", (0, -0.015, 1.52), 0.26, 0.18, 0.18, parchment, armature, "Spine", vertices=14))
    objects.append(sphere("Paperwing_Head", (0, -0.015, 1.82), (0.30, 0.27, 0.34), skin, armature, "Head"))
    objects.append(sphere("Paperwing_Hair", (0, 0.055, 1.9), (0.315, 0.28, 0.30), ink_soft, armature, "Head"))

    # Face and mask remain graphic at the camera floor distance.
    for side in (-1, 1):
        objects.append(sphere(
            f"Paperwing_Eye_{'L' if side < 0 else 'R'}",
            (0.105 * side, -0.266, 1.84),
            (0.055, 0.022, 0.075),
            eye,
            armature,
            "Head",
            segments=12,
            rings=6,
        ))
        objects.append(cone(
            f"Paperwing_Ear_{'L' if side < 0 else 'R'}",
            (0.34 * side, -0.01, 1.86),
            0.10,
            0,
            0.42,
            skin,
            armature,
            "Head",
            rotation=(0, math.radians(72) * side, math.radians(90)),
            vertices=8,
        ))

    limb_specs = [
        ("UpperArm.L", (-0.18, 0, 1.48), (-0.49, 0, 1.19), 0.095, ink),
        ("Forearm.L", (-0.49, 0, 1.19), (-0.64, -0.02, 0.88), 0.08, ink),
        ("UpperArm.R", (0.18, 0, 1.48), (0.49, 0, 1.19), 0.095, ink),
        ("Forearm.R", (0.49, 0, 1.19), (0.64, -0.02, 0.88), 0.08, ink),
        ("Thigh.L", (-0.17, 0, 0.78), (-0.20, 0, 0.42), 0.12, ink),
        ("Shin.L", (-0.20, 0, 0.42), (-0.20, -0.015, 0.08), 0.10, ink),
        ("Thigh.R", (0.17, 0, 0.78), (0.20, 0, 0.42), 0.12, ink),
        ("Shin.R", (0.20, 0, 0.42), (0.20, -0.015, 0.08), 0.10, ink),
    ]
    for bone, start, end, radius, mat in limb_specs:
        objects.append(cylinder_between(f"Paperwing_{bone}", start, end, radius, mat, armature, bone))

    for side in (-1, 1):
        label = "L" if side < 0 else "R"
        objects.append(sphere(f"Paperwing_Hand_{label}", (0.66 * side, -0.03, 0.83), (0.09, 0.075, 0.12), skin, armature, f"Forearm.{label}"))
        objects.append(sphere(f"Paperwing_Foot_{label}", (0.20 * side, -0.10, 0.05), (0.15, 0.25, 0.09), ink, armature, f"Shin.{label}"))

    # Clasps and a reader glyph at the sternum.
    for index, z in enumerate((1.2, 1.35, 1.49)):
        objects.append(sphere(f"Paperwing_Clasp_{index}", (0, -0.245, z), (0.045, 0.025, 0.045), brass, armature, "Spine", segments=10, rings=5))
    objects.append(sphere("Paperwing_ReaderGlyph", (0, -0.265, 1.06), (0.085, 0.018, 0.085), eye, armature, "Spine", segments=12, rings=6))

    wing_mesh("Paperwing_WingUpper_L", "L", True, parchment, wing_ink, armature, "WingUpper.L")
    wing_mesh("Paperwing_WingUpper_R", "R", True, parchment, wing_ink, armature, "WingUpper.R")
    wing_mesh("Paperwing_WingLower_L", "L", False, parchment, wing_ink, armature, "WingLower.L")
    wing_mesh("Paperwing_WingLower_R", "R", False, parchment, wing_ink, armature, "WingLower.R")
    return objects


def reset_pose(armature):
    for bone in armature.pose.bones:
        bone.location = (0, 0, 0)
        bone.rotation_euler = (0, 0, 0)
        bone.scale = (1, 1, 1)


def apply_pose(armature, frame, pose):
    reset_pose(armature)
    for bone_name, channels in pose.items():
        bone = armature.pose.bones[bone_name]
        if "rotation" in channels:
            bone.rotation_euler = tuple(math.radians(value) for value in channels["rotation"])
        if "location" in channels:
            bone.location = channels["location"]
        if "scale" in channels:
            bone.scale = channels["scale"]
    for bone in armature.pose.bones:
        bone.keyframe_insert("location", frame=frame, group=bone.name)
        bone.keyframe_insert("rotation_euler", frame=frame, group=bone.name)
        bone.keyframe_insert("scale", frame=frame, group=bone.name)


def mirrored_pose(left_leg=0, right_leg=0, left_arm=0, right_arm=0, root_z=0, spine_x=0, wing=0):
    return {
        "Root": {"location": (0, 0, root_z)},
        "Spine": {"rotation": (spine_x, 0, 0)},
        "Thigh.L": {"rotation": (left_leg, 0, 0)},
        "Thigh.R": {"rotation": (right_leg, 0, 0)},
        "Shin.L": {"rotation": (-max(0, left_leg) * 0.65, 0, 0)},
        "Shin.R": {"rotation": (-max(0, right_leg) * 0.65, 0, 0)},
        "UpperArm.L": {"rotation": (left_arm, 0, 0)},
        "UpperArm.R": {"rotation": (right_arm, 0, 0)},
        "WingUpper.L": {"rotation": (0, wing, -wing * 0.18)},
        "WingUpper.R": {"rotation": (0, -wing, wing * 0.18)},
        "WingLower.L": {"rotation": (0, wing * 0.7, -wing * 0.12)},
        "WingLower.R": {"rotation": (0, -wing * 0.7, wing * 0.12)},
    }


def make_action(armature, name, frame_count, keys, loop=True):
    action = bpy.data.actions.new(name)
    action.use_fake_user = True
    armature.animation_data_create()
    armature.animation_data.action = action
    for frame, pose in keys:
        apply_pose(armature, frame, pose)
    if loop and keys:
        apply_pose(armature, frame_count, keys[0][1])
    # Blender 5 stores keyed channels in action slots/channel bags rather than
    # exposing Action.fcurves directly.  Keyframe interpolation defaults are
    # already suitable for the exported samples; retain the older adjustment
    # when this compiler is run under Blender 4.x.
    for fcurve in getattr(action, "fcurves", ()):
        for point in fcurve.keyframe_points:
            point.interpolation = "BEZIER" if name in {"Idle", "Sleep"} else "SINE"
    return action


def build_actions(armature):
    idle_a = mirrored_pose(root_z=0, wing=3)
    idle_b = mirrored_pose(root_z=0.025, spine_x=-1.5, wing=9)
    idle_b["Head"] = {"rotation": (1.2, 0, -2.0)}
    make_action(armature, "Idle", 72, [(1, idle_a), (36, idle_b)], loop=True)

    walk_a = mirrored_pose(left_leg=28, right_leg=-24, left_arm=-20, right_arm=22, root_z=0.02, spine_x=6, wing=-5)
    walk_b = mirrored_pose(left_leg=-24, right_leg=28, left_arm=22, right_arm=-20, root_z=0.0, spine_x=6, wing=-2)
    make_action(armature, "Walk", 30, [(1, walk_a), (16, walk_b)], loop=True)

    run_a = mirrored_pose(left_leg=48, right_leg=-38, left_arm=-42, right_arm=38, root_z=0.08, spine_x=19, wing=-18)
    run_b = mirrored_pose(left_leg=-38, right_leg=48, left_arm=38, right_arm=-42, root_z=0.015, spine_x=19, wing=-13)
    make_action(armature, "Run", 22, [(1, run_a), (12, run_b)], loop=True)

    skid = mirrored_pose(left_leg=18, right_leg=-12, left_arm=-38, right_arm=-38, root_z=-0.04, spine_x=-23, wing=34)
    skid["Shin.L"] = {"rotation": (-35, 0, 0)}
    skid["Shin.R"] = {"rotation": (-18, 0, 0)}
    make_action(armature, "Skid", 18, [(1, mirrored_pose(wing=-10)), (7, skid), (18, mirrored_pose(wing=8))], loop=False)

    crouch = mirrored_pose(root_z=-0.33, spine_x=24, wing=-38)
    crouch["Thigh.L"] = {"rotation": (58, 0, 0)}
    crouch["Thigh.R"] = {"rotation": (58, 0, 0)}
    crouch["Shin.L"] = {"rotation": (-75, 0, 0)}
    crouch["Shin.R"] = {"rotation": (-75, 0, 0)}
    crouch["Head"] = {"rotation": (-12, 0, 0)}
    make_action(armature, "Crouch", 32, [(1, mirrored_pose()), (18, crouch), (32, crouch)], loop=False)

    sleep = dict(crouch)
    sleep["Root"] = {"location": (0, 0, -0.46)}
    sleep["Spine"] = {"rotation": (54, 0, 11)}
    sleep["Head"] = {"rotation": (35, 0, -15)}
    sleep["UpperArm.L"] = {"rotation": (42, 10, -28)}
    sleep["UpperArm.R"] = {"rotation": (42, -10, 28)}
    sleep["WingUpper.L"] = {"rotation": (8, -52, 12)}
    sleep["WingUpper.R"] = {"rotation": (8, 52, -12)}
    sleep["WingLower.L"] = {"rotation": (0, -58, 10)}
    sleep["WingLower.R"] = {"rotation": (0, 58, -10)}
    sleep_breath = {**sleep, "Root": {"location": (0, 0, -0.44)}}
    make_action(armature, "Sleep", 84, [(1, sleep), (42, sleep_breath)], loop=True)

    bow = mirrored_pose(root_z=-0.04, spine_x=42, wing=14)
    bow["Head"] = {"rotation": (24, 0, 0)}
    bow["UpperArm.L"] = {"rotation": (-12, 0, -18)}
    bow["UpperArm.R"] = {"rotation": (-12, 0, 18)}
    make_action(armature, "Bow", 42, [(1, mirrored_pose()), (18, bow), (29, bow), (42, mirrored_pose())], loop=False)

    beckon = mirrored_pose(wing=8)
    beckon["UpperArm.R"] = {"rotation": (-65, -8, 18)}
    beckon["Forearm.R"] = {"rotation": (-55, 0, 0)}
    beckon_back = {**beckon, "Forearm.R": {"rotation": (-95, 0, 0)}}
    make_action(armature, "Beckon", 46, [(1, mirrored_pose()), (14, beckon), (24, beckon_back), (34, beckon), (46, mirrored_pose())], loop=False)

    call = mirrored_pose(root_z=0.05, spine_x=-9, wing=52)
    call["Head"] = {"rotation": (-18, 0, 0)}
    call["UpperArm.L"] = {"rotation": (-38, 0, -42)}
    call["UpperArm.R"] = {"rotation": (-38, 0, 42)}
    make_action(armature, "Call", 50, [(1, mirrored_pose()), (15, call), (35, call), (50, mirrored_pose())], loop=False)

    offer = mirrored_pose(root_z=-0.035, spine_x=12, wing=12)
    offer["UpperArm.L"] = {"rotation": (-78, 0, -12)}
    offer["UpperArm.R"] = {"rotation": (-78, 0, 12)}
    offer["Forearm.L"] = {"rotation": (-45, 0, 0)}
    offer["Forearm.R"] = {"rotation": (-45, 0, 0)}
    make_action(armature, "Offer", 54, [(1, mirrored_pose()), (18, offer), (38, offer), (54, mirrored_pose())], loop=False)

    refuse = mirrored_pose(spine_x=-4, wing=22)
    refuse["Head"] = {"rotation": (0, 0, -22)}
    refuse["UpperArm.L"] = {"rotation": (-46, 0, -48)}
    refuse["Forearm.L"] = {"rotation": (-82, 0, 0)}
    make_action(armature, "Refuse", 38, [(1, mirrored_pose()), (12, refuse), (25, refuse), (38, mirrored_pose())], loop=False)

    hide = dict(crouch)
    hide["WingUpper.L"] = {"rotation": (0, -64, 18)}
    hide["WingUpper.R"] = {"rotation": (0, 64, -18)}
    hide["Head"] = {"rotation": (-8, 0, 14)}
    make_action(armature, "Hide", 40, [(1, mirrored_pose()), (20, hide), (40, hide)], loop=False)

    reset_pose(armature)
    armature.animation_data.action = None


def setup_preview_camera():
    bpy.ops.object.camera_add(location=(4.8, -7.6, 3.3))
    camera = bpy.context.object
    camera.name = "Paperwing_Preview_Camera"
    direction = Vector((0, 0, 1.25)) - camera.location
    camera.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    camera.data.lens = 58
    bpy.context.scene.camera = camera

    bpy.ops.object.light_add(type="AREA", location=(-3.8, -4.2, 6.0))
    key = bpy.context.object
    key.data.energy = 850
    key.data.shape = "DISK"
    key.data.size = 5.0
    bpy.ops.object.light_add(type="AREA", location=(3.5, 1.5, 4.0))
    fill = bpy.context.object
    fill.data.energy = 520
    fill.data.color = (0.52, 0.66, 0.58)
    fill.data.size = 4.0
    bpy.ops.object.light_add(type="POINT", location=(0, 1.4, 2.0))
    rim = bpy.context.object
    rim.data.energy = 240
    rim.data.color = (1.0, 0.65, 0.28)

    bpy.ops.mesh.primitive_plane_add(size=20, location=(0, 0, -0.03))
    floor = bpy.context.object
    floor.name = "Preview_Ground"
    floor.data.materials.append(material("Preview_Moss", (0.025, 0.045, 0.032), roughness=0.9))
    world = bpy.context.scene.world or bpy.data.worlds.new("PaperwingPreviewWorld")
    bpy.context.scene.world = world
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.006, 0.01, 0.009, 1)
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.22


def render_preview(output):
    setup_preview_camera()
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 900
    scene.render.resolution_y = 900
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.filepath = os.path.abspath(output)
    scene.render.film_transparent = False
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.resolution_percentage = 100
    bpy.ops.render.render(write_still=True)


def export_glb(output, armature):
    bpy.context.scene.frame_start = 1
    bpy.context.scene.frame_end = 90
    bpy.context.scene.render.fps = 30
    output = os.path.abspath(output)
    os.makedirs(os.path.dirname(output), exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    armature.select_set(True)
    for object_ in bpy.context.scene.objects:
        if object_.parent == armature:
            object_.select_set(True)
    bpy.context.view_layer.objects.active = armature
    bpy.ops.export_scene.gltf(
        filepath=output,
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_yup=True,
        export_animations=True,
        export_animation_mode="ACTIONS",
        export_force_sampling=True,
        export_frame_range=False,
        export_skins=True,
        export_morph=False,
    )
    return output


def main():
    args = arguments()
    clean_scene()
    bpy.context.scene.render.fps = 30
    armature = build_armature()
    build_character(armature)
    build_actions(armature)
    output = export_glb(args.output, armature)
    if args.blend:
        os.makedirs(os.path.dirname(os.path.abspath(args.blend)), exist_ok=True)
        bpy.ops.wm.save_as_mainfile(filepath=os.path.abspath(args.blend))
    if args.preview:
        render_preview(args.preview)
    triangles = sum(
        len(polygon.vertices) - 2
        for object_ in bpy.context.scene.objects
        if object_.type == "MESH" and not object_.name.startswith("Preview_")
        for polygon in object_.data.polygons
    )
    print(
        f"PAPERWING output={output} triangles={triangles} "
        f"animations={len(bpy.data.actions)} seed={args.seed}"
    )


if __name__ == "__main__":
    main()
