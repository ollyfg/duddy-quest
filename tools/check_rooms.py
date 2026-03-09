#!/usr/bin/env python3
"""
check_rooms.py – Validate that room exits and level connections are consistent.

Level metadata is loaded from data/*.json (one file per level).

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
  8. Exit-overlap safety: for A→dir→B, the source room's exit area must not be
     so close to the destination room's exit in the SAME direction that a player
     standing in A's exit zone would overlap B's exit zone when B is loaded.
     This is the class of bug that caused the "Petunia skip" where going east from
     l1_upper_hall (after being sent back west) skipped l1_hallway entirely.
"""

import json
import os
import re
import sys

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
SCENES_DIR = os.path.join(os.path.dirname(__file__), "..", "scenes")
DATA_DIR   = os.path.join(os.path.dirname(__file__), "..", "data")

ROOM_WIDTH  = 640
ROOM_HEIGHT = 480
WALL_THICK  = 24
X_MARGIN    = 10   # extra px of slack when checking entry x bounds
Y_TOLERANCE = 4    # px tolerance when comparing door y-coordinates

# Half-size of the exit Area2D shape (shape is 12×48 px for east/west exits).
EXIT_HALF_SIZE = 6
# Half-size of the player body (player CollisionShape2D is 16×16 px).
PLAYER_HALF_SIZE = 8
# A player anywhere inside the source exit zone has a center in the range
# [exit_center - EXIT_HALF_SIZE, exit_center + EXIT_HALF_SIZE].  Expanding by
# PLAYER_HALF_SIZE gives the full range of player positions that can trigger it.
# If that range overlaps the same-direction exit in the destination room, a
# deferred body_entered will fire the moment the new room is loaded.
EXIT_OVERLAP_THRESHOLD = EXIT_HALF_SIZE + PLAYER_HALF_SIZE  # = 14 px

# How many characters to scan after an Exit node declaration when looking for
# a position = Vector2(...) property line.
NODE_PROPERTY_SEARCH_WINDOW = 300

REVERSE = {"east": "west", "west": "east", "north": "south", "south": "north"}

# ---------------------------------------------------------------------------
# Parsing helpers
# ---------------------------------------------------------------------------

def parse_room_connections(data_dir):
    """
    Load room connections from all data/*.json level files.
    Returns all connections merged across levels as:
      {room_name: {direction: {"room": str, "entry": (x, y)}}}
    """
    if not os.path.isdir(data_dir):
        raise ValueError(
            "data/ directory not found at: {}".format(data_dir)
        )

    connections = {}
    for fname in sorted(os.listdir(data_dir)):
        if not fname.endswith(".json"):
            continue
        fpath = os.path.join(data_dir, fname)
        try:
            with open(fpath) as f:
                data = json.load(f)
        except (json.JSONDecodeError, OSError) as exc:
            raise ValueError("Failed to parse level file {}: {}".format(fpath, exc)) from exc
        for room_name, dirs in data.get("connections", {}).items():
            connections[room_name] = {}
            for direction, info in dirs.items():
                connections[room_name][direction] = {
                    "room":  info["room"],
                    "entry": (float(info["entry"][0]), float(info["entry"][1])),
                }
    return connections


def parse_room_size(tscn_path):
    """Parse the room_size export from the Room node in a .tscn file."""
    try:
        with open(tscn_path) as f:
            content = f.read()
        m = re.search(r'\broom_size\s*=\s*Vector2\(\s*([\d.]+)\s*,\s*([\d.]+)\s*\)', content)
        if m:
            return float(m.group(1)), float(m.group(2))
    except OSError:
        pass
    return float(ROOM_WIDTH), float(ROOM_HEIGHT)


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

    connections = parse_room_connections(DATA_DIR)

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
    # Match level room scenes (l<digit>_*).
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
            dest_tscn = os.path.join(SCENES_DIR, "{}.tscn".format(dest_room))
            dest_w, dest_h = parse_room_size(dest_tscn)
            x_min = WALL_THICK - X_MARGIN
            x_max = dest_w - WALL_THICK + X_MARGIN
            y_min = WALL_THICK - X_MARGIN
            y_max = dest_h - WALL_THICK + X_MARGIN
            if not (x_min <= entry_x <= x_max and y_min <= entry_y <= y_max):
                issues.append(
                    "[OUT-OF-BOUNDS ENTRY] {} -> {}: entry ({}, {}) is outside "
                    "expected bounds [{}-{}, {}-{}].".format(
                        room_name, direction, entry_x, entry_y,
                        x_min, x_max, y_min, y_max)
                )

            # 4. Reverse exit coordinate matches entry (Y for east/west, X for north/south).
            # For east/west connections both rooms' doors should be at the same Y so
            # the opening lines up visually.  For north/south connections the doors
            # must share the same X instead.
            rev_dir = REVERSE.get(direction)
            if rev_dir:
                dest_exits = room_exits.get(dest_room, {})
                if rev_dir in dest_exits:
                    rev_pos = dest_exits[rev_dir]
                    if rev_pos is not None:
                        if direction in ("east", "west"):
                            # Check Y alignment
                            if abs(rev_pos[1] - entry_y) > Y_TOLERANCE:
                                issues.append(
                                    "[Y MISMATCH] {} -> {} -> {}: "
                                    "entry y={} but {}'s {} exit is at y={}. "
                                    "Doors won't line up visually.".format(
                                        room_name, direction, dest_room,
                                        entry_y, dest_room, rev_dir, rev_pos[1])
                                )
                        else:
                            # north/south: check X alignment
                            if abs(rev_pos[0] - entry_x) > Y_TOLERANCE:
                                issues.append(
                                    "[X MISMATCH] {} -> {} -> {}: "
                                    "entry x={} but {}'s {} exit is at x={}. "
                                    "Doors won't line up visually.".format(
                                        room_name, direction, dest_room,
                                        entry_x, dest_room, rev_dir, rev_pos[0])
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

            # 8. Exit-overlap safety: the entry position placed in the destination
            # room must not land inside any exit Area2D of that room.  If it
            # did, the player would immediately re-trigger an exit on the very
            # first frame, causing a spurious room transition.
            #
            # For east/west exits the relevant coordinate is X; the exit Area2D
            # shape is 12 px wide (half-size 6 px) and the player body is 16 px
            # wide (half-size 8 px).  An overlap exists when the distance from
            # the entry position to an exit centre is less than the sum of their
            # half-sizes (6 + 8 = 14 px).
            dest_exits = room_exits.get(dest_room, {})
            for exit_dir, dest_exit_pos in dest_exits.items():
                if dest_exit_pos is None:
                    continue
                if exit_dir in ("east", "west"):
                    entry_coord = entry_x
                    exit_coord  = dest_exit_pos[0]
                else:  # north / south
                    entry_coord = entry_y
                    exit_coord  = dest_exit_pos[1]
                separation = abs(entry_coord - exit_coord)
                min_safe   = EXIT_HALF_SIZE + PLAYER_HALF_SIZE  # 14 px
                if separation < min_safe:
                    issues.append(
                        "[ENTRY INSIDE EXIT] {} -> {} -> {}: "
                        "entry position ({}, {}) is only {:.0f} px from "
                        "Exit{} in {} at {:.0f}. "
                        "Player would immediately re-trigger that exit on spawn.".format(
                            room_name, direction, dest_room,
                            entry_x, entry_y, separation,
                            exit_dir.capitalize(), dest_room, exit_coord)
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
