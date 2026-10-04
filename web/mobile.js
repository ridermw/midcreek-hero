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

  function renderPrompt(text, graphic, buttons, model = {}, carry = "", reducedMotion = false, compact = false, announcement = null, standaloneTouch = false) {
    const description = [model.description, carry].filter(Boolean).join(" | ");
    const visibleText = compact
      ? [model.action && model.intent === "hold" ? "Hold" : "", model.status, carry].filter(Boolean).join(" | ")
      : description;
    if (text.textContent !== visibleText) text.textContent = visibleText;
    if (announcement) {
      if (announcement.textContent !== description) announcement.textContent = description;
    } else if (text.getAttribute("aria-label") !== description) text.setAttribute("aria-label", description);
    const glyph = model.graphic;
    graphic.hidden = !model.action || !glyph || (model.display === "touch" && !standaloneTouch);
    if (!graphic.hidden) {
      graphic.textContent = glyph.label;
      graphic.dataset.shape = glyph.shape;
    }
    graphic.classList.toggle("guidance-pulse", !graphic.hidden && !!model.pulse && !model.held && !reducedMotion);
    for (const button of buttons) {
      const current = model.display === "touch" && button.dataset.action === model.action;
      button.classList.toggle("guidance-cue", current);
      button.classList.toggle("guidance-pulse", current && !!model.pulse && !model.held && !reducedMotion);
    }
  }

  function demoFrame(demo, seconds, reducedMotion = false) {
    const duration = demo.steps.reduce((sum, step) => sum + step.seconds, 0);
    let remaining = reducedMotion ? 0 : ((seconds % duration) + duration) % duration;
    for (let i = 0; i < demo.steps.length; i++) {
      const step = demo.steps[i];
      if (remaining < step.seconds) {
        const clip = demo.clips[step.clip];
        return {step: i, frame: clip.frames[Math.floor(remaining * clip.fps) % clip.frames.length],
          x: step.from + (step.to - step.from) * remaining / step.seconds};
      }
      remaining -= step.seconds;
    }
  }

  if (typeof module !== "undefined") module.exports = {isPhone, TouchState, renderPrompt, demoFrame};
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
  let promptGraphic;
  let promptText;
  let promptAnnouncement;
  let status;
  let rotate;
  let notice;
  let revision = -1;
  let lastPortrait;
  let lastOrientation;
  let clearing = false;
  let helpAnimation;
  const contexts = [];
  const activeContacts = new Set();
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
    activeContacts.clear();
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
    const orientation = screen.orientation?.angle ?? root.orientation ?? 0;
    if (portrait !== lastPortrait || orientation !== lastOrientation) {
      releaseAll();
      if (portrait !== lastPortrait) revision = -1;
      lastPortrait = portrait;
      lastOrientation = orientation;
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
      activeContacts.add(event.pointerId);
      state.press(event.pointerId, action);
    });
    for (const eventName of ["pointerup", "pointercancel", "lostpointercapture"]) {
      button.addEventListener(eventName, event => {
        activeContacts.delete(event.pointerId);
        state.release(event.pointerId);
      });
    }
    button.addEventListener("pointermove", event => {
      if (!activeContacts.has(event.pointerId)) return;
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
    promptGraphic = element("span", "", prompt);
    promptGraphic.className = "control-graphic";
    promptGraphic.setAttribute("aria-hidden", "true");
    promptText = element("span", "", prompt);
    promptText.className = "hint-visible";
    promptText.setAttribute("aria-hidden", "true");
    promptAnnouncement = element("span", "", prompt);
    promptAnnouncement.className = "visually-hidden";
    promptAnnouncement.setAttribute("role", "status");
    promptAnnouncement.setAttribute("aria-atomic", "true");
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
    screen.orientation?.addEventListener("change", layout);
    addEventListener("orientationchange", layout);
    root.visualViewport?.addEventListener("resize", layout);
    layout();
  }
  function buildHelp(help) {
    element("h2", `${help.title} · ${help.page} / ${help.count}`, menu);
    for (const control of help.controls) {
      const row = element("p", "", menu);
      const glyph = element("span", control.graphic.label, row);
      glyph.className = "control-graphic";
      glyph.dataset.shape = control.graphic.shape;
      glyph.setAttribute("aria-hidden", "true");
      element("span", control.description, row);
    }
    if (help.demo?.steps?.length) {
      const canvas = element("canvas", "", menu);
      canvas.width = 520;
      canvas.height = 190;
      canvas.className = "help-demo";
      canvas.setAttribute("role", "img");
      canvas.setAttribute("aria-label", `${help.title} demonstration.`);
      const caption = element("p", "", menu);
      const glyph = element("span", "", caption);
      glyph.className = "control-graphic";
      glyph.setAttribute("aria-hidden", "true");
      const text = element("span", "", caption);
      const images = {};
      for (const [id, source] of Object.entries(help.demo.images)) {
        images[id] = new Image();
        images[id].src = source;
      }
      const started = performance.now();
      const context = canvas.getContext("2d");
      function draw(id, x, y, width, height) {
        const image = images[id];
        if (image?.complete && image.naturalWidth) context.drawImage(image, x, y, width, height);
      }
      function animate() {
        const reduced = matchMedia("(prefers-reduced-motion: reduce)").matches;
        const frame = demoFrame(help.demo, (performance.now() - started) / 1000, reduced);
        const step = help.demo.steps[frame.step];
        context.fillStyle = "#061014";
        context.fillRect(0, 0, 520, 190);
        context.imageSmoothingEnabled = false;
        context.fillStyle = "#526773";
        context.fillRect(16, 163, 488, 2);
        for (const prop of step.props) {
          draw(prop.image, prop.x - prop.width / 2, 162 - prop.height, prop.width, prop.height);
          if (prop.label) {
            context.fillStyle = "#eaf5fa";
            context.font = "16px system-ui";
            context.fillText(prop.label, prop.x - 12, 20);
          }
        }
        draw(frame.frame, frame.x - 62.4, 51.6, 124.8, 124.8);
        if (step.carry) draw("props/psu", frame.x + 22, 106, 22, 22);
        // Help has no live touch controls; its touch examples need a graphic of their own.
        renderPrompt(text, glyph, [], step.prompt, "", reduced, false, null, true);
        helpAnimation = requestAnimationFrame(animate);
      }
      animate();
    }
    element("p", help.instructions, menu).className = "menu-summary";
  }
  function render(json) {
    const previousModel = model;
    model = JSON.parse(json);
    const changingHelpPage = model.screen === "help" &&
      (previousModel?.screen !== "help" || previousModel.help?.page !== model.help?.page);
    const playing = model.screen === "level" && !model.paused;
    document.body.classList.toggle("mobile-playing", playing);
    controls.hidden = !playing;
    menu.hidden = playing;
    rotate.hidden = !(model.screen === "level" && innerHeight > innerWidth);
    if (playing && innerHeight > innerWidth) {
      suspend();
      return;
    }
    const statusText = model.status || "";
    if (status.textContent !== statusText) status.textContent = statusText;
    renderPrompt(promptText, promptGraphic, controls.querySelectorAll("[data-action]"),
      playing ? model.prompt : {}, playing ? model.carry : "",
      matchMedia("(prefers-reduced-motion: reduce)").matches, true, promptAnnouncement);
    if (revision === model.revision) return;
    revision = model.revision;
    if (helpAnimation) cancelAnimationFrame(helpAnimation);
    helpAnimation = undefined;
    releaseAll();
    notice.hidden = true;
    menu.replaceChildren();
    element("h1", model.screen === "help" ? "How to Play" : model.paused ? "Paused" : "Midcreek Hero", menu);
    const summary = model.summary.replace("Press any key or button", "Use the touchscreen controls.");
    if (model.screen === "help") buildHelp(model.help);
    else {
      if (summary && summary !== "Paused") element("p", summary, menu).className = "menu-summary";
      if (model.paused && model.tasks) element("p", model.tasks, menu).className = "menu-summary";
    }
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
    if (changingHelpPage) menu.scrollTop = 0;
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
