const {test} = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const file = path.join(__dirname, "../web/mobile.js");

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
