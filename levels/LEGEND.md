# Level legend

A level file has a JSON header, a line that contains only `---`, then the tile grid.
Each grid cell is 32x32 pixels. All rows have the same width.

| Symbol | Meaning |
|---|---|
| `.` | Empty |
| `#` | Floor (solid) |
| `=` | Platform (solid from above only) |
| `T` | Cable tray (solid bar; M4) |
| `\|` | Ladder (M4) |
| `l` | Lift (M5) |
| `P` | Player start (exactly 1) |
| `E` | Exit door (exactly 1) |
| `C` | Checkpoint (shipped levels: exactly 3, activated from left to right) |
| `h` | Coolant pickup |
| `s` | Cable snag, static |
| `m` | Cable snag, moving (M4) |
| `v` | Heat vent (M3) |
| `k` | Spark arc (M5) |
| `d` | Patrol drone (M6) |
| `A` to `Z` except `C`, `E`, `P`, `T` | Anchor that a header task references |

Put an anchor, `P`, `E`, `C`, and `h` in the cell where the player stands,
directly above a solid cell. A rack drawn at an anchor stands behind the player.

Header keys: `name`, `music`, `background` (strings); `sla_seconds`, `par_seconds`
(numbers, `0 < par < sla`); `tasks` (array). Task keys: `id`, `type`, `required`,
`at` (array of anchors), optional `label`, and `part_at` for `fetch`.
Each task `id` must be a unique string that is not empty. A supplied `label`
must be a string; an omitted or empty label uses the default task label.
