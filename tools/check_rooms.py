#!/usr/bin/env python3
"""
check_rooms.py – Validate that room exits and level connections in main.gd are
consistent with one another.

Run from the project root:
    python3 tools/check_rooms.py

What it checks:
  1. Every room listed in connections has a matching .tscn file under scenes/.
  2. For each direction in connections[room], the source room .tscn contains
     an Exit<Direction> Area2D node.
  3. The destination room is also listed in connections (or is a terminal).
  4. The entry y-coordinate matches the exit trigger y-coordinate in the destination
     room's reverse-direction exit (doors should visually line up).
  5. The entry position is within the room's playable area (roughly 24-616 x,
     24-456 y for a 640x480 room with 24-px walls).
  6. For each exit found in a .tscn, a matching connections entry exists.
  7. Bidirectional symmetry: if A→east→B then B→west must lead back to A.
     Without this check a player going east then west can land in a different room.

Supports both the legacy flat ROOM_CONNECTIONS dict and the new LEVELS dict
introduced by the level-system refactor.
"""

import os
import re
import sys

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
SCENES_DIR = os.path.join(os.path.dirname(__file__), "..", "scenes")
MAIN_GD    = os.path.join(os.path.dirname(__file__), "..", "scripts", "main.gd")

ROOM_WIDTH  = 640
ROOM_HEIGHT = 480
WALL_THICK  = 24
X_MARGIN    = 10   # extra px of slack when checking entry x bounds
Y_TOLERANCE = 4    # px tolerance when comparing door y-coordinates

# How many characters to scan after an Exit node declaration when looking for
# a position = Vector2(...) property line.
NODE_PROPERTY_SEARCH_WINDOW = 300

REVERSE = {"east": "west", "west": "east", "north": "south", "south": "north"}

# ---------------------------------------------------------------------------
# Parsing helpers
# ---------------------------------------------------------------------------

def _extract_balanced(text, start):
    """Return the substring inside the braces opening at/after `start`."""
    i = text.index('{', start)
    depth = 0
    begin = i + 1
    while i < len(text):
        if text[i] == '{':
            depth += 1
        elif text[i] == '}':
            depth -= 1
            if depth == 0:
                return text[begin:i]
        i += 1
    raise ValueError("Unmatched brace")


def _parse_connections_block(block):
    """
    Parse a connections dict block (the inner part of a connections: {...}).
    Returns {room_name: {direction: {"room": str, "entry": (x, y)}}}
    """
    connections = {}

    # Match any key that contains an underscore – this covers both the
    # training rooms (room_a, room_b, …) and level rooms (l1_bedroom, …)
    # while excluding bare direction keys (east, west, north, south).
    room_key_re = re.compile(r'"(\w+_\w+)"\s*:')
    dir_re = re.compile(
        r'"(east|west|north|south)"\s*:\s*\{[^}]*"room"\s*:\s*"(\w+)"[^}]*'
        r'"entry"\s*:\s*Vector2\(\s*([\d.]+)\s*,\s*([\d.]+)\s*\)',
        re.DOTALL,
    )

    pos = 0
    while True:
        m = room_key_re.search(block, pos)
        if not m:
            break
        room_name = m.group(1)
        inner = _extract_balanced(block, m.end())
        connections[room_name] = {}
        for dm in dir_re.finditer(inner):
            direction, dest_room, ex, ey = dm.groups()
            connections[room_name][direction] = {
                "room":  dest_room,
                "entry": (float(ex), float(ey)),
            }
        pos = m.end()

    return connections


def parse_room_connections(path):
    """
    Extract room connections from main.gd.
    Supports both the legacy flat ROOM_CONNECTIONS dict and the new LEVELS
    dict.  All connections from all levels are merged and returned as:
      {room_name: {direction: {"room": str, "entry": (x, y)}}}
    """
    with open(path) as f:
        src = f.read()

    # ---- New LEVELS structure -----------------------------------------------
    levels_start = src.find('const LEVELS')
    if levels_start != -1:
        connections = {}
        outer_block = _extract_balanced(src, levels_start)

        # Each top-level entry is a level name; find every "connections": {...}
        # sub-block inside the outer LEVELS block.
        conn_key_re = re.compile(r'"connections"\s*:')
        for cm in conn_key_re.finditer(outer_block):
            conn_block = _extract_balanced(outer_block, cm.end())
            level_conns = _parse_connections_block(conn_block)
            # Merge; last write wins if the same room appears in multiple levels.
            connections.update(level_conns)
        return connections

    # ---- Legacy ROOM_CONNECTIONS structure ----------------------------------
    block_start = src.find('const ROOM_CONNECTIONS')
    if block_start == -1:
        raise ValueError(
            "Could not find LEVELS or ROOM_CONNECTIONS in main.gd"
        )

    outer_block = _extract_balanced(src, block_start)
    return _parse_connections_block(outer_block)


def find_exit_nodes(tscn_path):
    """
    Return {direction: (x, y)} for every Exit<Dir> Area2D node in the .tscn.
    """
    with open(tscn_path) as f:
        content = f.read()

    exits = {}
    node_re = re.compile(r'\[node name="Exit(East|West|North|South)"[^\]]*\]')
    pos_re  = re.compile(r'position\s*=\s*Vector2\(\s*([\d.]+)\s*,\s*([\d.]+)\s*\)')

    for m in node_re.finditer(content):
        direction = m.group(1).lower()
        segment   = content[m.end():m.end() + NODE_PROPERTY_SEARCH_WINDOW]
        pm = pos_re.search(segment)
        if pm:
            exits[direction] = (float(pm.group(1)), float(pm.group(2)))
        else:
            exits[direction] = None

    return exits


