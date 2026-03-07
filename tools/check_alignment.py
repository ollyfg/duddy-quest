#!/usr/bin/env python3
"""
check_alignment.py – Validate that gameplay nodes in room scenes are on the
16-px grid and that obstacle collision shapes have grid-compatible dimensions.

Run from the project root:
    python3 tools/check_alignment.py

What it checks
--------------
1. Position alignment – every gameplay node with a ``position = Vector2(x, y)``
   must have both x and y as exact multiples of ``GRID_SIZE`` (16 px).

2. Shape-size alignment – every ``RectangleShape2D`` sub_resource that is
   referenced by an obstacle ``CollisionShape2D`` (i.e. a CollisionShape2D
   whose ancestor is a non-structural StaticBody2D) must have both width and
   height as multiples of ``GRID_SIZE``.

Nodes that are intentionally exempt from position checks
---------------------------------------------------------
* Wall bodies – names containing "Wall" (TopWall, BottomWall, etc.) are
  positioned at x=12 / y=12 (half the 24-px wall thickness) by design.
* Exit trigger areas – names starting with "Exit" are at wall boundaries.
* Door panels – names starting with "Door" are wall-embedded.
* Floor / Room root – background rectangle, not a gameplay object.
* CollisionShape2D children – position is relative to their parent node.
* ColorRect / Sprite children – purely visual, relative to parent.
* Node2D group containers without an ``instance=`` (e.g. "NPCs", "Items").
* Instanced scenes for wall-embedded objects: magic_door.tscn,
  locked_door.tscn.  These are always placed at the wall centre (x=628 or
  x=12) by design.

Shape sub_resources that are intentionally exempt from size checks
------------------------------------------------------------------
* Horizontal / vertical wall shapes: one dimension equals the full room width
  or height (640 or 480).
* Exit shapes: both dimensions are ≤ 48 with at least one being 12 (the
  12×48 exit sensor shape).
* Shapes whose only use is inside a Wall or Exit node hierarchy.
"""

import os
import re
import sys

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
SCENES_DIR = os.path.join(os.path.dirname(__file__), "..", "scenes")
GRID_SIZE  = 16

# Pattern that identifies room scene files (training rooms and level rooms).
ROOM_FILENAME_RE = re.compile(r'^(?:room_|l\d+_).+\.tscn$')

# Node names or name patterns that are exempt from position alignment checks.
# Checked case-insensitively.
EXEMPT_NAME_CONTAINS = ("wall",)          # TopWall, BottomWall, LeftWallTop …
EXEMPT_NAME_STARTS   = ("exit", "door")   # ExitEast, Door_east_door …
EXEMPT_NAME_EXACT    = {"floor", "room"}  # Room root, Floor ColorRect

# Instanced scene filenames (basename without directory) that are intentionally
# placed at the wall boundary and must not be checked.
EXEMPT_INSTANCE_BASENAMES = {"magic_door.tscn", "locked_door.tscn"}

# Node types that are purely structural or visual children – never gameplay.
EXEMPT_TYPES = {"CollisionShape2D", "ColorRect"}

# A shape whose width *or* height equals the full room dimension is a wall
# shape and is exempt from size checks.
ROOM_DIMENSIONS = {640, 480}

# ---------------------------------------------------------------------------
# Parsing helpers
# ---------------------------------------------------------------------------

