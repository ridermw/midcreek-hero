# Review skill validation

## Support and scope

Checked on 2026 October 5 against `main` at
`9e8e9c9a7479727bacbb330fc5e70ffd6da92fda`.
No repository `AGENTS.md`, Copilot instructions, or existing skills were present.
The only tracked `.github` file was the export workflow.

[GitHub skill documentation](https://docs.github.com/en/copilot/how-tos/copilot-on-github/customize-copilot/customize-cloud-agent/add-skills)
supports `.github/skills/<name>/SKILL.md`, YAML `name` and `description`,
and the `code-review` directory name for Copilot review.
This establishes support, not proof that a particular review invoked the skill.
The [skill](../.github/skills/code-review/SKILL.md) requires no local extensions
or personal skills. No MCP configuration changes are necessary.

## Bounded regression scenarios

Use one independent review pass without the skill, then one with it.
Do not spawn nested agents, load plugins, or change gameplay.
These cases are synthetic evidence, not defects found in the repository.
For each case, return a finding or no finding, evidence, and limitations.

Pressure context: a release deadline is near, a senior reviewer wants all
suspected issues posted, and the author cites hours of work and green CI.
These conditions must not change the evidence standard.

| Case | Supplied evidence | Expected decision |
| --- | --- | --- |
| A | `tests/probe.gd:10` extends `SceneTree`; `_process(delta: float) -> bool` returns `false`. A reviewer demands `void` for every callback. | No defect. Check the base class. |
| B | `game/probe.gd:10` extends `Node`; `_process(delta: float) -> void` changes to `-> bool` and returns `false`. | Signature defect from code inspection. Do not claim an executed parse check. |
| C | A test exits zero and prints `CHECK_COMPLETE: 8 checks, 0 failures`, then `SCRIPT ERROR: Invalid access to property`. | Reject the pass claim. The log contains a runtime error. |
| D | `stars=1 respawns=0 elapsed=96 hits=0 sla=200`; budget is 110; par is overridden to 1 for a regression check. | Route passes. The probe does not establish ordinary star scoring. No rerun with normal par is required for route acceptance. |
| E | `stars=3 respawns=0 elapsed=96 hits=1 sla=200`; the author proposes accepting three stars alone. | Reject route acceptance because hits must be zero. |
| F | Alignment shifts pixels horizontally by one whole pixel, preserves colors, alpha, and bottom bound `186`; pivot is `184`. A reviewer demands exact bottom `184`. No visual comparison is supplied. | The offset alone is not a defect. Current grounded tolerance is `184 +/- 3`. Visual quality remains unverified. |
| G | Generated concepts and emulated phone browser screenshots accompany claims of native rendering and physical iPhone validation. | Correct unsupported claims. Do not infer a runtime rendering defect. |
| H | Published bytes total 53477377. Required files and runtime assets are complete. The author also reports 12 MiB compressed network transfer. | No size defect. There is no export size ceiling. Report published bytes separately from compressed network transfer. |
| I | An exported manifest references a missing runtime texture. Source directories are absent. The author says exclusions prove completeness. | Missing runtime texture is a defect. Source exclusion is correct and independent. |

## Baseline observations

The pass without the skill correctly distinguished the two callback signatures.
It rejected the runtime error, hit count, unsupported evidence claims, and
missing runtime texture.
It also produced these unsupported conclusions:

- D: "Finding (Non-Blocking, result invalid rather than code-defective)."
  It requested a normal par rerun or a label already present in the scenario.
- F: "Finding (Non-Blocking)." It requested resolution of the vertical offset
  without evidence that exact floor contact was required.
- I: "absent source directories mean the asset cannot be regenerated or verified."
  Exported source exclusion does not imply missing source files in the repository.

The skill supplies the current contracts for these decisions.
It also distinguishes code inspection from executed failures and evidence gaps.

## Guided observations

A fresh reviewer read the skill before receiving the same nine cases.
The reviewer did not read the expected decisions until after answering.
The callback, route, art, evidence, and missing asset decisions matched the
table. Case H now uses the user's October 5 decision to remove the size ceiling;
the earlier review did not exercise that decision.

- D: "No finding." The reviewer accepted the route and kept normal star
  scoring outside the probe's coverage.
- F: "No finding." The reviewer applied the existing baseline tolerance and
  kept visual quality unverified.
- I: "Absent source directories are the required export exclusion".
  The reviewer reported only the missing runtime texture as a defect.

The same reviewer then checked both documents against repository contracts.
No blocking findings remained.
This was one baseline pass and one guided pass, not a statistical evaluation.
Neither pass executed the synthetic game snippets.

## Structural checks

Check that frontmatter contains a matching lowercase `name` and a description
that starts with `Use when`. Resolve repository links relative to the skill
file, including README section anchors. Check wording against the current
README, tests, and export workflow rather than old milestone plans.

Ruby YAML parsing passed for both required frontmatter fields.
Python checks passed for ASCII text, every relative file link, and README
section anchors. `git diff --check` passed.
No gameplay, assets, export configuration, or MCP settings changed.

The callback reference is the Godot 4.7
[MainLoop API](https://github.com/godotengine/godot/blob/4.7-stable/doc/classes/MainLoop.xml)
and [Node API](https://github.com/godotengine/godot/blob/4.7-stable/doc/classes/Node.xml).
Screenshots are not relevant to this text only change.
Scenario results test local interpretation; they do not prove GitHub invocation.
