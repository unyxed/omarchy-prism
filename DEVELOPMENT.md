# Development guide — macOS Glass Widgets

How this plugin works, how to change it safely, and how to keep it healthy.
User-facing docs live in [README.md](README.md); publishing in
[PUBLISHING.md](PUBLISHING.md).

> **Agents:** load `AGENTS.md` first, then the matching skill under
> `.agents/skills/` (`macos-glass-style`, `macos-glass-widget`,
> `macos-glass-debug`). This guide is the human-readable companion; the
> skills are the executable procedures.

## 1. Architecture

Two QML entry points, one settings flow:

```
BarWidget.qml (bar icon + popup) ──write──▶ shell.json bar entry
        │ pushes settings                        ▲ host re-injects
        ▼                                        │
Service.qml ──owns──▶ samplers + DesktopSurface ─┘
                         │ PanelWindow per card, WlrLayer.Bottom
                         ▼
                    widgets/*.qml (display only)
```

- **BarWidget is the ONLY writer of `shell.json`.** `write()` merges over the
  host-injected `settings`, normalizes, assigns `settings = next` for instant
  UI feedback, then calls `bar.shell.updateEntryInline(moduleName, next)`
  synchronously. No timers, no shadow copies.
- **Service never writes.** It exposes `applySettings(next)` (ignores empty
  pushes) and derives `config = normalize(pushedSettings ?? barConfig)`.
  BarWidget pushes on `onSettingsChanged`, `onServiceChanged`, `onCompleted`.
- **Service lookup, not injection:** the bar host injects `bar`, `moduleName`,
  `settings` — never `service`. BarWidget resolves it itself:
  `bar.shell.serviceFor(moduleName)`, tolerating null (service-less bars).
- **Desktop is display-only.** Cards bind to service samplers; drag/resize/todo
  toggles re-emit as Service signals → BarWidget `Connections` → `write()`.
  The desktop layer has `keyboardFocus: None`, so there is deliberately **no
  text input on desktop cards** — the todo composer lives in the popup.
- **One `PanelWindow` per card** (not one fullscreen overlay), so gaps between
  cards stay click-through. Exclusion zone 0, namespace `unyxed-macos-glass`
  (the hyprglass target).

### File map

| Path | Role |
|---|---|
| `manifest.json` | Plugin contract: id, kinds, entry points, defaults + schema. **Keep `defaults`/`schema` in sync with `model/Settings.js`.** |
| `BarWidget.qml` | Bar icon, popup wiring, the single write path, todo add/toggle |
| `Service.qml` | Samplers, `applySettings`, desktop surface, re-emitted signals |
| `surfaces/DesktopSurface.qml` | Per-card `PanelWindow`s, stack/bento layout, drag/resize math |
| `widgets/GlassCard.qml` | Shared frosted card chrome (fill, rim, header, drag/resize areas) |
| `widgets/*Card.qml` | One display card per widget id |
| `widgets/RingGauge.qml` | Canvas ring gauge shared by System/Gpu cards |
| `widgets/AlbumArt.qml` | Bounded art fetch + masked display (round or rounded-rect) |
| `services/*.qml` | Pollers/sensors: System (`/proc`), Gpu (`nvidia-smi`/sysfs), Media (MPRIS), Calendar (local JSON) |
| `model/Settings.js` | Normalization + `fromBarConfig`; pure JS, unit-tested with node |
| `model/Layout.js` | 1–2 column bento flow positions; pure JS |
| `model/Sanitize.js` | `escapeMarkup` / `cleanLine` / `boundList`; pure JS, unit-tested |
| `model/Sysfs.js` | `/proc` parsers; pure JS |
| `settings/SettingsPanel.qml` | Popup content: toggles, style pickers, sliders, todo manager |
| `scripts/macos-glass-art` | Bounded art fetcher (curl/file copy + magic-byte gate) |
| `i18n/en.json` | English card strings (bar tooltip, empty states, plurals) |
| `tests/` | `test_sanitize.js`, `test_settings.js` — run with `node` |

## 2. Data flow per widget

