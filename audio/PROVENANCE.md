# Midcreek Hero audio

All 25 audio files are CC0. The author is Juhani Junkala, who publishes on
OpenGameArt as SubspaceAudio. Source pages were read before downloading.
`sources.json` records the direct archive URL, exact member, final SHA256,
and conversion recipe for every file. `LICENSES.md` is the generated inventory.

## License evidence

Each of these source pages displayed `License(s):` followed by `CC0`, linked
to <http://creativecommons.org/publicdomain/zero/1.0/>.

| Source | Verified page | Evidence |
| --- | --- | --- |
| Action | https://opengameart.org/content/5-chiptunes-action | `License(s): CC0`; author `SubspaceAudio`; download `5 Action Chiptunes By Juhani Junkala.zip` |
| Adventure | https://opengameart.org/content/4-chiptunes-adventure | `License(s): CC0`; author `SubspaceAudio`; download `Juhani Junkala [Chiptune Adventures] WAV.zip` |
| Effects | https://opengameart.org/content/512-sound-effects-8-bit-style | `License(s): CC0`; author `SubspaceAudio`; download `The Essential Retro Video Game Sound Effects Collection [512 sounds].zip` |

The Action archive also says in `INFO.txt`: "These music tracks have been
released under CC0 creative commons license. You can do anything you want with
these tunes."

The Effects archive says in `INFO.txt`: "These sound effects have been released
under CC0 creative commons license. You can do anything you want with these
sounds." It identifies the author as Juhani Junkala and the WAV format as
44100 Hz, 16 bit, mono, at a volume level of minus 6 dB.

The Action page describes its tracks as "all seamlessly looping".
The Adventure page says: "Works especially well with lighthearted platformers.
Seamlessly looping. Both OGG and WAV versions available!"

## Selection

Source labels below refer to the verified pages above. All rows have license
`CC0-1.0`. No music is duplicated between levels. The restrained Stage Select
and Ending tracks provide menu relief, the action tracks support the levels,
and Boss Fight provides the final level escalation. Music retains the full
original loop; no time trimming or tempo change was necessary.

| Repository file | Source | Original selection |
| --- | --- | --- |
| `music/title.ogg` | Adventure | 4. Stage Select |
| `music/results.ogg` | Action | Ending |
| `music/level1.ogg` | Action | Level 1 |
| `music/level2.ogg` | Adventure | 2. Stage2 |
| `music/level3.ogg` | Action | Level 2 |
| `music/level4.ogg` | Action | Level 3 |
| `music/level5.ogg` | Adventure | 3. Boss Fight |
| `sfx/jump.wav` | Effects | `sfx_movement_jump10.wav` |
| `sfx/land.wav` | Effects | `sfx_movement_jump10_landing.wav` |
| `sfx/hit.wav` | Effects | `sfx_damage_hit1.wav` |
| `sfx/heal.wav` | Effects | `sfx_sounds_powerup1.wav` |
| `sfx/repair_tick.wav` | Effects | `sfx_sounds_interaction1.wav` |
| `sfx/repair_done.wav` | Effects | `sfx_sounds_powerup4.wav` |
| `sfx/checkpoint.wav` | Effects | `sfx_sounds_powerup3.wav` |
| `sfx/door_open.wav` | Effects | `sfx_movement_dooropen1.wav` |
| `sfx/timer_warning.wav` | Effects | `sfx_lowhealth_alarmloop1.wav` |
| `sfx/fail.wav` | Effects | `sfx_sounds_error1.wav` |
| `sfx/win.wav` | Effects | `sfx_sounds_fanfare1.wav` |
| `sfx/pickup.wav` | Effects | `sfx_coin_single1.wav` |
| `sfx/deliver.wav` | Effects | `sfx_sounds_powerup2.wav` |
| `sfx/diagnose.wav` | Effects | `sfx_sounds_Blip4.wav` |
| `sfx/switch.wav` | Effects | `sfx_sounds_button1.wav` |
| `sfx/spark.wav` | Effects | `sfx_sounds_impact1.wav` |
| `sfx/menu_move.wav` | Effects | `sfx_menu_move1.wav` |
| `sfx/menu_select.wav` | Effects | `sfx_menu_select1.wav` |

