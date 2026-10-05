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


def fire_response_hall():
    layout = WorkLayout(68)
    low, upper = layout.stand, 11
    layout.platform(upper + 1, 8, 60)
    for column in [10, 26, 46, 58]:
        layout.ladder_cells(column, upper)
    layout.checkpoint(5)
    layout.checkpoint(32)
    layout.put(50, upper, "C")
    layout.put(18, low, "f")
    layout.put(42, low, "f")
    layout.put(52, low, "v")
    tasks = [
        {"id": "bay-a", "type": "extinguish_fire", "required": True,
         "label": "Extinguish the first equipment bay", "sites": [[14, low]],
         "resources": [{"kind": "extinguisher", "cell": [24, upper]}],
         "effect_cells": [[18, low]]},
        {"id": "bay-b", "type": "extinguish_fire", "required": True,
         "label": "Extinguish the second equipment bay", "sites": [[38, low]],
         "resources": [{"kind": "extinguisher", "cell": [30, upper]}],
         "effect_cells": [[42, low]]},
        {"id": "extract", "type": "restore_cooling", "required": True,
         "label": "Restart the extraction fan", "sites": [[48, upper], [56, upper]],
         "resources": [{"kind": "filter", "cell": [34, upper]}],
         "effect_cells": [[52, low]]},
    ]
    for source, service, access in [(24, 14, 10), (30, 38, 26)]:
        layout.climb(access, upper, True)
        layout.go(source, across_ladder=True)
        layout.action()
        layout.climb(access, low, False)
        layout.go(service)
        layout.action(seconds=2.1)
        layout.climb(access, upper, True)
        layout.go(source, across_ladder=True)
        layout.action()
        layout.climb(access, low, False)
        layout.go(service)
        layout.action(seconds=1.2)
    layout.climb(46, upper, True)
    layout.go(34, across_ladder=True)
    layout.action()
    layout.go(48, across_ladder=True)
    layout.action("diagnose")
    layout.go(56)
    layout.action()
    layout.go(48)
    layout.action()
    layout.action(seconds=1.7)
    layout.climb(58, low, False)
    layout.exit(64)
    return layout, {"name": "Fire Response Hall", "background": "fire-response-hall",
                    "music": "level4", "par_seconds": 240, "sla_seconds": 480,
                    "tasks": tasks}


def pump_station():
    layout = WorkLayout(64)
    low, upper = layout.stand, 11
    layout.platform(upper + 1, 8, 58)
    for column in [10, 30, 54]:
        layout.ladder_cells(column, upper)
    layout.checkpoint(5)
    layout.put(28, upper, "C")
    layout.put(44, upper, "C")
    for column in list(range(12, 27)) + list(range(34, 49)):
        layout.put(column, low, "~")
    layout.put(56, low, "v")
    tasks = [
        {"id": "west", "type": "contain_leak", "required": True,
         "label": "Drain the west pump floor", "sites": [[18, upper], [22, upper]],
         "resources": [{"kind": "seal", "cell": [14, upper]}],
         "effect_cells": [[column, low] for column in range(12, 27)]},
        {"id": "east", "type": "contain_leak", "required": True,
         "label": "Drain the east pump floor", "sites": [[38, upper], [42, upper]],
         "resources": [{"kind": "seal", "cell": [34, upper]}],
         "effect_cells": [[column, low] for column in range(34, 49)]},
        {"id": "pumps", "type": "restore_cooling", "required": True,
         "label": "Restore pump ventilation", "sites": [[52, upper], [56, upper]],
         "resources": [{"kind": "filter", "cell": [50, upper]}],
         "effect_cells": [[56, low]]},
    ]
    layout.climb(10, upper, True)
    for source, valve, drain in [(14, 18, 22), (34, 38, 42)]:
        layout.go(source, across_ladder=True)
        layout.action()
        layout.go(valve)
        layout.action()
        layout.action()
        layout.go(drain)
        layout.action(seconds=3.2)
    layout.go(50)
    layout.action()
    layout.go(52)
    layout.action("diagnose")
    layout.go(56, across_ladder=True)
    layout.action()
    layout.go(52, across_ladder=True)
    layout.action()
    layout.action(seconds=1.7)
    layout.climb(54, low, False)
    layout.put(4, low, "E")
    layout.go(4)
    return layout, {"name": "Pump Station", "background": "pump-station",
                    "music": "level2", "par_seconds": 240, "sla_seconds": 480,
                    "tasks": tasks}


def rooftop_air_handlers():
    layout = WorkLayout(70)
    low, roof = layout.stand, 8
    for first, last in [(6, 22), (28, 44), (50, 64)]:
        layout.platform(roof + 1, first, last)
    for column in [10, 32, 56]:
        layout.ladder_cells(column, roof)
    layout.checkpoint(5)
    layout.checkpoint(30)
    layout.put(52, roof, "C")
    layout.put(20, roof, "v")
    tasks = [
        {"id": "air", "type": "restore_cooling", "required": True,
         "label": "Start the west air handler", "sites": [[18, roof], [14, roof]],
         "resources": [{"kind": "filter", "cell": [6, low]}],
         "effect_cells": [[20, roof]]},
        {"id": "roof", "type": "run_cable", "required": True,
         "label": "Connect the separated roof sections",
         "sites": [[32, low], [38, roof], [54, roof]],
         "resources": [{"kind": "spool", "cell": [34, low]}]},
        {"id": "east", "type": "restore_power", "required": True,
         "label": "Energize the east roof branch", "sites": [[62, roof]],
         "resources": [{"kind": "fuse", "cell": [50, low]}]},
    ]
    layout.go(6)
    layout.action()
    layout.climb(10, roof, True)
    layout.go(18)
    layout.action("diagnose")
    layout.go(14)
    layout.action()
    layout.go(18)
    layout.action()
    layout.action(seconds=1.7)
    layout.climb(10, low, False)
    layout.tray(24, 26)
    layout.route_column = 28
    layout.go(34)
    layout.action()
    layout.go(32)
    layout.action()
    layout.climb(32, roof, True)
    layout.go(38)
    layout.action()
    layout.climb(32, low, False)
    layout.go(50)
    layout.action()
    layout.climb(56, roof, True)
    layout.go(52, across_ladder=True)
    layout.go(54)
    layout.action()
    layout.go(62, across_ladder=True)
    layout.action()
    layout.action()
    layout.action("diagnose", 1.7)
    layout.action()
    layout.climb(56, low, False)
    layout.exit(66)
    return layout, {"name": "Rooftop Air Handlers", "background": "rooftop-air-handlers",
                    "music": "level4", "par_seconds": 270, "sla_seconds": 540,
                    "tasks": tasks}


BUILDERS = {
    "06-cooling-gallery": cooling_gallery,
    "07-operations-suite": operations_suite,
    "08-fiber-exchange": fiber_exchange,
    "09-loading-yard": loading_yard,
    "10-fire-response-hall": fire_response_hall,
    "11-pump-station": pump_station,
    "12-rooftop-air-handlers": rooftop_air_handlers,
}


def main():
    for slug, build in BUILDERS.items():
        layout, header = build()
        layout.write(slug, header)


if __name__ == "__main__":
    main()
