// LRC (synced lyrics) parsing. Pure functions, so `node` can exercise them.
//
// Accepted line shape: one or more [mm:ss.xx] tags followed by text.
// Metadata lines ([ar:...], [ti:...], [offset:...]) carry no numeric tag and
// are dropped. Text is control-stripped and length-capped; display sinks must
// still use PlainText.
var MAX_LINES = 500
var MAX_TEXT = 200

function cleanLine(raw) {
  var text = String(raw === undefined || raw === null ? "" : raw)
  text = text.replace(/[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]/g, "")
  text = text.replace(/\s+/g, " ").trim()
  return text.substring(0, MAX_TEXT)
}

function tagToSeconds(mm, ss, frac) {
  var m = Number(mm)
  var s = Number(ss)
  if (!isFinite(m) || !isFinite(s) || m < 0 || s < 0 || s >= 100) return -1
  var total = m * 60 + s
  if (frac !== undefined && frac !== "") {
    var f = Number("0." + frac)
    if (isFinite(f)) total += f
  }
  return total
}

// Returns [{t: seconds, text}] sorted by time, or [] when nothing parses.
function parseLrc(raw) {
  var out = []
  var lines = String(raw || "").split("\n")
  for (var i = 0; i < lines.length && out.length < MAX_LINES; i++) {
    var line = lines[i]
    var times = []
    var rest = line
    var m = rest.match(/^\[(\d{1,3}):(\d{2})(?:[.:](\d{1,3}))?\]/)
    while (m) {
      var t = tagToSeconds(m[1], m[2], m[3])
      if (t >= 0) times.push(t)
      rest = rest.substring(m[0].length)
      m = rest.match(/^\[(\d{1,3}):(\d{2})(?:[.:](\d{1,3}))?\]/)
    }
    if (times.length === 0) continue
    var text = cleanLine(rest)
    for (var k = 0; k < times.length; k++) out.push({ t: times[k], text: text })
  }
  out.sort(function (a, b) { return a.t - b.t })
  return out
}

// Index of the last line at or before `pos` seconds, or -1 when none.
function lineIndexAt(lines, pos) {
  var idx = -1
  var p = Number(pos) || 0
  for (var i = 0; i < lines.length; i++) {
    if (lines[i].t <= p + 0.001) idx = i
    else break
  }
  return idx
}

// Plain (untimed) lyrics split into display lines, bounded.
function plainLines(raw) {
  var out = []
  var lines = String(raw || "").split("\n")
  for (var i = 0; i < lines.length && out.length < MAX_LINES; i++) {
    var text = cleanLine(lines[i])
    if (text !== "") out.push(text)
  }
  return out
}

if (typeof module !== "undefined") {
  module.exports = {
    MAX_LINES: MAX_LINES,
    parseLrc: parseLrc,
    lineIndexAt: lineIndexAt,
    plainLines: plainLines
  }
}
