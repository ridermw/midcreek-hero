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

  function stickVector(dx, dy) {
    const distance = Math.hypot(dx, dy);
    const scale = Math.min(1, 28 / (distance || 1));
    const threshold = Math.max(9, distance * 0.4);
    return {x: dx * scale, y: dy * scale,
      horizontal: Math.abs(dx) < threshold ? "" : dx < 0 ? "move_left" : "move_right",
      vertical: Math.abs(dy) < threshold ? "" : dy < 0 ? "move_up" : "move_down"};
  }

  function renderPrompt(text, graphic, buttons, model = {}, carry = "", reducedMotion = false, compact = false, announcement = null, standaloneTouch = false) {
    const steering = compact && model.display === "touch" && model.action?.startsWith("move_");
    const hold = !steering && model.action && model.intent === "hold";
    const hint = model.approach ? "Approach the work site" : hold ? "Hold" : "";
    const description = [model.description, carry].filter(Boolean).join(" | ");
    const visibleText = compact
      ? [hint, model.status, carry].filter(Boolean).join(" | ")
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

  if (typeof module !== "undefined") module.exports = {isPhone, TouchState, stickVector, renderPrompt};
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
  let taskList;
  let rotate;
  let notice, noticeText;
  let pause;
  const twins = new Map();
  let revision = -1;
  let lastPortrait;
  let lastOrientation;
  let clearing = false;
  const contexts = [];
  let stick;
  let stickRing;
  const activeContacts = new Map();
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
    stick = null;
    if (stickRing) stickRing.hidden = true;
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
      noticeText.textContent = String(error);
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
      lastPortrait = portrait;
      lastOrientation = orientation;
    }
    shell.classList.toggle("portrait", portrait);
    if (model) visibility();
    if (portrait && model?.screen === "level" && !model.paused) suspend();
  }
  // Menus are drawn by the game. The HTML twins are invisible and only serve screen readers.
  function visibility() {
    const portrait = innerHeight > innerWidth;
    const playing = model.screen === "level" && !model.paused;
    document.body.classList.toggle("mobile-playing", playing);
    controls.hidden = !playing;
    pause.hidden = !playing;
    menu.hidden = playing || portrait;
    rotate.hidden = !portrait;
    const message = "Rotate your phone to landscape to play." + (model.screen === "level" ? " The game is paused." : "");
    if (rotate.textContent !== message) rotate.textContent = message;
    return {portrait, playing};
  }
  function placeTwins() {
    for (const item of model.controls) {
      const twin = twins.get(item.id);
      if (!twin || !item.rect) continue;
      const key = item.rect.join(",");
      if (twin.dataset.rect !== key) {
        twin.dataset.rect = key;
        const [x, y, width, height] = item.rect.map(n => `${n * 100}%`);
        Object.assign(twin.style, {left: x, top: y, width, height});
      }
      const slider = twin.querySelector("input");
      if (slider && Number(slider.value) !== item.value) slider.value = item.value;
    }
  }
  function buildJoystick(parent) {
    const zone = element("div", "", parent);
    zone.className = "stick-zone";
    zone.setAttribute("aria-hidden", "true");
    stickRing = element("div", "", zone);
    stickRing.className = "stick-ring";
    stickRing.hidden = true;
    const knob = element("div", "", stickRing);
    knob.className = "stick-knob";
    zone.addEventListener("pointerdown", event => {
      if (stick || event.button !== 0) return;
      event.preventDefault();
      resumeAudio();
      zone.setPointerCapture(event.pointerId);
      stick = {id: event.pointerId, x: event.clientX, y: event.clientY};
      const rect = zone.getBoundingClientRect();
      stickRing.style.left = `${stick.x - rect.left}px`;
      stickRing.style.top = `${stick.y - rect.top}px`;
      knob.style.transform = "";
      stickRing.hidden = false;
    });
    zone.addEventListener("pointermove", event => {
      if (stick?.id !== event.pointerId) return;
      const v = stickVector(event.clientX - stick.x, event.clientY - stick.y);
      knob.style.transform = `translate(${v.x}px, ${v.y}px)`;
      if (v.horizontal) state.press("stick-x", v.horizontal); else state.release("stick-x");
      if (v.vertical) state.press("stick-y", v.vertical); else state.release("stick-y");
    });
    for (const name of ["pointerup", "pointercancel", "lostpointercapture"]) {
      zone.addEventListener(name, event => {
        if (stick?.id !== event.pointerId) return;
        stick = null;
        stickRing.hidden = true;
        state.release("stick-x");
        state.release("stick-y");
      });
    }
    // Movement remains operable without performing a drag.
    const alternatives = element("div", "", parent);
    alternatives.className = "stick-alternatives";
    for (const label of ["Left", "Right", "Up", "Down"]) actionButton("move_" + label.toLowerCase(), label, alternatives);
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
      activeContacts.set(event.pointerId, action);
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
      if (target === button) state.press(event.pointerId, action);
      else state.release(event.pointerId);
    });
    // Screen readers activate buttons with click rather than pointer events.
    button.addEventListener("click", event => {
      if (event.detail !== 0 || button.hidden) return;
      resumeAudio();
      const heldWork = (action === "repair" || action === "diagnose") && model?.prompt?.intent === "hold";
      if (action.startsWith("move_") || heldWork) {
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
  function updateActions(prompt, slideNearby) {
    for (const button of controls.querySelectorAll(".action-pad button")) {
      const action = button.dataset.action;
      const visible = action === "jump" || (action === prompt?.action && !prompt.approach) || (action === "slide" && slideNearby);
      if (button.hidden === !visible) continue;
      if (!visible) {
        // A context change releases the old action without transferring its finger to the new one.
        for (const [id, original] of activeContacts) {
          if (original !== action) continue;
          activeContacts.delete(id);
          state.release(id);
        }
        state.release(`assist-${action}`);
      }
      button.hidden = !visible;
    }
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
    buildJoystick(controls);
    const actions = element("div", "", controls);
    actions.className = "action-pad";
    for (const [action, label] of [["jump", "Jump"], ["slide", "Slide"], ["repair", "Repair"], ["diagnose", "Diagnose"]]) {
      actionButton(action, label, actions);
    }
    const toolbar = element("div", "", shell);
    toolbar.className = "play-tools";
    if (document.fullscreenEnabled) {
      const fullscreen = element("button", "Full screen", toolbar);
      fullscreen.id = "mobile-fullscreen";
      fullscreen.addEventListener("click", async () => {
        try {
          if (document.fullscreenElement) await document.exitFullscreen();
          else await document.documentElement.requestFullscreen();
        } catch (error) {
          reportError(error);
        }
      });
      document.addEventListener("fullscreenchange", () => {
        fullscreen.textContent = document.fullscreenElement ? "Exit full screen" : "Full screen";
      });
    }
    pause = element("button", "Pause", toolbar);
    pause.id = "mobile-pause";
    pause.addEventListener("click", () => {
      resumeAudio();
      releaseAll();
      send({type: "pause"});
    });
    const tasks = element("details", "", controls);
    tasks.id = "mobile-tasks";
    const summary = element("summary", "", tasks);
    status = element("span", "", summary);
    status.id = "mobile-status";
    element("span", " · Work order tasks", summary).className = "visually-hidden";
    taskList = element("div", "", tasks);
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
    rotate = element("p", "Rotate your phone to landscape to play.", shell);
    rotate.id = "mobile-rotate";
    notice = element("div", "", shell);
    notice.id = "mobile-error";
    notice.hidden = true;
    noticeText = element("p", "", notice);
    noticeText.setAttribute("role", "alert");
    // The banner covers in-game menu buttons, so players need a way to clear it.
    element("button", "Dismiss", notice).addEventListener("click", () => { notice.hidden = true; });
    shell.addEventListener("contextmenu", event => event.preventDefault());
    // Menu taps reach the game canvas directly, so audio resumes on any gesture.
    for (const name of ["pointerdown", "pointerup", "touchend"]) document.addEventListener(name, resumeAudio, true);
    addEventListener("blur", suspend);
    document.addEventListener("visibilitychange", () => { if (document.hidden) suspend(); });
    addEventListener("pagehide", suspend);
    addEventListener("resize", layout);
    screen.orientation?.addEventListener("change", layout);
    addEventListener("orientationchange", layout);
    root.visualViewport?.addEventListener("resize", layout);
    layout();
  }
  function buildHelp(help, parent) {
    element("h2", `${help.title} · ${help.page} / ${help.count}`, parent);
    for (const control of help.controls) element("p", control.description, parent);
    element("p", help.instructions, parent);
  }
  function render(json) {
    model = JSON.parse(json);
    const {portrait, playing} = visibility();
    if (playing && portrait) {
      suspend();
      return;
    }
    const statusText = model.status || "";
    if (status.textContent !== statusText) status.textContent = statusText;
    const tasks = model.tasks || "";
    if (taskList.textContent !== tasks) taskList.textContent = tasks;
    if (playing) updateActions(model.prompt, !!model.slide_nearby);
    renderPrompt(promptText, promptGraphic, controls.querySelectorAll("[data-action]"),
      playing ? model.prompt : {}, playing ? model.carry : "",
      matchMedia("(prefers-reduced-motion: reduce)").matches, true, promptAnnouncement);
    if (revision !== model.revision) rebuildTwins();
    placeTwins();
  }
  function rebuildTwins() {
    revision = model.revision;
    taskList.parentElement.open = false;
    releaseAll();
    notice.hidden = true;
    menu.replaceChildren();
    twins.clear();
    const text = element("div", "", menu);
    text.className = "visually-hidden";
    element("h1", model.screen === "help" ? "How to Play" : model.paused ? "Paused" : "Midcreek Hero", text);
    if (model.screen === "help") buildHelp(model.help, text);
    else {
      if (model.summary && model.summary !== "Paused") element("p", model.summary, text).className = "menu-summary";
      if (model.paused && model.tasks) element("p", model.tasks, text).className = "menu-summary";
    }
    for (const item of model.controls) {
      let twin;
      if (item.kind === "button") {
        twin = element("button", item.text, menu);
        twin.disabled = item.disabled;
        twin.addEventListener("click", () => {
          resumeAudio();
          send({type: "menu", revision: model.revision, id: item.id});
        });
      } else {
        twin = element("label", item.text, menu);
        const slider = element("input", "", twin);
        slider.type = "range";
        for (const key of ["min", "max", "step", "value"]) slider[key] = item[key];
        slider.addEventListener("input", () => {
          resumeAudio();
          send({type: "menu", revision: model.revision, id: item.id, value: Number(slider.value)});
        });
      }
      twins.set(item.id, twin);
    }
    placeTwins();
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
