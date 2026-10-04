"""Level 4, Power Room: spark arcs, lifts, and an ordered switch reboot."""

from tools.levels.layout import Layout

HEADER = {'name': 'Power Room',
 'sla_seconds': 105,
 'par_seconds': 65,
 'music': 'level4',
 'background': 'power-room',
 'prompts': [{'x': 2, 'text': 'Spark arcs flicker before they fire. Jump them'},
             {'x': 16, 'text': 'Reboot the core switch: throw switches 1, 2, 3 in order'},
             {'x': 39, 'text': 'Ride the lift up to the busbar deck'},
             {'x': 99, 'text': 'Optional: a spare PSU sits on the upper deck'}],
 'tasks': [{'id': 'b1',
            'type': 'reboot',
            'at': ['Y', 'X', 'Z'],
            'required': True,
            'label': 'Reboot core switch'},
           {'id': 'd1', 'type': 'diagnose_repair', 'at': ['D'], 'required': True, 'label': 'Diagnose PDU D2'},
           {'id': 'r1', 'type': 'repair', 'at': ['G'], 'required': True, 'label': 'Repair UPS G1'},
           {'id': 'o1',
            'type': 'fetch',
            'at': ['F'],
            'part_at': 'K',
            'part': 'psu',
            'required': False,
            'label': 'Install PSU in F5'}]}


def build():
    L = Layout(164)
    S = L.stand
    L.start()
    L.arc(9)
    L.switch(24, "Y")
    L.switch(18, "X", left=True)
    L.switch(30, "Z")
    L.checkpoint(36)
    L.lift_up(42, 44, 60)
    L.rack(50, 9, "D", "diagnose")
    L.arc(55, 9)
    L.run_to(L.cx(64))
    L.pit(68, 70)
    L.arc(76)
    L.checkpoint(82)
    L.rack(88, S, "G")
    L.lift_up(94, 96, 112)
    L.part(102, 9, "K")
    L.arc(107, 9)
    L.run_to(L.cx(115))
    L.rack(118, S, "F", "deliver")
    L.arc(124)
    L.checkpoint(130)
    L.pit(136, 138)
    L.arc(144)
    L.snag(151)
    L.exit(158)
    return L, HEADER


if __name__ == "__main__":
    grid, header = build()
    grid.write("04-power-room", header)
