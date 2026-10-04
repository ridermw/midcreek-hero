const {test} = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const file = path.join(__dirname, "../web/mobile.js");

function cueNode(action = "") {
  const classes = new Set();
  let content = "";
  return {
    dataset: {action}, hidden: false, writes: 0, textWrites: 0,
    get textContent() { return content; },
    set textContent(value) { content = value; this.textWrites++; },
    attributes: {"aria-pressed": "true"},
    getAttribute(name) { return this.attributes[name]; },
    setAttribute(name, value) { this.attributes[name] = value; this.writes++; },
    classList: {toggle(name, value) { value ? classes.add(name) : classes.delete(name); }, contains(name) { return classes.has(name); }},
  };
}

test("live status text announces a changed purpose once even when the compact Hold text is unchanged", () => {
  const {renderPrompt} = require(file);
  const visible = cueNode(), graphic = cueNode(), announcement = cueNode();
  const model = {action: "repair", intent: "hold", display: "touch", status: "",
    description: "Hold Repair to repair", graphic: {shape: "touch", label: "Repair"}, pulse: true};
  renderPrompt(visible, graphic, [], model, "", false, true, announcement);
  assert.equal(announcement.textContent, "Hold Repair to repair", "The full description must be actual live-region text, not only aria-label.");
  const install = {...model, description: "Hold Repair to install the PSU"};
  renderPrompt(visible, graphic, [], install, "", false, true, announcement);
  assert.equal(visible.textContent, "Hold");
  assert.equal(announcement.textContent, "Hold Repair to install the PSU");
  const updates = announcement.textWrites;
  renderPrompt(visible, graphic, [], {...install, held: true, pulse: false}, "", false, true, announcement);
  renderPrompt(visible, graphic, [], install, "", false, true, announcement);
  assert.equal(announcement.textWrites, updates, "Held and pulse refreshes must not repeat the announcement.");
});

test("live hints show graphics, Hold and status only while retaining full semantic descriptions", () => {
  const {renderPrompt} = require(file);
  const text = cueNode(), graphic = cueNode();
  const press = {action: "jump", intent: "press", display: "keyboard", description: "Press Space to jump cables",
    graphic: {shape: "keycap", label: "Space"}};
  renderPrompt(text, graphic, [], press, "", false, true);
  assert.equal(graphic.textContent, "Space");
  assert.equal(text.textContent, "", "Live action prose must not duplicate the keycap.");
  assert.equal(text.attributes["aria-label"], "Press Space to jump cables");
  const hold = {action: "repair", intent: "hold", display: "touch", description: "Hold Repair to repair",
    status: "", graphic: {shape: "touch", label: "Repair"}};
  renderPrompt(text, graphic, [], hold, "", false, true);
  assert.equal(text.textContent, "Hold");
  renderPrompt(text, graphic, [], {...hold, description: "Hold Repair to install the PSU"}, "", false, true);
  assert.equal(text.textContent, "Hold");
  assert.equal(text.attributes["aria-label"], "Hold Repair to install the PSU", "A changed purpose must update accessibility even when visible Hold is unchanged.");
  renderPrompt(text, graphic, [], {action: "", status: "Wrong order. Start again at switch 1", description: "Wrong order. Start again at switch 1"}, "", false, true);
  assert.equal(text.textContent, "Wrong order. Start again at switch 1");
  renderPrompt(text, graphic, [], press);
  assert.equal(text.textContent, "Press Space to jump cables", "Help keeps its full purpose text.");
});

test("structured touch guidance highlights only the existing requested button without changing pressed state", () => {
  const {renderPrompt} = require(file);
  assert.equal(typeof renderPrompt, "function", "structured prompt renderer is missing");
  const text = cueNode(), graphic = cueNode(), repair = cueNode("repair"), jump = cueNode("jump");
  const nodes = [repair, jump];
  const model = {action: "repair", intent: "hold", display: "touch", description: "Hold Repair to repair", pulse: true, held: false, graphic: {shape: "touch", label: "Repair"}};
  renderPrompt(text, graphic, nodes, model);
  assert.equal(repair.classList.contains("guidance-cue"), true);
  assert.equal(repair.classList.contains("guidance-pulse"), true);
  assert.equal(jump.classList.contains("guidance-cue"), false);
  assert.equal(graphic.hidden, true, "touch uses the original button, not a duplicate");
  assert.equal(repair.attributes["aria-pressed"], "true");
  assert.equal(text.textContent, "Hold Repair to repair");
  const writes = text.writes;
  renderPrompt(text, graphic, nodes, {...model, held: true});
  assert.equal(text.writes, writes, "held-state changes must not repeat accessible announcements");
  assert.equal(repair.classList.contains("guidance-pulse"), false);
  renderPrompt(text, graphic, nodes, {...model, action: "jump", description: "Press Jump", graphic: {shape: "touch", label: "Jump"}}, "", true);
  assert.equal(repair.classList.contains("guidance-cue"), false);
  assert.equal(jump.classList.contains("guidance-cue"), true);
  assert.equal(jump.classList.contains("guidance-pulse"), false, "reduced motion uses a static highlight");
  assert.equal(nodes[0], repair, "existing controls retain their identities");
  assert.equal(nodes[1], jump);
  renderPrompt(text, graphic, nodes, {});
  assert.equal(jump.classList.contains("guidance-cue"), false);
  assert.equal(text.textContent, "");
  assert.equal(jump.attributes["aria-pressed"], "true", "clearing cues never releases held contacts");
});

