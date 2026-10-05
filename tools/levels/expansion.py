"""Author expansion geometry and ordinary input routes together."""

from tools.levels.layout import Layout


class WorkLayout(Layout):
    def __init__(self, width, height=20):
        super().__init__(width, height)
        self.route_column = 3
        self.start(self.route_column)

    def go(self, column):
        direction = "move_right" if column >= self.route_column else "move_left"
        self.route.append({
            "hold": [direction], "until_x": self.cx(column),
            "max_seconds": 12,
        })
        self.stop()
        self.route_column = column

    def action(self, action="repair", seconds=None):
        self.route.append({"wait": 0.1})
        self.route.append(
            {"tap": action} if seconds is None
            else {"hold": [action], "seconds": seconds}
        )
        self.route.append({"wait": 0.1})

    def climb(self, column, row, up):
        self.go(column)
        self.route.append({
            "hold": ["move_up" if up else "move_down"],
            "until_y": (row + 1) * 32 - (20 if up else 1),
            "max_seconds": 8,
        })
        if up:
            self.route.append({"hold": ["move_up", "move_right"], "seconds": 0.45})
            self.route_column = column + 2
        self.stop()

    def ladder_cells(self, column, top):
        for row in range(top, self.stand + 1):
            self.put(column, row, "|")


def cooling_gallery():
    layout = WorkLayout(60)
    upper = 11
    lower = layout.stand
    layout.platform(upper + 1, 8, 46)
    layout.ladder_cells(10, upper)
    layout.ladder_cells(44, upper)
    layout.checkpoint(5)
    layout.put(33, upper, "C")
    layout.checkpoint(45)
    layout.put(30, upper, "v")
    for column in range(22, 31):
        layout.put(column, lower, "~")
    tasks = [
        {
            "id": "cooling", "type": "restore_cooling", "required": True,
            "label": "Restore gallery cooling",
            "sites": [[18, upper], [24, upper]],
            "resources": [{"kind": "filter", "cell": [6, lower]}],
            "effect_cells": [[30, upper]],
        },
        {
            "id": "leak", "type": "contain_leak", "required": True,
            "label": "Drain the lower gallery",
            "sites": [[38, upper], [42, upper]],
            "resources": [{"kind": "seal", "cell": [34, upper]}],
            "effect_cells": [[column, lower] for column in range(22, 31)],
        },
        {
            "id": "cable", "type": "run_cable", "required": True,
            "label": "Connect the gallery return cable",
            "sites": [[48, lower], [42, lower], [14, lower]],
            "resources": [{"kind": "spool", "cell": [50, lower]}],
        },
    ]
    layout.go(6)
    layout.action()
    layout.climb(10, upper, True)
    layout.go(18)
    layout.action("diagnose")
    layout.go(24)
    layout.action()
    layout.go(18)
    layout.action()
    layout.action(seconds=1.7)
    layout.go(34)
    layout.action()
    layout.go(38)
    layout.action()
    layout.action()
    layout.go(42)
    layout.action(seconds=3.2)
    layout.climb(44, lower, False)
    layout.go(50)
    layout.action()
    for column in [48, 42, 14]:
        layout.go(column)
        layout.action()
    layout.exit(56)
    header = {
        "name": "Cooling Gallery", "background": "cooling-gallery",
        "music": "level1", "par_seconds": 210, "sla_seconds": 420,
        "tasks": tasks,
    }
    return layout, header


def main():
    layout, header = cooling_gallery()
    layout.write("06-cooling-gallery", header)


if __name__ == "__main__":
    main()
