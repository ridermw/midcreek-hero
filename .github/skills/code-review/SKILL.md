---
name: code-review
description: Use when reviewing Midcreek Hero pull requests or changes to Godot gameplay, GDScript tests, authored routes, pixel art, browser evidence, or web exports.
---

# Midcreek Hero review

Report concrete defects introduced by the change with high confidence. Check
the base revision, callers, and current contracts before reporting a finding.
Use the current [README](../../../README.md), implementation, and tests.
Old milestone plans can differ from shipped behavior; do not restore obsolete
requirements. Preserve existing behavior outside the intended change.

## Findings

For each finding, give severity, changed file and line range, trigger, impact,
and supporting evidence. State whether evidence comes from execution or code
inspection. Keep unverified risks and missing evidence separate from defects.
If no concrete defect remains, say so. Do not request style changes.

Use repository files and available tools directly. This guide requires no
personal skills, plugins, MCP configuration, or additional agents.

## Review checks

| Area | Contract and evidence |
| --- | --- |
| Godot callbacks | Read `extends` first. For `_process(delta)` and `_physics_process(delta)`, `Node` returns `void`; `SceneTree` inherits `MainLoop` and returns `bool`. `false` continues; `true` exits. Check the engine version in [project.godot](../../../project.godot) and [CI](../../workflows/pages.yml), not a rule inferred from another base class. |
| Test completion | Use [godot_test.sh](../../../tools/godot_test.sh) for the relevant GDScript test. Require a successful exit, a completion marker with positive checks and zero failures, and no script, parse, or runtime error lines. Exit zero alone is insufficient. CI defines the separate exported pack check. |
| Routes and timing | [Level layouts](../../../README.md#level-layouts), [route tests](../../../tests/route_test.gd), and [smoke checker](../../../tools/check_route_result.py) define deterministic authored routes at fixed 60 fps. Require zero hits, zero respawns, no runtime errors, elapsed time within the independent route budget, and completion before the service level agreement (SLA) deadline. Par and SLA are authored player targets, not values to derive from route timing. Stars do not determine route acceptance. |
| Pixel art | Follow [art contracts](../../../README.md#game-art-pipeline) and [asset tests](../../../tests/test_asset_pipeline.py). Preserve palette, binary alpha, nearest sampling, shared scale, and pivots. Alignment must preserve pixels and tool reach through whole pixel translation without clipping or recoloring. The grounded bottom bound uses `184 +/- 3`, with authored airborne exceptions. Do not replace that tolerance with exact `184`. Check each clip's specific contract. |
| Rendered evidence | Distinguish native game captures, exported browser captures, and concept art. Concepts do not prove runtime behavior. [Browser checks](../../../README.md#exported-animation-checks) establish emulation evidence, not physical phone or controller validation. State missing evidence without inventing a rendering failure. |
| Exports | Check [presets](../../../export_presets.cfg), [pack tests](../../../tests/export_test.gd), and [CI](../../workflows/pages.yml). Load all declared runtime assets from the pack outside the source project. Source exclusion is required, not a defect, and does not prove runtime completeness. [The budget](../../../tests/export_budget.json) caps all published files before HTTP compression at 51 MiB, or 53477376 bytes. Require a fresh measurement; intentional growth needs a reviewed budget update, not an automatic increase. |

## Common mistakes

A one star route with zero hits and respawns that meets its budget and SLA
still passes when a test overrides par. It does not test normal star scoring.
Likewise, bottom bound `186` alone is not an alignment defect.

Run the smallest relevant check when available. Report unavailable tools and
unrun checks as limitations. For text only guidance, inspect links and scenario
results; screenshots cannot validate review decisions.
