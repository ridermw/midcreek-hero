"""Level 1, Cold Aisle Onboarding: run, jump, then repair."""

from tools.levels.layout import Layout

HEADER = {'name': 'Cold Aisle Onboarding',
 'sla_seconds': 90,
 'par_seconds': 55,
 'music': 'level1',
 'background': 'cold-aisle',
 'prompts': [{'x': 1, 'text': 'Run: A / D or arrows. Pad: left stick'},
             {'x': 6, 'text': 'Jump cables: Space. Pad: A'},
             {'x': 13, 'text': 'Repair red racks: hold E. Pad: hold X'},
             {'x': 20, 'text': 'Jump the open floor tiles'},
             {'x': 34, 'text': 'Climb the catwalks'},
             {'x': 69, 'text': 'Optional: a rack up high needs tuning'},
             {'x': 174, 'text': 'Reach the exit when every required task is done'}],
 'tasks': [{'id': 'r1', 'type': 'repair', 'at': ['A'], 'required': True, 'label': 'Repair rack A12'},
           {'id': 'r2', 'type': 'repair', 'at': ['B'], 'required': True, 'label': 'Repair rack B07'},
           {'id': 'r3', 'type': 'repair', 'at': ['G'], 'required': True, 'label': 'Repair rack G03'},
           {'id': 'o1', 'type': 'repair', 'at': ['F'], 'required': False, 'label': 'Tune rack F21'}]}


def build():
    L = Layout(180)
    S = L.stand
    L.start()
    L.snag(9)
    L.rack(15, S, "A")
    L.pit(22, 24)
    L.checkpoint(31)
    L.platform(11, 36, 39)
    L.platform(9, 42, 46)
    L.coolant(44, 8)
    for col in (40, 44):
        L.put(col, S, "s")
    L.climb_to(36)
    L.climb_to(42)
    L.run_to(L.cx(56) - 40)
    L.rack(58, S, "B")
    L.pit(64, 66)
    L.platform(11, 71, 74)
    L.platform(9, 77, 80)
    L.climb_to(71)
    L.climb_to(77)
    L.rack(79, 8, "F")
    L.run_to(L.cx(84))
    L.route.append({"wait": 0.6})
    L.checkpoint(88)
    L.snag(94)
    L.snag(102)
    L.pit(109, 111)
    L.snag(118)
    L.platform(11, 127, 130)
    L.platform(9, 133, 136)
    L.platform(7, 139, 142)
    L.coolant(135, 8)
    for col in (131, 137):
        L.put(col, S, "s")
    L.climb_to(127)
    L.climb_to(133)
    L.climb_to(139)
    L.rack(141, 6, "G")
    L.run_to(L.cx(145))
    L.route.append({"wait": 0.6})
    L.checkpoint(148)
    L.snag(152)
    L.snag(160)
    L.pit(166, 168)
    L.exit(176)
    return L, HEADER


if __name__ == "__main__":
    grid, header = build()
    grid.write("01-cold-aisle", header)