# ---------------------------------------------------------------------------
# Main check
# ---------------------------------------------------------------------------

def check_rooms():
    """Return a list of issue strings; empty means all OK."""
    issues = []

    connections = parse_room_connections(MAIN_GD)

    # Pre-load exit info for every room listed in connections
    room_exits = {}
    for room_name in connections:
        tscn = os.path.join(SCENES_DIR, "{}.tscn".format(room_name))
        if not os.path.isfile(tscn):
            issues.append("[MISSING SCENE] {}.tscn not found in scenes/".format(room_name))
            room_exits[room_name] = {}
            continue
        room_exits[room_name] = find_exit_nodes(tscn)

    # Scan all room .tscn files to catch exits not listed in connections.
    # Match training rooms (room_*) and level rooms (l<digit>_*).
    all_tscns = sorted(
        f for f in os.listdir(SCENES_DIR)
        if re.match(r'^(?:room_|l\d+_)', f) and f.endswith(".tscn")
    )
    for tscn_file in all_tscns:
        room_name = tscn_file[:-5]
        tscn_path = os.path.join(SCENES_DIR, tscn_file)
        exits = find_exit_nodes(tscn_path)
        if room_name not in room_exits:
            room_exits[room_name] = exits
        for direction in exits:
            if (room_name not in connections or
                    direction not in connections.get(room_name, {})):
                issues.append(
                    "[ORPHAN EXIT] {}.tscn has Exit{} "
                    "but no matching entry in the level connections for \"{}\".".format(
                        room_name, direction.capitalize(), room_name)
                )

    # Check every connections entry
    for room_name, dirs in connections.items():
        tscn_exits = room_exits.get(room_name, {})

        for direction, info in dirs.items():
            dest_room        = info["room"]
            entry_x, entry_y = info["entry"]

            # 1. Source room has the exit node
            if direction not in tscn_exits:
                issues.append(
                    "[MISSING EXIT NODE] {}.tscn has no Exit{} "
                    "but level connections expects one.".format(
                        room_name, direction.capitalize())
                )
                continue

            exit_pos = tscn_exits[direction]
            if exit_pos is None:
                issues.append(
                    "[NO POSITION] Exit{} in {}.tscn has no position property.".format(
                        direction.capitalize(), room_name)
                )

            # 2. Destination room exists
            if dest_room not in room_exits:
                issues.append(
                    "[UNKNOWN DEST] {} -> {} -> \"{}\" but that room "
                    "has no .tscn.".format(room_name, direction, dest_room)
                )
                continue

            # 3. Entry position is inside the playable area
            x_min = WALL_THICK - X_MARGIN
            x_max = ROOM_WIDTH  - WALL_THICK + X_MARGIN
            y_min = WALL_THICK - X_MARGIN
            y_max = ROOM_HEIGHT - WALL_THICK + X_MARGIN
            if not (x_min <= entry_x <= x_max and y_min <= entry_y <= y_max):
                issues.append(
                    "[OUT-OF-BOUNDS ENTRY] {} -> {}: entry ({}, {}) is outside "
                    "expected bounds [{}-{}, {}-{}].".format(
                        room_name, direction, entry_x, entry_y,
                        x_min, x_max, y_min, y_max)
                )

            # 4. Reverse exit y-coordinate matches entry y
            rev_dir = REVERSE.get(direction)
            if rev_dir:
                dest_exits = room_exits.get(dest_room, {})
                if rev_dir in dest_exits:
                    rev_pos = dest_exits[rev_dir]
                    if rev_pos is not None:
                        if abs(rev_pos[1] - entry_y) > Y_TOLERANCE:
                            issues.append(
                                "[Y MISMATCH] {} -> {} -> {}: "
                                "entry y={} but {}'s {} exit is at y={}. "
                                "Doors won't line up visually.".format(
                                    room_name, direction, dest_room,
                                    entry_y, dest_room, rev_dir, rev_pos[1])
                            )

                # 7. Bidirectional symmetry: B→reverse(dir) must lead back to A.
                dest_conns = connections.get(dest_room, {})
                if rev_dir not in dest_conns:
                    issues.append(
                        "[ASYMMETRIC] {} -> {} -> {}: "
                        "but {}.{} has no connection back.".format(
                            room_name, direction, dest_room,
                            dest_room, rev_dir)
                    )
                elif dest_conns[rev_dir]["room"] != room_name:
                    issues.append(
                        "[ASYMMETRIC] {} -> {} -> {}: "
                        "but {} -> {} -> {} (not back to {}).".format(
                            room_name, direction, dest_room,
                            dest_room, rev_dir, dest_conns[rev_dir]["room"],
                            room_name)
                    )

    return issues


def main():
    issues = check_rooms()
    if not issues:
        print("All room connections look consistent.")
        sys.exit(0)
    else:
        print("Found {} issue(s):\n".format(len(issues)))
        for i, issue in enumerate(issues, 1):
            print("  {}. {}".format(i, issue))
        sys.exit(1)


if __name__ == "__main__":
    main()
