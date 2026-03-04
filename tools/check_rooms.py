#!/usr/bin/env python3
"""
check_rooms.py – Validate that room exits and ROOM_CONNECTIONS in main.gd are
consistent with one another.

Run from the project root:
    python3 tools/check_rooms.py

What it checks:
  1. Every room listed in ROOM_CONNECTIONS has a matching .tscn file under scenes/.
  2. For each direction in ROOM_CONNECTIONS[room], the source room .tscn contains
     an Exit<Direction> Area2D node.
  3. The destination room is also listed in ROOM_CONNECTIONS (or is a terminal).
  4. The entry y-coordinate matches the exit trigger y-coordinate in the destination
     room's reverse-direction exit (doors should visually line up).
  5. The entry position is within the room's playable area (roughly 24-616 x,
     24-456 y for a 640x480 room with 24-px walls).
  6. For each exit found in a .tscn, a matching ROOM_CONNECTIONS entry exists.
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


def parse_room_connections(path):
    """
    Extract ROOM_CONNECTIONS from main.gd.
    Returns {room_name: {direction: {"room": str, "entry": (x, y)}}}
    """
    with open(path) as f:
        src = f.read()

    connections = {}

    block_start = src.find('const ROOM_CONNECTIONS')
    if block_start == -1:
        raise ValueError("Could not find ROOM_CONNECTIONS in main.gd")

    outer_block = _extract_balanced(src, block_start)

    room_key_re = re.compile(r'"(room_\w+)"\s*:')
    dir_re = re.compile(
        r'"(east|west|north|south)"\s*:\s*\{[^}]*"room"\s*:\s*"(\w+)"[^}]*'
        r'"entry"\s*:\s*Vector2\(\s*([\d.]+)\s*,\s*([\d.]+)\s*\)',
        re.DOTALL,
    )

    pos = 0
    while True:
        m = room_key_re.search(outer_block, pos)
        if not m:
            break
        room_name = m.group(1)
        inner = _extract_balanced(outer_block, m.end())
        connections[room_name] = {}
        for dm in dir_re.finditer(inner):
            direction, dest_room, ex, ey = dm.groups()
            connections[room_name][direction] = {
                "room":  dest_room,
                "entry": (float(ex), float(ey)),
            }
        pos = m.end()

    return connections


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
        segment   = content[m.end():m.end() + 300]
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

    # Pre-load exit info for every room listed in ROOM_CONNECTIONS
    room_exits = {}
    for room_name in connections:
        tscn = os.path.join(SCENES_DIR, "{}.tscn".format(room_name))
        if not os.path.isfile(tscn):
            issues.append("[MISSING SCENE] {}.tscn not found in scenes/".format(room_name))
            room_exits[room_name] = {}
            continue
        room_exits[room_name] = find_exit_nodes(tscn)

    # Also scan all room .tscn files to catch exits not listed in ROOM_CONNECTIONS
    all_tscns = sorted(
        f for f in os.listdir(SCENES_DIR)
        if f.startswith("room_") and f.endswith(".tscn")
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
                    "but no matching entry in ROOM_CONNECTIONS[\"{}\"]".format(
                        room_name, direction.capitalize(), room_name)
                )

    # Check every ROOM_CONNECTIONS entry
    for room_name, dirs in connections.items():
        tscn_exits = room_exits.get(room_name, {})

        for direction, info in dirs.items():
            dest_room        = info["room"]
            entry_x, entry_y = info["entry"]

            # 1. Source room has the exit node
            if direction not in tscn_exits:
                issues.append(
                    "[MISSING EXIT NODE] {}.tscn has no Exit{} "
                    "but ROOM_CONNECTIONS expects one.".format(
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
