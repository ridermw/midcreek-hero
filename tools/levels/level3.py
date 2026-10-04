"""Level 3, Cable Jungle: trays, ladders, moving snags, and reseats."""

from tools.levels.layout import Layout

SEQUENCES = {"c2": ["diagnose", "diagnose", "jump"], "o2": ["repair", "diagnose", "jump"]}
HEADER = {'name': 'Cable Jungle',
 'sla_seconds': 75,
 'par_seconds': 45,
 'music': 'level3',
 'background': 'cable-jungle',
 'prompts': [{'x': 2, 'text': 'Low trays ahead: slide under them with C or Shift'},
             {'x': 16, 'text': 'Loose cables crawl along the floor. Time your jump'},
             {'x': 25, 'text': 'Reseat the cable: press E, then each button shown'},
             {'x': 36, 'text': 'Climb with W or Up, then step onto the catwalk'},
             {'x': 58, 'text': 'Grab the spare DIMM'},
             {'x': 100, 'text': 'Optional: a loose patch cable up the ladder'}],
 'tasks': [{'id': 'c2', 'type': 'reseat', 'at': ['A'], 'required': True, 'label': 'Reseat uplink A3'},
           {'id': 'r1', 'type': 'repair', 'at': ['G'], 'required': True, 'label': 'Repair rack G14'},
           {'id': 'f1',
            'type': 'fetch',
            'at': ['B'],
            'part_at': 'D',
            'part': 'dimm',
            'required': True,
            'label': 'Install DIMM in B08'},
           {'id': 'o2', 'type': 'reseat', 'at': ['H'], 'required': False, 'label': 'Reseat patch H1'}]}


def build():
    L = Layout(158)
    S = L.stand
    L.start()
    L.tray(8, 13)
    L.put(20, S, "m")
    L.route.append({"wait": 0.0})
    L.run_to(L.cx(17))
    L.jump()
    L.port(28, "A", SEQUENCES["c2"])
    L.checkpoint(33)
    L.ladder(38, 9, 39, 44)
    L.rack(42, 9, "G")
    L.run_to(L.cx(47))
    L.tray(50, 56)
    L.part(60, S, "D")
    L.pit(64, 66)
    L.mover(72, 69)
    L.checkpoint(78)
    L.tray(84, 90)
    L.rack(96, S, "B", "deliver")
    L.ladder(102, 7, 103, 108)
    L.port(106, "H", SEQUENCES["o2"], row=7)
    L.run_to(L.cx(111))
    L.checkpoint(116)
    L.mover(122, 117)
    L.tray(128, 133)
    L.pit(138, 140)
    L.snag(146)
    L.exit(154)
    return L, HEADER


if __name__ == "__main__":
    grid, header = build()
    grid.write("03-cable-jungle", header)
