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

    def mover(self, col, jump_col, jump_offset=0):
        # Pixel offsets depend on patrol phase; remeasure after any earlier route edit.
        self.put(col, self.stand, "m")
        self.run_to(self.cx(jump_col) + jump_offset)
        self.jump()

    def drone(self, col):
        self.put(col, self.stand, "d")
        self.run_to((col - 7) * TILE)
        # Release and press slide again every 0.45 s; the motor's slide buffer chains the slides.
        for _ in range(4):
            self.route.append({"hold": ["move_right", "slide"], "seconds": 0.43})
            self.route.append({"hold": ["move_right"], "seconds": 0.02})
        self.run_to((col + 7) * TILE)

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

    def trim(self, width):
        """Cut the grid to `width` columns after the last piece is placed."""
        self.width = width
        self.grid = [row[:width] for row in self.grid]

    def render(self, header):
        level = json.dumps(header, indent=2) + "\n---\n" + "\n".join("".join(r) for r in self.grid) + "\n"
        steps = ",\n".join("  " + json.dumps(step) for step in self.route)
        return level, "[\n" + steps + "\n]\n"

    def write(self, slug, header, root=ROOT):
        level, route = self.render(header)
        (root / "levels" / f"{slug}.level").write_text(level)
        (root / "levels" / "routes" / f"{slug}.route.json").write_text(route)


# Set pieces. Each starts on the floor at column `x` and returns the first free
# floor column after it, so pieces can be chained without overlapping.

def stairs(L, x, steps, rack=None, coolant=False):
    """Platforms rising 2 rows per step, 3 columns apart, with an optional rack on top."""
    row = L.stand - 1
    first = x
    for i in range(steps):
        L.platform(row, first, first + 3)
        L.climb_to(first)
        top_row, top_first = row, first
        row -= 2
        first += 6
    if coolant:
        L.coolant(top_first + 1, top_row - 1)
    if rack:
        L.rack(top_first + 2, top_row - 1, rack)
    L.run_to((top_first + 4) * TILE + 20)
    return top_first + 9


def catwalk(L, x, segments, gap=3, length=6):
    """A raised catwalk 2 rows up with open gaps to jump."""
    L.platform(L.stand - 1, x, x + 3)
    L.climb_to(x)
    first = x + 6
    for i in range(segments):
        L.platform(L.stand - 3, first, first + length - 1)
        if i == 0:
            L.climb_to(first)
        else:
            L.run_to(first * TILE - 28)
            L.jump()
        first += length + gap
    end = first - gap
    L.run_to(end * TILE + 20)
    return end + 5


def snag_run(L, x, count, spacing=8):
    for i in range(count):
        L.snag(x + 2 + i * spacing)
    return x + 2 + count * spacing


def pit_run(L, x, count, spacing=9):
    for i in range(count):
        start = x + 2 + i * spacing
        L.pit(start, start + 2)
    return x + 2 + count * spacing


def vent_run(L, x, count, spacing=7):
    for i in range(count):
        L.vent(x + 2 + i * spacing)
    return x + 2 + count * spacing


def arc_run(L, x, count, spacing=8):
    for i in range(count):
        L.arc(x + 3 + i * spacing)
    return x + 3 + count * spacing


def mover_run(L, x, count, spacing=12, lead=3, jump_offset=0):
    for i in range(count):
        col = x + 6 + i * spacing
        L.mover(col, col - lead, jump_offset)
    return x + 6 + count * spacing


def drone_run(L, x, count, spacing=16):
    for i in range(count):
        L.drone(x + 8 + i * spacing)
    return x + 8 + count * spacing


def ladder_tower(L, x, top_row, rack=None, length=6):
    L.ladder(x, top_row, x + 1, x + length)
    if rack:
        L.rack(x + length - 2, top_row, rack)
    L.run_to((x + length + 1) * TILE + 20)
    return x + length + 6


def lift_deck(L, x, length=14, rack=None, hazard=None, mode="repair"):
    L.lift_up(x, x + 2, x + 2 + length)
    deck_row = L.stand - 3
    if hazard == "arc":
        L.arc(x + 2 + length // 2, deck_row)
    elif hazard == "vent":
        L.vent(x + 2 + length // 2, deck_row)
    if rack:
        L.rack(x + length - 1, deck_row, rack, mode)
    L.run_to((x + 3 + length) * TILE + 20)
    return x + length + 8


def tray_run(L, x, count, length=5, spacing=11):
    for i in range(count):
        start = x + 3 + i * spacing
        L.tray(start, start + length - 1)
    return x + 3 + count * spacing
