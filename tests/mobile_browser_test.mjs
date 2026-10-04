import assert from "node:assert/strict";
import {mkdir, writeFile} from "node:fs/promises";

// Use only the dedicated agent-browser session started for this test.
const [endpoint, url, output] = process.argv.slice(2);
assert.ok(endpoint?.startsWith("ws://127.0.0.1:"), "Supply the agent-browser CDP endpoint.");
assert.ok(url?.startsWith("http://127.0.0.1:"), "Supply the local game URL.");
assert.ok(output, "Supply an evidence directory.");
await mkdir(output, {recursive: true});
const socket = new WebSocket(endpoint);
await new Promise((resolve, reject) => { socket.onopen = resolve; socket.onerror = reject; });
let sequence = 0;
const requests = new Map();
const errors = [];
const regressions = [];
socket.onmessage = event => {
  const message = JSON.parse(event.data);
  if (message.method === "Runtime.exceptionThrown") errors.push(message.params.exceptionDetails);
  const request = requests.get(message.id);
  if (!request) return;
  requests.delete(message.id);
  if (message.error) request.reject(new Error(JSON.stringify(message.error)));
  else request.resolve(message.result);
};
function send(method, params = {}, sessionId) {
  return new Promise((resolve, reject) => {
    const id = ++sequence;
    requests.set(id, {resolve, reject});
    socket.send(JSON.stringify({id, method, params, sessionId}));
  });
}
const targets = await send("Target.getTargets");
const target = targets.targetInfos.find(item => item.type === "page" && item.url.startsWith(url));
assert.ok(target, "Open the game in the dedicated agent-browser session first.");
const {sessionId} = await send("Target.attachToTarget", {targetId: target.targetId, flatten: true});
const cdp = (method, params) => send(method, params, sessionId);
async function evaluate(expression) {
  const result = await cdp("Runtime.evaluate", {expression, returnByValue: true, awaitPromise: true});
  if (result.exceptionDetails) throw new Error(JSON.stringify(result.exceptionDetails));
  return result.result.value;
}
const delay = ms => new Promise(resolve => setTimeout(resolve, ms));
async function wait(expression) {
  for (let i = 0; i < 100; i++) {
    if (await evaluate(expression)) return;
    await delay(100);
  }
  await screenshot("failure");
  console.error(await evaluate('JSON.stringify({width:innerWidth,height:innerHeight,body:document.body.innerText,buttons:[...document.querySelectorAll("#mobile-menu button")].map(b=>({text:b.textContent,disabled:b.disabled})),scripts:[...document.scripts].map(s=>s.src)})'));
  throw new Error("Timed out: " + expression);
}
async function dimensions(width, height) {
  await cdp("Emulation.setDeviceMetricsOverride", {width, height, screenWidth: width, screenHeight: height, deviceScaleFactor: 1, mobile: true});
}
async function point(selector) {
  const box = await evaluate(`(() => { const node = document.querySelector(${JSON.stringify(selector)}); if (!node) return null; const r = node.getBoundingClientRect(); return {x:r.x,y:r.y,width:r.width,height:r.height}; })()`);
  assert.ok(box, selector + " exists");
  assert.ok(box.width >= 44 && box.height >= 44, selector + " has a usable touch target");
  return {x: box.x + box.width / 2, y: box.y + box.height / 2, id: 1};
}
async function tap(selector) {
  const p = await point(selector);
  await cdp("Input.dispatchTouchEvent", {type: "touchStart", touchPoints: [p]});
  await cdp("Input.dispatchTouchEvent", {type: "touchEnd", touchPoints: []});
}
async function menuButton(text) {
  const selector = await evaluate(`(() => { const buttons = [...document.querySelectorAll("#mobile-menu button")]; const i = buttons.findIndex(b => b.textContent === ${JSON.stringify(text)}); if(i < 0) return null; buttons[i].scrollIntoView({block:"center"}); return "#mobile-menu button:nth-of-type(" + (i+1) + ")"; })()`);
  assert.ok(selector, text + " is reachable");
  await tap(selector);
}
async function screenshot(name) {
  const {data} = await cdp("Page.captureScreenshot", {format: "png"});
  await writeFile(`${output}/${name}.png`, Buffer.from(data, "base64"));
}
try {
  await cdp("Page.enable");
  await cdp("Runtime.enable");
  await cdp("Network.enable");
  await cdp("Network.setCacheDisabled", {cacheDisabled: true});
  await cdp("Page.addScriptToEvaluateOnNewDocument", {source: `
    window.__audioContexts = [];
    const BaseAudioContext = window.AudioContext;
    window.AudioContext = class extends BaseAudioContext {
      constructor(...args) { super(...args); window.__audioContexts.push(this); }
    };
  `});
  await dimensions(390, 844);
  await cdp("Emulation.setTouchEmulationEnabled", {enabled: true, maxTouchPoints: 5});
  errors.length = 0;
  await cdp("Page.navigate", {url});
  await wait('document.querySelector("#mobile-menu button")?.textContent === "Start"');
  assert.equal(await evaluate("MidcreekTouch.enabled"), true);
  await screenshot("phone-title");
  await menuButton("Settings");
  await wait('document.querySelector("#mobile-menu input") !== null');
  await wait('window.__audioContexts.length > 0 && window.__audioContexts.every(c => c.state === "running")');
  await tap("#mobile-menu input");
  await evaluate('window.savedSlider = document.querySelector("#mobile-menu input")');
  await dimensions(390, 840);
  await delay(250);
  if (!await evaluate('window.savedSlider === document.querySelector("#mobile-menu input")')) regressions.push("Minor viewport resize replaces the active settings slider.");
  await evaluate('MidcreekTouch.reportError("Test expired command")');
  if (!await evaluate('[...document.querySelectorAll(\'[role="alert"]\')].some(n => n.getBoundingClientRect().height > 0 && n.textContent.includes("Test expired command"))')) regressions.push("Menu errors are not visible.");
  await screenshot("phone-settings");
  await menuButton("Back");
  await wait('document.querySelector("#mobile-menu button")?.textContent === "Start"');
  await menuButton("Start");
  await wait('document.querySelector("#mobile-menu")?.textContent.includes("Woman")');
  await menuButton("Woman");
  await wait('document.querySelector("#mobile-menu")?.textContent.includes("01  Cold Aisle")');
  await screenshot("phone-work-orders");
  await menuButton("01  Cold Aisle Onboarding");
  await wait('document.querySelector("#mobile-menu")?.textContent.includes("Resume")');
  assert.equal(await evaluate('document.querySelector("#mobile-menu button").disabled'), true, "Portrait cannot resume gameplay.");
  await screenshot("phone-portrait-pause");
  await dimensions(844, 390);
  await wait('document.querySelector("#mobile-menu button")?.disabled === false');
  await menuButton("Resume");
  await wait('document.body.classList.contains("mobile-playing")');
  assert.equal(await evaluate('document.querySelector("#mobile-prompt").textContent.includes("A / D")'), false, "Mobile prompts do not require a keyboard.");
  assert.equal(await evaluate(`(() => {
    const game = document.querySelector("#canvas").getBoundingClientRect();
    return [...document.querySelectorAll("#mobile-controls button, #mobile-prompt")].every(node => {
      const r = node.getBoundingClientRect();
      return r.right <= game.left || r.left >= game.right || r.bottom <= game.top || r.top >= game.bottom;
    });
  })()`), true, "Controls and prompt do not cover the game image.");
  await screenshot("phone-gameplay");
  const right = await point('[data-action="move_right"]');
  const jump = {...await point('[data-action="jump"]'), id: 2};
  await cdp("Input.dispatchTouchEvent", {type: "touchStart", touchPoints: [right]});
  await delay(150);
  await cdp("Input.dispatchTouchEvent", {type: "touchStart", touchPoints: [right, jump]});
  await delay(150);
  assert.equal(await evaluate('document.querySelectorAll(\'[aria-pressed="true"]\').length'), 2, "Two fingers hold independent actions.");
  await screenshot("phone-move-jump");
  await cdp("Input.dispatchTouchEvent", {type: "touchCancel", touchPoints: []});
  assert.equal(await evaluate('document.querySelectorAll(\'[aria-pressed="true"]\').length'), 0, "Cancellation releases both actions.");
  await cdp("Input.dispatchTouchEvent", {type: "touchStart", touchPoints: [right]});
  await cdp("Input.dispatchTouchEvent", {type: "touchMove", touchPoints: [{x: 422, y: 100, id: 1}]});
  assert.equal(await evaluate('document.querySelectorAll(\'[aria-pressed="true"]\').length'), 0, "Dragging off a control releases it.");
  await cdp("Input.dispatchTouchEvent", {type: "touchEnd", touchPoints: []});
  for (const action of ["slide", "move_up", "move_down", "repair", "diagnose"]) await tap(`[data-action="${action}"]`);
  await evaluate('document.querySelector(\'[data-action="repair"]\').click()');
  await delay(100);
  if (!await evaluate('document.querySelector(\'[data-action="repair"]\').getAttribute("aria-pressed") === "true"')) regressions.push("Assistive activation cannot hold Repair.");
  await evaluate('document.querySelector(\'[data-action="repair"]\').click()');
  assert.equal(await evaluate("scrollX === 0 && scrollY === 0"), true, "Play does not scroll the page.");
  await tap("#mobile-pause");
  await wait('document.querySelector("#mobile-menu")?.textContent.includes("Restart work order")');
  await menuButton("Restart work order");
  await wait('document.body.classList.contains("mobile-playing")');
  await cdp("Emulation.setSafeAreaInsetsOverride", {insets: {left: 44, right: 0, top: 0, bottom: 21}});
  await dimensions(667, 375);
  await delay(200);
  assert.equal(await evaluate('document.querySelector(".direction-pad").getBoundingClientRect().left >= 44'), true, "The directional pad avoids the notch.");
  await screenshot("phone-small-safe-area");
  await cdp("Emulation.setSafeAreaInsetsOverride", {insets: {left: 0, right: 0, top: 0, bottom: 0}});
  await dimensions(568, 320);
  await delay(200);
  for (const action of ["jump", "slide", "repair", "diagnose", "move_up", "move_down"]) await point(`[data-action="${action}"]`);
  await screenshot("phone-small-landscape");
  await dimensions(390, 844);
  await wait('!document.body.classList.contains("mobile-playing")');
  await menuButton("Quit to level select");
  await wait('document.querySelector("#mobile-menu")?.textContent.includes("01  Cold Aisle")');
  if (process.argv.includes("--smoke")) {
    await dimensions(844, 390);
    await cdp("Page.navigate", {url: url + "?route=01"});
    for (let i = 0; i < 1500; i++) {
      if (await evaluate('document.querySelector("#mobile-menu")?.textContent.includes("Work order complete")')) break;
      await delay(100);
    }
    assert.equal(await evaluate('document.querySelector("#mobile-menu")?.textContent.includes("3 stars")'), true, "Exported route reaches mobile results.");
    await screenshot("phone-results");
    await menuButton("Retry");
    await wait('document.body.classList.contains("mobile-playing")');
  }
  await cdp("Emulation.setDeviceMetricsOverride", {width: 390, height: 844, screenWidth: 1920, screenHeight: 1080, deviceScaleFactor: 1, mobile: false});
  await cdp("Page.navigate", {url});
  await wait('typeof MidcreekTouch !== "undefined"');
  assert.equal(await evaluate("MidcreekTouch.enabled"), false, "Resized touch laptops keep desktop mode.");
  await cdp("Emulation.setTouchEmulationEnabled", {enabled: false});
  await cdp("Emulation.setDeviceMetricsOverride", {width: 960, height: 720, screenWidth: 1920, screenHeight: 1080, deviceScaleFactor: 1, mobile: false});
  await cdp("Page.navigate", {url});
  await wait('document.querySelector("#status") === null');
  assert.equal(await evaluate('document.querySelector("#mobile-shell") === null'), true, "Desktop has no mobile interface.");
  await screenshot("desktop-title");
  for (let i = 0; i < 3; i++) {
    await cdp("Input.dispatchKeyEvent", {type: "keyDown", key: "Enter", code: "Enter", windowsVirtualKeyCode: 13});
    await cdp("Input.dispatchKeyEvent", {type: "keyUp", key: "Enter", code: "Enter", windowsVirtualKeyCode: 13});
    await delay(300);
  }
  await screenshot("desktop-keyboard-gameplay");
  console.log("UI regressions:", JSON.stringify(regressions));
  await cdp("Network.setBlockedURLs", {urls: ["*mobile.js"]});
  await cdp("Page.navigate", {url});
  await wait('document.querySelector("#status") === null');
  assert.equal(await evaluate('document.querySelector(\'[role="alert"]\')?.textContent.includes("touch interface")'), true, "Missing touch resources report an error without blocking desktop.");
  await cdp("Network.setBlockedURLs", {urls: []});
  assert.deepEqual(regressions, []);
  assert.deepEqual(errors, [], "No browser script exceptions.");
  console.log("MOBILE_BROWSER_TEST_COMPLETE: phone menus, settings, orientation, real multitouch, cancellation, all actions and restart passed.");
} finally {
  await send("Target.detachFromTarget", {sessionId});
  socket.close();
}
