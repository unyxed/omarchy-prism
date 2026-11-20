#!/usr/bin/env node
// Regression coverage for markup-shaped input (plugin UI safety guide).
// Ensures Sanitize.escapeMarkup neutralizes rich-text payloads before they
// reach sinks the plugin does not own (bar tooltip), and that cleanLine
// bounds untrusted subprocess/file text.
const mod = require("../model/Sanitize.js");

function assert(cond, msg) {
  if (!cond) {
    console.error("FAIL: " + msg);
    process.exit(1);
  }
  console.log("ok: " + msg);
}

const hostile = '<img src="https://example.invalid/tracker">';
const escaped = mod.escapeMarkup(hostile, 200);
assert(escaped.indexOf("<img") === -1, "angle brackets are escaped");
assert(escaped.indexOf("&lt;img") !== -1, "markup becomes entities");
assert(escaped.indexOf("example.invalid") !== -1, "readable text survives");

assert(mod.escapeMarkup("<b>hi</b>", 200) === "&lt;b&gt;hi&lt;/b&gt;", "basic tags escaped");
assert(mod.escapeMarkup("a&b", 200) === "a&amp;b", "ampersand escaped");

const long = "x".repeat(500);
assert(mod.escapeMarkup(long, 200).length === 200, "output length is bounded");

const dirty = "  hello\x00\x1f   world\n\n";
assert(mod.cleanLine(dirty, 200) === "hello world", "control chars and whitespace collapsed");

assert(mod.cleanLine('<img src=x onerror=alert(1)>', 200) === "<img src=x onerror=alert(1)>", "cleanLine preserves text for PlainText sinks (no rich-text interpretation)");

const listed = mod.boundList([1, 2, 3, 4, 5], 3);
assert(listed.length === 3, "collections are bounded");

console.log("All sanitize tests passed.");
