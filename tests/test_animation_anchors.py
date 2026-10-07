"""Check anchor measurement and discontinuity classification for rendered probe traces."""

import unittest

from PIL import Image

from tools import animation_anchors

HAT = (15, 80, 180, 255)
VEST = (230, 140, 30, 255)
BOOT = (60, 40, 20, 255)


def figure(shift=0, hat_shift=0, reach=0):
    frame = Image.new("RGBA", (208, 208))
    frame.paste(HAT, (96 + shift + hat_shift, 40, 113 + shift + hat_shift, 52))
    frame.paste(VEST, (92 + shift, 60, 117 + shift, 120))
    frame.paste(BOOT, (90 + shift, 168, 102 + shift, 184))
    frame.paste(BOOT, (108 + shift, 168, 120 + shift, 184))
    if reach:
        frame.paste((200, 200, 200, 255), (117 + shift, 80, 117 + shift + reach, 84))
    return frame


def sample(phase, clip, frame, tick, x=0.0, y=416.0, camera_x=None, camera_y=300.0,
           flip=False, wall_us=None, playback_speed=1.0, progress=0.0, camera_limits=None, viewport_size=None):
    item = {
        "phase": phase, "clip": clip, "frame": frame, "physics_frame": tick,
        "wall_us": tick * 16667 if wall_us is None else wall_us,
        "position": [x, y], "camera": [x if camera_x is None else camera_x, camera_y], "flip": flip,
        "playback_speed": playback_speed, "progress": progress,
    }
    if camera_limits is not None:
        item["camera_limits"] = camera_limits
    if viewport_size is not None:
        item["viewport_size"] = viewport_size
    return item


