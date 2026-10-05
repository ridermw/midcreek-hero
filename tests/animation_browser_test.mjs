import assert from "node:assert/strict";
import {mkdir, rm, writeFile} from "node:fs/promises";
import {connectBrowser} from "./browser_cdp.mjs";

const [endpoint, url, output] = process.argv.slice(2);
assert.ok(output, "Supply an evidence directory.");
await mkdir(output, {recursive: true});
const browser = await connectBrowser(endpoint, url);
const {cdp, evaluate} = browser;
const delay = ms => new Promise(resolve => setTimeout(resolve, ms));
const observations = [];
let initScriptId;
const debugUrl = new URL(url);
debugUrl.searchParams.set("animation_probe", "1");

async function state() {
  const value = await evaluate("window.midcreekAnimationProbe ?? null");
  if (value?.error) throw new Error(value.error);
  return value;
}
async function waitState(predicate, label, timeout = 20000) {
  const deadline = Date.now() + timeout;
  let last;
  while (Date.now() < deadline) {
    last = await state();
    if (last && predicate(last)) return last;
    await delay(20);
  }
  throw new Error(label + ": " + JSON.stringify(last));
}
async function key(key, code, modifiers = 0) {
  await cdp("Input.dispatchKeyEvent", {type: "keyDown", key, code: key, windowsVirtualKeyCode: code, modifiers});
  await delay(70);
  await cdp("Input.dispatchKeyEvent", {type: "keyUp", key, code: key, windowsVirtualKeyCode: code, modifiers});
}
async function screenshot(name, cropped = false) {
  const options = {format: "png"};
  if (cropped) options.clip = {x: 0, y: 440, width: 640, height: 260, scale: 1};
  const {data} = await cdp("Page.captureScreenshot", options);
  await writeFile(`${output}/${name}.png`, Buffer.from(data, "base64"));
}
async function walk(hero, direction) {
  const label = direction > 0 ? "right" : "left";
  const environment = await evaluate("({userAgent:navigator.userAgent,viewport:[innerWidth,innerHeight],devicePixelRatio,startedAt:new Date().toISOString()})");
  assert.deepEqual(environment.viewport, [960, 720], "Walking capture uses the authored desktop viewport.");
  assert.equal(environment.devicePixelRatio, 1);
  const before = await state();
  const frames = new Set();
  const trace = [];
  await evaluate(`window.__walkPad.axes[0] = ${direction * 0.55}; window.__walkRelease = setTimeout(() => window.__walkPad.axes[0] = 0, 2000)`);
  try {
    await waitState(s => s.clip === "walk" && Math.sign(s.velocity[0]) === direction, "Gamepad starts walking", 3000);
    const deadline = Date.now() + 1800;
    while (Date.now() < deadline) {
      const sample = await state();
      trace.push(sample);
      if (sample.clip !== "walk") break;
      assert.equal(sample.hits, 0, "Walking remains clear of hazards.");
      assert.equal(sample.respawns, 0);
      assert.equal(sample.facing_left, direction < 0);
      if (!frames.has(sample.frame)) {
        const {data} = await cdp("Page.captureScreenshot", {format: "png", clip: {x: 0, y: 440, width: 640, height: 260, scale: 1}});
        const after = await state();
        if (after.clip === "walk" && after.frame === sample.frame) {
          await writeFile(`${output}/${hero}-${label}-${sample.frame}.png`, Buffer.from(data, "base64"));
          frames.add(sample.frame);
        }
      }
      if ((direction > 0 && sample.position[0] >= 240) || (direction < 0 && sample.position[0] <= 48)) break;
      await delay(20);
    }
  } finally {
    await evaluate("clearTimeout(window.__walkRelease); window.__walkPad.axes[0] = 0");
  }
  const stopped = await waitState(s => Math.abs(s.velocity[0]) < 0.01, "Released gamepad stops movement");
  assert.ok(direction * (stopped.position[0] - before.position[0]) > 0, "Actual player position follows the gamepad.");
  assert.deepEqual([...frames].sort(), [0, 1, 2, 3, 4, 5, 6, 7], "Every walking frame appears in rendered gameplay.");
  observations.push({hero, direction: label, environment, frames: [...frames].sort(), before, stopped, trace});
}

