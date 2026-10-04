"""Level 1, Cold Aisle Onboarding: run, jump, then repair."""

from tools.levels.layout import Layout, catwalk, pit_run, snag_run, stairs

HEADER = {'name': 'Cold Aisle Onboarding',
 'sla_seconds': 195,
 'par_seconds': 120,
 'music': 'level1',
 'background': 'cold-aisle',
 'prompts': [{'x': 1, 'action': 'move_right', 'intent': 'hold', 'text': 'run right', 'status': ''},
             {'x': 6, 'action': 'jump', 'intent': 'press', 'text': 'jump cables', 'status': ''},
             {'x': 13, 'task': 'r1', 'action': 'repair', 'intent': 'hold', 'text': 'repair red racks', 'status': ''},
             {'x': 20, 'action': 'jump', 'intent': 'press', 'text': 'jump the open floor tiles', 'status': ''},
             {'x': 34, 'action': 'move_up', 'intent': 'hold', 'text': 'climb the catwalks', 'status': ''},
             {'x': 69, 'action': '', 'intent': '', 'text': '', 'status': 'Optional: a rack up high needs tuning'},
             {'x': 176, 'action': 'move_up', 'intent': 'hold', 'text': 'climb the stacked catwalks to rack H30', 'status': ''},
             {'x': 430, 'action': '', 'intent': '', 'text': '', 'status': 'Reach the exit when every required task is done'}],
 'tasks': [{'id': 'r1', 'type': 'repair', 'at': ['A'], 'required': True, 'label': 'Repair rack A12'},
           {'id': 'r2', 'type': 'repair', 'at': ['B'], 'required': True, 'label': 'Repair rack B07'},
           {'id': 'r3', 'type': 'repair', 'at': ['G'], 'required': True, 'label': 'Repair rack G03'},
           {'id': 'o1', 'type': 'repair', 'at': ['F'], 'required': False, 'label': 'Tune rack F21'},
           {'id': 'r4', 'type': 'repair', 'at': ['H'], 'required': True, 'label': 'Repair rack H30'},
           {'id': 'r5', 'type': 'repair', 'at': ['J'], 'required': True, 'label': 'Repair rack J44'}]}


def build():
    L = Layout(520)
    S = L.stand
    L.start()
    L.snag(9)
    L.rack(15, S, "A")
    L.pit(22, 24)
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
    L.snag(152)
    L.snag(160)
    L.pit(166, 168)
    x = stairs(L, 178, 3, rack="H", coolant=True)
    L.checkpoint(x + 1)
    x = snag_run(L, x + 4, 3)
    x = pit_run(L, x, 2)
    x = catwalk(L, x, 3)
    x = snag_run(L, x, 2)
    L.rack(x + 3, L.stand, "J")
    x += 9
    L.checkpoint(x)
    x = stairs(L, x + 3, 4)
    x = catwalk(L, x + 2, 2, length=5)
    x = pit_run(L, x, 2)
    x = stairs(L, x + 4, 3, coolant=True)
    x = snag_run(L, x, 2)
    L.exit(x + 4)
    L.trim(x + 8)
    return L, HEADER


if __name__ == "__main__":
    grid, header = build()
    grid.write("01-cold-aisle", header)
