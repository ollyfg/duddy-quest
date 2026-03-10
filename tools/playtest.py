#!/usr/bin/env python3
"""
Duddy Quest playtest client.

Communicates with the DevTools autoload running inside Godot via a simple
file-based IPC protocol:

  Command file : /tmp/duddy_quest_cmd.json   (client writes, game reads)
  Result file  : /tmp/duddy_quest_result.json (game writes, client reads)

Usage (CLI)
-----------
    python3 tools/playtest.py wait [seconds]
    python3 tools/playtest.py screenshot [output.png]
    python3 tools/playtest.py input <action> [duration_seconds]
    python3 tools/playtest.py release <action>
    python3 tools/playtest.py state
    python3 tools/playtest.py spawn [--room ROOM] [--x X] [--y Y]
    python3 tools/playtest.py mobile-viewport [on|off]

Available actions:
    move_up  move_down  move_left  move_right
    melee_attack  ranged_attack  interact

IMPORTANT – always release inputs before pressing them again
------------------------------------------------------------
``input <action>`` without a duration leaves the action held until an
explicit ``release <action>`` is sent.  Godot's ``is_action_just_pressed()``
only fires on the *first* frame the action becomes pressed; it will NOT fire
again while the action is still held.

Correct pattern for repeated presses (e.g. advancing dialog lines):

    send_input("melee_attack")          # press  → advances line 1
    send_input("melee_attack", pressed=False)  # release
    send_input("melee_attack")          # press  → advances line 2
    send_input("melee_attack", pressed=False)  # release

When using the CLI, use ``release`` between consecutive ``input`` calls:

    python3 tools/playtest.py input   melee_attack
    python3 tools/playtest.py release melee_attack
    python3 tools/playtest.py input   melee_attack
    python3 tools/playtest.py release melee_attack

Using ``input <action> <duration>`` auto-releases after the timer, but you
must still sleep for at least the duration before sending the next command.

Usage (library)
---------------
    import sys
    sys.path.insert(0, "/path/to/duddy-quest")
    from tools.playtest import PlaytestClient

    client = PlaytestClient()
    client.wait_for_devtools()          # wait until game is ready
    client.send_input("move_right", duration=1.5)
    client.screenshot("/tmp/after_move.png")
    state = client.state()
    print(state)
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import time
from datetime import datetime
from pathlib import Path
from typing import Any

CMD_FILE = Path("/tmp/duddy_quest_cmd.json")
RESULT_FILE = Path("/tmp/duddy_quest_result.json")
DEFAULT_TIMEOUT = 5.0   # seconds to wait for a result


class PlaytestClient:
    """Client for the Duddy Quest DevTools IPC interface."""

    def __init__(
        self,
        cmd_file: Path = CMD_FILE,
        result_file: Path = RESULT_FILE,
        default_timeout: float = DEFAULT_TIMEOUT,
    ) -> None:
        self.cmd_file = cmd_file
        self.result_file = result_file
        self.default_timeout = default_timeout

    # ------------------------------------------------------------------
    # Low-level IPC helpers
    # ------------------------------------------------------------------

    def _send(self, command: dict[str, Any], timeout: float | None = None) -> dict[str, Any]:
        """Write *command* to the command file and wait for the result.

        Raises TimeoutError if the game does not respond within *timeout*
        seconds.  Raises RuntimeError if the result contains an error field.
        """
        if timeout is None:
            timeout = self.default_timeout

        # Remove a stale result file so we don't accidentally pick it up.
        self.result_file.unlink(missing_ok=True)

        self.cmd_file.write_text(json.dumps(command))

        # Poll for the result file.
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            if self.result_file.exists():
                try:
                    result = json.loads(self.result_file.read_text())
                    self.result_file.unlink(missing_ok=True)
                    if "error" in result:
                        raise RuntimeError("DevTools error: %s" % result["error"])
                    return result
                except json.JSONDecodeError:
                    pass  # file may still be partially written
            time.sleep(0.05)

        raise TimeoutError(
            "No response from DevTools within %.1f s. "
            "Is the game running with -- --dev-tools?" % timeout
        )

    # ------------------------------------------------------------------
    # Public API
    # ------------------------------------------------------------------

    def wait_for_devtools(self, timeout: float = 30.0, poll: float = 0.5) -> None:
        """Block until DevTools responds or *timeout* seconds elapse.

        Useful right after calling ``tools/launch.sh`` to wait for the game to
        finish starting before sending commands.
        """
        deadline = time.monotonic() + timeout
        last_err: Exception = TimeoutError("timed out")
        while time.monotonic() < deadline:
            try:
                self._send({"type": "state"}, timeout=2.0)
                return
            except (TimeoutError, RuntimeError) as exc:
                last_err = exc
                time.sleep(poll)
        raise TimeoutError(
            "DevTools did not become ready within %.0f s: %s" % (timeout, last_err)
        )

    def screenshot(self, output: str | Path | None = None) -> Path:
        """Take a screenshot of the game viewport and save it as a PNG.

        If *output* is omitted a timestamped file is created in ``/tmp``.
        Returns the path to the saved PNG.
        """
        if output is None:
            output = Path("/tmp/duddy_screenshot_%s.png" % datetime.now().strftime("%Y%m%d_%H%M%S"))
        output = Path(output)
        result = self._send({"type": "screenshot", "path": str(output)})
        saved = Path(result["path"])
        if not saved.exists():
            raise FileNotFoundError("Screenshot file not found at %s" % saved)
        return saved

    def send_input(
        self,
        action: str,
        pressed: bool = True,
        duration: float = 0.0,
    ) -> dict[str, Any]:
        """Inject an input action into the game.

        Args:
            action:   One of the input action names defined in project.godot
                      (move_up, move_down, move_left, move_right,
                       melee_attack, ranged_attack, interact).
            pressed:  True to press, False to release.
            duration: If > 0 and pressed=True, the action is held for this
                      many seconds and then auto-released by the game.
        """
        return self._send(
            {"type": "input", "action": action, "pressed": pressed, "duration": duration}
        )

    def release(self, action: str) -> dict[str, Any]:
        """Release a held input action."""
        return self.send_input(action, pressed=False)

    def spawn(
        self,
        room: str | None = None,
        x: float | None = None,
        y: float | None = None,
    ) -> dict[str, Any]:
        """Teleport the player to a specific room and/or position.

        Args:
            room: Name of the room to load (e.g. "l1_hallway", "l1_street").
                  Must be a room in the current level.  Omit to stay in the
                  current room.
            x:    Target X position.  When *room* is given, *x* and *y* must
                  both be provided to take effect; if either is omitted the
                  player is placed at the centre of the viewport (320, 240).
                  When no room is given, *x* and *y* must both be provided.
            y:    Target Y position.  Same rules as *x*.

        At least one of *room*, or both *x* and *y*, must be provided.
        Returns the result dict including the final ``room``, ``x``, and ``y``.
        """
        cmd: dict[str, Any] = {"type": "spawn"}
        if room is not None:
            cmd["room"] = room
        if x is not None:
            cmd["x"] = x
        if y is not None:
            cmd["y"] = y
        return self._send(cmd)

    def state(self) -> dict[str, Any]:
        """Return the current game state.

        Returns a dict like::

            {
                "player": {"x": 100.0, "y": 240.0, "hp": 5},
                "room": "l1_bedroom"
            }
        """
        return self._send({"type": "state"})

    def set_mobile_viewport(self, enabled: bool = True) -> dict[str, Any]:
        """Enable or disable mobile viewport simulation.

        When enabled the game window is resized to 640×770, on-screen touch
        controls are shown, and the camera is shifted so the visible game area
        above the controls remains centred on the player.

        When disabled the window shrinks back to 640×480 and the camera offset
        is removed.
        """
        return self._send({"type": "set_mobile_viewport", "enabled": enabled})


# ----------------------------------------------------------------------
# CLI entry-point
# ----------------------------------------------------------------------

def _build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Duddy Quest DevTools client",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    parser.add_argument(
        "--timeout",
        type=float,
        default=DEFAULT_TIMEOUT,
        help="Seconds to wait for a game response (default: %(default)s)",
    )

    sub = parser.add_subparsers(dest="command", metavar="command")

    # wait
    wait_p = sub.add_parser("wait", help="Wait for DevTools to become ready")
    wait_p.add_argument(
        "seconds",
        type=float,
        nargs="?",
        default=30.0,
        help="Maximum wait time in seconds (default: 30)",
    )

    # screenshot
    ss_p = sub.add_parser("screenshot", help="Take a screenshot of the game viewport")
    ss_p.add_argument(
        "output",
        nargs="?",
        default=None,
        help="Output PNG file path (default: /tmp/duddy_screenshot_<timestamp>.png)",
    )

    # input
    inp_p = sub.add_parser("input", help="Inject an input action")
    inp_p.add_argument("action", help="Action name (e.g. move_right)")
    inp_p.add_argument(
        "duration",
        type=float,
        nargs="?",
        default=0.0,
        help="Hold duration in seconds; 0 = single frame press (default: 0)",
    )

    # release
    rel_p = sub.add_parser("release", help="Release a held input action")
    rel_p.add_argument("action", help="Action name to release")

    # state
    sub.add_parser("state", help="Print current game state as JSON")

    # spawn
    spawn_p = sub.add_parser(
        "spawn",
        help="Teleport the player to a room and/or position",
    )
    spawn_p.add_argument("--room", default=None, help="Room name to load (e.g. l1_hallway)")
    spawn_p.add_argument("--x", type=float, default=None, help="Target X position")
    spawn_p.add_argument("--y", type=float, default=None, help="Target Y position")

    # mobile-viewport
    mv_p = sub.add_parser(
        "mobile-viewport",
        help="Enable or disable mobile viewport simulation",
    )
    mv_p.add_argument(
        "enabled",
        nargs="?",
        default="on",
        choices=["on", "off"],
        help="'on' to enable mobile viewport (default), 'off' to disable",
    )

    return parser


def main(argv: list[str] | None = None) -> None:
    parser = _build_parser()
    args = parser.parse_args(argv)

    if args.command is None:
        parser.print_help()
        sys.exit(1)

    client = PlaytestClient(default_timeout=args.timeout)

    if args.command == "wait":
        print("Waiting for DevTools (up to %.0f s)…" % args.seconds)
        client.wait_for_devtools(timeout=args.seconds)
        print("DevTools is ready.")

    elif args.command == "screenshot":
        path = client.screenshot(args.output)
        print("Screenshot saved: %s" % path)

    elif args.command == "input":
        result = client.send_input(args.action, duration=args.duration)
        print(json.dumps(result, indent=2))

    elif args.command == "release":
        result = client.release(args.action)
        print(json.dumps(result, indent=2))

    elif args.command == "state":
        result = client.state()
        print(json.dumps(result, indent=2))

    elif args.command == "spawn":
        result = client.spawn(room=args.room, x=args.x, y=args.y)
        print(json.dumps(result, indent=2))

    elif args.command == "mobile-viewport":
        enabled = args.enabled == "on"
        result = client.set_mobile_viewport(enabled=enabled)
        print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
