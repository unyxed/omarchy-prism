---
name: macos-glass-debug
description: >
  Diagnose a broken unyxed.macos-glass Omarchy plugin install: desktop cards
  missing or zero-height, bar toggles with no effect, stale behavior after
  edits, QML binding loops, or shell-log errors. Use when anything about the
  plugin misbehaves. Read shell state and logs first; never guess.
---

# Debug macOS Glass Widgets

Work top-down: shell state → live layers → shell log. Each symptom below maps
to a cause already root-caused once — check in order before theorizing.

## 0. Baseline (always run first)

```sh
python3 -c "import json;d=json.load(open('/home/unyxed/.config/omarchy/shell.json'));[print(sec,e) for sec,arr in d['bar']['layout'].items() for e in arr if 'macos' in str(e.get('id',''))]"
hyprctl layers | grep unyxed
quickshell log -p /usr/share/omarchy/shell --no-color 2>&1 | grep -iE "unyxed|WARN scene" | grep -v qmlscanner | tail -n 20
./scripts/check.sh
```

## 1. Cards missing from desktop

- **Entry absent from `shell.json` layout** → plugin disabled or entry
  removed: `omarchy plugin enable unyxed.macos-glass`.
- **`widgets: []`** → everything toggled off (writes work, state is empty).
  Re-enable in the popup or via
  `omarchy bar set unyxed.macos-glass widgets '["clock"]' --json`.
- **Surfaces `280x1`** → card `Loader` failed. Read the log:
  - `GlassCard is not a type` → module-registration failure. Fix: shared
    components co-located in `widgets/` + static `import "../widgets"` in
    `DesktopSurface.qml`. Dynamic `Loader` URLs never register.
  - `Cannot assign object of type ... to list property "content"` → a
    `QtObject` (`Translations`, `Timer`) placed as a bare child of a
    `GlassCard` (whose default property accepts only `Item`s). Fix:
    declare as `property var x: ...`.

## 2. Toggles do nothing

Writes never landed if the `shell.json` entry stays bare `{}` after toggling.

- BarWidget resolves the service itself via
  `bar.shell.serviceFor(moduleName)` — the host never injects `service`
  into bar widgets. A `property var service: null` waiting on injection
  stays null forever.
- The only write path is synchronous `updateEntryInline` in BarWidget.
  Timer/queue/shadow-copy machinery around it diverges and must go.
- Service must never call `updateEntryInline` — it only `applySettings()`.
- Isolate the link under test with a direct write:
  `omarchy bar set unyxed.macos-glass opacity 0.5` then re-read
  `shell.json`. If it persists, the host path is fine and the bug is in
  the popup's QML (handler never fires, or an exception before the write —
  check the log).

## 3. Edit seems ignored

`omarchy-shell shell rescanPlugins` does **not** recreate running service
instances. Edits to `Service.qml`, `services/`, `model/*.js`, or `surfaces/`
require `omarchy restart shell`. Popup-only edits apply on rescan.

## 4. Binding loops / type errors in log

- `Binding loop detected for property ...` → a property read inside its own
  dependency chain (e.g. `onPlayersChanged: revision++` while the player
  list itself derives from `revision`). Restructure so event sources feed
  one counter that derivations read, never the reverse.
- `Passing incompatible arguments to C++ functions` → usually a
  `Qt.formatDateTime`/`Qt.locale` misuse: format locale dates with
  `Qt.locale(...).toString(date, format)`, not a 3-arg `formatDateTime`.
- `Cannot assign to read-only property "title"` → a card declared its own
  `title` shadowing the inherited `GlassCard.title`; rename the card's
  property (e.g. `trackTitle`).

## 5. Flipable cards (learned 0.4.0 — read before touching MediaCard)

- `Flipable` paints **both** sides unconditionally — there is no automatic
  backface culling. Gate visibility explicitly on the live angle, e.g.
  `showingFront` from `((angle % 360) + 360) % 360`, front visible at
  `a <= 90 || a >= 270`, back otherwise. Without this the reverse side
  bleeds through mirrored.
- Do **not** pre-rotate the back side (`transform: Rotation { angle: 180 }`
  on `back:`). It double-mirrors: the canonical Qt Flipable demo uses a
  plain back and reads correctly. Tested the wrong way — mirrored text
  in `hyprctl`-adjacent screenshots.
- Inner content keeps measuring while its wrapper is hidden, so height
  bindings off inner columns stay valid across the visibility swap.
- In `ListView` delegates (and highlights), never use the `ListView.view`
  attached property — it is null during delegate setup and spams
  `Cannot read property 'currentIndex' of null`. Give the view an `id`
  and reference it directly.
- `clip: true` on a rounded `Rectangle` clips children to the *square*
  bounding box, not the rounded shape. Anything full-bleed (photos, backdrops)
  needs its own rounded-rect mask (`MultiEffect` + hidden mask item, same
  pattern as `AlbumArt`) or corners render square while the card chrome stays
  round.
- Drag deltas must be measured in a frame that does not move with the drag.
  Absolute global deltas from the press point (`mapToGlobal`, recomputed
  against the stable pre-drag base every move event); never per-event
  increments and never a moving frame (`DragHandler.centroid` resolves in
  the handler's moving parent frame — a feedback loop that lags behind
  the cursor). Dragging is right-button only by design, so move, resize
  and double-click-to-flip never fight over one gesture.
- Interactive pointer areas must be explicit visual children (`data:` list
  on the card root — the default alias swallows bare children into the
  content column, and property-held items may silently receive no events).
- Rebuilding desktop surfaces mid-drag destroys the live grab: the card
  stops following the pointer until the next press (looks like lag, then a
  jump on re-press). Gate `refreshSurfaces()` on interaction state and flush
  deferred rebuilds after release.
- Flipable sizing: fix the height at `max(front, back)` for the whole flip.
  Animating height per side forces per-frame layer-surface resizes plus a
  full sibling reflow underneath the rotation — reads as stutter. Center
  content vertically so the shorter side sits naturally.
- One `Component.onCompleted` per object. A duplicated handler (e.g. from
  a temp test edit) warns `Property value set multiple times`.

## 6. After any fix

`./scripts/check.sh`, restart-or-rescan per section 3, then re-run the
section-0 baseline: entry populated, full-size surfaces, zero log warnings.
Update the relevant skill + `DEVELOPMENT.md` if a new failure mode was found
so it is only debugged once.