- **Clock:** local `Timer` (1s) + `Qt.locale(...).toString(...)` for dates.
- **System:** `FileView` on `/proc/stat` + `/proc/meminfo`, 2s timer, baseline
  reset on resume. Gated by `sampling` (no widgets visible → no polling).
- **GPU:** one-shot `Process` discovery (NVIDIA `nvidia-smi` vs AMD sysfs vs
  `none`), then vendor-appropriate sampling.
- **Media:** `Quickshell.Services.Mpris` signal-driven. An `Instantiator`
  attaches `Connections` to every player (`onIsPlayingChanged`,
  `onTrackTitleChanged`, …) bumping `revision`; derived properties re-read.
  Player pick order: preferred+playing → preferred → playing → loaded.
  Progress ticks 1/s while playing. Controls call `togglePlaying/next/previous`
  gated on `canControl`/`canGo*`.
- **Lyrics:** per-track MPRIS change triggers a debounced `scripts/macos-glass-lyrics`
  fetch (LRClrc, 8s timeout, 64 KiB cap, validated JSON). `model/Lyrics.js`
  parses LRC (`[{t, text}]`, bounded, control-stripped) and resolves the
  current line from playback position. Synced lines render in an auto-following
  `ListView`; untimed lyrics render as scrollable text.
- **Calendar:** reads `~/.config/omarchy/calendars.json` (names+colors only,
  30s refresh). No network fetch for the front face.
- **Agenda (card back):** `scripts/macos-glass-agenda` downloads enabled
  http(s) feed URLs (plain `url` or Google `googleCalendarId` private ICS),
  10s timeout, 512 KiB cap, 2000-VEVENT cap per feed. Parses VEVENTs
  (timezones via zoneinfo, `VALUE=DATE` all-day), expands simple recurrence
  (`FREQ=DAILY|WEEKLY|MONTHLY|YEARLY` + `INTERVAL`/`COUNT`/`UNTIL`/weekly
  `BYDAY`, `EXDATE` honored, `RECURRENCE-ID` overrides skipped), sorts and
  caps at 50 events over a 14-day window. Refreshed every 15 min while the
  card is shown, plus a manual refresh button. Self-test:
  `scripts/macos-glass-agenda --selftest` (wired into `check.sh`).
- **Todos:** stored in the plugin's own bar entry (`todos`, max 50×200 chars).
- **Photos:** runtime data, not code. `photos: [{id, path}]` (max 12,
  extension-allowlisted in `normalizePhotos`) renders one `WlrLayer.Bottom`
  surface per entry with ids namespaced `photo.<id>` so stored
  positions/sizes can never collide with widget ids. `DesktopSurface`
  stacks `displayWidgets` (widgets minus `photos`, plus photo ids) and
  resolves paths via `photoEntryFor`. Files come only from the system file
  picker (`omarchy file select`), validated as regular non-symlink files
  ≤ 20 MiB before persisting; rendering caps decode size for large photos.

## 3. Adding a widget

1. `model/Settings.js`: add id to `KNOWN_WIDGETS`, defaults, `normalize()`.
2. `manifest.json`: mirror the default + a `schema` entry (keep in sync!).
3. `widgets/<Name>Card.qml`: extend `GlassCard`, `Text.PlainText` everywhere,
   read data via props (never import a service directly).
4. `surfaces/DesktopSurface.qml`: add `sourceFor()` branch; add prop bindings
   in `configure()` guarded by `if ("prop" in item)`.
5. `model/Layout.js`: `widgetName`/`widgetGlyph`.
6. `settings/SettingsPanel.qml`: add a `Toggle` + `onWidgetToggled`.
7. `i18n/en.json`: add card strings; use `.arg()` for placeholders,
   `strings.tn()` for plurals.
8. `tests/`: extend `test_settings.js` for new normalization.

## 4. Adding a widget style

1. `model/Settings.js`: extend the `<thing>_STYLES` list + `DEFAULTS` +
   `normalize` via `pickChoice`.