try {
  for (const hero of ["man", "woman"]) {
    for (const name of ["start", "paused"]) await rm(`${output}/${hero}-${name}.png`, {force: true});
    for (const direction of ["right", "left"]) {
      await rm(`${output}/${hero}-${direction}-sheet.png`, {force: true});
      for (let frame = 0; frame < 8; frame++) {
        await rm(`${output}/${hero}-${direction}-${frame}.png`, {force: true});
      }
    }
  }
  for (const name of ["walking.json", "walking-partial.json", "failure.png"]) await rm(`${output}/${name}`, {force: true});
  await cdp("Page.enable");
  // The existing mobile regression deliberately leaves a failed-resource page.
  await cdp("Page.navigate", {url: "about:blank"});
  await cdp("Runtime.discardConsoleEntries");
  await cdp("Runtime.enable");
  await cdp("Network.enable");
  await cdp("Network.setCacheDisabled", {cacheDisabled: true});
  await cdp("Emulation.setDeviceMetricsOverride", {width: 960, height: 720, deviceScaleFactor: 1, mobile: false});
  await cdp("Emulation.setTouchEmulationEnabled", {enabled: false});
  ({identifier: initScriptId} = await cdp("Page.addScriptToEvaluateOnNewDocument", {source: `
    window.__walkPad = {
      id: "Midcreek animation test controller", index: 0, connected: false, mapping: "standard",
      axes: [0, 0, 0, 0], timestamp: 0,
      buttons: Array.from({length: 17}, () => ({pressed: false, touched: false, value: 0}))
    };
    Object.defineProperty(navigator, "getGamepads", {configurable: true, value: () => {
      window.__walkPad.timestamp = performance.now();
      return window.__walkPad.connected ? [window.__walkPad] : [];
    }});
    window.__connectWalkPad = () => {
      window.__walkPad.connected = true;
      const event = new Event("gamepadconnected");
      Object.defineProperty(event, "gamepad", {value: window.__walkPad});
      window.dispatchEvent(event);
    };
  `}));
  for (const hero of ["man", "woman"]) {
    // This origin belongs to the isolated test browser, never the user's browser profile.
    await cdp("Page.navigate", {url: "about:blank"});
    await cdp("Storage.clearDataForOrigin", {origin: new URL(url).origin, storageTypes: "all"});
    await cdp("Page.navigate", {url: debugUrl.href});
    await waitState(s => s.screen === "title", "Debug animation probe starts");
    await evaluate('document.querySelector("canvas").focus()');
    await key("Enter", 13);
    const selection = await waitState(s => s.screen === "character_select", "Character selection opens");
    if (selection.character !== hero) await key("Tab", 9, hero === "man" ? 8 : 0);
    await key("Enter", 13);
    await waitState(s => s.screen === "level_select" && s.character === hero, "Requested hero is selected");
    await key("Enter", 13);
    await waitState(s => s.screen === "level" && s.level_id === "01", "First work order starts");
    await screenshot(hero + "-start");
    await evaluate("window.__connectWalkPad()");
    await walk(hero, 1);
    await walk(hero, -1);
    await key("Escape", 27);
    await waitState(s => s.paused, "Pause still works after gamepad movement");
    await screenshot(hero + "-paused");
    await key("Escape", 27);
    await waitState(s => !s.paused && Math.abs(s.velocity[0]) < 0.01, "Resume does not repeat released movement");
  }
  await cdp("Page.removeScriptToEvaluateOnNewDocument", {identifier: initScriptId});
  initScriptId = undefined;
  await cdp("Page.navigate", {url});
  for (let i = 0; i < 200; i++) {
    if (await evaluate('document.querySelector("#status") === null')) break;
    await delay(100);
  }
  assert.equal(await evaluate('document.querySelector("#status") === null'), true, "The ordinary URL starts.");
  await evaluate("new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve)))");
  assert.equal(await evaluate("typeof window.midcreekAnimationProbe"), "undefined", "Ordinary browser launches do not publish probe data.");
  assert.equal(await evaluate("typeof window.__walkPad"), "undefined", "The emulated controller hook is removed after the test.");
  assert.deepEqual(browser.errors, [], "No browser script exceptions.");
  assert.deepEqual(browser.consoleErrors, [], "No runtime console errors.");
  await writeFile(`${output}/walking.json`, JSON.stringify(observations, null, 2));
  console.log("ANIMATION_BROWSER_TEST_COMPLETE: both heroes, all eight frames, both directions, pause and release passed with an emulated gamepad.");
} catch (error) {
  try {
    await screenshot("failure");
  } catch (captureError) {
    console.error("Could not capture the failed browser state:", captureError.message);
  }
  await writeFile(`${output}/walking-partial.json`, JSON.stringify(observations, null, 2));
  throw error;
} finally {
  try {
    if (initScriptId) await cdp("Page.removeScriptToEvaluateOnNewDocument", {identifier: initScriptId});
  } finally {
    await browser.disconnect();
  }
}
