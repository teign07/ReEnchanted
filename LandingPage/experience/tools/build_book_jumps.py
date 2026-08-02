"""Build compact hero props for the three public-domain Book Jumps.

Blender is used as an offline shape compiler. Runtime atmosphere, repetition,
lighting, text, and variation remain in Three.js.
"""

import argparse
import math
import random
import sys
from pathlib import Path

import bpy


def arguments():
    values = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", required=True)
    parser.add_argument("--seed", type=int, default=1897)
    return parser.parse_args(values)


def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for datablocks in (bpy.data.meshes, bpy.data.curves, bpy.data.materials):
        for block in list(datablocks):
            if block.users == 0:
                datablocks.remove(block)


def material(name, color, metallic=0.0, roughness=0.55):
    item = bpy.data.materials.new(name)
    item.diffuse_color = (*color, 1.0)
    item.use_nodes = True
    bsdf = item.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    return item


def parent(name):
    item = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(item)
    return item


def finish(obj, name, group, mat=None, bevel=0.0):
    obj.name = name
    obj.parent = group
    if mat:
        obj.data.materials.append(mat)
    if bevel:
        modifier = obj.modifiers.new("Edge truth", "BEVEL")
        modifier.width = bevel
        modifier.segments = 2
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.shade_smooth_by_angle()
    obj.select_set(False)
    return obj


def cube(name, group, location, scale, mat, bevel=0.0, rotation=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(location=location, rotation=rotation)
    obj = bpy.context.object
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return finish(obj, name, group, mat, bevel)


def cylinder(name, group, location, radius, depth, mat, vertices=16, rotation=(0, 0, 0)):
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=vertices,
        radius=radius,
        depth=depth,
        location=location,
        rotation=rotation,
    )
    return finish(bpy.context.object, name, group, mat, 0.025)


def torus(name, group, location, major_radius, minor_radius, mat, rotation=(0, 0, 0)):
    bpy.ops.mesh.primitive_torus_add(
        major_radius=major_radius,
        minor_radius=minor_radius,
        major_segments=32,
        minor_segments=8,
        location=location,
        rotation=rotation,
    )
    return finish(bpy.context.object, name, group, mat)


def build_regency(mats, rng):
    group = parent("BOOK_PRIDE_AND_PREJUDICE")
    group["book_title"] = "Pride and Prejudice"
    group["source_year"] = 1813

    cube("Pemberley_DanceFloor", group, (0, 0, 0.11), (4.8, 3.2, 0.11), mats["oak"], 0.04)
    for side in (-1, 1):
        for depth in (-2.5, 0, 2.5):
            cylinder(f"Pemberley_Column_{side}_{depth}", group, (side * 4.2, depth, 2.15), 0.22, 4.3, mats["ivory"], 20)
            cube(f"Pemberley_Capital_{side}_{depth}", group, (side * 4.2, depth, 4.2), (0.38, 0.38, 0.12), mats["gold"], 0.04)

    torus("Pemberley_ChandelierRing", group, (0, 0, 4.7), 1.34, 0.075, mats["gold"])
    cylinder("Pemberley_ChandelierStem", group, (0, 0, 5.55), 0.07, 1.7, mats["gold"], 12)
    for index in range(12):
        angle = index * math.tau / 12
        radius = 1.34
        x, z = math.cos(angle) * radius, math.sin(angle) * radius
        length = 0.45 + rng.random() * 0.42
        cylinder(
            f"Pemberley_Crystal_{index}",
            group,
            (x, z, 4.43 - length / 2),
            0.035,
            length,
            mats["glass"],
            8,
        )
    return group


