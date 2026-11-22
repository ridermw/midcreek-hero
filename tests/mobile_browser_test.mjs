import assert from "node:assert/strict";
import {mkdir, writeFile} from "node:fs/promises";
import {connectBrowser} from "./browser_cdp.mjs";

// Use only the dedicated agent-browser session started for this test.
const [endpoint, url, output] = process.argv.slice(2);
assert.ok(endpoint?.startsWith("ws://127.0.0.1:"), "Supply the agent-browser CDP endpoint.");
assert.ok(url?.startsWith("http://127.0.0.1:"), "Supply the local game URL.");
assert.ok(output, "Supply an evidence directory.");
await mkdir(output, {recursive: true});
const browser = await connectBrowser(endpoint, url);
const {cdp, evaluate, errors} = browser;
const regressions = [];
const delay = ms => new Promise(resolve => setTimeout(resolve, ms));
// Above the 24 px WCAG minimum. Standard menu buttons reach about 43 px on a 390 px tall phone.
const MIN_GAME_TARGET = 28;
async function wait(expression) {
  for (let i = 0; i < 100; i++) {
    if (await evaluate(expression)) return;
    await delay(100);
  }
  await screenshot("failure");
  console.error(await evaluate('JSON.stringify({width:innerWidth,height:innerHeight,body:document.body.innerText,buttons:[...document.querySelectorAll("#mobile-menu button")].map(b=>({text:b.textContent,disabled:b.disabled,rect:b.style.cssText})),scripts:[...document.scripts].map(s=>s.src)})'));
  throw new Error("Timed out: " + expression);
}
async function dimensions(width, height) {
  await cdp("Emulation.setDeviceMetricsOverride", {
    width, height, screenWidth: width, screenHeight: height, deviceScaleFactor: 1, mobile: true,
    screenOrientation: {type: width > height ? "landscapePrimary" : "portraitPrimary", angle: width > height ? 90 : 0},
  });
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
async function moveTouches(touchPoints) {
  const before = await evaluate("window.touchMoves");
  await cdp("Input.dispatchTouchEvent", {type: "touchMove", touchPoints});
  await wait(`window.touchMoves > ${before}`);
}
// Menus are drawn by the game. Each screen reader twin sits over its in-game control and lets taps reach the canvas.
async function gamePoint(selector, text) {
  const expression = `(() => {
    const node = [...document.querySelectorAll(${JSON.stringify(selector)})].find(n => n.textContent === ${JSON.stringify(text)});
    if (!node) return null;
    const r = node.getBoundingClientRect();
    const x = r.x + r.width / 2, y = r.y + r.height / 2;
    return {x, y, width: r.width, height: r.height, onCanvas: document.elementFromPoint(x, y) === document.querySelector("#canvas"),
      inside: r.left >= 0 && r.top >= 0 && r.right <= innerWidth && r.bottom <= innerHeight};
  })()`;
  await wait(expression + "?.onCanvas");
  // The game republishes control positions shortly after a resize or rotation.
  let box;
  for (let i = 0; i < 30; i++) {
    box = await evaluate(expression);
    if (box?.onCanvas && box.inside && box.width >= MIN_GAME_TARGET && box.height >= MIN_GAME_TARGET) break;
    await delay(100);
  }
  assert.ok(box.inside, text + " is on screen");
  assert.ok(box.width >= MIN_GAME_TARGET && box.height >= MIN_GAME_TARGET, `${text} is a usable in-game touch target (${box.width} x ${box.height}).`);
  return {x: box.x, y: box.y, width: box.width, id: 1};
}
async function menuButton(text, selector = "#mobile-menu button") {
  const p = await gamePoint(selector, text);
  await cdp("Input.dispatchTouchEvent", {type: "touchStart", touchPoints: [p]});
  await delay(60);
  await cdp("Input.dispatchTouchEvent", {type: "touchEnd", touchPoints: []});
}
async function mirror(text) {
  await wait(`document.querySelector("#mobile-menu")?.textContent.includes(${JSON.stringify(text)})`);
}
async function checkMenuLayout(name) {
  const layout = await evaluate(`(() => {
    const canvas = document.querySelector("#canvas");
    const r = canvas.getBoundingClientRect();
    const menu = document.querySelector("#mobile-menu");
    const twins = [...menu.querySelectorAll("button, label")];
    return {game: [r.x, r.y, r.width, r.height], viewport: [innerWidth, innerHeight], visible: getComputedStyle(canvas).visibility,
      mirrorOpacity: getComputedStyle(menu).opacity, twins: twins.length,
      blocked: twins.filter(n => { const b = n.getBoundingClientRect(); return document.elementFromPoint(b.x + b.width / 2, b.y + b.height / 2) !== canvas && b.top >= 0 && b.bottom <= innerHeight; }).map(n => n.textContent),
      pause: !document.querySelector("#mobile-pause")?.hidden,
      fullscreen: !document.fullscreenEnabled || document.querySelector("#mobile-fullscreen")?.getBoundingClientRect().height >= 44};
  })()`);
  assert.equal(layout.visible, "visible", name + " is drawn by the game.");
  assert.deepEqual(layout.game, [0, 0, ...layout.viewport], name + " fills the phone screen.");
  assert.equal(layout.mirrorOpacity, "0", name + " has no visible HTML copy.");
  assert.ok(layout.twins > 0, name + " keeps screen reader controls.");
  assert.deepEqual(layout.blocked, [], name + " passes taps on its controls through to the game.");
  assert.equal(layout.pause, false, "Pause shows only during play.");
  assert.ok(layout.fullscreen, "Full screen stays available on menus.");
}
async function checkRotateNotice(paused) {
  const notice = await evaluate(`(() => {
    const node = document.querySelector("#mobile-rotate");
    const r = node.getBoundingClientRect();
    return {covers: !node.hidden && r.width >= innerWidth - 1 && r.height >= innerHeight - 1 && node.contains(document.elementFromPoint(innerWidth / 2, innerHeight / 2)),
      text: node.textContent, menuHidden: document.querySelector("#mobile-menu").hidden};
  })()`);
  assert.ok(notice.covers, "Portrait shows a full screen rotate notice.");
  assert.equal(notice.text.includes("paused"), paused, "Only gameplay mentions the pause.");
  assert.ok(notice.menuHidden, "Portrait hides menu controls from screen readers too.");
}
async function screenshot(name) {
  const {data} = await cdp("Page.captureScreenshot", {format: "png"});
  await writeFile(`${output}/${name}.png`, Buffer.from(data, "base64"));
}
async function checkPlayLayout() {
  const layout = await evaluate(`(() => {
    const canvas = document.querySelector("#canvas");
    const game = canvas.getBoundingClientRect();
    const safe = document.querySelector("#mobile-shell").getBoundingClientRect();
    const zone = document.querySelector(".stick-zone").getBoundingClientRect();
    const jump = document.querySelector('[data-action="jump"]').getBoundingClientRect();
    const buttons = [...document.querySelectorAll(".play-tools button, .action-pad button:not([hidden])")];
    return {
      viewport: [innerWidth, innerHeight], zoom: visualViewport.scale, game: [game.x, game.y, game.width, game.height],
      bufferAspect: canvas.width / canvas.height,
      edgeGaps: [zone.left - safe.left, safe.right - jump.right, safe.bottom - jump.bottom],
      jumpRatio: [jump.width / 60, jump.height / Math.min(56, Math.max(44, innerHeight * .12))],
      unreachable: buttons.filter(b => {
        const r = b.getBoundingClientRect();
        return r.width < 44 || r.height < 44 || r.left < safe.left || r.right > safe.right ||
          r.top < safe.top || r.bottom > safe.bottom ||
          !b.contains(document.elementFromPoint(r.x + r.width / 2, r.y + r.height / 2));
      }).map(b => b.outerHTML),
      translucent: buttons.every(b => getComputedStyle(b).backgroundColor.startsWith("rgba(")),
    };
  })()`);
  const [w, h] = layout.viewport;
  assert.ok(Math.abs(layout.zoom - 1) < 0.01, `Resizing must not shrink the page and touch targets (scale ${layout.zoom}).`);
  assert.deepEqual(layout.game, [0, 0, w, h], "Gameplay fills the viewport, including behind safe areas.");
  assert.ok(Math.abs(layout.bufferAspect - w / h) < 0.01, "The render buffer matches the phone aspect without stretching.");
  assert.ok(layout.edgeGaps.every(n => n >= 0 && n <= 20), "The stick zone and Jump hug the safe edges.");
  assert.ok(layout.jumpRatio.every(n => Math.abs(n - 1.5) < .01), "Jump is 1.5 times the old width and height.");
  assert.deepEqual(layout.unreachable, [], "All controls remain separate, reachable touch targets inside the safe area.");
  assert.ok(layout.translucent, "The game remains visible through the controls.");
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
  await checkRotateNotice(false);
  await screenshot("phone-portrait-title");
  await dimensions(844, 390);
  await wait('document.querySelector("#mobile-rotate").hidden');
  await gamePoint("#mobile-menu button", "Start");
  await checkMenuLayout("The title");
  if (!await evaluate('document.querySelector("#mobile-menu").textContent.includes("Tap Start")')) regressions.push("The title still asks touch players for a key.");
  await screenshot("phone-title");
  await menuButton("How to Play");
  await mirror("Touch the left half of the screen");
  await checkMenuLayout("How to Play");
  await screenshot("phone-help-controls");
  await menuButton("Next");
  await mirror("Repair a rack");
  await delay(1500);
  await screenshot("phone-help-demo");
  await menuButton("Back");
  await mirror("Tap Start");
  await menuButton("Settings");
  await wait('document.querySelector("#mobile-menu input") !== null');
  await checkMenuLayout("Settings");
  const before = await evaluate('Number(document.querySelector("#mobile-menu input").value)');
  const {width, ...slider} = await gamePoint("#mobile-menu label", await evaluate('document.querySelector("#mobile-menu label").textContent'));
  // Saved settings persist between runs, so tap the far side of the current value.
  const lower = before > 0.5;
  await cdp("Input.dispatchTouchEvent", {type: "touchStart", touchPoints: [{...slider, x: slider.x + (lower ? -0.4 : 0.4) * width}]});
  await delay(60);
  await cdp("Input.dispatchTouchEvent", {type: "touchEnd", touchPoints: []});
  await wait(`Number(document.querySelector("#mobile-menu input").value) ${lower ? "<" : ">"} ${before}`);
  await wait('window.__audioContexts.length > 0 && window.__audioContexts.every(c => c.state === "running")');
  await evaluate('window.savedSlider = document.querySelector("#mobile-menu input")');
  await dimensions(844, 386);
  await delay(250);
  if (!await evaluate('window.savedSlider === document.querySelector("#mobile-menu input")')) regressions.push("Minor viewport resize replaces the active settings slider.");
  await evaluate('MidcreekTouch.reportError("Test expired command")');
  if (!await evaluate('[...document.querySelectorAll(\'[role="alert"]\')].some(n => n.getBoundingClientRect().height > 0 && n.textContent.includes("Test expired command"))')) regressions.push("Menu errors are not visible.");
  await screenshot("phone-settings");
  // The banner overlaps in-game controls, so one tap must clear it.
  await tap("#mobile-error button");
  await wait('document.querySelector("#mobile-error").hidden');
  await menuButton("Back");
  await wait('document.querySelector("#mobile-menu button")?.textContent === "Start"');
  await menuButton("Start");
  await mirror("Woman");
  await screenshot("phone-characters");
  await menuButton("Woman");
  await mirror("01  Cold Aisle");
  await checkMenuLayout("Work orders");
  await screenshot("phone-work-orders");
  await menuButton("01  Cold Aisle Onboarding");
  await wait('document.body.classList.contains("mobile-playing")');
  await dimensions(390, 844);
  await mirror("Resume");
  await checkRotateNotice(true);
  await screenshot("phone-portrait-pause");
  await dimensions(844, 390);
  await wait('document.querySelector("#mobile-rotate").hidden');
  await checkMenuLayout("Pause");
  await screenshot("phone-pause");
  await menuButton("Resume");
  await wait('document.body.classList.contains("mobile-playing")');
  assert.equal(await evaluate('document.querySelector("#mobile-prompt").textContent.includes("A / D")'), false, "Mobile prompts do not require a keyboard.");
  await checkPlayLayout();
  await screenshot("phone-gameplay");
  await tap("#mobile-tasks summary");
  await wait('document.querySelector("#mobile-tasks[open]")?.innerText.includes("Repair rack A12")');
  await tap("#mobile-tasks summary");
  await wait('document.querySelector(\'#mobile-prompt [role="status"]\')?.textContent === "Drag right to run right"');
  assert.equal(await evaluate('document.querySelector("#mobile-prompt .hint-visible").textContent'), "", "Steering does not add a visible caption.");
  assert.deepEqual(await evaluate('[...document.querySelectorAll(".action-pad button:not([hidden])")].map(b => b.dataset.action)'), ["jump"]);
  const repeatedMutations = await evaluate(`new Promise(resolve => {
    const node = document.querySelector('#mobile-prompt [role="status"]');
    let count = 0;
    const observer = new MutationObserver(records => { count += records.length; });
    observer.observe(node, {childList: true, characterData: true, subtree: true});
    setTimeout(() => { observer.disconnect(); resolve({count, text: node.textContent}); }, 350);
  })`);
  assert.equal(repeatedMutations.text, "Drag right to run right", "The directional alternative keeps its accessible description.");
  if (repeatedMutations.count !== 0) regressions.push("Unchanged live prompt mutates repeatedly.");
  const origin = {x: 120, y: 290, id: 1};
  const right = {...origin, x: origin.x + 45}, left = {...origin, x: origin.x - 45};
  const jump = {...await point('[data-action="jump"]'), id: 2};
  await evaluate('window.touchMoves = 0; document.addEventListener("pointermove", () => { window.touchMoves++; }, true)');
  assert.ok(await evaluate('document.querySelector(".stick-ring").hidden'), "No idle joystick covers the level.");
  await cdp("Input.dispatchTouchEvent", {type: "touchStart", touchPoints: [origin]});
  assert.ok(await evaluate('!document.querySelector(".stick-ring").hidden && !document.querySelector(\'[aria-pressed="true"]\')'), "Touch anchors a neutral joystick.");
  await moveTouches([right]);
  await cdp("Input.dispatchTouchEvent", {type: "touchStart", touchPoints: [right, jump]});
  await delay(150);
  assert.equal(await evaluate('document.querySelectorAll(\'[aria-pressed="true"]\').length'), 2, "Two fingers hold independent actions.");
  await screenshot("phone-move-jump");
  await moveTouches([origin, jump]);
  assert.equal(await evaluate('document.querySelectorAll(\'[aria-pressed="true"]\').length'), 1, "Returning to center releases movement but keeps Jump held.");
  await moveTouches([left, jump]);
  if (!await evaluate('document.querySelector(\'[data-action="move_left"]\').getAttribute("aria-pressed") === "true"')) {
    regressions.push("A finger cannot reverse the joystick through its center.");
  }
  await cdp("Input.dispatchTouchEvent", {type: "touchCancel", touchPoints: []});
  assert.equal(await evaluate('document.querySelectorAll(\'[aria-pressed="true"]\').length'), 0, "Cancellation releases both actions.");
  assert.ok(await evaluate('document.querySelector(".stick-ring").hidden'), "Cancellation hides the joystick.");
  await cdp("Input.dispatchTouchEvent", {type: "touchStart", touchPoints: [jump]});
  await moveTouches([{x: 422, y: 100, id: 2}]);
  assert.equal(await evaluate('document.querySelectorAll(\'[aria-pressed="true"]\').length'), 0, "Dragging off Jump releases it.");
  await cdp("Input.dispatchTouchEvent", {type: "touchEnd", touchPoints: []});
  await cdp("Input.dispatchTouchEvent", {type: "touchStart", touchPoints: [right]});
  await evaluate("MidcreekTouch.releaseAll()");
  await moveTouches([left]);
  assert.equal(await evaluate('document.querySelectorAll(\'[aria-pressed="true"]\').length'), 0, "A cleared contact cannot resume without another press.");
  await cdp("Input.dispatchTouchEvent", {type: "touchEnd", touchPoints: []});
  await cdp("Input.dispatchTouchEvent", {type: "touchStart", touchPoints: [origin]});
  await moveTouches([right]);
  await wait('document.querySelector(\'.action-pad [data-action="repair"]:not([hidden])\') !== null');
  const repair = {...await point('[data-action="repair"]'), id: 2};
  await cdp("Input.dispatchTouchEvent", {type: "touchStart", touchPoints: [right, repair]});
  await moveTouches([origin, repair]);
  await wait('document.querySelector("#mobile-tasks").textContent.includes("[x] Repair rack A12")');
  await wait('document.querySelector(\'[data-action="repair"]\').hidden');
  assert.equal(await evaluate('document.querySelector(\'[data-action="repair"]\').getAttribute("aria-pressed")'), "false", "Finishing a rack releases its context button even before the finger lifts.");
  await cdp("Input.dispatchTouchEvent", {type: "touchEnd", touchPoints: []});
  await evaluate('document.querySelector(\'[data-action="move_up"]\').click()');
  await delay(100);
  if (!await evaluate('document.querySelector(\'[data-action="move_up"]\').getAttribute("aria-pressed") === "true"')) regressions.push("Assistive activation cannot hold movement.");
  await evaluate(`window.orientationEvents = 0;
    screen.orientation.addEventListener("change", () => { window.orientationEvents++; });`);
  await cdp("Emulation.setDeviceMetricsOverride", {
    width: 844, height: 390, screenWidth: 844, screenHeight: 390, deviceScaleFactor: 1, mobile: true,
    screenOrientation: {type: "landscapeSecondary", angle: 270},
  });
  await wait("screen.orientation.angle === 270 && window.orientationEvents > 0");
  if (!await evaluate('document.querySelector(\'[data-action="move_up"]\').getAttribute("aria-pressed") === "false"')) regressions.push("A 180 degree landscape rotation retains held movement.");
  await evaluate("MidcreekTouch.releaseAll()");
  assert.equal(await evaluate("scrollX === 0 && scrollY === 0"), true, "Play does not scroll the page.");
  await tap("#mobile-pause");
  await mirror("Restart work order");
  await menuButton("Restart work order");
  await wait('document.body.classList.contains("mobile-playing")');
  await cdp("Emulation.setSafeAreaInsetsOverride", {insets: {left: 44, right: 0, top: 0, bottom: 21}});
  await dimensions(667, 375);
  await delay(200);
  assert.equal(await evaluate('document.querySelector(".stick-zone").getBoundingClientRect().left >= 44'), true, "The joystick avoids the notch.");
  await checkPlayLayout();
  await screenshot("phone-small-safe-area");
  await cdp("Emulation.setSafeAreaInsetsOverride", {insets: {left: 0, right: 0, top: 0, bottom: 0}});
  await dimensions(568, 320);
  await delay(200);
  await checkPlayLayout();
  await screenshot("phone-small-landscape");
  await tap("#mobile-fullscreen");
  await wait("document.fullscreenElement === document.documentElement");
  await checkPlayLayout();
  await tap("#mobile-fullscreen");
  await wait("!document.fullscreenElement");
  await dimensions(390, 844);
  await wait('!document.body.classList.contains("mobile-playing")');
  await checkRotateNotice(true);
  await dimensions(844, 390);
  await menuButton("Quit to level select");
  await mirror("01  Cold Aisle");
  if (process.argv.includes("--smoke")) {
    await dimensions(844, 390);
    await cdp("Page.navigate", {url: url + "?route=01"});
    for (let i = 0; i < 1500; i++) {
      if (await evaluate('document.querySelector("#mobile-menu")?.textContent.includes("Work order complete")')) break;
      await delay(100);
    }
    assert.match(await evaluate('document.querySelector("#mobile-menu")?.textContent ?? ""'), /\b[123] stars\b/, "Exported route reaches mobile results regardless of rating.");
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
  await wait('document.querySelector("#status") === null && document.querySelector(\'[role="alert"]\')');
  assert.equal(await evaluate('document.querySelector(\'[role="alert"]\')?.textContent.includes("touch interface")'), true, "Missing touch resources report an error without blocking desktop.");
  await cdp("Network.setBlockedURLs", {urls: []});
  assert.deepEqual(regressions, []);
  assert.deepEqual(errors, [], "No browser script exceptions.");
  console.log("MOBILE_BROWSER_TEST_COMPLETE: in-game phone menus, touch help, settings, orientation, real multitouch, cancellation, all actions and restart passed.");
} finally {
  await browser.disconnect();
}
