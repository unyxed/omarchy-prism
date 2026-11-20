# AGENTS.md — macOS Glass Widgets

Omarchy shell plugin (service + bar-widget): macOS-style glass desktop cards.
Lives at `~/.config/omarchy/plugins/unyxed.macos-glass/` when installed, and in
its own public git repo when published.

## Golden rules (violations have broken this plugin before)

1. **BarWidget is the ONLY writer of `shell.json`.** Service never writes.
   Write path: merge over injected `settings` → `Settings.normalize` →
   `settings = next` → `bar.shell.updateEntryInline(moduleName, next)`.
2. **The bar host never injects `service`.** Resolve it with
   `bar.shell.serviceFor(moduleName)`, tolerating null.
3. **`rescanPlugins` does NOT recreate running services.** Edits to
   `Service.qml`, `services/`, `model/*.js`, or `surfaces/` need
   `omarchy restart shell`. Popup-only edits apply on rescan.
4. **No text input on desktop cards** (`keyboardFocus: None` layer).
   Composers live in the bar popup.
5. **Display text is `Text.PlainText`.** Dynamic text handed to
   Omarchy-owned sinks goes through `Sanitize.escapeMarkup`. Bound all
   external input. Fixed commands only — never interpolate untrusted
   values into shell strings.
6. **Keep `manifest.json` defaults/schema in sync with
   `model/Settings.js`** (`scripts/check.sh` verifies this).

## Skills (load the matching one before working)

- `.agents/skills/macos-glass-style/SKILL.md` — add or change a widget style
- `.agents/skills/macos-glass-widget/SKILL.md` — add a whole new widget
- `.agents/skills/macos-glass-debug/SKILL.md` — cards broken / toggles dead /
  stale behavior: diagnose with logs, don't guess

## Docs

- `README.md` — users. `DEVELOPMENT.md` — architecture + checklists.
  `PUBLISHING.md` — releases. `CHANGELOG.md` — history.

## Verify every change

```sh
./scripts/check.sh   # unit tests + validate + qmllint + manifest sync + symlinks
```

Then reload (`rescanPlugins`, or full `omarchy restart shell` per rule 3)
and confirm with `hyprctl layers` (one full-size surface per card) and
`quickshell log` (zero warnings for this plugin).
