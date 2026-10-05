"""Author expansion geometry and ordinary input routes together."""

from tools.levels.layout import Layout


class WorkLayout(Layout):
    def __init__(self, width, height=20):
        super().__init__(width, height)
        self.route_column = 3
        self.start(self.route_column)

    def go(self, column, across_ladder=False):
        direction = "move_right" if column >= self.route_column else "move_left"
        self.route.append({
            "hold": [direction, "move_up"] if across_ladder else [direction],
            "until_x": self.cx(column),
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
            self.route_column = column + 3
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


def operations_suite():
    layout = WorkLayout(60)
    low = layout.stand
    layout.platform(12, 8, 20)
    layout.platform(9, 30, 46)
    layout.ladder_cells(10, 11)
    layout.ladder_cells(40, 8)
    for column in [8, 30, 48]:
        layout.checkpoint(column)
    tasks = [
        {"id": "assembly", "type": "assemble_rack", "required": True,
         "label": "Assemble the operations rack", "sites": [[24, low]],
         "resources": [{"kind": "chassis", "cell": [6, low]},
                       {"kind": "psu", "cell": [14, 11]},
                       {"kind": "dimm", "cell": [34, 8]}]},
        {"id": "uplink", "type": "run_cable", "required": True,
         "label": "Connect the upper operations link",
         "sites": [[32, 8], [38, 8], [44, 8]],
         "resources": [{"kind": "spool", "cell": [42, 8]}]},
        {"id": "branch", "type": "restore_power", "required": True,
         "label": "Energize the operations branch", "sites": [[50, low]],
         "resources": [{"kind": "fuse", "cell": [46, low]}]},
    ]
    layout.go(6)
    layout.action()
    layout.go(24)
    layout.action()
    layout.climb(10, 11, True)
    layout.go(14)
    layout.action()
    layout.climb(10, low, False)
    layout.go(24)
    layout.action()
    layout.climb(40, 8, True)
    layout.go(34, across_ladder=True)
    layout.action()
    layout.climb(40, low, False)
    layout.go(24)
    layout.action()
    layout.action("diagnose", 1.7)
    layout.climb(40, 8, True)
    layout.go(42)
    layout.action()
    for column in [32, 38, 44]:
        layout.go(column, across_ladder=True)
        layout.action()
    layout.climb(40, low, False)
    layout.go(46)
    layout.action()
    layout.go(50)
    layout.action()
    layout.action()
    layout.action("diagnose", 1.7)
    layout.action()
    layout.exit(56)
    return layout, {"name": "Operations Suite", "background": "operations-suite",
                    "music": "level3", "par_seconds": 210, "sla_seconds": 420,
                    "tasks": tasks}


def fiber_exchange():
    layout = WorkLayout(60)
    low = layout.stand
    top = 10
    layout.platform(top + 1, 12, 46)
    layout.ladder_cells(14, top)
    layout.ladder_cells(44, top)
    for column in [5, 45, 52]:
        layout.checkpoint(column)
    tasks = [
        {"id": "upper", "type": "run_cable", "required": True,
         "label": "Connect the upper fiber tray",
         "sites": [[12, low], [18, top], [42, top]],
         "resources": [{"kind": "spool", "cell": [8, low]}]},
        {"id": "return", "type": "run_cable", "required": True,
         "label": "Connect the lower return route",
         "sites": [[46, low], [30, low], [14, low]],
         "resources": [{"kind": "spool", "cell": [48, low]}]},
        {"id": "exchange", "type": "assemble_rack", "required": True,
         "label": "Assemble the exchange rack", "sites": [[54, low]],
         "resources": [{"kind": "chassis", "cell": [50, low]},
                       {"kind": "psu", "cell": [36, low]},
                       {"kind": "dimm", "cell": [20, low]}]},
    ]
    layout.go(8)
    layout.action()
    layout.go(12)
    layout.action()
    layout.climb(14, top, True)
    for column in [18, 42]:
        layout.go(column)
        layout.action()
    layout.climb(44, low, False)
    layout.go(48)
    layout.action()
    for column in [46, 30, 14]:
        layout.go(column)
        layout.action()
    for column in [50, 36, 20]:
        layout.go(column)
        layout.action()
        layout.go(54)
        layout.action()
    layout.action("diagnose", 1.7)
    layout.exit(57)
    return layout, {"name": "Fiber Exchange", "background": "fiber-exchange",
                    "music": "level3", "par_seconds": 210, "sla_seconds": 420,
                    "tasks": tasks}


def loading_yard():
    layout = WorkLayout(60)
    low = layout.stand
    deck = 14
    layout.platform(deck + 1, 10, 24)
    layout.platform(deck + 1, 32, 46)
    layout.platform(10, 10, 46)
    layout.ladder_cells(12, deck)
    layout.ladder_cells(34, deck)
    for column in [5, 24, 48]:
        layout.checkpoint(column)
    for column in range(25, 32):
        layout.put(column, low, "~")
    tasks = [
        {"id": "delivery", "type": "assemble_rack", "required": True,
         "label": "Assemble the delivered rack", "sites": [[52, low]],
         "resources": [{"kind": "chassis", "cell": [6, low]},
                       {"kind": "psu", "cell": [20, low]},
                       {"kind": "dimm", "cell": [42, low]}]},
        {"id": "trench", "type": "contain_leak", "required": True,
         "label": "Drain the service trench", "sites": [[22, deck], [18, deck]],
         "resources": [{"kind": "seal", "cell": [14, deck]}],
         "effect_cells": [[column, low] for column in range(25, 32)]},
        {"id": "yard", "type": "restore_power", "required": True,
         "label": "Restore loading platform power", "sites": [[40, deck]],
         "resources": [{"kind": "fuse", "cell": [36, deck]}]},
    ]
    layout.climb(12, deck, True)
    layout.go(14)
    layout.action()
    layout.go(22)
    layout.action()
    layout.action()
    layout.go(18)
    layout.action(seconds=3.2)
    layout.climb(12, low, False)
    for column in [6, 20, 42]:
        layout.go(column)
        layout.action()
        layout.go(52)
        layout.action()
    layout.action("diagnose", 1.7)
    layout.climb(34, deck, True)
    layout.go(36)
    layout.action()
    layout.go(40)
    layout.action()
    layout.action()
    layout.action("diagnose", 1.7)
    layout.action()
    layout.climb(34, low, False)
    layout.exit(56)
    return layout, {"name": "Loading Yard", "background": "loading-yard",
                    "music": "level2", "par_seconds": 240, "sla_seconds": 480,
                    "tasks": tasks}


BUILDERS = {
    "06-cooling-gallery": cooling_gallery,
    "07-operations-suite": operations_suite,
    "08-fiber-exchange": fiber_exchange,
    "09-loading-yard": loading_yard,
}


def main():
    for slug, build in BUILDERS.items():
        layout, header = build()
        layout.write(slug, header)


if __name__ == "__main__":
    main()
