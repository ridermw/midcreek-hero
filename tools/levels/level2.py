"""Level 2, Hot Aisle: heat vents, part fetches, and diagnosis."""

from tools.levels.layout import Layout, catwalk, pit_run, snag_run, stairs, vent_run

HEADER = {'name': 'Hot Aisle',
 'sla_seconds': 195,
 'par_seconds': 120,
 'music': 'level2',
 'background': 'hot-aisle',
 'prompts': [{'x': 2, 'action': 'jump', 'intent': 'press', 'text': 'jump the vents', 'status': 'Heat vents blast on a cycle. Wait for a safe opening.'},
             {'x': 12, 'action': 'move_right', 'intent': 'hold', 'text': 'run over the spare PSU to pick it up', 'status': ''},
             {'x': 24, 'task': 'f1', 'action': 'repair', 'intent': 'hold', 'text': 'install the PSU at the rack', 'status': ''},
             {'x': 49, 'task': 'd1', 'action': 'diagnose', 'intent': 'press', 'text': 'diagnose the rack', 'status': 'Diagnose before repairing.'},
             {'x': 84, 'action': '', 'intent': '', 'text': '', 'status': 'A spare DIMM waits on the catwalk'},
             {'x': 155, 'action': '', 'intent': '', 'text': '', 'status': 'Optional: diagnose the rack on the catwalk'}],
 'tasks': [{'id': 'f1',
            'type': 'fetch',
            'at': ['A'],
            'part_at': 'D',
            'part': 'psu',
            'required': True,
            'label': 'Install PSU in A04'},
           {'id': 'd1',
            'type': 'diagnose_repair',
            'at': ['B'],
            'required': True,
            'label': 'Diagnose and fix B11'},
           {'id': 'r1', 'type': 'repair', 'at': ['G'], 'required': True, 'label': 'Repair rack G09'},
           {'id': 'f2',
            'type': 'fetch',
            'at': ['F'],
            'part_at': 'K',
            'part': 'dimm',
            'required': True,
            'label': 'Install DIMM in F02'},
           {'id': 'o1',
            'type': 'diagnose_repair',
            'at': ['H'],
            'required': False,
            'label': 'Diagnose rack H15'},
           {'id': 'f3', 'type': 'fetch', 'at': ['N'], 'part_at': 'M', 'part': 'dimm', 'required': True, 'label': 'Install DIMM in N06'}]}


def build():
    L = Layout(520)
    S = L.stand
    L.start()
    L.vent(8)
    L.part(14, S, "D")
    L.vent(20)
    L.rack(26, S, "A", "deliver")
    L.platform(11, 34, 37)
    L.platform(9, 40, 43)
    L.coolant(42, 8)
    L.put(38, S, "s")
    L.put(42, S, "s")
    L.climb_to(34)
    L.climb_to(40)
    L.rack(52, S, "B", "diagnose")
    L.pit(57, 59)
    L.vent(65)
    L.vent(72)
    L.checkpoint(76)
    L.platform(11, 81, 84)
    L.platform(9, 86, 89)
    L.part(88, 8, "K")
    L.climb_to(81)
    L.climb_to(86)
    L.vent(96)
    L.pit(102, 104)
    L.rack(110, S, "G")
    L.rack(118, S, "F", "deliver")
    L.vent(130)
    L.vent(137)
    L.snag(144)
    L.pit(150, 152)
    L.platform(11, 158, 161)
    L.platform(9, 164, 167)
    L.climb_to(158)
    L.climb_to(164)
    L.rack(166, 8, "H", "diagnose")
    L.run_to(L.cx(170))
    x = vent_run(L, 172, 3)
    L.checkpoint(x + 1)
    x = stairs(L, x + 6, 3, coolant=True)
    L.part(x + 2, L.stand, "M")
    x = catwalk(L, x + 6, 3)
    x = vent_run(L, x, 2)
    x = pit_run(L, x, 2)
    L.rack(x + 3, L.stand, "N", "deliver")
    x += 9
    L.checkpoint(x)
    x = stairs(L, x + 3, 4)
    x = vent_run(L, x, 3)
    x = catwalk(L, x + 4, 3, length=5)
    x = pit_run(L, x, 1)
    x = stairs(L, x + 4, 3, coolant=True)
    x = vent_run(L, x, 2)
    x = snag_run(L, x, 2)
    L.exit(x + 4)
    L.trim(x + 8)
    return L, HEADER


if __name__ == "__main__":
    grid, header = build()
    grid.write("02-hot-aisle", header)
