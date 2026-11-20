// Settings normalisation for macOS Glass Widgets.
// The stored object comes from shell.json and is untrusted: every field is
// coerced and clamped so a bad value yields a working widget.
var WIDGET_CLOCK = "clock"
var WIDGET_SYSTEM = "system"
var WIDGET_GPU = "gpu"
var WIDGET_MEDIA = "media"
var WIDGET_CALENDAR = "calendar"
var WIDGET_TODO = "todo"
var WIDGET_PHOTOS = "photos"

var KNOWN_WIDGETS = [WIDGET_CLOCK, WIDGET_SYSTEM, WIDGET_GPU, WIDGET_MEDIA, WIDGET_CALENDAR, WIDGET_TODO, WIDGET_PHOTOS]

var POSITIONS = [
  "top-left", "top-center", "top-right",
  "middle-left", "middle-right",
  "bottom-left", "bottom-center", "bottom-right"
]

var MEDIA_STYLES = ["cover", "poster", "vinyl", "lyrics"]
var CLOCK_STYLES = ["hero", "glass", "minimal"]
var SYSTEM_STYLES = ["rings", "bars"]
var CALENDAR_STYLES = ["split", "month"]

var DEFAULTS = {
  widgets: KNOWN_WIDGETS.slice(),
  positions: {},
  sizes: {},
  position: "top-left",
  marginX: 58,
  marginY: 24,
  cardWidth: 288,
  spacing: 14,
  opacity: 0.42,
  radius: 24,
  monitor: "",
  intervalMs: 2000,
  timeFormat: "24h",
  showDate: true,
  showLabels: false,
  showCpuCores: true,
  hideMediaWhenIdle: false,
  preferredPlayer: "",
  todoRows: 5,
  todos: [],
  photos: [],
  mediaStyle: "cover",
  clockStyle: "hero",
  systemStyle: "rings",
  calendarStyle: "split"
}

function isPlainObject(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value)
}

function clamp(value, min, max, fallback) {
  var n = Number(value)
  if (!isFinite(n)) return fallback
  return Math.max(min, Math.min(max, n))
}

function asList(value) {
  if (Array.isArray(value)) return value
  if (!value || typeof value !== "object") return []
  var length = value.length
  if (typeof length !== "number" || !isFinite(length) || length < 0) return []
  var out = []
  for (var i = 0; i < Math.min(Math.floor(length), 64); i++) out.push(value[i])
  return out
}

function normalizeWidgets(value) {
  var wanted = asList(value)
  var seen = {}
  for (var i = 0; i < wanted.length; i++) {
    var id = String(wanted[i] || "")
    if (KNOWN_WIDGETS.indexOf(id) !== -1) seen[id] = true
  }
  var out = []
  for (var k = 0; k < KNOWN_WIDGETS.length; k++) {
    if (seen[KNOWN_WIDGETS[k]]) out.push(KNOWN_WIDGETS[k])
  }
  return out
}

function normalizeSizes(value) {
  if (!isPlainObject(value)) return {}
  var out = {}
  for (var i = 0; i < KNOWN_WIDGETS.length; i++) {
    var id = KNOWN_WIDGETS[i]
    var entry = value[id]
    if (!isPlainObject(entry)) continue
    var w = clamp(entry.w, 120, 2000, 0)
    var h = clamp(entry.h, 80, 2000, 0)
    if (w > 0 && h > 0) out[id] = { w: Math.round(w), h: Math.round(h) }
  }
  return out
}

function normalizePositions(value) {
  if (!isPlainObject(value)) return {}
  var out = {}
  for (var i = 0; i < KNOWN_WIDGETS.length; i++) {
    var id = KNOWN_WIDGETS[i]
    var entry = value[id]
    if (!isPlainObject(entry)) continue
    var x = Number(entry.x)
    var y = Number(entry.y)
    if (!isFinite(x) || !isFinite(y)) continue
    out[id] = {
      x: Math.round(Math.max(-20000, Math.min(20000, x))),
      y: Math.round(Math.max(-20000, Math.min(20000, y)))
    }
  }
  return out
}

function normalizeTodos(value) {
  var list = asList(value)
  var out = []
  for (var i = 0; i < Math.min(list.length, 50); i++) {
    var entry = list[i]
    if (!isPlainObject(entry)) continue
    var text = String(entry.text || "").substring(0, 200)
    if (text.trim() === "") continue
    out.push({
      id: String(entry.id || ("t" + i + "_" + Date.now())).substring(0, 64),
      text: text,
      done: !!entry.done
    })
  }
  return out
}

var PHOTO_EXTS = ["jpg", "jpeg", "png", "webp", "gif", "bmp", "avif"]
var MAX_PHOTOS = 12