class AnimationAnchorsTest(unittest.TestCase):
    def test_frame_anchors_find_helmet_torso_boots_and_reach(self):
        anchors = animation_anchors.frame_anchors(figure(reach=30))
        self.assertEqual(anchors["helmet_x"], 104)
        self.assertEqual(anchors["helmet_top"], 40)
        self.assertAlmostEqual(anchors["torso_x"], 104.0)
        self.assertEqual(anchors["boot_x"], 104.5)
        self.assertEqual(anchors["reach_x"], 146)

    def test_frame_anchors_measure_the_hard_hat_region_not_blue_shoulders(self):
        frame = Image.new("RGBA", (208, 208))
        frame.paste(HAT, (112, 35, 129, 51))
        frame.paste(HAT, (50, 70, 101, 84))
        anchors = animation_anchors.frame_anchors(frame)
        self.assertEqual(anchors["helmet_x"], 120)

    def test_frame_anchors_reject_a_frame_without_a_helmet(self):
        with self.assertRaisesRegex(ValueError, "helmet"):
            animation_anchors.frame_anchors(Image.new("RGBA", (208, 208)))

    def test_whole_figure_jump_inside_a_clip_is_a_source_registration_change(self):
        anchors = {
            ("man-midcreek", "run", 0): animation_anchors.frame_anchors(figure()),
            ("man-midcreek", "run", 1): animation_anchors.frame_anchors(figure(shift=9)),
        }
        trace = [sample("man-run", "run", 0, 0), sample("man-run", "run", 1, 4, x=12.0)]
        change = animation_anchors.analyze(trace, anchors, {"run": 14})["man-run"]["changes"][0]
        self.assertEqual(change["kind"], "frame")
        self.assertEqual(change["causes"], ["source registration"])
        self.assertEqual(change["helmet_texels"], 9)

    def test_helmet_motion_over_a_stable_torso_is_an_authored_pose(self):
        anchors = {
            ("man-midcreek", "idle", 0): animation_anchors.frame_anchors(figure()),
            ("man-midcreek", "run", 0): animation_anchors.frame_anchors(figure(hat_shift=9)),
        }
        trace = [sample("man-idle-run", "idle", 0, 0), sample("man-idle-run", "run", 0, 5, x=3.0)]
        change = animation_anchors.analyze(trace, anchors, {"idle": 6, "run": 14})["man-idle-run"]["changes"][0]
        self.assertEqual(change["kind"], "transition")
        self.assertEqual(change["causes"], ["authored pose"])

    def test_a_late_frame_inside_a_clip_is_playback_timing(self):
        anchors = {("woman-midcreek", "run", i): animation_anchors.frame_anchors(figure()) for i in range(3)}
        trace = [
            sample("woman-run", "run", 0, 0),
            sample("woman-run", "run", 1, 4),
            sample("woman-run", "run", 2, 11),
        ]
        changes = animation_anchors.analyze(trace, anchors, {"run": 14})["woman-run"]["changes"]
        self.assertEqual(changes[0]["causes"], [])
        self.assertEqual(changes[1]["causes"], ["playback timing"])
        self.assertEqual(changes[1]["ticks"], 7)

    def test_forward_loop_wrap_counts_as_one_frame_advance(self):
        anchors = {("man-midcreek", "run", i): animation_anchors.frame_anchors(figure()) for i in (0, 6, 7)}
        trace = [
            sample("man-run", "run", 6, 0),
            sample("man-run", "run", 7, 4),
            sample("man-run", "run", 0, 8),
        ]
        changes = animation_anchors.analyze(trace, anchors, {"run": 14})["man-run"]["changes"]
        self.assertEqual(changes[1]["kind"], "loop")
        self.assertEqual(changes[1]["causes"], [])

    def test_reverse_loop_wrap_counts_as_one_frame_advance(self):
        anchors = {("man-midcreek", "climb", i): animation_anchors.frame_anchors(figure()) for i in (0, 1, 5)}
        trace = [
            sample("man-climb", "climb", 1, 0, playback_speed=-1.0),
            sample("man-climb", "climb", 0, 8, playback_speed=-1.0),
            sample("man-climb", "climb", 5, 16, playback_speed=-1.0),
        ]
        changes = animation_anchors.analyze(trace, anchors, {"climb": 8})["man-climb"]["changes"]
        self.assertEqual(changes[1]["kind"], "frame")
        self.assertEqual(changes[1]["causes"], [])

    def test_camera_that_does_not_follow_physics_is_render_timing(self):
        anchors = {("man-midcreek", "run", i): animation_anchors.frame_anchors(figure()) for i in range(2)}
        trace = [sample("man-run", "run", 0, 0, x=0.0), sample("man-run", "run", 1, 4, x=12.0)]
        trace[1]["camera"] = [30.0, 300.0]
        change = animation_anchors.analyze(trace, anchors, {"run": 14})["man-run"]["changes"][0]
        self.assertEqual(change["causes"], ["camera or render timing"])

    def test_camera_jitter_between_unchanged_frames_is_render_timing(self):
        anchors = {("man-midcreek", "run", 0): animation_anchors.frame_anchors(figure())}
        trace = [
            sample("man-run", "run", 0, 0, x=0.0),
            sample("man-run", "run", 0, 1, x=0.0),
        ]
        trace[1]["camera"] = [5.0, 300.0]
        change = animation_anchors.analyze(trace, anchors, {"run": 14})["man-run"]["changes"][0]
        self.assertEqual(change["kind"], "sample")
        self.assertEqual(change["causes"], ["camera or render timing"])

    def test_stalled_playback_between_unchanged_frames_is_timing(self):
        anchors = {("man-midcreek", "run", i): animation_anchors.frame_anchors(figure()) for i in (0, 1)}
        trace = [
            sample("man-run", "run", 1, 0),
            sample("man-run", "run", 0, 4),
            sample("man-run", "run", 0, 14, playback_speed=1.0),
        ]
        changes = animation_anchors.analyze(trace, anchors, {"run": 14})["man-run"]["changes"]
        self.assertEqual(changes[1]["kind"], "sample")
        self.assertEqual(changes[1]["causes"], ["playback timing"])

    def test_mirrored_samples_use_mirrored_world_anchors(self):
        anchors = {
            ("man-midcreek", "run", 0): animation_anchors.frame_anchors(figure()),
            ("man-midcreek", "run", 1): animation_anchors.frame_anchors(figure(shift=9)),
        }
        trace = [sample("man-run", "run", 0, 0, flip=True), sample("man-run", "run", 1, 4, x=-12.0, flip=True)]
        change = animation_anchors.analyze(trace, anchors, {"run": 14})["man-run"]["changes"][0]
        self.assertEqual(change["helmet_world"], -4.5)

    def test_facing_changes_apply_each_sample_flip_to_world_anchors(self):
        anchors = {
            ("man-midcreek", "idle", 0): animation_anchors.frame_anchors(figure(hat_shift=6)),
            ("man-midcreek", "run", 0): animation_anchors.frame_anchors(figure(hat_shift=6)),
        }
        trace = [sample("man-turn", "idle", 0, 0), sample("man-turn", "run", 0, 4, flip=True)]
        change = animation_anchors.analyze(trace, anchors, {"idle": 6, "run": 14})["man-turn"]["changes"][0]
        self.assertEqual(change["helmet_world"], -6.0)

    def test_same_frame_facing_change_is_reported_without_resetting_timing(self):
        anchors = {("man-midcreek", "run", i): animation_anchors.frame_anchors(figure(hat_shift=6)) for i in (0, 1, 2)}
        trace = [
            sample("man-run", "run", 0, 0),
            sample("man-run", "run", 1, 4),
            sample("man-run", "run", 1, 5, flip=True),
            sample("man-run", "run", 2, 8, flip=True),
        ]
        changes = animation_anchors.analyze(trace, anchors, {"run": 14})["man-run"]["changes"]
        self.assertEqual(changes[1]["kind"], "facing")
        self.assertEqual(changes[1]["helmet_world"], -6.0)
        self.assertEqual(changes[2]["ticks"], 4)
        self.assertEqual(changes[2]["causes"], [])

    def test_planted_upper_body_lean_over_fixed_boots_is_an_authored_pose(self):
        lean = figure()
        lean.paste((0, 0, 0, 0), (80, 40, 130, 120))
        lean.paste(HAT, (90, 40, 107, 52))
        lean.paste(VEST, (84, 60, 109, 120))
        anchors = {
            ("woman-midcreek", "secondary", 5): animation_anchors.frame_anchors(figure()),
            ("woman-midcreek", "secondary", 6): animation_anchors.frame_anchors(lean),
        }
        trace = [sample("woman-idle-diagnose", "secondary", 5, 0), sample("woman-idle-diagnose", "secondary", 6, 6)]
        change = animation_anchors.analyze(trace, anchors, {"secondary": 10})["woman-idle-diagnose"]["changes"][0]
        self.assertEqual(change["boot_texels"], 0)
        self.assertEqual(change["causes"], ["authored pose"])

    def test_planted_boot_drift_is_a_source_registration_change(self):
        anchors = {
            ("man-midcreek", "idle", 2): animation_anchors.frame_anchors(figure()),
            ("man-midcreek", "idle", 3): animation_anchors.frame_anchors(figure(shift=3)),
        }
        trace = [sample("man-idle-run", "idle", 2, 0), sample("man-idle-run", "idle", 3, 10)]
        change = animation_anchors.analyze(trace, anchors, {"idle": 6})["man-idle-run"]["changes"][0]
        self.assertEqual(change["causes"], ["source registration"])

    def test_forward_lean_between_gaits_is_an_authored_pose(self):
        lean = Image.new("RGBA", (208, 208))
        lean.paste(HAT, (102, 40, 119, 52))
        lean.paste(VEST, (96, 60, 121, 120))
        lean.paste(BOOT, (90, 168, 102, 184))
        lean.paste(BOOT, (108, 168, 120, 184))
        anchors = {
            ("woman-midcreek", "walk", 0): animation_anchors.frame_anchors(figure()),
            ("woman-midcreek", "run", 0): animation_anchors.frame_anchors(lean),
        }
        trace = [sample("woman-idle-run", "walk", 0, 0), sample("woman-idle-run", "run", 0, 5, x=2.0)]
        change = animation_anchors.analyze(trace, anchors, {"walk": 10, "run": 14})["woman-idle-run"]["changes"][0]
        self.assertEqual((change["helmet_texels"], change["torso_texels"]), (6, 4.0))
        self.assertEqual(change["causes"], ["authored pose"])

    def test_a_pose_change_does_not_hide_a_camera_error(self):
        anchors = {
            ("man-midcreek", "idle", 0): animation_anchors.frame_anchors(figure()),
            ("man-midcreek", "run", 0): animation_anchors.frame_anchors(figure(hat_shift=9)),
        }
        trace = [sample("man-idle-run", "idle", 0, 0), sample("man-idle-run", "run", 0, 5, x=3.0)]
        trace[1]["camera"] = [11.0, 300.0]
        result = animation_anchors.analyze(trace, anchors, {"idle": 6, "run": 14})["man-idle-run"]
        self.assertEqual(result["changes"][0]["causes"], ["authored pose", "camera or render timing"])
        self.assertEqual(result["unexplained"], 1)

    def test_a_registration_shift_does_not_hide_late_playback(self):
        anchors = {
            ("man-midcreek", "run", 0): animation_anchors.frame_anchors(figure()),
            ("man-midcreek", "run", 1): animation_anchors.frame_anchors(figure()),
            ("man-midcreek", "run", 2): animation_anchors.frame_anchors(figure(shift=9)),
        }
        trace = [sample("man-run", "run", 0, 0), sample("man-run", "run", 1, 4), sample("man-run", "run", 2, 11)]
        change = animation_anchors.analyze(trace, anchors, {"run": 14})["man-run"]["changes"][1]
        self.assertEqual(change["causes"], ["source registration", "playback timing"])

    def test_tool_reach_is_reported_and_mirrored(self):
        anchors = {
            ("woman-midcreek", "primary", 0): animation_anchors.frame_anchors(figure(reach=10)),
            ("woman-midcreek", "primary", 1): animation_anchors.frame_anchors(figure(reach=30)),
        }
        trace = [sample("woman-repair", "primary", 0, 0, flip=True), sample("woman-repair", "primary", 1, 6, flip=True)]
        change = animation_anchors.analyze(trace, anchors, {"primary": 10})["woman-repair"]["changes"][0]
        self.assertEqual((change["reach_texels"], change["reach_world"]), (20, -10.0))
        self.assertEqual(change["causes"], ["authored pose"])

    def test_tool_reach_moving_with_drifting_boots_is_registration(self):
        anchors = {
            ("man-midcreek", "primary", 0): animation_anchors.frame_anchors(figure(reach=10)),
            ("man-midcreek", "primary", 1): animation_anchors.frame_anchors(figure(shift=4, reach=10)),
        }
        trace = [sample("man-repair", "primary", 0, 0), sample("man-repair", "primary", 1, 6)]
        change = animation_anchors.analyze(trace, anchors, {"primary": 10})["man-repair"]["changes"][0]
        self.assertEqual(change["reach_texels"], 4)
        self.assertEqual(change["causes"], ["source registration"])

    def test_frozen_active_run_from_phase_start_is_playback_timing(self):
        anchors = {("man-midcreek", "run", 0): animation_anchors.frame_anchors(figure())}
        trace = [
            sample("man-run", "run", 0, 0, playback_speed=1.0, progress=0.0),
            sample("man-run", "run", 0, 30, playback_speed=1.0, progress=0.0),
        ]
        changes = animation_anchors.analyze(trace, anchors, {"run": 14})["man-run"]["changes"]
        self.assertEqual(len(changes), 1)
        self.assertEqual(changes[0]["kind"], "sample")
        self.assertEqual(changes[0]["causes"], ["playback timing"])

    def test_first_run_frame_advance_uses_phase_start_for_timing(self):
        anchors = {("man-midcreek", "run", i): animation_anchors.frame_anchors(figure()) for i in (0, 1)}
        trace = [
            sample("man-run", "run", 0, 0, playback_speed=1.0, progress=0.0),
            sample("man-run", "run", 1, 30, playback_speed=1.0, progress=0.0),
        ]
        change = animation_anchors.analyze(trace, anchors, {"run": 14})["man-run"]["changes"][0]
        self.assertEqual(change["kind"], "frame")
        self.assertEqual(change["causes"], ["playback timing"])

    def test_fractional_progress_from_phase_start_is_not_timing_drift(self):
        anchors = {("man-midcreek", "run", i): animation_anchors.frame_anchors(figure()) for i in (0, 1)}
        trace = [
            sample("man-run", "run", 0, 0, playback_speed=1.0, progress=0.0),
            sample("man-run", "run", 0, 4, playback_speed=1.0, progress=14.0 * 4.0 / 60.0),
            sample("man-run", "run", 1, 5, playback_speed=1.0, progress=14.0 * 5.0 / 60.0 - 1.0),
        ]
        changes = animation_anchors.analyze(trace, anchors, {"run": 14})["man-run"]["changes"]
        self.assertEqual(len(changes), 1)
        self.assertEqual(changes[0]["causes"], [])

    def test_vertical_camera_jitter_between_unchanged_frames_is_render_timing(self):
        anchors = {("man-midcreek", "run", 0): animation_anchors.frame_anchors(figure())}
        trace = [
            sample("man-run", "run", 0, 0, x=320.0, y=320.0, camera_x=320.0, camera_y=320.0),
            sample("man-run", "run", 0, 1, x=320.0, y=320.0, camera_x=320.0, camera_y=328.0),
        ]
        changes = animation_anchors.analyze(trace, anchors, {"run": 14})["man-run"]["changes"]
        self.assertEqual(len(changes), 1)
        self.assertEqual(changes[0]["kind"], "sample")
        self.assertEqual(changes[0]["causes"], ["camera or render timing"])

    def test_vertical_camera_jitter_during_frame_change_is_render_timing(self):
        anchors = {("man-midcreek", "run", i): animation_anchors.frame_anchors(figure()) for i in (0, 1)}
        trace = [
            sample("man-run", "run", 0, 0, x=320.0, y=320.0, camera_x=320.0, camera_y=320.0),
            sample("man-run", "run", 1, 4, x=320.0, y=320.0, camera_x=320.0, camera_y=328.0),
        ]
        change = animation_anchors.analyze(trace, anchors, {"run": 14})["man-run"]["changes"][0]
        self.assertEqual(change["causes"], ["camera or render timing"])

    def test_clamped_camera_movement_is_not_render_timing(self):
        limits = [0.0, 0.0, 960.0, 720.0]
        viewport = [480.0, 360.0]
        anchors = {("man-midcreek", "run", 0): animation_anchors.frame_anchors(figure())}
        trace = [
            sample("man-run", "run", 0, 0, x=170.0, y=170.0, camera_x=240.0, camera_y=180.0,
                   camera_limits=limits, viewport_size=viewport),
            sample("man-run", "run", 0, 1, x=160.0, y=160.0, camera_x=240.0, camera_y=180.0,
                   camera_limits=limits, viewport_size=viewport),
        ]
        result = animation_anchors.analyze(trace, anchors, {"run": 14})["man-run"]
        self.assertEqual(result["changes"], [])

    def test_tool_motion_relative_to_torso_is_reported_with_boot_registration(self):
        anchors = {
            ("man-midcreek", "primary", 0): animation_anchors.frame_anchors(figure(reach=10)),
            ("man-midcreek", "primary", 1): animation_anchors.frame_anchors(figure(shift=4, reach=30)),
        }
        trace = [sample("man-repair", "primary", 0, 0), sample("man-repair", "primary", 1, 6)]
        change = animation_anchors.analyze(trace, anchors, {"primary": 10})["man-repair"]["changes"][0]
        self.assertEqual(change["causes"], ["source registration", "authored pose"])

    def test_helmet_motion_relative_to_boots_is_reported_with_boot_registration(self):
        anchors = {
            ("woman-midcreek", "secondary", 0): animation_anchors.frame_anchors(figure()),
            ("woman-midcreek", "secondary", 1): animation_anchors.frame_anchors(figure(shift=4, hat_shift=6)),
        }
        trace = [sample("woman-diagnose", "secondary", 0, 0), sample("woman-diagnose", "secondary", 1, 6)]
        change = animation_anchors.analyze(trace, anchors, {"secondary": 10})["woman-diagnose"]["changes"][0]
        self.assertEqual(change["causes"], ["source registration", "authored pose"])

    def test_speed_scaled_climb_ascent_is_not_flagged_as_late_playback(self):
        anchors = {("man-midcreek", "climb", i): animation_anchors.frame_anchors(figure()) for i in range(3)}
        trace = [
            sample("man-climb", "climb", 0, 0, playback_speed=2.109375),
            sample("man-climb", "climb", 1, 4, playback_speed=2.109375),
            sample("man-climb", "climb", 2, 8, playback_speed=2.109375),
        ]
        changes = animation_anchors.analyze(trace, anchors, {"climb": 8})["man-climb"]["changes"]
        self.assertEqual(changes[1]["causes"], [])

    def test_speed_scaled_climb_descent_is_not_flagged_as_late_playback(self):
        anchors = {("man-midcreek", "climb", i): animation_anchors.frame_anchors(figure()) for i in range(3)}
        trace = [
            sample("man-climb", "climb", 2, 0, playback_speed=-2.109375),
            sample("man-climb", "climb", 1, 4, playback_speed=-2.109375),
            sample("man-climb", "climb", 0, 8, playback_speed=-2.109375),
        ]
        changes = animation_anchors.analyze(trace, anchors, {"climb": 8})["man-climb"]["changes"]
        self.assertEqual(changes[1]["causes"], [])

    def test_paused_climb_time_is_not_counted_as_playback_drift(self):
        anchors = {("man-midcreek", "climb", i): animation_anchors.frame_anchors(figure()) for i in range(3)}
        trace = [
            sample("man-climb", "climb", 0, 0, playback_speed=1.0),
            sample("man-climb", "climb", 1, 8, playback_speed=0.0),
            sample("man-climb", "climb", 1, 14, playback_speed=1.0),
            sample("man-climb", "climb", 2, 22, playback_speed=1.0),
        ]
        changes = animation_anchors.analyze(trace, anchors, {"climb": 8})["man-climb"]["changes"]
        self.assertEqual(changes[1]["causes"], [])

    def test_within_frame_climb_reversal_uses_post_reversal_progress(self):
        anchors = {("man-midcreek", "climb", i): animation_anchors.frame_anchors(figure()) for i in (0, 1, 5)}
        trace = [
            sample("man-climb", "climb", 1, -8, playback_speed=2.109375, progress=0.0),
            sample("man-climb", "climb", 0, 0, playback_speed=2.109375, progress=0.35),
            sample("man-climb", "climb", 0, 2, playback_speed=-2.109375, progress=0.75),
            sample("man-climb", "climb", 5, 5, playback_speed=-2.109375, progress=0.9),
        ]
        change = animation_anchors.analyze(trace, anchors, {"climb": 8})["man-climb"]["changes"][1]
        self.assertEqual(change["causes"], [])

    def test_summary_reports_the_largest_unexplained_jump(self):
        anchors = {
            ("man-midcreek", "run", 0): animation_anchors.frame_anchors(figure()),
            ("man-midcreek", "run", 1): animation_anchors.frame_anchors(figure(shift=9)),
            ("man-midcreek", "run", 2): animation_anchors.frame_anchors(figure()),
        }
        trace = [sample("man-run", "run", i, i * 4, x=i * 12.0) for i in range(3)]
        result = animation_anchors.analyze(trace, anchors, {"run": 14})["man-run"]
        self.assertEqual(result["unexplained"], 2)
        self.assertEqual(result["max_helmet_texels"], 9)


if __name__ == "__main__":
    unittest.main()