def _parse_tscn(path):
    """
    Parse a .tscn file into a dict with two keys:

    ``sub_resources``
        {id_str: {"type": str, "size": (w, h) | None}}

    ``nodes``
        [{"name": str, "type": str | None, "parent": str,
          "instance_basename": str | None,
          "position": (x, y) | None,
          "shape_ref": str | None}]   # sub_resource id referenced by shape=
    """
    with open(path) as f:
        text = f.read()

    sub_resources = {}
    nodes = []

    # ---- sub_resource blocks ------------------------------------------------
    # [sub_resource type="RectangleShape2D" id="Sh_flowerbed"]
    # size = Vector2(64, 32)
    sr_header_re = re.compile(
        r'\[sub_resource\s+type="([^"]+)"\s+id="([^"]+)"\]([^\[]*)',
        re.DOTALL,
    )
    vec2_re = re.compile(r'Vector2\(\s*([-\d.]+)\s*,\s*([-\d.]+)\s*\)')

    for m in sr_header_re.finditer(text):
        sr_type, sr_id, sr_body = m.group(1), m.group(2), m.group(3)
        size = None
        if sr_type == "RectangleShape2D":
            sm = re.search(r'\bsize\s*=\s*' + vec2_re.pattern, sr_body)
            if sm:
                size = (float(sm.group(1)), float(sm.group(2)))
        sub_resources[sr_id] = {"type": sr_type, "size": size}

    # ---- node blocks --------------------------------------------------------
    # [node name="..." type="..." parent="..." instance=ExtResource("...")]
    # position = Vector2(x, y)
    # shape = SubResource("id")
    node_header_re = re.compile(
        r'\[node\s([^\]]+)\]([^\[]*)',
        re.DOTALL,
    )
    attr_name_re     = re.compile(r'\bname="([^"]+)"')
    attr_type_re     = re.compile(r'\btype="([^"]+)"')
    attr_parent_re   = re.compile(r'\bparent="([^"]+)"')
    attr_instance_re = re.compile(r'\binstance=ExtResource\("([^"]+)"\)')

    # Map ExtResource id → path (from [ext_resource ...] headers)
    ext_res = {}
    ext_re = re.compile(r'\[ext_resource[^\]]+path="([^"]+)"[^\]]+id="([^"]+)"\]')
    for em in ext_re.finditer(text):
        ext_res[em.group(2)] = em.group(1)

    shape_subres_re = re.compile(r'\bshape\s*=\s*SubResource\("([^"]+)"\)')

    for m in node_header_re.finditer(text):
        header, body = m.group(1), m.group(2)

        nm = attr_name_re.search(header)
        tm = attr_type_re.search(header)
        pm = attr_parent_re.search(header)
        im = attr_instance_re.search(header)

        name   = nm.group(1) if nm else ""
        ntype  = tm.group(1) if tm else None
        parent = pm.group(1) if pm else "."

        # Resolve instance to a scene basename, e.g. "npc.tscn"
        instance_basename = None
        if im:
            res_id = im.group(1)
            res_path = ext_res.get(res_id, "")
            instance_basename = os.path.basename(res_path) if res_path else None

        # Extract position
        pos = None
        pos_m = re.search(r'\bposition\s*=\s*' + vec2_re.pattern, body)
        if pos_m:
            pos = (float(pos_m.group(1)), float(pos_m.group(2)))

        # Extract shape reference (for CollisionShape2D nodes)
        shape_ref = None
        sm = shape_subres_re.search(body)
        if sm:
            shape_ref = sm.group(1)

        nodes.append({
            "name":               name,
            "type":               ntype,
            "parent":             parent,
            "instance_basename":  instance_basename,
            "position":           pos,
            "shape_ref":          shape_ref,
        })

    return {"sub_resources": sub_resources, "nodes": nodes}


def _is_structural_name(name):
    """Return True if the node name matches a structural (exempt) pattern."""
    lower = name.lower()
    if lower in EXEMPT_NAME_EXACT:
        return True
    for pat in EXEMPT_NAME_CONTAINS:
        if pat in lower:
            return True
    for pat in EXEMPT_NAME_STARTS:
        if lower.startswith(pat):
            return True
    return False


def _is_exempt_for_position(node):
    """Return True if this node should be skipped for the position check."""
    name               = node["name"]
    ntype              = node["type"]
    instance_basename  = node["instance_basename"]

    # Structural name pattern (Wall, Exit, Door, Floor, Room …)
    if _is_structural_name(name):
        return True

    # Purely visual/structural node types
    if ntype in EXEMPT_TYPES:
        return True

    # Group containers: type=Node2D without an instance= attribute
    if ntype == "Node2D" and instance_basename is None:
        return True

    # Wall-embedded prefabs
    if instance_basename in EXEMPT_INSTANCE_BASENAMES:
        return True

    return False


# ---------------------------------------------------------------------------
# Main check
# ---------------------------------------------------------------------------

def _is_on_grid(coord):
    """True if the coordinate is an exact multiple of GRID_SIZE."""
    # int(round()) handles floating-point imprecision (e.g. 239.9999…) and
    # works correctly for negative coordinates where Python's % would otherwise
    # return a positive remainder (e.g. round(-16) % 16 == 0, but
    # round(-1) % 16 == 15 not -1).
    return int(round(coord)) % GRID_SIZE == 0


