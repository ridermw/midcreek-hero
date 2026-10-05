"""Check route completion independently of the player's star rating."""

import argparse
import json
import math
from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[1]
RESULT = re.compile(
    r"SMOKE_RESULT (?P<level>\d{2}) stars=[123] respawns=(?P<respawns>\d+) "
    r"elapsed=(?P<elapsed>\S+) hits=(?P<hits>\d+) sla=(?P<sla>\S+)"
)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("level")
    parser.add_argument("log", type=Path)
    args = parser.parse_args()
    budgets = json.loads((ROOT / "tests/route_budgets.json").read_text())
    budget = budgets.get(args.level)
    if type(budget) not in (int, float) or not math.isfinite(budget) or budget <= 0:
        parser.error(f"Missing or invalid independent route budget for {args.level}")
    lines = args.log.read_text().splitlines()
    for line in lines:
        if re.match(r"^(SCRIPT ERROR|ERROR|USER ERROR|Parse Error)", line.strip()):
            parser.error(f"Route {args.level} reported a runtime error: {line}")
    results = [line for line in lines if line.startswith("SMOKE_RESULT")]
    if len(results) != 1:
        parser.error(f"Expected one completion result for {args.level}; found {len(results)}")
    match = RESULT.fullmatch(results[0])
    if match is None or match["level"] != args.level:
        parser.error(f"Invalid completion result for {args.level}: {results[0]}")
    try:
        elapsed, sla = float(match["elapsed"]), float(match["sla"])
    except ValueError:
        parser.error("Route elapsed time and SLA must be numbers")
    if not math.isfinite(elapsed) or not math.isfinite(sla) or elapsed < 0 or sla <= 0:
        parser.error("Route elapsed time and SLA must be finite and in range")
    if int(match["hits"]) or int(match["respawns"]):
        parser.error(f"Route {args.level} must finish without hits or respawns")
    if elapsed >= sla:
        parser.error(f"Route {args.level} took {elapsed}s, outside its {sla}s SLA")
    if elapsed > budget:
        parser.error(f"Route {args.level} took {elapsed}s, above its independent {budget}s budget")
    print(f"ROUTE_CHECK {args.level} elapsed={elapsed:.2f} budget={budget} sla={sla:.2f} PASS")


if __name__ == "__main__":
    main()
