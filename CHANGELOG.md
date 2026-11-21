# Changelog

## 0.9.0

- Fixed: popup changes could be silently deferred until a shell restart —
  a killed drag wedged the surface-rebuild gate (repro'd live: the toggle
  landed in shell.json, the desktop never refreshed). The gate is now
  event-driven with a self-healing watchdog; toggles apply instantly
- Fixed: startup layout pile-up (cards stacked at the anchor and cascaded
  as measurements arrived) — provisional per-card heights make the first
  layout near-final
- Fixed: drags and flow placement now respect a right-edge floating dock
  (probed once at startup; no dock, no clamp)
- Popup: position picker shows the pinned count and explains that pinned
  cards ignore it; photo add failures show an inline reason instead of
  failing silently; reminders section notes when the card is hidden

## 0.8.3

- Removed the "Double-click to flip back" hint lines: cleaner backs with
  more room for content (flip gesture is documented in README/popup)

## 0.8.2

- Flip backs fit the front frame (remaining-space lists): flipping and
  late-arriving lyrics/events never resize a card; music progress area
  always reserved so first playback doesn't resize either

## 0.8.1

- Flip height follows the visible face (plus explicit user resizes):
  no more permanent dead space from pinning the taller face

## 0.8.0

- Flippable system card: per-core bar strips removed from the front;
  double-click reveals labeled per-thread rows plus memory on the back
  (the per-thread toggle is gone with them)

## 0.7.4

- First-flip stutter, second attempt: warm-up now runs for 5 s behind the
  front face instead of 150 ms at 0 opacity — a short early window misses
  because the layer surface is not yet mapped, so nothing was painted

## 0.7.3

- Fix one-time first-flip stutter: the back face was never painted before
  the first flip, so shaders/delegates compiled mid-animation; both flip
  cards now warm the back invisibly at startup

## 0.7.2

- Right-button-only dragging: left-drag removed so move, resize and
  double-click-to-flip never fight over the same gesture; drag areas are
  explicit visual children (guaranteed event delivery)

## 0.7.1

- Fix drag lag: left-drag now measures in global screen coordinates
  (the DragHandler centroid was resolved in the card's own moving frame,
  so the widget perpetually trailed the cursor); flip gesture moved onto
  the same card-level handler

## 0.7.0

- Photo widgets: add your own pictures as desktop tiles via the bar popup
  (system file picker, extension + size + regular-file validation, max 12),
  edge-to-edge rounded display, free drag placement, corner resize

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
