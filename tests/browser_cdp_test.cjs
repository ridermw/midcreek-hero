const assert = require("node:assert/strict");
const test = require("node:test");

for (const failingMethod of ["Target.getTargets", "Target.attachToTarget"]) {
  test(`CDP acquisition closes its socket when ${failingMethod} fails`, async () => {
    const original = globalThis.WebSocket;
    let socket;
    class FakeSocket {
      static OPEN = 1;
      constructor() {
        socket = this;
        this.readyState = FakeSocket.OPEN;
        this.closed = false;
        queueMicrotask(() => this.onopen());
      }
      send(encoded) {
        const request = JSON.parse(encoded);
        const response = request.method === failingMethod
          ? {id: request.id, error: {message: "simulated acquisition failure"}}
          : {id: request.id, result: {targetInfos: [{type: "page", url: "http://127.0.0.1:3000/", targetId: "page"}]}};
        queueMicrotask(() => this.onmessage({data: JSON.stringify(response)}));
      }
      close() {
        this.closed = true;
        this.readyState = 3;
        queueMicrotask(() => this.onclose?.());
      }
    }
    globalThis.WebSocket = FakeSocket;
    try {
      const {connectBrowser} = await import("./browser_cdp.mjs");
      await assert.rejects(connectBrowser("ws://127.0.0.1:1234/test", "http://127.0.0.1:3000/"), /simulated acquisition failure/);
      assert.equal(socket.closed, true, "Failed acquisition must not leave an open browser connection.");
    } finally {
      globalThis.WebSocket = original;
    }
  });
}

for (const remote of ["endpoint", "page"]) {
  test(`CDP rejects a disguised nonlocal ${remote} authority`, async () => {
    const original = globalThis.WebSocket;
    const foreign = new URL(remote === "endpoint" ? "ws://outside.invalid/test" : "http://outside.invalid/");
    foreign.username = "127.0.0.1";
    foreign.password = "1234";
    const endpoint = remote === "endpoint" ? foreign.href : "ws://127.0.0.1:1234/test";
    const url = remote === "page" ? foreign.href : "http://127.0.0.1:3000/";
    let opened = false;
    globalThis.WebSocket = class {
      constructor() { opened = true; throw new Error("Unexpected connection"); }
    };
    try {
      const {connectBrowser} = await import("./browser_cdp.mjs");
      await assert.rejects(connectBrowser(endpoint, url), /loopback/);
      assert.equal(opened, false);
    } finally {
      globalThis.WebSocket = original;
    }
  });
}
