#!/usr/bin/env node
// Settings normalisation regression: bad shell.json values yield working widgets.
const S = require("../model/Settings.js");

function assert(cond, msg) {
  if (!cond) {
    console.error("FAIL: " + msg);
    process.exit(1);
  }
  console.log("ok: " + msg);
}

let n = S.normalize({});
assert(JSON.stringify(n.widgets) === JSON.stringify(S.DEFAULTS.widgets), "defaults when empty");

n = S.normalize({ widgets: ["system", "nope", "todo", "system"] });
assert(JSON.stringify(n.widgets) === JSON.stringify(["system", "todo"]), "unknown widgets dropped, order canonical, dupes removed");

n = S.normalize({ opacity: 99 });
assert(n.opacity === 1, "opacity clamped high");

n = S.normalize({ opacity: -5 });
assert(n.opacity === 0.05, "opacity clamped low");

n = S.normalize({ intervalMs: 10 });
assert(n.intervalMs === 500, "interval clamped low");

n = S.normalize({ todos: [{ id: "a", text: "x".repeat(500), done: 1 }, { text: "   " }, "nope"] });
assert(n.todos.length === 1 && n.todos[0].text.length === 200, "todos bounded and cleaned");

n = S.normalize({ positions: { system: { x: 1e9, y: "bad" } } });
assert(JSON.stringify(n.positions) === JSON.stringify({}), "bad positions dropped");

n = S.normalize({ mediaStyle: "poster", clockStyle: "glass", systemStyle: "bars", calendarStyle: "month" });
assert(n.mediaStyle === "poster" && n.clockStyle === "glass" && n.systemStyle === "bars" && n.calendarStyle === "month", "valid styles pass through");

n = S.normalize({ mediaStyle: "cinema", clockStyle: "", systemStyle: null, calendarStyle: "week" });
assert(n.mediaStyle === S.DEFAULTS.mediaStyle && n.clockStyle === S.DEFAULTS.clockStyle && n.systemStyle === S.DEFAULTS.systemStyle && n.calendarStyle === S.DEFAULTS.calendarStyle, "unknown styles fall back to defaults");

console.log("All settings tests passed.");