def check_alignment():
    """Return a list of issue strings; empty list means all OK."""
    issues = []

    room_files = sorted(
        f for f in os.listdir(SCENES_DIR) if ROOM_FILENAME_RE.match(f)
    )

    for filename in room_files:
        path  = os.path.join(SCENES_DIR, filename)
        scene = _parse_tscn(path)
        sub_resources = scene["sub_resources"]
        nodes         = scene["nodes"]

        # Build a name→node lookup so we can walk the ancestry chain.
        node_by_name = {n["name"]: n for n in nodes}

        def _any_ancestor_structural(node):
            """
            Walk the full parent chain and return True if any ancestor has a
            structural name (Wall, Exit, Door, …).

            The .tscn ``parent`` attribute is either ``"."`` (direct child of
            the root) or a slash-separated path such as
            ``"Doors/Door_east_door"``.  We resolve each path component
            against ``node_by_name`` and recurse until we reach ``"."`` or
            exhaust the chain.
            """
            parent_path = node["parent"]
            if parent_path == ".":
                return False
            # Each component of the path is a node name.
            for part in parent_path.split("/"):
                if _is_structural_name(part):
                    return True
                # Recurse into the actual parent node (if found).
                parent_node = node_by_name.get(part)
                if parent_node and parent_node["name"] != node["name"]:
                    if _any_ancestor_structural(parent_node):
                        return True
            return False

        # ---- 1. Position alignment check ------------------------------------
        for node in nodes:
            pos = node["position"]
            if pos is None:
                continue
            if _is_exempt_for_position(node):
                continue
            if _any_ancestor_structural(node):
                continue

            x, y = pos
            bad_x = not _is_on_grid(x)
            bad_y = not _is_on_grid(y)
            if bad_x or bad_y:
                axes = []
                if bad_x:
                    axes.append("x={} (not a multiple of {})".format(x, GRID_SIZE))
                if bad_y:
                    axes.append("y={} (not a multiple of {})".format(y, GRID_SIZE))
                issues.append(
                    "[MISALIGNED POSITION] {}: node \"{}\" at ({}, {}) — {}".format(
                        filename, node["name"], x, y, ", ".join(axes))
                )

        # ---- 2. Shape-size alignment check ----------------------------------
        # Find all CollisionShape2D nodes whose parent is a non-structural
        # StaticBody2D (obstacle).
        for node in nodes:
            if node["type"] != "CollisionShape2D":
                continue
            if node["shape_ref"] is None:
                continue

            parent_name = node["parent"]
            # parent may be a path; take the last component
            if "/" in parent_name:
                parent_name = parent_name.split("/")[-1]

            parent_node = node_by_name.get(parent_name)
            if parent_node is None:
                continue

            # Only check shapes on StaticBody2D nodes
            if parent_node.get("type") != "StaticBody2D":
                continue
            # Skip structural parents (walls, doors)
            if _is_structural_name(parent_node["name"]):
                continue
            if _any_ancestor_structural(parent_node):
                continue

            sr = sub_resources.get(node["shape_ref"])
            if sr is None or sr["type"] != "RectangleShape2D":
                continue
            size = sr["size"]
            if size is None:
                continue

            w, h = size
            # Exempt wall/room-spanning shapes
            if w in ROOM_DIMENSIONS or h in ROOM_DIMENSIONS:
                continue

            bad_w = not _is_on_grid(w)
            bad_h = not _is_on_grid(h)
            if bad_w or bad_h:
                dims = []
                if bad_w:
                    dims.append("width={} (not a multiple of {})".format(w, GRID_SIZE))
                if bad_h:
                    dims.append("height={} (not a multiple of {})".format(h, GRID_SIZE))
                issues.append(
                    "[MISALIGNED SHAPE] {}: node \"{}\" CollisionShape2D size "
                    "({}, {}) — {}".format(
                        filename, parent_node["name"], w, h, ", ".join(dims))
                )

    return issues


def main():
    issues = check_alignment()
    if not issues:
        print("All room gameplay nodes are correctly grid-aligned.")
        sys.exit(0)
    else:
        print("Found {} alignment issue(s):\n".format(len(issues)))
        for i, issue in enumerate(issues, 1):
            print("  {}. {}".format(i, issue))
        sys.exit(1)


if __name__ == "__main__":
    main()
