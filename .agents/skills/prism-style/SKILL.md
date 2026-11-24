---
name: prism-style
description: >
  Add or change a widget style in the unyxed.prism Omarchy plugin
  (e.g. a new music/clock/system/calendar look). Use when the task is a new
  entry for mediaStyle, clockStyle, systemStyle, or calendarStyle, or
  modifying an existing style's layout. Covers the 6-file change set,
  manifest/Settings sync, popup picker wiring, and verification.
---

# Add a Widget Style

Styles are string settings (e.g. `mediaStyle: "cover" | "poster" | "vinyl"`).
Every style touches the same 6 files. Do all of them — a style that skips the
manifest or the `DesktopSurface` binding silently never appears.

## Procedure

### 0. Orient (read before editing)

- `model/Settings.js` — `*_STYLES` lists, `DEFAULTS`, `normalize`/`pickChoice`
- The target card in `widgets/` (e.g. `MediaCard.qml`)
- `surfaces/DesktopSurface.qml` → `configure()` style bindings
- `settings/SettingsPanel.qml` → existing `StyleRow` blocks
- `manifest.json` → `barWidget.defaults` + `barWidget.schema`

### 1. `model/Settings.js`

- Append the value to the matching `*_STYLES` array (create one if the widget
  has no style family yet, and export it in `module.exports`).
- Add the default to `DEFAULTS`.
- Normalize with `pickChoice(value.xStyle, X_STYLES, DEFAULTS.xStyle)` —
  never a bare assignment (hand-edited `shell.json` must fall back, not break).

### 2. `manifest.json`

- Mirror the default under `barWidget.defaults`.
- Add a `schema` entry: `{key, type: "string", label, description listing the
  allowed values, defaultValue}`.
- Bump `version` if this is a release-bound change.

### 3. Card QML

- Declare `property string <thing>Style: "<default>";` on the card root.
- Gate each look in its own top-level item with `visible: root.<thing>Style === "..."`.
- New display text: `textFormat: Text.PlainText`. Text for Omarchy-owned sinks
  (tooltips): `Sanitize.escapeMarkup(...)`. No `TextInput` on cards — the
  desktop layer has `keyboardFocus: None`, so inputs can never focus.
- Never put a `QtObject` (`Translations`, `Timer`) as a bare child of a
  `GlassCard`: its `default property alias content: column.children` accepts
  only `Item`s and the card will fail to load with
  `Cannot assign object of type ... to list property "content"`.
  Declare them as `property var x: ...` instead (see `GlassCard.strings`).
- Files using bare `Style`/`Color`/`Util` need plain `import qs.Commons`;
  files using `Commons.X` need `import qs.Commons as Commons`. Most files
  need both.

### 4. `surfaces/DesktopSurface.qml` → `configure()`

- Add the binding, guarded exactly like the others:
  `if ("<thing>Style" in item) item.<thing>Style = Qt.binding(function () { return root.config.<thing>Style })`
- A style that skips this step renders the default forever — this is the most
  commonly forgotten step.

### 5. `settings/SettingsPanel.qml`

- Add a `StyleRow` with `label`, `selected: root.config.<thing>Style`,
  `options` (`[{value, label}...]`), `onPicked: settingChanged("<thing>Style", v)`.

### 6. Tests

- Extend `tests/test_settings.js`: valid value passes through, unknown value
  falls back to `DEFAULTS` (copy the existing style assertions).

## Verify

```sh
./scripts/check.sh
```

Then reload and prove it live:

- Popup-only + card changes: `omarchy-shell shell rescanPlugins`
- `model/*.js`, `Service.qml`, `services/`, `surfaces/` touched:
  `omarchy restart shell` (rescan does NOT recreate running services —
  edits will look ignored otherwise)
- `hyprctl layers` — one full-size `unyxed-prism` surface per enabled
  card (`280x1` = card `Loader` failed; see prism-debug skill)
- `quickshell log -p /usr/share/omarchy/shell` — zero warnings for this plugin
- Flip the new style in the popup; confirm it renders and persists across a
  shell restart

## Failure patterns this procedure prevents

| Symptom | Cause | Already debugged |
|---|---|---|
| Style never appears, default always renders | Binding missing in `configure()` | yes |
| All cards vanish (`280x1` surfaces) | Card failed to load (bad import, QtObject child) | yes — see debug skill |
| Bad `shell.json` value blanks the card | Style assigned without `pickChoice` fallback | yes |
| Popup picker missing | No `StyleRow`, or signal name mismatch | yes |
| Edit seems ignored | Changed service-tree file, only rescanned | yes |
