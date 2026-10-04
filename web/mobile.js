(function (root) {
  "use strict";

  function isPhone({touch, coarse, width, height}) {
    return touch > 0 && coarse && Math.min(width, height) <= 600 && Math.max(width, height) <= 1000;
  }

  class TouchState {
    constructor(emit) {
      this.emit = emit;
      this.pointers = new Map();
    }
    press(id, action) {
      if (this.pointers.get(id) === action) return;
      this.release(id);
      const alreadyHeld = [...this.pointers.values()].includes(action);
      this.pointers.set(id, action);
      if (!alreadyHeld) this.emit(action, true);
    }
    release(id) {
      const action = this.pointers.get(id);
      if (!this.pointers.delete(id)) return;
      if (![...this.pointers.values()].includes(action)) this.emit(action, false);
    }
    clear() {
      for (const id of [...this.pointers.keys()]) this.release(id);
    }
  }

  if (typeof module !== "undefined") module.exports = {isPhone, TouchState};
  if (!root.document) return;
  const enabled = isPhone({
    touch: navigator.maxTouchPoints,
    coarse: matchMedia("(pointer: coarse)").matches,
    width: screen.width,
    height: screen.height,
  });
  let callback;
  let model;
  let shell;
  let menu;
  let controls;
  let prompt;
  let status;
  let rotate;
  let notice;
  let revision = -1;
  let lastPortrait;
  let clearing = false;
  const contexts = [];
  const state = new TouchState((action, down) => {
    if (!clearing) send({type: "action", action, down});
    shell?.querySelector(`[data-action="${action}"]`)?.setAttribute("aria-pressed", String(down));
  });

  // Godot owns its audio context. Resume it in the original browser gesture.
  if (enabled) {
    for (const name of ["AudioContext", "webkitAudioContext"]) {
      const Constructor = root[name];
      if (Constructor) root[name] = class extends Constructor {
        constructor(...args) {
          super(...args);
          contexts.push(this);
        }
      };
    }
  }

  function send(command) {
    if (callback) callback(JSON.stringify(command));
  }
  function resumeAudio() {
    for (const context of contexts) {
      if (context.state === "suspended") context.resume().catch(reportError);
    }
  }
  function releaseAll() {
    clearing = true;
    state.clear();
    clearing = false;
    send({type: "clear"});
  }
  function suspend() {
    releaseAll();
    send({type: "suspend"});
  }
  function reportError(error) {
    console.error(error);
    if (notice) {
      notice.textContent = String(error);
      notice.hidden = false;
    }
  }
  function element(tag, text, parent) {
    const node = document.createElement(tag);
    if (text) node.textContent = text;
    parent?.append(node);
    return node;
  }
  function layout() {
    if (!shell) return;
    const portrait = innerHeight > innerWidth;
    if (portrait !== lastPortrait) {
      releaseAll();
      revision = -1;
      lastPortrait = portrait;
    }
    shell.classList.toggle("portrait", portrait);
    if (portrait && model?.screen === "level" && !model.paused) suspend();
    const canvas = document.getElementById("canvas");
    const available = shell.getBoundingClientRect();
    const width = Math.max(1, Math.min(available.width - 264, (available.height - 88) * 4 / 3));
    canvas.style.left = `${available.left + available.width / 2}px`;
    canvas.style.top = `${available.top + available.height / 2 - 8}px`;
    canvas.style.width = `${width}px`;
    canvas.style.height = `${width * 3 / 4}px`;
  }
  function actionButton(action, text, parent) {
    const button = element("button", text, parent);
    button.type = "button";
    button.dataset.action = action;
    button.setAttribute("aria-label", text);
    button.setAttribute("aria-pressed", "false");
    button.addEventListener("pointerdown", event => {
      if (event.pointerType === "mouse" && event.button !== 0) return;
      event.preventDefault();
      resumeAudio();
      button.setPointerCapture(event.pointerId);
      state.press(event.pointerId, action);
    });
    for (const eventName of ["pointerup", "pointercancel", "lostpointercapture"]) {
      button.addEventListener(eventName, event => state.release(event.pointerId));
    }
    button.addEventListener("pointermove", event => {
      if (!state.pointers.has(event.pointerId)) return;
      const target = document.elementFromPoint(event.clientX, event.clientY);
      if (target?.dataset.action) state.press(event.pointerId, target.dataset.action);
      else state.release(event.pointerId);
    });
    // Screen readers activate buttons with click rather than pointer events.
    button.addEventListener("click", event => {
      if (event.detail !== 0) return;
      resumeAudio();
      if (action.startsWith("move_") || action === "repair") {
        const id = `assist-${action}`;
        if (state.pointers.has(id)) state.release(id);
        else state.press(id, action);
      } else {
        send({type: "action", action, down: true});
        send({type: "action", action, down: false});
      }
    });
    return button;
  }
  function build() {
    document.body.classList.add("mobile");
    document.querySelector('meta[name="viewport"]').content = "width=device-width, initial-scale=1, viewport-fit=cover";
    shell = element("main", "", document.body);
    shell.id = "mobile-shell";
    menu = element("section", "", shell);
    menu.id = "mobile-menu";
    controls = element("section", "", shell);
    controls.id = "mobile-controls";
    controls.setAttribute("aria-label", "Game controls");
    const pad = element("div", "", controls);
    pad.className = "direction-pad";
    for (const [action, label] of [["move_up", "Up"], ["move_left", "Left"], ["move_right", "Right"], ["move_down", "Down"]]) {
      actionButton(action, label, pad);
    }
    const actions = element("div", "", controls);
    actions.className = "action-pad";
    for (const [action, label] of [["jump", "Jump"], ["slide", "Slide"], ["repair", "Repair"], ["diagnose", "Diagnose"]]) {
      actionButton(action, label, actions);
    }
    const pause = element("button", "Pause", controls);
    pause.id = "mobile-pause";
    pause.addEventListener("click", () => {
      resumeAudio();
      releaseAll();
      send({type: "pause"});
    });
    status = element("div", "", controls);
    status.id = "mobile-status";
    prompt = element("div", "", controls);
    prompt.id = "mobile-prompt";
    prompt.setAttribute("role", "status");
    rotate = element("p", "Rotate your phone to landscape to play. The game is paused.", shell);
    rotate.id = "mobile-rotate";
    notice = element("p", "", shell);
    notice.id = "mobile-error";
    notice.setAttribute("role", "alert");
    notice.hidden = true;
    shell.addEventListener("contextmenu", event => event.preventDefault());
    addEventListener("blur", suspend);
    document.addEventListener("visibilitychange", () => { if (document.hidden) suspend(); });
    addEventListener("pagehide", suspend);
    addEventListener("resize", layout);
    root.visualViewport?.addEventListener("resize", layout);
    layout();
  }
  function render(json) {
    model = JSON.parse(json);
    const playing = model.screen === "level" && !model.paused;
    document.body.classList.toggle("mobile-playing", playing);
    controls.hidden = !playing;
    menu.hidden = playing;
    rotate.hidden = !(model.screen === "level" && innerHeight > innerWidth);
    if (playing && innerHeight > innerWidth) {
      suspend();
      return;
    }
    status.textContent = model.status || "";
    prompt.textContent = [model.prompt, model.carry].filter(Boolean).join(" | ");
    if (revision === model.revision) return;
    revision = model.revision;
    releaseAll();
    notice.hidden = true;
    menu.replaceChildren();
    element("h1", model.paused ? "Paused" : "Midcreek Hero", menu);
    const summary = model.summary.replace("Press any key or button", "Use the touchscreen controls.");
    if (summary && summary !== "Paused") element("p", summary, menu).className = "menu-summary";
    if (model.paused && model.tasks) element("p", model.tasks, menu).className = "menu-summary";
    for (const item of model.controls) {
      if (item.kind === "button") {
        const button = element("button", item.text, menu);
        button.disabled = item.disabled;
        if (item.text === "Resume" && innerHeight > innerWidth) button.disabled = true;
        button.addEventListener("click", () => {
          resumeAudio();
          send({type: "menu", revision: model.revision, id: item.id});
        });
      } else {
        const label = element("label", item.text, menu);
        const slider = element("input", "", label);
        slider.type = "range";
        for (const key of ["min", "max", "step", "value"]) slider[key] = item[key];
        slider.addEventListener("input", () => {
          resumeAudio();
          send({type: "menu", revision: model.revision, id: item.id, value: Number(slider.value)});
        });
      }
    }
    menu.querySelector("button:not(:disabled), input")?.focus({preventScroll: true});
  }
  root.MidcreekTouch = {
    enabled,
    connectGame(handler) {
      callback = handler;
      if (enabled) build();
    },
    render,
    releaseAll,
    reportError,
  };
})(typeof window === "undefined" ? globalThis : window);
