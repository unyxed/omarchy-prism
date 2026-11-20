# Changelog

## 0.6.0

- Flippable calendar: double-click reveals a live agenda from Google
  Calendar ICS feeds (bounded fetch, recurrence + timezones, 14-day window,
  15-min refresh, manual refresh button)

## 0.5.0

- Free placement: left-drag any card to move it (clicks on buttons and
  checkboxes still work — drag only takes over past the threshold);
  right-drag still works; popup explains the gesture

## 0.4.0

- Flippable music card: double-click flips cover/poster/vinyl to reveal
  synced lyrics on the back (and back); animated 3D turn with height morph

## 0.3.0

- Lyrics: 4th music style with Apple-Music-style scrolling synced lyrics,
  live line highlight + auto-follow, plain-lyrics fallback, instrumental
  detection, per-track LRClrc fetch (bounded helper, no API key)

## 0.2.0

- Switchable styles per widget (Music: Cover/Poster/Vinyl, Clock:
  Hero/Glass/Minimal, System & GPU: Rings/Bars, Calendar: Split/Month)
  with live pickers in the bar popup
- MPRIS-native media service (no `playerctl`): live play/pause/track/art
  updates, progress bar, capability-gated transport buttons
- Bounded album-art pipeline (fetch helper + magic-byte gate + masked display)
- Split month-grid calendar with today highlight; reminders card redesign
- Bento 1–2 column desktop layout, drag/resize persistence
- i18n catalog for card strings; unit tests for styles

## 0.1.0

- Initial release: clock, system, GPU, media, calendar, todo desktop cards;
  bar popup with toggles; hyprglass-compatible glass styling.
