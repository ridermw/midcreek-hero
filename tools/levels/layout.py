"""Build a level grid and its scripted route together.

Each helper places level symbols and appends the route steps that get the
technician through them. tests/route_test.gd is the authority: a layout is
only valid when its route finishes without a restart.
"""

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TILE = 32


class Layout:
    def __init__(self, width, height=14):
        self.width = width
        self.height = height
        self.stand = height - 2
        self.grid = [["." for _ in range(width)] for _ in range(height)]
        self.route = []
        for x in range(width):
            self.put(x, height - 1, "#")

    def put(self, x, y, symbol):
        self.grid[y][x] = symbol

    @staticmethod
    def cx(col):
        return col * TILE + TILE // 2

    def run_to(self, x):
        self.route.append({"hold": ["move_right"], "until_x": x, "max_seconds": 8})

    def run_left_to(self, x):
        self.route.append({"hold": ["move_left"], "until_x": x, "max_seconds": 8})

    def jump(self):
        self.route.append({"hold": ["move_right", "jump"], "seconds": 0.45})

    def stop(self):
        self.route.append({"wait": 0.35})

    def start(self, col=1):
        self.put(col, self.stand, "P")

    def checkpoint(self, col):
        self.put(col, self.stand, "C")

    def exit(self, col):
        self.put(col, self.stand, "E")
        self.run_to(self.cx(col))

    def snag(self, col):
        self.put(col, self.stand, "s")
        self.run_to(self.cx(col) - 62)
        self.jump()

    def vent(self, col, row=None):
        self.put(col, self.stand if row is None else row, "v")
        self.run_to(self.cx(col) - 58)
        self.jump()

    def arc(self, col, row=None):
        self.put(col, self.stand if row is None else row, "k")
        self.run_to(self.cx(col) - 70)
        self.jump()

    def mover(self, col, jump_col):
        self.put(col, self.stand, "m")
        self.run_to(self.cx(jump_col))
        self.jump()

    def drone(self, col):
        self.put(col, self.stand, "d")
        self.run_to((col - 7) * TILE)
        self.route.append({"hold": ["move_right", "slide"], "until_x": (col + 7) * TILE, "max_seconds": 8})

    def coolant(self, col, row=None):
        self.put(col, self.stand if row is None else row, "h")

    def pit(self, first, last):
        for x in range(first, last + 1):
            self.put(x, self.height - 1, ".")
        self.run_to(first * TILE - 28)
        self.jump()

    def platform(self, row, first, last):
        for x in range(first, last + 1):
            self.put(x, row, "=")

    def climb_to(self, col):
        self.run_to(col * TILE - 104)
        self.jump()

    def tray(self, first, last):
        for x in range(first, last + 1):
            self.put(x, self.stand - 1, "T")
        self.run_to(first * TILE - 30)
        self.route.append({"hold": ["move_right", "slide"], "seconds": 0.1})
        self.run_to((last + 1) * TILE + 30)

    def rack(self, col, row, letter, mode="repair"):
        self.put(col, row, letter)
        self.run_to(self.cx(col) - 16)
        self.stop()
        if mode == "diagnose":
            self.route.append({"tap": "diagnose"})
            self.route.append({"wait": 0.9})
        self.route.append({"hold": ["repair"], "seconds": 0.6 if mode == "deliver" else 2.15})

    def part(self, col, row, letter):
        self.put(col, row, letter)

    def port(self, col, letter, sequence, row=None):
        self.put(col, self.stand if row is None else row, letter)
        self.run_to(self.cx(col) - 16)
        self.stop()
        self.route.append({"tap": "repair"})
        self.route.append({"wait": 0.15})
        for button in sequence:
            self.route.append({"tap": button})
            self.route.append({"wait": 0.15})
        self.route.append({"wait": 0.2})

    def switch(self, col, letter, left=False):
        self.put(col, self.stand, letter)
        if left:
            self.run_left_to(self.cx(col) + 8)
        else:
            self.run_to(self.cx(col) - 8)
        self.stop()
        self.route.append({"tap": "repair"})
        self.route.append({"wait": 0.2})

    def lift_up(self, col, first, last):
        self.put(col, self.stand, "l")
        for x in range(first, last + 1):
            for row in range(self.stand - 2, self.stand + 1):
                self.put(x, row, "#")
        self.run_to(self.cx(col) - 6)
        self.route.append({"wait": 0.2})
        self.route.append({"hold": ["move_up"], "until_y": (self.stand + 1) * TILE - 96 + 2, "max_seconds": 8})
        self.run_to(first * TILE + 24)

    def ladder(self, col, top_row, first, last):
        for row in range(top_row, self.stand + 1):
            self.put(col, row, "|")
        self.platform(top_row + 1, first, last)
        self.run_to(self.cx(col) - 4)
        self.route.append({"wait": 0.3})
        self.route.append({"hold": ["move_up"], "until_y": (top_row + 1) * TILE - 20, "max_seconds": 8})
        self.route.append({"hold": ["move_up", "move_right"], "seconds": 0.45})
        self.route.append({"wait": 0.3})

    def render(self, header):
        level = json.dumps(header, indent=2) + "\n---\n" + "\n".join("".join(r) for r in self.grid) + "\n"
        steps = ",\n".join("  " + json.dumps(step) for step in self.route)
        return level, "[\n" + steps + "\n]\n"

    def write(self, slug, header, root=ROOT):
        level, route = self.render(header)
        (root / "levels" / f"{slug}.level").write_text(level)
        (root / "levels" / "routes" / f"{slug}.route.json").write_text(route)


def par_and_sla(route_seconds, sla_factor=1.6):
    """The plan's balance rule: par is the route time plus 25 percent, rounded up to 5 s."""
    par = -(-route_seconds * 1.25 // 5) * 5
    sla = -(-par * sla_factor // 5) * 5
    return int(par), int(sla)
