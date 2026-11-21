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

n = S.normalize({ photos: [{ id: "unique-id", path: "/x/y.jpg" }] });
assert(n.photos.length === 1, "valid photo passes through");
let manyPhotos = [];
for (let i = 0; i < 20; i++) manyPhotos.push({ id: "p" + i, path: "/x/" + i + ".png" });
n = S.normalize({ photos: manyPhotos });
assert(n.photos.length === 12, "photos capped at 12");
n = S.normalize({ photos: [{ id: "badext", path: "/x/y.txt" }, { id: "", path: "/x/z.png" }, "nope", { id: "ok", path: "/x/w.WEBP" }] });
assert(n.photos.length === 1 && n.photos[0].id === "ok", "photos bounded to real image extensions with ids");
n = S.normalize({ positions: { system: { x: 1e9, y: "bad" } } });
assert(JSON.stringify(n.positions) === JSON.stringify({}), "bad positions dropped");

n = S.normalize({ positions: { system: { x: 100, y: 200, screen: "HDMI-A-1" }, gpu: { x: 50, y: 60, screen: "" } } });
assert(n.positions.system.screen === "HDMI-A-1", "per-monitor pin screen kept");
assert(n.positions.gpu.screen === undefined, "empty screen field treated as legacy (applies everywhere)");

n = S.normalize({ mediaStyle: "lyrics", clockStyle: "glass", systemStyle: "bars", calendarStyle: "month" });
assert(n.mediaStyle === "lyrics" && n.clockStyle === "glass" && n.systemStyle === "bars" && n.calendarStyle === "month", "valid styles pass through");

n = S.normalize({ mediaStyle: "cinema", clockStyle: "", systemStyle: null, calendarStyle: "week" });
assert(n.mediaStyle === S.DEFAULTS.mediaStyle && n.clockStyle === S.DEFAULTS.clockStyle && n.systemStyle === S.DEFAULTS.systemStyle && n.calendarStyle === S.DEFAULTS.calendarStyle, "unknown styles fall back to defaults");

console.log("All settings tests passed.");
