---
name: macos-glass-widget
description: >
  Add a whole new widget card to the unyxed.macos-glass Omarchy plugin
  (new data source + new desktop card). Use when the task is a new widget
  id alongside clock/system/gpu/media/calendar/todo. Covers Settings,
  manifest, sampler service, card, surface wiring, popup toggle, i18n,
  and tests.
---

# Add a Widget

A widget is a data source plus a display card. Follow all 8 steps; a widget
that skips surface wiring or the manifest renders nowhere.

## Procedure

### 0. Orient

Read `Service.qml` (sampler ownership, `applySettings`), one existing
`services/*Service.qml` pair, `surfaces/DesktopSurface.qml` (`sourceFor`,
`configure`), and `model/Settings.js` (`KNOWN_WIDGETS`, `normalize`).

### 1. `model/Settings.js`

- Append the id to `KNOWN_WIDGETS` (canonical order = display order).
- Add any widget-specific defaults + normalization (clamp numbers, bound
  strings/lists — see `normalizeTodos`).

### 2. `manifest.json`

- Append the id to `barWidget.defaults.widgets`.
- Add defaults + `schema` entries for any new keys. Keep meaning-identical
  with `Settings.js` (`scripts/check.sh` enforces this).

### 3. Sampler (`services/<Name>Service.qml`)

- Own polling/sensing here, never in the card. Gate expensive work on an
  `active` prop; Service sets `active` from widget visibility.
- Bound everything from outside (list lengths, string lengths, value ranges).
- Instantiate in `Service.qml` with `active:` / `intervalMs:` bindings.

### 4. Card (`widgets/<Name>Card.qml`)

- Root must be `GlassCard`. Display-only: props in, `toggleRequested`-style
  signals out. No `TextInput` (desktop layer never takes keyboard).
- `textFormat: Text.PlainText` on all display text; co-locate the card with
  any shared components it uses (see step 6).
- Dual `qs.Commons` imports as needed (bare names need the plain import).

### 5. `surfaces/DesktopSurface.qml`

- `sourceFor()`: add the `id → "../widgets/<Name>Card.qml"` branch.
- `configure()`: pass sampler + config with guarded bindings,
  e.g. `if ("system" in item) item.system = root.system`.
- Wire card signals to the existing Service re-emit signals; add a new
  `signal ...Committed` on Service only if the interaction persists data —
  persistence itself happens in BarWidget (single-writer rule).

### 6. Module registration (will bite otherwise)

Quickshell's scanner only registers directories imported **statically** from
an entry point. Dynamic `Loader` string URLs don't register.

- Shared card components must live in `widgets/` next to the cards.
- `DesktopSurface.qml` must keep its static `import "../widgets"`.
- Never `import "../ui"`-style cross-directory imports for card chrome —
  the `ui/` directory was deleted for exactly this reason.

### 7. `settings/SettingsPanel.qml` + BarWidget

- Add a `Toggle` (`onClicked: root.widgetToggled("<id>")`).
- If the widget persists interactions, add the write helper in BarWidget
  (merge over `settings` → normalize → `settings = next` →
  `updateEntryInline`) plus a `Connections` block on the Service signal.

### 8. i18n + tests

- Card strings → `i18n/en.json`; reference via `root.strings.t(...)` /
  `.tn(...)`; placeholders with `.arg()`, never concatenation into a
  translated sentence.
- Extend `tests/test_settings.js` for new normalization.

## Verify

`./scripts/check.sh`, then reload (`omarchy restart shell` — a new sampler
means service-tree changes), `hyprctl layers` (new surface at full size),
`quickshell log` (zero warnings), toggle on/off in the popup, restart shell
and confirm it persists.
