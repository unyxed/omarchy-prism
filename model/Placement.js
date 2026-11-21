// Collision-aware placement for desktop cards. Pure functions, so `node`
// can exercise them directly (tests/test_placement.js).
//
// The desktop is free-form: a drop can land anywhere, including on top of
// another card. resolveDrop turns any drop into a position that fits
// without touching any other card and stays inside the screen bounds —
// the nearest such position, so a bad drop reads as a small magnetic
// nudge rather than a teleport.

// Breathing room kept between resolved cards, in px.
var GAP = 4

// Step used by the expanding search when simple push-outs are all blocked.
var SEARCH_STEP = 24
var SEARCH_MAX_CANDIDATES = 600

function num(value, fallback) {
  var n = Number(value)
  return isFinite(n) ? n : fallback
}

function asRect(rect) {
  return {
    x: num(rect && rect.x, 0),
    y: num(rect && rect.y, 0),
    w: Math.max(0, num(rect && rect.w, 0)),
    h: Math.max(0, num(rect && rect.h, 0))
  }
}

// True when the two rects overlap (touching edges do not count, and the
// optional gap keeps them apart).
function rectsOverlap(a, b, gap) {
  var ra = asRect(a)
  var rb = asRect(b)
  var g = num(gap, 0)
  return ra.x < rb.x + rb.w + g
    && rb.x < ra.x + ra.w + g
    && ra.y < rb.y + rb.h + g
    && rb.y < ra.y + ra.h + g
}

function overlapsAny(rect, others) {
  for (var i = 0; i < (others ? others.length : 0); i++)
    if (rectsOverlap(rect, others[i])) return true
  return false
}

// Keep a rect inside the bounds (or as close as it fits).
function clampRect(rect, bounds) {
  var r = asRect(rect)
  var b = bounds || { x: 0, y: 0, w: Infinity, h: Infinity }
  var bw = num(b.w, Infinity)
  var bh = num(b.h, Infinity)
  r.x = Math.min(Math.max(r.x, num(b.x, 0)), Math.max(num(b.x, 0), bw - r.w))
  r.y = Math.min(Math.max(r.y, num(b.y, 0)), Math.max(num(b.y, 0), bh - r.h))
  return r
}

function displacement(from, to) {
  var dx = num(to.x, 0) - num(from.x, 0)
  var dy = num(to.y, 0) - num(from.y, 0)
  return dx * dx + dy * dy
}

// All positions the drop could be pushed to, one per overlapping obstacle
// and per axis, ordered by nothing (the caller picks by displacement).
function pushOutCandidates(dropped, others, bounds) {
  var d = asRect(dropped)
  var out = []
  for (var i = 0; i < (others ? others.length : 0); i++) {
    var o = asRect(others[i])
    if (!rectsOverlap(d, o)) continue
    var options = [
      { x: o.x - d.w - GAP, y: d.y },
      { x: o.x + o.w + GAP, y: d.y },
      { x: d.x, y: o.y - d.h - GAP },
      { x: d.x, y: o.y + o.h + GAP }
    ]
    for (var k = 0; k < options.length; k++) {
      var cand = clampRect({ x: options[k].x, y: options[k].y, w: d.w, h: d.h }, bounds)
      if (!overlapsAny(cand, others)) out.push(cand)
    }
  }
  return out
}

// Expanding ring search around the drop, used when every simple push-out
// is blocked (drop into a dense cluster). Returns the first free position
// scanning increasing radii on a coarse grid, favouring small moves by
// scanning order.
function searchFreeSpot(dropped, others, bounds) {
  var d = asRect(dropped)
  var best = null
  var tested = 0
  var maxRadius = Math.max(num(bounds && bounds.w, 4000), num(bounds && bounds.h, 4000))
  for (var radius = SEARCH_STEP; radius <= maxRadius && tested < SEARCH_MAX_CANDIDATES; radius += SEARCH_STEP) {
    var ring = Math.max(1, Math.round(radius / SEARCH_STEP))
    for (var dx = -ring; dx <= ring; dx++) {
      for (var dy = -ring; dy <= ring; dy++) {
        // Only the expanding square's border, not its interior (smaller
        // radii covered that already).
        if (Math.abs(dx) !== ring && Math.abs(dy) !== ring) continue
        tested++
        if (tested > SEARCH_MAX_CANDIDATES) break
        var cand = clampRect({
          x: d.x + dx * SEARCH_STEP,
          y: d.y + dy * SEARCH_STEP,
          w: d.w, h: d.h
        }, bounds)
        if (overlapsAny(cand, others)) continue
        if (best === null || displacement(d, cand) < displacement(d, best)) best = cand
      }
    }
    // A free spot found on this radius is the nearest there is; scanning
    // the full ring first keeps ties deterministic (min displacement).
    if (best !== null) return best
  }
  return null
}

// The public entry: nearest non-overlapping, in-bounds position for the
// dropped rect. Falls back to bounds-clamped when nothing fits (e.g. a
// screen too small for the card plus obstacles).
function resolveDrop(dropped, others, bounds) {
  var d = asRect(dropped)
  var clamped = clampRect(d, bounds)
  if (!overlapsAny(clamped, others)) return clamped

  var candidates = pushOutCandidates(clamped, others, bounds)
  var best = null
  for (var i = 0; i < candidates.length; i++)
    if (best === null || displacement(clamped, candidates[i]) < displacement(clamped, best))
      best = candidates[i]
  if (best !== null) return best

  var searched = searchFreeSpot(clamped, others, bounds)
  if (searched !== null) return searched

  return clamped
}

if (typeof module !== "undefined") {
  module.exports = {
    GAP: GAP,
    SEARCH_STEP: SEARCH_STEP,
    rectsOverlap: rectsOverlap,
    overlapsAny: overlapsAny,
    clampRect: clampRect,
    resolveDrop: resolveDrop
  }
}