2. `manifest.json`: default + schema entry.
3. Card QML: `property string <thing>Style: "<default>"`; gate sections on it.
4. `surfaces/DesktopSurface.qml`: bind it in `configure()`.
5. `settings/SettingsPanel.qml`: add a `StyleRow`.
6. Test: flip styles live from the popup; verify no `quickshell log` warnings.

## 5. Testing

```sh
cd ~/.config/omarchy/plugins/unyxed.macos-glass
node tests/test_sanitize.js && node tests/test_settings.js
omarchy plugin validate .
for f in BarWidget.qml Service.qml ui/*.qml settings/*.qml surfaces/*.qml widgets/*.qml services/*.qml; do
  /usr/lib/qt6/bin/qmllint "$f" || echo "FAIL $f"
done
omarchy-shell shell rescanPlugins   # picks up QML edits (service instances persist!)
```

Caveats that have bitten before — read before debugging:

- **`rescanPlugins` does NOT recreate running services.** After editing
  `Service.qml` or anything it instantiates, run `omarchy restart shell`.
  BarWidget/popup edits apply on rescan.
- **QML module registration:** Quickshell's scanner only registers directories
  imported *statically* from entry points. Cards must live beside their shared
  components (`widgets/GlassCard.qml` next to the cards, `import "../widgets"`
  in `DesktopSurface.qml`) — dynamic `Loader` string URLs don't register.
- **`default property alias content: column.children` accepts only Items.**
  Never put a `QtObject` (e.g. `Commons.Translations`, `Timer`) as a bare
  child of a card — declare them as `property var x: ...` instead.
- **QML files using bare `Style`/`Color`/`Util` need plain `import qs.Commons`;**
  files using `Commons.X` need `import qs.Commons as Commons`. Most files need
  both (see Omarchy's own clock panel).
- **No `Component.onCompleted` twice** on one object; no duplicate signal
  handlers. Check `onSettingsChanged` loops when assigning injected props.
- **Verify visually:** `hyprctl layers` (one surface per card, real sizes —
  `280x1` means the card `Loader` failed), `quickshell log -p
  /usr/share/omarchy/shell` (zero `WARN scene` lines for this plugin).

## 6. Safety rules (Omarchy plugin contract)

- Display text the plugin owns: `textFormat: Text.PlainText`.
- Text handed to Omarchy-owned sinks (bar tooltips): `Sanitize.escapeMarkup`.
- Bound everything from outside: collection lengths, string lengths, response
  sizes, identifiers, timestamps (`Sanitize.cleanLine`/`boundList`, 200-char
  todo cap, 1–2 MiB art cap).
- Fixed commands only. Never interpolate untrusted values into shell commands;
  media controls call MPRIS methods, not subprocesses.
- Art pipeline: player URL → scheme allowlist (`https/http/file`) → helper
  download under timeout+size cap → magic-byte gate (PNG/JPEG/GIF/WebP) →
  `Image` only ever loads the helper-written file. See `scripts/macos-glass-art`
  and `widgets/AlbumArt.qml`.
- No network polling loops; sampling timers stop when nothing is shown.
- Keep tests green: every shared sink for dynamic text needs a regression test.

## 7. i18n

Card strings live in `i18n/<lang>.json`, read via `Commons.Translations`
(declared once as `strings` on `GlassCard`, inherited by cards). Missing keys
fall back en → key. Whole sentences with `%1` + `.arg()`; counts via
`strings.tn(key, n).arg(...)` with CLDR plural categories. Dates via
`Qt.locale(Commons.I18n.formatLocale).toString(...)`, numbers via
`Commons.I18n.formatNumber`. Known gap: the settings popup is English-only
for now — cards are translated, popup chrome is not.

## 8. Release checklist

- [ ] `node` tests pass, `omarchy plugin validate` clean, `qmllint` clean
- [ ] `hyprctl layers` shows one full-size surface per enabled card
- [ ] `quickshell log` shows no warnings for `unyxed.macos-glass`
- [ ] Toggles/styles persist across shell restart (write path round-trip)
- [ ] `manifest.json` version bumped, `defaults`/`schema` match `Settings.js`
- [ ] `CHANGELOG.md` updated
