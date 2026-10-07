"""Level 5, Outage Night: darkness, drones, every task type, and a 4 rack finale."""

from tools.levels.layout import (
    Layout, arc_run, catwalk, drone_run, ladder_tower, lift_deck, snag_run, stairs, tray_run,
)

SEQUENCES = {"c3": ["diagnose", "jump", "repair"]}
HEADER = {'name': 'Outage Night',
 'sla_seconds': 170,
 'par_seconds': 125,
 'music': 'level5',
 'background': 'outage-night',
 'darkness': True,
 'prompts': [{'x': 2, 'action': 'slide', 'intent': 'press', 'text': 'slide under security drones', 'status': 'Outage!'},
             {'x': 21, 'task': 'c3', 'action': 'repair', 'intent': 'press', 'text': 'reseat the core uplink', 'status': ''},
             {'x': 57, 'action': '', 'intent': '', 'text': '', 'status': 'Spare PSU. The lift goes up to the PDU deck'},
             {'x': 96, 'task': 'b1', 'action': 'repair', 'intent': 'press', 'text': 'throw switch 1', 'status': 'Reboot the spine switch: 1, 2, 3 in order.'},
             {'x': 129, 'action': '', 'intent': '', 'text': '', 'status': 'Optional: a rack on the catwalk'},
             {'x': 392, 'action': '', 'intent': '', 'text': '', 'status': 'Final job: bring the whole row back online'}],
 'tasks': [{'id': 'c3', 'type': 'reseat', 'at': ['A'], 'required': True, 'label': 'Reseat core uplink'},
           {'id': 'd1', 'type': 'diagnose_repair', 'at': ['D'], 'required': True, 'label': 'Diagnose PDU D7'},
           {'id': 'f1',
            'type': 'fetch',
            'at': ['F'],
            'part_at': 'K',
            'part': 'psu',
            'required': True,
            'label': 'Install PSU in F3'},
           {'id': 'b1',
            'type': 'reboot',
            'at': ['Y', 'X', 'Z'],
            'required': True,
            'label': 'Reboot spine switch'},
           {'id': 'row',
            'type': 'repair',
            'at': ['R', 'U', 'V', 'W'],
            'required': True,
            'label': 'Restore row 9 (4 racks)'},
           {'id': 'o1', 'type': 'repair', 'at': ['O'], 'required': False, 'label': 'Repair rack O2'}]}


def build():
    L = Layout(560)
    S = L.stand
    L.start()
    L.drone(12)
    L.port(23, "A", SEQUENCES["c3"])
    L.vent(29)
    L.tray(38, 43)
    L.mover(50)
    L.part(55, S, "K")
    L.lift_up(59, 61, 75)
    L.rack(66, 9, "D", "diagnose")
    L.arc(71, 9)
    L.run_to(L.cx(78))
    L.pit(81, 83)
    L.rack(89, S, "F", "deliver")
    L.checkpoint(94)
    L.switch(104, "Y")
    L.switch(98, "X", left=True)
    L.switch(110, "Z")
    L.drone(120)
    L.ladder(131, 9, 132, 137)
    L.rack(135, 9, "O")
    L.run_to(L.cx(140))
    L.checkpoint(144)
    L.arc(149)
    L.vent(155)
    # A vent jump lands near x=5068; the patrolling pile must not reach that landing.
    L.snag(162)
    x = drone_run(L, 164, 2)
    x = ladder_tower(L, x + 2, 7)
    x = lift_deck(L, x + 2, length=12, hazard="vent")
    L.checkpoint(x)
    x = tray_run(L, x + 3, 2)
    x = catwalk(L, x + 2, 3)
    x = arc_run(L, x + 2, 2)
    x = drone_run(L, x, 1)
    x = stairs(L, x + 3, 3)
    x = snag_run(L, x, 2)
    for i, letter in enumerate("RUVW"):
        L.rack(x + 3 + i * 3, S, letter)
    L.exit(x + 19)
    L.trim(x + 23)
    return L, HEADER


if __name__ == "__main__":
    grid, header = build()
    grid.write("05-outage-night", header)
