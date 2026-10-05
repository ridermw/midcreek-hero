import assert from "node:assert/strict";

export async function connectBrowser(endpoint, url) {
  assert.ok(endpoint?.startsWith("ws://127.0.0.1:"), "Supply the dedicated agent-browser CDP endpoint.");
  assert.ok(url?.startsWith("http://127.0.0.1:"), "Supply the local game URL.");
  for (const value of [endpoint, url]) {
    const address = new URL(value);
    assert.ok(address.hostname === "127.0.0.1" && !address.username && !address.password, "Use a loopback URL without credentials.");
  }
  const socket = new WebSocket(endpoint);
  await new Promise((resolve, reject) => {
    const timeout = setTimeout(() => { socket.close(); reject(new Error("CDP connection timed out.")); }, 15000);
    socket.onopen = () => { clearTimeout(timeout); resolve(); };
    socket.onerror = () => { clearTimeout(timeout); socket.close(); reject(new Error("CDP connection failed.")); };
  });
  let sequence = 0;
  const requests = new Map();
  const errors = [];
  const consoleErrors = [];
  socket.onmessage = event => {
    const message = JSON.parse(event.data);
    if (message.method === "Runtime.exceptionThrown") errors.push(message.params.exceptionDetails);
    if (message.method === "Runtime.consoleAPICalled" && message.params.type === "error") {
      consoleErrors.push(message.params.args.map(arg => arg.value ?? arg.description).join(" "));
    }
    const request = requests.get(message.id);
    if (!request) return;
    requests.delete(message.id);
    clearTimeout(request.timeout);
    if (message.error) request.reject(new Error(JSON.stringify(message.error)));
    else request.resolve(message.result);
  };
  socket.onclose = () => {
    for (const request of requests.values()) {
      clearTimeout(request.timeout);
      request.reject(new Error("CDP connection closed before the response."));
    }
    requests.clear();
  };
  function send(method, params = {}, sessionId) {
    return new Promise((resolve, reject) => {
      if (socket.readyState !== WebSocket.OPEN) {
        reject(new Error("CDP connection is not open: " + method));
        return;
      }
      const id = ++sequence;
      const timeout = setTimeout(() => {
        requests.delete(id);
        reject(new Error("CDP request timed out: " + method));
      }, 15000);
      requests.set(id, {resolve, reject, timeout});
      try {
        socket.send(JSON.stringify({id, method, params, sessionId}));
      } catch (error) {
        clearTimeout(timeout);
        requests.delete(id);
        reject(error);
      }
    });
  }
  let sessionId;
  try {
    const targets = await send("Target.getTargets");
    const target = targets.targetInfos.find(item => item.type === "page" && item.url.startsWith(url));
    if (!target) throw new Error("Open the game in the dedicated agent-browser session first.");
    ({sessionId} = await send("Target.attachToTarget", {targetId: target.targetId, flatten: true}));
  } catch (error) {
    socket.close();
    throw error;
  }
  const cdp = (method, params) => send(method, params, sessionId);
  async function evaluate(expression) {
    const result = await cdp("Runtime.evaluate", {expression, returnByValue: true, awaitPromise: true});
    if (result.exceptionDetails) throw new Error(JSON.stringify(result.exceptionDetails));
    return result.result.value;
  }
  async function disconnect() {
    if (socket.readyState === WebSocket.OPEN) {
      try {
        await send("Target.detachFromTarget", {sessionId});
      } finally {
        socket.close();
      }
    }
  }
  return {cdp, evaluate, errors, consoleErrors, disconnect};
}
