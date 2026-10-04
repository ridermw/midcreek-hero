"""Level 4, Power Room: spark arcs, lifts, and an ordered switch reboot."""

from tools.levels.layout import Layout, arc_run, catwalk, lift_deck, pit_run, snag_run, stairs

HEADER = {'name': 'Power Room',
 'sla_seconds': 200,
 'par_seconds': 125,
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
            'label': 'Install PSU in F5'},
           {'id': 'd2', 'type': 'diagnose_repair', 'at': ['V'], 'required': True, 'label': 'Diagnose busbar V3'},
           {'id': 'r2', 'type': 'repair', 'at': ['W'], 'required': True, 'label': 'Repair UPS W6'}]}


def build():
    L = Layout(520)
    S = L.stand
    L.start()
    L.arc(9)
    L.switch(24, "Y")
    L.switch(18, "X", left=True)
    L.switch(30, "Z")
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
    L.pit(136, 138)
    L.arc(144)
    L.snag(151)
    x = lift_deck(L, 157, length=14, rack="V", hazard="arc", mode="diagnose")
    L.checkpoint(x)
    x = arc_run(L, x + 3, 3)
    x = catwalk(L, x + 2, 3)
    L.rack(x + 3, L.stand, "W")
    x += 9
    L.checkpoint(x)
    x = stairs(L, x + 3, 3)
    x = lift_deck(L, x + 3, length=12, hazard="arc")
    x = pit_run(L, x, 2)
    x = arc_run(L, x, 2)
    x = snag_run(L, x + 2, 2)
    L.exit(x + 4)
    L.trim(x + 8)
    return L, HEADER


if __name__ == "__main__":
    grid, header = build()
    grid.write("04-power-room", header)
