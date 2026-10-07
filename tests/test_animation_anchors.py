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


def sample(phase, clip, frame, tick, x=0.0, flip=False, wall_us=None):
    return {
        "phase": phase, "clip": clip, "frame": frame, "physics_frame": tick,
        "wall_us": tick * 16667 if wall_us is None else wall_us,
        "position": [x, 416.0], "camera": [x, 300.0], "flip": flip,
    }


class AnimationAnchorsTest(unittest.TestCase):
    def test_frame_anchors_find_helmet_torso_boots_and_reach(self):
        anchors = animation_anchors.frame_anchors(figure(reach=30))
        self.assertEqual(anchors["helmet_x"], 104)
        self.assertEqual(anchors["helmet_top"], 40)
        self.assertAlmostEqual(anchors["torso_x"], 104.0)
        self.assertEqual(anchors["boot_x"], 104.5)
        self.assertEqual(anchors["reach_x"], 146)

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
        self.assertEqual(change["cause"], "source registration")
        self.assertEqual(change["helmet_texels"], 9)

    def test_helmet_motion_over_a_stable_torso_is_an_authored_pose(self):
        anchors = {
            ("man-midcreek", "idle", 0): animation_anchors.frame_anchors(figure()),
            ("man-midcreek", "run", 0): animation_anchors.frame_anchors(figure(hat_shift=9)),
        }
        trace = [sample("man-idle-run", "idle", 0, 0), sample("man-idle-run", "run", 0, 5, x=3.0)]
        change = animation_anchors.analyze(trace, anchors, {"idle": 6, "run": 14})["man-idle-run"]["changes"][0]
        self.assertEqual(change["kind"], "transition")
        self.assertEqual(change["cause"], "authored pose")

    def test_a_late_frame_inside_a_clip_is_playback_timing(self):
        anchors = {("woman-midcreek", "run", i): animation_anchors.frame_anchors(figure()) for i in range(3)}
        trace = [
            sample("woman-run", "run", 0, 0),
            sample("woman-run", "run", 1, 4),
            sample("woman-run", "run", 2, 11),
        ]
        changes = animation_anchors.analyze(trace, anchors, {"run": 14})["woman-run"]["changes"]
        self.assertEqual(changes[0]["cause"], "none")
        self.assertEqual(changes[1]["cause"], "playback timing")
        self.assertEqual(changes[1]["ticks"], 7)

    def test_camera_that_does_not_follow_physics_is_render_timing(self):
        anchors = {("man-midcreek", "run", i): animation_anchors.frame_anchors(figure()) for i in range(2)}
        trace = [sample("man-run", "run", 0, 0, x=0.0), sample("man-run", "run", 1, 4, x=12.0)]
        trace[1]["camera"] = [30.0, 300.0]
        change = animation_anchors.analyze(trace, anchors, {"run": 14})["man-run"]["changes"][0]
        self.assertEqual(change["cause"], "camera or render timing")

    def test_mirrored_samples_use_mirrored_world_anchors(self):
        anchors = {
            ("man-midcreek", "run", 0): animation_anchors.frame_anchors(figure()),
            ("man-midcreek", "run", 1): animation_anchors.frame_anchors(figure(shift=9)),
        }
        trace = [sample("man-run", "run", 0, 0, flip=True), sample("man-run", "run", 1, 4, x=-12.0, flip=True)]
        change = animation_anchors.analyze(trace, anchors, {"run": 14})["man-run"]["changes"][0]
        self.assertEqual(change["helmet_world"], -4.5)

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
        self.assertEqual(change["cause"], "authored pose")

    def test_planted_boot_drift_is_a_source_registration_change(self):
        anchors = {
            ("man-midcreek", "idle", 2): animation_anchors.frame_anchors(figure()),
            ("man-midcreek", "idle", 3): animation_anchors.frame_anchors(figure(shift=3)),
        }
        trace = [sample("man-idle-run", "idle", 2, 0), sample("man-idle-run", "idle", 3, 10)]
        change = animation_anchors.analyze(trace, anchors, {"idle": 6})["man-idle-run"]["changes"][0]
        self.assertEqual(change["cause"], "source registration")

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
        self.assertEqual(change["cause"], "authored pose")

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
