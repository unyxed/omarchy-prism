# Publishing — macOS Glass Widgets

How to ship this plugin to other Omarchy users and list it on the community
marketplace.

## 1. One-time setup: public git repo

The marketplace lists git repos; `omarchy plugin add <url>` installs from them.

```sh
cd ~/.config/omarchy/plugins/unyxed.macos-glass
git init
git add -A
git commit -m "macOS Glass Widgets 0.2.0"
gh repo create omarchy-macos-glass --public --source=. --push
```

Requirements for the repo root (all already in place except the remote):

- [ ] Public GitHub repository
- [ ] `manifest.json` in the root (valid — `omarchy plugin validate .`)
- [ ] `README.md` with install + remove instructions
- [ ] `LICENSE` file (MIT)
- [ ] Documented external dependencies (README “External dependencies”)
- [ ] Unique id outside `omarchy.*` (`unyxed.macos-glass` ✓)
- [ ] No symlinks in the tree (`find . -type l` must print nothing)
- [ ] Optional `preview.png` at root (included; marketplace auto-optimizes)

Before pushing, set the real repo URL: nothing in the tree hardcodes one, so
no code changes are needed — just push.

## 2. Submit to the marketplace

Listing lives at <https://plugins.omarchy.org> (repo:
`omacom/omarchy-plugin-marketplace`). Submission is an issue form:

- **Repository URL:** `github.com/<you>/omarchy-macos-glass`
- **Category:** `Widgets`
- **Tags:** `media, quickshell, system`
- **Checklist:** repo is public with install/remove docs; license +
  dependencies documented; you own the code and preview assets; no silent
  config overwrites (all writes go through `updateEntryInline` on the
  plugin's own entry); listing ≠ security review, you stay responsible.

Automated validation checks the submitted commit; a maintainer approves.

Suggested maintainer notes to paste:

> Desktop widget suite (service + bar-widget): clock, CPU/RAM, GPU, MPRIS
> media with bounded cover-art fetch, calendar, local reminders. No required
> dependencies; optional hyprglass + any MPRIS player. Writes only its own
> bar entry via updateEntryInline.

## 3. Versioning

Strict semver, always increasing. Bump `manifest.json` `version` on every
release and add a `CHANGELOG.md` entry. Keep `manifest.json`
`defaults`/`schema` byte-identical in meaning to `model/Settings.js`
`DEFAULTS`/`normalize` — the release checklist in DEVELOPMENT.md covers this.

## 4. After listing

- Users install with `omarchy plugin add <repo-url> --enable`.
- Push fixes as normal commits; users update with
  `omarchy plugin update unyxed.macos-glass`.
- Never rename the plugin id — user configs key off it.