test("phone prompt honors a chosen keyboard or gamepad graphic without guessing actions from prose", () => {
  const {renderPrompt} = require(file);
  assert.equal(typeof renderPrompt, "function");
  const text = cueNode(), graphic = cueNode(), repair = cueNode("repair");
  renderPrompt(text, graphic, [repair], {action: "repair", display: "gamepad", description: "Hold X to repair", graphic: {shape: "button", label: "X"}});
  assert.equal(graphic.hidden, false);
  assert.equal(graphic.textContent, "X");
  assert.equal(graphic.dataset.shape, "button");
  assert.equal(repair.classList.contains("guidance-cue"), false);
  renderPrompt(text, graphic, [repair], {action: "", display: "touch", description: "Bring the PSU. Repair later."});
  assert.equal(repair.classList.contains("guidance-cue"), false);
  assert.equal(text.textContent, "Bring the PSU. Repair later.");
});

test("phone task demonstration uses its shared timeline and loops; reduced motion stays static", () => {
  const {demoFrame} = require(file);
  assert.equal(typeof demoFrame, "function", "help demonstration renderer is missing");
  const demo = {steps: [
    {seconds: 1, clip: "run", from: 20, to: 80},
    {seconds: 2, clip: "primary", from: 80, to: 80},
  ], clips: {run: {fps: 4, frames: ["run0", "run1"]}, primary: {fps: 2, frames: ["work0", "work1"]}}};
  assert.deepEqual(demoFrame(demo, 0), {step: 0, frame: "run0", x: 20});
  assert.deepEqual(demoFrame(demo, 0.5), {step: 0, frame: "run0", x: 50});
  assert.deepEqual(demoFrame(demo, 1.5), {step: 1, frame: "work1", x: 80});
  assert.deepEqual(demoFrame(demo, 3), demoFrame(demo, 0));
  assert.deepEqual(demoFrame(demo, 1.5, true), demoFrame(demo, 0));
});

test("phone controls require touch, coarse input and phone screen dimensions", () => {
  assert.ok(fs.existsSync(file), "Mobile browser interface is missing");
  const {isPhone} = require(file);
  assert.equal(isPhone({touch: 5, coarse: true, width: 390, height: 844}), true);
  assert.equal(isPhone({touch: 5, coarse: true, width: 844, height: 390}), true);
  assert.equal(isPhone({touch: 0, coarse: true, width: 390, height: 844}), false);
  assert.equal(isPhone({touch: 5, coarse: false, width: 390, height: 844}), false);
  assert.equal(isPhone({touch: 10, coarse: true, width: 1920, height: 1080}), false);
  assert.equal(isPhone({touch: 10, coarse: true, width: 1366, height: 768}), false);
});

test("independent fingers and cancellation preserve other held actions", () => {
  assert.ok(fs.existsSync(file), "Mobile browser interface is missing");
  const {TouchState} = require(file);
  const events = [];
  const state = new TouchState((action, down) => events.push([action, down]));
  state.press(1, "move_right");
  state.press(2, "jump");
  state.press(3, "move_right");
  state.release(1);
  assert.deepEqual(events, [["move_right", true], ["jump", true]]);
  state.release(2);
  assert.deepEqual(events.at(-1), ["jump", false]);
  state.clear();
  assert.deepEqual(events.at(-1), ["move_right", false]);
  const count = events.length;
  state.release(3);
  state.clear();
  assert.equal(events.length, count);
});

test("dragging a finger between pad directions releases the previous action", () => {
  assert.ok(fs.existsSync(file), "Mobile browser interface is missing");
  const {TouchState} = require(file);
  const events = [];
  const state = new TouchState((action, down) => events.push([action, down]));
  state.press(1, "move_left");
  state.press(1, "move_up");
  state.release(1);
  assert.deepEqual(events, [["move_left", true], ["move_left", false], ["move_up", true], ["move_up", false]]);
});