function normalizePhotos(value) {
  var list = asList(value)
  var out = []
  for (var i = 0; i < Math.min(list.length, MAX_PHOTOS); i++) {
    var entry = list[i]
    if (!isPlainObject(entry)) continue
    var id = String(entry.id || "").substring(0, 64)
    if (id === "") continue
    var path = String(entry.path || "").substring(0, 1024)
    var dot = path.lastIndexOf(".")
    var ext = dot !== -1 ? path.substring(dot + 1).toLowerCase() : ""
    if (PHOTO_EXTS.indexOf(ext) === -1) continue
    out.push({ id: id, path: path })
  }
  return out
}

function pickChoice(value, allowed, fallback) {
  var s = String(value || "")
  return allowed.indexOf(s) !== -1 ? s : fallback
}

function fromBarConfig(barConfig, id) {
  if (!isPlainObject(barConfig) || !isPlainObject(barConfig.layout)) return {}
  var sections = ["left", "center", "centerBegin", "centerEnd", "right", "tray"]
  for (var s = 0; s < sections.length; s++) {
    var arr = asList(barConfig.layout[sections[s]])
    for (var i = 0; i < arr.length; i++) {
      if (arr[i] && String(arr[i].id) === String(id)) return arr[i]
    }
  }
  return {}
}

function normalize(raw) {
  var value = isPlainObject(raw) ? raw : {}
  var out = {}
  out.widgets = normalizeWidgets(value.widgets !== undefined ? value.widgets : DEFAULTS.widgets)
  out.positions = normalizePositions(value.positions)
  out.sizes = normalizeSizes(value.sizes)
  out.position = pickChoice(value.position, POSITIONS, DEFAULTS.position)
  out.marginX = clamp(value.marginX, 0, 400, DEFAULTS.marginX)
  out.marginY = clamp(value.marginY, 0, 400, DEFAULTS.marginY)
  out.cardWidth = clamp(value.cardWidth, 120, 900, DEFAULTS.cardWidth)
  out.spacing = clamp(value.spacing, 0, 80, DEFAULTS.spacing)
  out.opacity = clamp(value.opacity, 0.05, 1, DEFAULTS.opacity)
  out.radius = clamp(value.radius, 0, 64, DEFAULTS.radius)
  out.monitor = typeof value.monitor === "string" ? value.monitor.substring(0, 64) : DEFAULTS.monitor
  out.intervalMs = clamp(value.intervalMs, 500, 60000, DEFAULTS.intervalMs)
  out.timeFormat = String(value.timeFormat) === "12h" ? "12h" : "24h"
  out.showDate = value.showDate === undefined ? DEFAULTS.showDate : !!value.showDate
  out.showLabels = value.showLabels === undefined ? DEFAULTS.showLabels : !!value.showLabels
  out.showCpuCores = value.showCpuCores === undefined ? DEFAULTS.showCpuCores : !!value.showCpuCores
  out.hideMediaWhenIdle = value.hideMediaWhenIdle === undefined ? DEFAULTS.hideMediaWhenIdle : !!value.hideMediaWhenIdle
  out.preferredPlayer = typeof value.preferredPlayer === "string" ? value.preferredPlayer.substring(0, 64) : ""
  out.todoRows = clamp(value.todoRows, 1, 20, DEFAULTS.todoRows)
  out.todos = normalizeTodos(value.todos !== undefined ? value.todos : DEFAULTS.todos)
  out.photos = normalizePhotos(value.photos !== undefined ? value.photos : DEFAULTS.photos)
  out.mediaStyle = pickChoice(value.mediaStyle, MEDIA_STYLES, DEFAULTS.mediaStyle)
  out.clockStyle = pickChoice(value.clockStyle, CLOCK_STYLES, DEFAULTS.clockStyle)
  out.systemStyle = pickChoice(value.systemStyle, SYSTEM_STYLES, DEFAULTS.systemStyle)
  out.calendarStyle = pickChoice(value.calendarStyle, CALENDAR_STYLES, DEFAULTS.calendarStyle)
  return out
}

if (typeof module !== "undefined") {
  module.exports = {
    DEFAULTS: DEFAULTS,
    KNOWN_WIDGETS: KNOWN_WIDGETS,
    MEDIA_STYLES: MEDIA_STYLES,
    CLOCK_STYLES: CLOCK_STYLES,
    SYSTEM_STYLES: SYSTEM_STYLES,
    CALENDAR_STYLES: CALENDAR_STYLES,
    normalize: normalize,
    normalizeWidgets: normalizeWidgets,
    normalizeTodos: normalizeTodos,
    fromBarConfig: fromBarConfig
  }
}
