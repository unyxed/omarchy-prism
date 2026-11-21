#!/usr/bin/env node
// Collision resolver regression: overlap detection, push-out choice,
// bounds clamping, dense-cluster search, and the packed fallback.
const P = require("../model/Placement.js");

function assert(cond, msg) {
  if (!cond) {
    console.error("FAIL: " + msg);
    process.exit(1);
  }
  console.log("ok: " + msg);
}

const BOUNDS = { x: 0, y: 0, w: 1920, h: 1080 };

assert(P.rectsOverlap({ x: 0, y: 0, w: 100, h: 100 }, { x: 50, y: 50, w: 100, h: 100 }), "overlapping rects detected");
assert(!P.rectsOverlap({ x: 0, y: 0, w: 100, h: 100 }, { x: 100, y: 0, w: 100, h: 100 }), "touching edges are not overlap");
assert(P.rectsOverlap({ x: 0, y: 0, w: 100, h: 100 }, { x: 101, y: 0, w: 100, h: 100 }, 4), "gap widens the overlap test");

// Clean drop: unchanged (only clamped).
let r = P.resolveDrop({ x: 500, y: 500, w: 200, h: 100 }, [{ x: 0, y: 0, w: 100, h: 100 }], BOUNDS);
assert(r.x === 500 && r.y === 500, "free drop stays put");

// Drop onto a card fully to its left -> pushed out along the short axis.
r = P.resolveDrop(
  { x: 50, y: 0, w: 200, h: 100 },
  [{ x: 0, y: 0, w: 100, h: 100 }],
  BOUNDS
);
assert(r.x === 104 && r.y === 0, "pushed clear of the obstacle (GAP honored), got " + JSON.stringify(r));

// Same drop, but the left edge is against the screen: must resolve to the
// other side rather than clamp back into the obstacle.
r = P.resolveDrop(
  { x: 10, y: 0, w: 200, h: 100 },
  [{ x: 0, y: 0, w: 100, h: 100 }],
  BOUNDS
);
assert(!P.rectsOverlap(r, { x: 0, y: 0, w: 100, h: 100 }), "no candidate re-overlaps the obstacle, got " + JSON.stringify(r));

// Obstacle above and below: vertical push-outs blocked by both, must pick
// a horizontal one.
r = P.resolveDrop(
  { x: 100, y: 90, w: 100, h: 100 },
  [
    { x: 100, y: 0, w: 100, h: 100 },
    { x: 100, y: 180, w: 100, h: 100 }
  ],
  BOUNDS
);
assert(!P.overlapsAny(r, [
  { x: 100, y: 0, w: 100, h: 100 },
  { x: 100, y: 180, w: 100, h: 100 }
]), "sandwiched drop resolves somewhere free, got " + JSON.stringify(r));

// Drop fully inside a dense cluster: ring search finds the nearest gap.
let cluster = [];
for (let gx = 0; gx < 5; gx++)
  for (let gy = 0; gy < 5; gy++)
    cluster.push({ x: 400 + gx * 120, y: 400 + gy * 120, w: 100, h: 100 });
r = P.resolveDrop({ x: 450, y: 450, w: 100, h: 100 }, cluster, BOUNDS);
assert(!P.overlapsAny(r, cluster), "dense-cluster drop lands in a gap, got " + JSON.stringify(r));

// Screen too small for card plus obstacle: honest clamp, no crash.
r = P.resolveDrop(
  { x: 0, y: 0, w: 150, h: 80 },
  [{ x: 0, y: 0, w: 150, h: 80 }],
  { x: 0, y: 0, w: 150, h: 80 }
);
assert(r.x === 0 && r.y === 0, "impossible fit clamps inside bounds, got " + JSON.stringify(r));

// Drop partly off-screen: clamped into bounds even when free.
r = P.resolveDrop({ x: 1800, y: 1000, w: 200, h: 100 }, [], BOUNDS);
assert(r.x === 1720 && r.y === 980, "off-screen drop clamped, got " + JSON.stringify(r));

// Minimal displacement wins: push-out clears the obstacle's edge + gap,
// not the dropped card's own edge (14px move beats teleporting to 204).
r = P.resolveDrop(
  { x: 90, y: 0, w: 100, h: 100 },
  [{ x: 0, y: 0, w: 100, h: 100 }],
  BOUNDS
);
assert(r.x === 104 && r.y === 0, "nearest push-out chosen, got " + JSON.stringify(r));

console.log("All placement tests passed.");
