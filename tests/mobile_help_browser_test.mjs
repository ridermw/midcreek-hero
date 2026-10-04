import assert from "node:assert/strict";
import {mkdir, rm} from "node:fs/promises";
import {createRequire} from "node:module";
import path from "node:path";

// Usage: node tests/mobile_help_browser_test.mjs /path/to/installed/playwright
const profile = path.resolve(`.help-browser-check-${process.pid}`);
await mkdir(profile);
process.env.TMPDIR = profile;
const require = createRequire(import.meta.url);
let context;
try {
  const {chromium} = require(process.argv[2] || "playwright");
  context = await chromium.launchPersistentContext(path.join(profile, "profile"), {
    channel: "msedge", headless: true, viewport: {width: 844, height: 390},
    screen: {width: 844, height: 390}, isMobile: true, hasTouch: true,
    downloadsPath: path.join(profile, "downloads"),
  });
  const page = context.pages()[0];
  const errors = [];
  page.on("pageerror", error => errors.push(error.message));
  await page.setContent('<html><head><meta name="viewport" content="width=device-width, initial-scale=1"></head><body><canvas id="canvas"></canvas></body></html>');
  await page.addStyleTag({path: path.resolve("web/mobile.css")});
  await page.addScriptTag({path: path.resolve("web/mobile.js")});
  await page.evaluate(() => {
    const actions = ["Left", "Right", "Up", "Down", "Jump", "Slide", "Repair", "Diagnose", "Pause"];
    const image = "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9Wl6HQAAAABJRU5ErkJggg==";
    const controls = [
      {id: "previous", kind: "button", text: "Previous", disabled: false},
      {id: "next", kind: "button", text: "Next", disabled: false},
      {id: "back", kind: "button", text: "Back", disabled: false},
    ];
    window.helpModels = [
      {screen: "help", revision: 1, paused: false, controls, summary: "", help: {
        id: "controls", title: "Controls", page: 1, count: 6,
        instructions: "Choose the control display in Settings. All input devices still work.",
        controls: actions.map(label => ({
          graphic: {shape: "touch", label}, description: `Use ${label} to move or work in the data hall.`,
        })), demo: {},
      }},
      {screen: "help", revision: 2, paused: false, controls, summary: "", help: {
        id: "repair", title: "Repair a rack", page: 2, count: 6, controls: [],
        instructions: "1. Stand beside a red rack.\n2. Hold Repair until the work completes. Letting go cancels progress.\n3. A green rack is finished.",
        demo: {images: {hero: image, "props/psu": image}, clips: {primary: {fps: 1, frames: ["hero"]}},
          steps: [{seconds: 2, clip: "primary", from: 280, to: 280, props: [], carry: false,
            prompt: {action: "repair", intent: "hold", display: "touch", description: "Hold Repair to repair the rack",
              graphic: {shape: "touch", label: "Repair"}}}]},
      }},
    ];
    window.currentHelp = 0;
    MidcreekTouch.connectGame(json => {
      const command = JSON.parse(json);
      if (command.type !== "menu") return;
      currentHelp = command.id === "next" ? 1 : 0;
      helpModels[currentHelp].revision = command.revision + 1;
      MidcreekTouch.render(JSON.stringify(helpModels[currentHelp]));
    });
    MidcreekTouch.render(JSON.stringify(helpModels[0]));
  });
  const menu = page.locator("#mobile-menu");
  await menu.evaluate(node => { node.scrollTop = node.scrollHeight; });
  assert.ok(await menu.evaluate(node => node.scrollTop > 0), "Controls page must actually be scrolled before navigation.");
  await page.getByRole("button", {name: "Next", exact: true}).click();
  assert.match(await page.locator("#mobile-menu h2").textContent(), /Repair a rack/);
  assert.equal(await menu.evaluate(node => node.scrollTop), 0, "Next must open the new help page at the top.");
  const demoBox = await page.locator("canvas.help-demo").boundingBox();
  assert.ok(demoBox.y >= 0 && demoBox.y < 390, "The new demonstration must be visible.");
  assert.equal(await page.evaluate(() => document.activeElement.textContent), "Previous", "Navigation keeps its focus behavior.");

  await menu.evaluate(node => { node.scrollTop = 150; });
  const readingPosition = await menu.evaluate(node => node.scrollTop);
  assert.ok(readingPosition > 0);
  await page.evaluate(() => MidcreekTouch.render(JSON.stringify(helpModels[1])));
  assert.equal(await menu.evaluate(node => node.scrollTop), readingPosition, "Periodic same-page updates must preserve reading position.");
  await page.evaluate(() => {
    helpModels[1].revision++;
    MidcreekTouch.render(JSON.stringify(helpModels[1]));
  });
  assert.equal(await menu.evaluate(node => node.scrollTop), readingPosition, "Same-page menu refresh must preserve reading position.");
  await page.getByRole("button", {name: "Previous", exact: true}).click();
  assert.equal(await menu.evaluate(node => node.scrollTop), 0, "Previous must also open its destination at the top.");
  await page.getByRole("button", {name: "Next", exact: true}).click();
  assert.match(await menu.innerText(), /Hold Repair to repair the rack/, "Help keeps the full visible action purpose.");
  await page.evaluate(() => {
    MidcreekTouch.render(JSON.stringify({screen: "level", revision: 100, paused: false, summary: "", controls: [],
      prompt: {action: "jump", intent: "press", display: "keyboard", description: "Press Space to jump cables",
        text: "jump cables", status: "", pulse: true, graphic: {shape: "keycap", label: "Space"}}}));
  });
  assert.equal(await page.locator("#mobile-prompt .control-graphic").innerText(), "Space", "Live gameplay keeps the graphical key.");
  const announcement = page.locator("#mobile-prompt [role=status]");
  assert.equal(await announcement.textContent(), "Press Space to jump cables", "Full live instructions are real status text, not only an accessible label.");
  const announcementBox = await announcement.boundingBox();
  assert.ok(announcementBox.width <= 1 && announcementBox.height <= 1, "The full live description is visually hidden.");
  assert.equal(await page.locator("#mobile-prompt .hint-visible").textContent(), "", "Visible press hints do not repeat prose.");
  assert.equal(await page.locator("#mobile-prompt .hint-visible").getAttribute("role"), null, "Compact visible text is not a second live region.");
  await page.evaluate(() => {
    window.liveModel = {screen: "level", revision: 100, paused: false, summary: "", controls: [],
      prompt: {action: "repair", intent: "hold", display: "touch", description: "Hold Repair to repair",
        status: "", pulse: true, graphic: {shape: "touch", label: "Repair"}}};
    MidcreekTouch.render(JSON.stringify(liveModel));
    window.announcements = [];
    const status = document.querySelector("#mobile-prompt [role=status]");
    new MutationObserver(() => announcements.push(status.textContent)).observe(status, {childList: true, characterData: true, subtree: true});
  });
  await page.evaluate(() => {
    liveModel.prompt.description = "Hold Repair to install the PSU";
    MidcreekTouch.render(JSON.stringify(liveModel));
  });
  assert.equal(await page.locator("#mobile-prompt .hint-visible").textContent(), "Hold");
  await page.evaluate(() => {
    liveModel.prompt.held = true;
    liveModel.prompt.pulse = false;
    MidcreekTouch.render(JSON.stringify(liveModel));
    MidcreekTouch.render(JSON.stringify(liveModel));
  });
  assert.deepEqual(await page.evaluate(() => announcements), ["Hold Repair to install the PSU"], "The live region mutates once for purpose, never for held/pulse refresh.");
  assert.deepEqual(errors, [], "Browser must remain free of page errors.");
  console.log("MOBILE_HELP_BROWSER_TEST_COMPLETE: scroll navigation, stable refresh and focus passed");
} finally {
  await context?.close();
  await rm(profile, {recursive: true, force: true});
}
