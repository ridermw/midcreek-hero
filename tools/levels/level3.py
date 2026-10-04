"""Level 3, Cable Jungle: trays, ladders, moving snags, and reseats."""

from tools.levels.layout import Layout, catwalk, ladder_tower, mover_run, pit_run, snag_run, stairs, tray_run

SEQUENCES = {
    "c2": ["diagnose", "diagnose", "jump"],
    "o2": ["repair", "diagnose", "jump"],
    "c4": ["diagnose", "jump", "diagnose"],
}
HEADER = {'name': 'Cable Jungle',
 'sla_seconds': 200,
 'par_seconds': 125,
 'music': 'level3',
 'background': 'cable-jungle',
 'prompts': [{'x': 2, 'action': 'slide', 'intent': 'press', 'text': 'slide under the low trays', 'status': ''},
             {'x': 16, 'action': 'jump', 'intent': 'press', 'text': 'jump the loose cables', 'status': 'Time your jump.'},
             {'x': 25, 'task': 'c2', 'action': 'repair', 'intent': 'press', 'text': 'start reseating the cable', 'status': 'Follow each button shown.'},
             {'x': 36, 'action': 'move_up', 'intent': 'hold', 'text': 'climb onto the catwalk', 'status': ''},
             {'x': 58, 'action': '', 'intent': '', 'text': '', 'status': 'Grab the spare DIMM'},
             {'x': 100, 'action': '', 'intent': '', 'text': '', 'status': 'Optional: a loose patch cable up the ladder'}],
 'tasks': [{'id': 'c2', 'type': 'reseat', 'at': ['A'], 'required': True, 'label': 'Reseat uplink A3'},
           {'id': 'r1', 'type': 'repair', 'at': ['G'], 'required': True, 'label': 'Repair rack G14'},
           {'id': 'f1',
            'type': 'fetch',
            'at': ['B'],
            'part_at': 'D',
            'part': 'dimm',
            'required': True,
            'label': 'Install DIMM in B08'},
           {'id': 'o2', 'type': 'reseat', 'at': ['H'], 'required': False, 'label': 'Reseat patch H1'},
           {'id': 'r3', 'type': 'repair', 'at': ['Q'], 'required': True, 'label': 'Repair switch Q9'},
           {'id': 'c4', 'type': 'reseat', 'at': ['U'], 'required': True, 'label': 'Reseat spine U4'}]}


def build():
    L = Layout(520)
    S = L.stand
    L.start()
    L.tray(8, 13)
    L.put(20, S, "m")
    L.route.append({"wait": 0.0})
    L.run_to(L.cx(17))
    L.jump()
    L.port(28, "A", SEQUENCES["c2"])
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
    L.mover(122, 117)
    L.tray(128, 133)
    L.pit(138, 140)
    L.snag(146)
    x = ladder_tower(L, 152, 7, rack="Q")
    L.checkpoint(x)
    x = tray_run(L, x + 4, 2)
    x = mover_run(L, x, 2, lead=4)
    x = catwalk(L, x + 2, 3)
    L.port(x + 3, "U", SEQUENCES["c4"])
    x += 9
    L.checkpoint(x)
    x = stairs(L, x + 4, 3)
    x = tray_run(L, x, 2)
    x = ladder_tower(L, x + 3, 6)
    x = catwalk(L, x + 2, 2)
    x = stairs(L, x + 4, 3)
    x = pit_run(L, x, 2)
    x = mover_run(L, x, 1, lead=2)
    x = snag_run(L, x + 2, 2)
    L.exit(x + 4)
    L.trim(x + 8)
    return L, HEADER


if __name__ == "__main__":
    grid, header = build()
    grid.write("03-cable-jungle", header)
