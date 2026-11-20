#!/usr/bin/env node
// LRC parser regression: timestamps, multi-tags, metadata, bounds.
const L = require("../model/Lyrics.js");

function assert(cond, msg) {
  if (!cond) {
    console.error("FAIL: " + msg);
    process.exit(1);
  }
  console.log("ok: " + msg);
}

let lines = L.parseLrc("[00:12.00] Hello\n[00:15.50] World\n");
assert(lines.length === 2 && Math.abs(lines[0].t - 12) < 0.001 && lines[1].text === "World", "basic mm:ss.xx lines parse");

lines = L.parseLrc("[ar:Coldplay]\n[ti:Yellow]\n[00:10] Verse\n[offset:+500]\n");
assert(lines.length === 1 && lines[0].text === "Verse", "metadata and offset lines dropped");

lines = L.parseLrc("[00:10.00][00:20.00] Chorus\n");
assert(lines.length === 2 && lines[1].t === 20, "multi-tag line expands");

lines = L.parseLrc("[00:01] \n[00:02]\n[bad] nope\n");
assert(lines.length === 2, "empty-text and tagless lines handled");

lines = L.parseLrc("[00:10] A\x01B\x7fC\n");
assert(lines[0].text === "ABC", "control chars stripped");

var sampleLines = [{ t: 10, text: "a" }, { t: 20, text: "b" }, { t: 30, text: "c" }];
assert(L.lineIndexAt(sampleLines, 25) === 1, "current line is last at-or-before position");
assert(L.lineIndexAt([{ t: 10, text: "a" }], 5) === -1, "position before first line is -1");
assert(L.lineIndexAt([], 99) === -1, "empty list is -1");

let big = "";
for (let i = 0; i < 2000; i++) big += "[00:01] line " + i + "\n";
assert(L.parseLrc(big).length === L.MAX_LINES, "line count bounded");

assert(L.plainLines("a\n\nb\n   \nc").join("|") === "a|b|c", "plain lyrics split and blanks dropped");

console.log("All lyrics tests passed.");