The alarm source supplies a single cycle. Its WAV import has looping disabled,
so each `play_sfx("timer_warning")` call produces one warning, not an endless alarm.
Jump and land are a matched pair. Repair ticks and menu sounds are short;
completion sounds are longer and distinct.

## Validation and restoration

Run from the repository root:

```sh
python3 tools/audio_assets.py check
python3 tools/audio_assets.py licenses
python3 tools/audio_assets.py fetch
python3 -m unittest discover -s tests -p 'test_*.py'
godot --headless --editor --path . --import
tools/godot_test.sh tests/audio_director_test.gd AUDIO_DIRECTOR_TEST
```

`check` works offline with the Python standard library. It checks every file
under `audio/music` and `audio/sfx`, except Godot `.import` sidecars. Those files
are generated importer metadata, not audio or additional licensed assets.
Missing or duplicate entries, missing files, invalid licenses, mismatched
hashes, and missing license table rows cause a nonzero exit.

`licenses` regenerates the table from the manifest. It does not download files.
`--audio-root PATH` selects an isolated audio directory for all three commands.

`fetch` is best effort. It requires curl and, for music conversions, ffmpeg.
It downloads each distinct archive once per run, reads only the selected ZIP
member, converts if required, and verifies the final file hash before replacing
anything. A failed file leaves the current copy untouched; later entries still
run. A failed archive request is remembered for the rest of the run, so entries
sharing its URL do not repeat the request and retries. Failures are printed
per file and produce a nonzero exit. The license table
is regenerated. Downloads and conversion files live inside an automatically
cleaned `.fetch-*` directory under the selected audio directory.

The `notes` field is either `copy` for the original WAV bytes or `ffmpeg: `
followed by a JSON array of output arguments. The command is:

```text
ffmpeg -nostdin -hide_banner -loglevel error -y -i INPUT RECORDED_ARGUMENTS OUTPUT
```

Arguments are passed directly, never through a shell. The manifest is maintained
as trusted project data. It must not be replaced with an unreviewed external
manifest. Source paths must stay inside the selected audio directory.

The original conversions used ffmpeg 9.0.2 and its native `vorbis` encoder
with `-strict experimental`, quality 4, stereo, and 44100 Hz. The local ffmpeg
build did not include `libvorbis`; no additional package was needed.
Bit exact output flags and stripped metadata make repeat conversions stable
on this toolchain. Different encoder versions or architectures can change
bytes. Such a mismatch is reported rather than silently accepting new hashes;
keep the checked in files or deliberately review a new conversion and manifest.

Music uses a gain of 0.5 for levels and 0.35 for title and results. Original
SFX bytes are unchanged. Every music file is below 2 MB, comfortably inside
the 3 MB limit.

## Runtime integration

Add one persistent instance of `game/audio_director.gd` before menus request
music. Keep it outside the child screen that is replaced during navigation.
Either own it from the main scene or register it as an autoload, not both.
Call `play_music` with `title`, `results`, or `level1` through `level5`.
Use the SFX names in the inventory above for interactions and menu events.

Only web builds start locked. Until the first key, mouse button, or joypad button
press, the newest valid music request is pending and SFX requests are accepted
without playback. Motion, releases, and key repeats do not unlock audio.
Unknown names quietly return false and preserve playback state.

Music loops via `AudioStreamOggVorbis.loop` and crossfades across two players
over 0.5 seconds. Repeating the current track does not restart it. New requests
cancel earlier fades. SFX uses eight preallocated players, choosing an idle
voice before recycling the oldest busy voice.

`set_bus_volume` accepts linear gain from zero to one, clamps out of range
values, mutes at zero, and ignores unknown buses or nonfinite values.
