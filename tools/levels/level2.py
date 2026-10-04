"""Level 2, Hot Aisle: heat vents, part fetches, and diagnosis."""

from tools.levels.layout import Layout

HEADER = {'name': 'Hot Aisle',
 'sla_seconds': 90,
 'par_seconds': 55,
 'music': 'level2',
 'background': 'hot-aisle',
 'prompts': [{'x': 2, 'text': 'Heat vents blast on a cycle. Jump them or wait'},
             {'x': 12, 'text': 'Run over the spare PSU to pick it up'},
             {'x': 24, 'text': 'Hold E at the rack to install the PSU'},
             {'x': 49, 'text': 'Press Q to diagnose, then hold E to repair'},
             {'x': 84, 'text': 'A spare DIMM waits on the catwalk'},
             {'x': 155, 'text': 'Optional: diagnose the rack on the catwalk'}],
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
            'label': 'Diagnose rack H15'}]}


def build():
    L = Layout(182)
    S = L.stand
    L.start()
    L.vent(8)
    L.part(14, S, "D")
    L.vent(20)
    L.rack(26, S, "A", "deliver")
    L.checkpoint(31)
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
    L.checkpoint(124)
    L.vent(130)
    L.vent(137)
    L.snag(144)
    L.pit(150, 152)
    L.platform(11, 158, 161)
    L.platform(9, 164, 167)
    L.climb_to(158)
    L.climb_to(164)
    L.rack(166, 8, "H", "diagnose")
    L.exit(176)
    return L, HEADER


if __name__ == "__main__":
    grid, header = build()
    grid.write("02-hot-aisle", header)
