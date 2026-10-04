const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");
const vm = require("node:vm");

const shell = fs.readFileSync(path.join(__dirname, "../web/shell.html"), "utf8");
const startup = shell.match(/<script>([\s\S]*?)<\/script>/)[1]
  .replaceAll("$GODOT_CONFIG", "{}")
  .replaceAll("$GODOT_THREADS_ENABLED", "false");

function boot({missing = [], error = null} = {}) {
  const nodes = new Map();
  for (const id of ["status", "status-progress", "status-notice", "canvas"]) {
    nodes.set(id, {
      style: {}, textContent: "", removed: false,
      remove() { this.removed = true; },
      removeAttribute(name) { delete this[name]; },
    });
  }
  const messages = [];
  let progress;
  let resolve;
  const ready = new Promise(r => { resolve = r; });
  class Engine {
    static getMissingFeatures() { return missing; }
    startGame(options) {
      progress = options.onProgress;
      return ready.then(() => { if (error) throw error; });
    }
  }
  vm.runInNewContext(startup, {
    Engine, Error,
    window: {MidcreekTouch: {enabled: false}},
    console: {error: message => messages.push(message)},
    document: {getElementById: id => nodes.get(id)},
  });
  return {nodes, messages, progress, finish: async () => {
    resolve();
    await new Promise(r => setImmediate(r));
  }};
}

test("loading brand has a useful accessible name", () => {
  const image = shell.match(/<img\b[^>]*id="status-splash"[^>]*>/)[0];
  assert.match(image, /alt="Midcreek Hero"/);
});

test("exported splash markup does not depend on unsupported exporter placeholders", () => {
  const image = shell.match(/<img\b[^>]*id="status-splash"[^>]*>/)[0]
    .replaceAll("$GODOT_SPLASH", "index.png");
  assert.match(image, /src="index.png"/);
  assert.doesNotMatch(image, /index\.png_/);
});

test("loading overlay reports progress and disappears only after startup succeeds", async () => {
  const app = boot();
  assert.equal(app.nodes.get("status").style.visibility, "visible");
  assert.equal(app.nodes.get("status").removed, false);
  app.progress(50, 100);
  assert.equal(app.nodes.get("status-progress").value, 50);
  assert.equal(app.nodes.get("status-progress").max, 100);
  app.progress(0, 0);
  assert.equal("value" in app.nodes.get("status-progress"), false);
  await app.finish();
  assert.equal(app.nodes.get("status").removed, true);
});

test("failed startup retains branding and displays its reason", async () => {
  const app = boot({error: new Error("Game download failed")});
  await app.finish();
  assert.equal(app.nodes.get("status").removed, false);
  assert.equal(app.nodes.get("status-notice").textContent, "Game download failed");
  assert.equal(app.nodes.get("status-notice").style.display, "block");
  assert.equal(app.nodes.get("status-progress").style.display, "none");
  assert.equal(app.messages.length, 1);
});

test("unsupported browsers show a visible explanation before starting", () => {
  const app = boot({missing: ["WebGL 2"]});
  assert.match(app.nodes.get("status-notice").textContent, /WebGL 2/);
  assert.equal(app.nodes.get("status").style.visibility, "visible");
  assert.equal(app.progress, undefined);
});