def build_dracula(mats):
    group = parent("BOOK_DRACULA")
    group["book_title"] = "Dracula"
    group["source_year"] = 1897

    for side in (-1, 1):
        cube(f"Castle_Post_{side}", group, (side * 2.15, 0, 2.5), (0.46, 0.55, 2.5), mats["stone"], 0.08)
        cube(
            f"Castle_Point_{side}",
            group,
            (side * 1.15, 0, 5.0),
            (1.42, 0.52, 0.27),
            mats["stone"],
            0.06,
            (0, side * math.radians(34), 0),
        )
    cube("Castle_Threshold", group, (0, 0, 0.23), (3.0, 0.72, 0.23), mats["stone"], 0.06)
    for index, x in enumerate((-1.2, -0.6, 0, 0.6, 1.2)):
        cylinder(f"Castle_Portcullis_{index}", group, (x, 0.2, 2.7), 0.045, 4.8, mats["iron"], 8)
    for index, height in enumerate((1.2, 2.4, 3.6, 4.7)):
        cube(f"Castle_Crossbar_{index}", group, (0, 0.2, height), (1.55, 0.05, 0.05), mats["iron"], 0.015)
    torus("Castle_Seal", group, (0, -0.35, 3.1), 0.72, 0.075, mats["blood"], (math.pi / 2, 0, 0))
    return group


def build_neverland(mats):
    group = parent("BOOK_PETER_PAN")
    group["book_title"] = "Peter Pan"
    group["source_year"] = 1911

    cube("Darling_Roof", group, (0, 0, 0.25), (5.1, 3.2, 0.25), mats["roof"], 0.05)
    cube("Darling_Chimney", group, (-3.2, 0.6, 1.35), (0.62, 0.62, 1.35), mats["brick"], 0.06)
    cube("Darling_ChimneyCap", group, (-3.2, 0.6, 2.75), (0.78, 0.78, 0.12), mats["stone"], 0.04)
    torus("Neverland_Clock", group, (2.6, -0.1, 2.55), 1.25, 0.12, mats["gold"], (math.pi / 2, 0, 0))
    cylinder("Neverland_ClockPin", group, (2.6, -0.18, 2.55), 0.1, 0.25, mats["gold"], 12, (math.pi / 2, 0, 0))
    for index in range(12):
        angle = index * math.tau / 12
        x = 2.6 + math.sin(angle) * 1.03
        y = 2.55 + math.cos(angle) * 1.03
        cube(f"Neverland_Tick_{index}", group, (x, -0.2, y), (0.035, 0.035, 0.12), mats["ivory"], rotation=(0, -angle, 0))
    cube("Neverland_MinuteHand", group, (2.6, -0.28, 2.92), (0.035, 0.035, 0.5), mats["ivory"], 0.01, (0, -0.28, 0))
    cube("Neverland_HourHand", group, (2.84, -0.28, 2.55), (0.36, 0.035, 0.035), mats["ivory"], 0.01, (0, 0.16, 0))
    return group


def main():
    args = arguments()
    rng = random.Random(args.seed)
    clear_scene()
    mats = {
        "oak": material("Regency_Oak", (0.22, 0.09, 0.035), 0.05, 0.5),
        "ivory": material("Regency_Ivory", (0.66, 0.58, 0.43), 0.0, 0.68),
        "gold": material("Old_Gold", (0.5, 0.29, 0.07), 0.72, 0.24),
        "glass": material("Candle_Glass", (0.55, 0.67, 0.62), 0.24, 0.16),
        "stone": material("Carpathian_Stone", (0.12, 0.13, 0.15), 0.08, 0.9),
        "iron": material("Castle_Iron", (0.035, 0.04, 0.05), 0.8, 0.32),
        "blood": material("Sealing_Wax", (0.24, 0.008, 0.012), 0.16, 0.28),
        "roof": material("London_Slate", (0.055, 0.07, 0.09), 0.18, 0.72),
        "brick": material("London_Brick", (0.22, 0.08, 0.05), 0.04, 0.8),
    }
    build_regency(mats, rng)
    build_dracula(mats)
    build_neverland(mats)

    for obj in bpy.context.scene.objects:
        obj.select_set(True)
    output = Path(args.output).expanduser().resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=str(output),
        export_format="GLB",
        export_apply=True,
        export_yup=True,
        export_texcoords=True,
        export_normals=True,
        export_materials="EXPORT",
        export_animations=False,
    )
    triangles = sum(
        len(obj.data.polygons) for obj in bpy.context.scene.objects if obj.type == "MESH"
    )
    print(f"BOOK_JUMPS output={output} seed={args.seed} faces={triangles}")


if __name__ == "__main__":
    main()
