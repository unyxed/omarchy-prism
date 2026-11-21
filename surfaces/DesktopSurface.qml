import QtQuick
import qs.Commons
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Ui
import "../widgets"
import "../model/Layout.js" as Layout
import "../model/Placement.js" as Placement

// Desktop cards above the wallpaper, below windows. One small surface per
// card so gaps between cards stay click-through. The namespace is the one
// hyprglass is bound to, so translucency becomes real liquid glass.
Item {
  id: root

  required property var config
  required property var system
  required property var gpu
  required property var media
  required property var calendar
  property var todos: []
  property int todoRows: 5

  property bool show: true

  signal resizePreview(string id, real w, real h)
  signal resizeCommit(string id, real w, real h)
  signal movePreview(string id, real dx, real dy)
  // pinned=false means "rejoin the flow" (the position args are the flow
  // slot, kept for the write path's symmetry). screen is the monitor the
  // drop happened on, so pins can belong to one monitor only.
  signal moveCommit(string id, real x, real y, bool pinned, string screen)
  signal todoToggled(string id)

  readonly property var widgets: config && config.widgets ? config.widgets : []
  readonly property var photoEntries: config && config.photos ? config.photos : []

  // Stack widgets first (canonical order), then one surface per photo entry.
  // Photo ids are namespaced ("photo.<id>") so drag/resize/tooltip keys in
  // shell.json can never collide with widget ids.
  readonly property var displayWidgets: {
    var out = []
    var list = root.widgets
    for (var i = 0; i < list.length; i++)
      if (list[i] !== "photos") out.push(list[i])
    if (list.indexOf("photos") !== -1) {
      var photos = root.photoEntries
      for (var j = 0; j < photos.length; j++)
        if (photos[j] && photos[j].id) out.push("photo." + String(photos[j].id))
    }
    return out
  }

  function photoEntryFor(id) {
    var list = root.photoEntries
    for (var i = 0; i < list.length; i++)
      if (list[i] && ("photo." + String(list[i].id)) === String(id)) return list[i]
    return null
  }
  readonly property bool mediaPresent: media ? media.hasMedia : false
  onMediaPresentChanged: root.refreshSurfaces()
  onMediaChanged: root.refreshSurfaces()

  property var heights: ({})
  property var widths: ({})
  property var liveSizes: ({})
  property var livePositions: ({})

  function explicitSize(id) {
    if (liveSizes[id]) return liveSizes[id]
    return config && config.sizes ? config.sizes[id] : null
  }

  function cardWidth(id) {
    var size = explicitSize(id)
    return size ? size.w : config.cardWidth
  }

  function cardHeight(id) {
    var size = explicitSize(id)
    return size ? size.h : 0
  }

  function flowWidth(id) {
    var size = explicitSize(id)
    if (size) return size.w
    return widths[id] !== undefined ? widths[id] : config.cardWidth
  }

  // Provisional heights: a fresh shell measures each card asynchronously,
  // so the first flow layout would stack everything at the anchor and
  // cascade into place as measurements arrive — visible pile-up, transient
  // overlaps, and column-count flip-flops. These seeds approximate each
  // card's measured size (observed at default settings), making the first
  // layout near-final with one small settle instead.
  readonly property var seedHeights: ({
    clock: 134, system: 130, gpu: 130, media: 140, calendar: 183, todo: 126
  })

  function flowHeight(id) {
    var size = explicitSize(id)
    if (size) return size.h
    if (heights[id] !== undefined) return heights[id]
    if (String(id).indexOf("photo.") === 0) return Math.round(config.cardWidth * 0.75)
    return seedHeights[id] !== undefined ? seedHeights[id] : 140
  }

  function noteMetrics(id, w, h) {
    if (widths[id] === w && heights[id] === h) return
    var nextWidths = {}
    for (var k in widths) nextWidths[k] = widths[k]
    nextWidths[id] = w
    var nextHeights = {}
    for (var j in heights) nextHeights[j] = heights[j]
    nextHeights[id] = h
    widths = nextWidths
    heights = nextHeights
  }

  // A pin belongs to the screen it was dropped on. Entries without a
  // screen are legacy and apply everywhere, so single-monitor users and
  // old configs never see a difference.
  function pinnedFor(id, screen) {
    var entry = config.positions ? config.positions[id] : null
    if (!entry) return null
    if (typeof entry.screen === "string" && entry.screen !== ""
      && screen && String(screen.name) !== entry.screen) return null
    return entry
  }

  // includeId: compute the flow as if that one card were unpinned — the
  // "home slot" a drop can return to.
  function flowEntries(includeId, screen) {
    var out = []
    var list = root.displayWidgets || []
    for (var i = 0; i < list.length; i++) {
      var id = list[i]
      if (id === "media" && config.hideMediaWhenIdle && media && !media.hasMedia) continue
      var pin = root.pinnedFor(id, screen)
      if (pin && id !== includeId) continue
      out.push({ id: id, w: root.flowWidth(id), h: root.flowHeight(id) })
    }
    return out
  }

  function flowFor(screen, includeId) {
    return Layout.flowPositions(config.position, root.flowEntries(includeId, screen),
      config.spacing, config.marginX, config.marginY,
      screen ? screen.width - root.reservedRightFor(screen) : 0,
      screen ? screen.height : 0)
  }

  function basePositionFor(id, screen) {
    var pin = root.pinnedFor(id, screen)
    if (pin) return pin
    var flow = root.flowFor(screen)
    return flow[id] || { x: config.marginX, y: config.marginY }
  }

  function positionFor(id, screen) {
    if (root.livePositions[id]) return root.livePositions[id]
    return root.basePositionFor(id, screen)
  }

  function clampPosition(id, screen, x, y) {
    var reserve = root.reservedRightFor(screen)
    var maxX = Math.max(0, (screen ? screen.width - reserve : 0) - root.flowWidth(id))
    var maxY = Math.max(0, (screen ? screen.height : 0) - root.flowHeight(id))
    return {
      x: Math.round(Math.max(0, Math.min(maxX, x))),
      y: Math.round(Math.max(0, Math.min(maxY, y)))
    }
  }

  // A surface rebuild destroys live grab state, which kills an in-progress
  // drag dead mid-motion (card stops following until the next press). While
  // pointer events keep arriving for a card, rebuilds are deferred.
  //
  // The gate must never wedge. A drag whose grab dies mid-motion sends no
  // more events, so the watchdog releases the gate, drops the stale preview
  // and flushes whatever was deferred — otherwise one killed drag
  // permanently defers every popup change until the shell restarts (the
  // write still lands in shell.json, so restarting looks like the only
  // fix). Verified live: toggles landed but surfaces never refreshed.
  property double lastPointerEventMs: 0
  property bool gateHeld: false
  property bool surfacesDirty: false

  function notePointerEvent() {
    root.lastPointerEventMs = Date.now()
    if (!root.gateHeld) root.gateHeld = true
  }

  Timer {
    id: gateWatchdog
    interval: 500
    repeat: true
    running: root.gateHeld
    onTriggered: {
      var idleMs = Date.now() - root.lastPointerEventMs
      var empty = Object.keys(root.livePositions).length === 0
        && Object.keys(root.liveSizes).length === 0
      // Fast release: drag committed and round-tripped (maps pruned).
      if (idleMs > 750 && empty) {
        root.gateHeld = false
        if (root.surfacesDirty) root.refreshSurfaces()
      // Hard release: grab died mid-motion (no events for 2s). The stale
      // preview is dropped — the position was never committed, so showing
      // it there was a lie — and deferred rebuilds flush.
      } else if (idleMs > 2000) {
        root.gateHeld = false
        root.livePositions = ({})
        root.liveSizes = ({})
        if (root.surfacesDirty) root.refreshSurfaces()
      }
    }
  }

  readonly property bool interacting: root.gateHeld

  function showCardMove(id, dx, dy, screen) {
    root.notePointerEvent()
    var base = root.basePositionFor(id, screen)
    var pos = root.clampPosition(id, screen, base.x + dx, base.y + dy)
    var next = {}
    for (var k in root.livePositions) next[k] = root.livePositions[k]
    next[id] = pos
    root.livePositions = next
  }

  function commitCardMove(id, dx, dy, screen) {
    root.showCardMove(id, dx, dy, screen)
    var raw = root.livePositions[id]
    var card = { x: raw.x, y: raw.y, w: root.flowWidth(id), h: root.flowHeight(id) }
    var screenName = screen ? String(screen.name) : ""

    // Dropped back onto the flow slot the card would occupy when unpinned:
    // rejoin the stack instead of pinning beside it. Clear the live
    // override so the card falls to its flow binding immediately.
    var home = root.flowFor(screen, id)[id]
    if (home && Placement.rectsOverlap(card, home)) {
      var cleared = {}
      for (var lp in root.livePositions) if (lp !== id) cleared[lp] = root.livePositions[lp]
      root.livePositions = cleared
      root.moveCommit(id, home.x, home.y, false, screenName)
      return
    }

    // Free placement, minus overlaps: settle to the nearest spot that
    // touches neither another card nor the screen edge.
    var resolved = Placement.resolveDrop(card, root.otherRects(id, screen), root.screenBounds(screen))
    root.moveCommit(id, Math.round(resolved.x), Math.round(resolved.y), true, screenName)
  }

  function screenBounds(screen) {
    return {
      x: 0, y: 0,
      w: Math.max(0, (screen ? screen.width : 0) - root.reservedRightFor(screen)),
      h: screen ? screen.height : 0
    }
  }

  function otherRects(id, screen) {
    var out = []
    var list = root.displayWidgets || []
    for (var i = 0; i < list.length; i++) {
      var other = list[i]
      if (other === id || !root.isVisible(other)) continue
      var pos = root.positionFor(other, screen)
      out.push({ x: pos.x, y: pos.y, w: root.flowWidth(other), h: root.flowHeight(other) })
    }
    return out
  }

  function showCardResize(id, w, h) {
    root.notePointerEvent()
    var next = {}
    for (var k in root.liveSizes) next[k] = root.liveSizes[k]
    next[id] = { w: w, h: h }
    root.liveSizes = next
  }

  function commitCardResize(id, w, h) {
    root.showCardResize(id, w, h)
    root.resizeCommit(id, w, h)
  }

  function pruneLive() {
    // Live previews only make sense for cards that still exist; a toggle
    // that removes a widget mid-drag must not leave its entry behind.
    var known = {}
    var list = root.displayWidgets || []
    for (var w = 0; w < list.length; w++) known[String(list[w])] = true
    var sizes = {}
    var sizeChanged = false
    for (var k in root.liveSizes) {
      if (!known[k]) { sizeChanged = true; continue }
      var stored = config.sizes ? config.sizes[k] : null
      if (stored && stored.w === root.liveSizes[k].w && stored.h === root.liveSizes[k].h)
        sizeChanged = true
      else
        sizes[k] = root.liveSizes[k]
    }
    if (sizeChanged) root.liveSizes = sizes
    var positions = {}
    var positionChanged = false
    for (var p in root.livePositions) {
      if (!known[p]) { positionChanged = true; continue }
      var committed = config.positions ? config.positions[p] : null
      if (committed && committed.x === root.livePositions[p].x
          && committed.y === root.livePositions[p].y)
        positionChanged = true
      else
        positions[p] = root.livePositions[p]
    }
    if (positionChanged) root.livePositions = positions
  }

  onConfigChanged: {
    root.pruneLive()
    root.refreshSurfaces()
  }

  function isVisible(id) {
    if (id === "media" && config.hideMediaWhenIdle && media && !media.hasMedia) return false
    return true
  }

  function sourceFor(id) {
    if (id === "clock") return "../widgets/ClockCard.qml"
    if (id === "system") return "../widgets/SystemCard.qml"
    if (id === "gpu") return "../widgets/GpuCard.qml"
    if (id === "media") return "../widgets/MediaCard.qml"
    if (id === "calendar") return "../widgets/CalendarCard.qml"
    if (id === "todo") return "../widgets/TodoCard.qml"
    if (String(id).indexOf("photo.") === 0) return "../widgets/PhotoCard.qml"
    return ""
  }

  function configure(item, id, screen) {
    if (!item) return
    item.widgetId = id
    if (String(id).indexOf("photo.") === 0) {
      // Photo tiles are chromeless; the header stays off for them.
      item.title = ""
      item.glyph = ""
      var entry = root.photoEntryFor(id)
      item.filePath = entry ? String(entry.path || "") : ""
    } else {
      item.title = Layout.widgetName(id)
      item.glyph = Layout.widgetGlyph(id)
    }
    item.showHeader = Qt.binding(function () { return root.config.showLabels })
    item.bgOpacity = Qt.binding(function () { return root.config.opacity })
    item.cardRadius = Qt.binding(function () { return root.config.radius })
    item.cardW = Qt.binding(function () { return root.cardWidth(id) })
    item.cardH = Qt.binding(function () { return root.cardHeight(id) })
    if ("system" in item) item.system = root.system
    if ("gpu" in item) item.gpu = root.gpu
    if ("media" in item) item.media = root.media
    if ("calendar" in item) item.calendar = root.calendar
    if ("todos" in item) {
      item.todos = Qt.binding(function () { return root.todos })
      item.todoRows = Qt.binding(function () { return root.todoRows })
      if (item.toggleRequested && typeof item.toggleRequested.connect === "function")
        item.toggleRequested.connect(function (todoId) { root.todoToggled(todoId) })
    }
    if ("timeFormat" in item)
      item.timeFormat = Qt.binding(function () { return root.config.timeFormat })
    if ("showDate" in item)
      item.showDate = Qt.binding(function () { return root.config.showDate })
    if ("mediaStyle" in item)
      item.mediaStyle = Qt.binding(function () { return root.config.mediaStyle })
    if ("clockStyle" in item)
      item.clockStyle = Qt.binding(function () { return root.config.clockStyle })
    if ("systemStyle" in item)
      item.systemStyle = Qt.binding(function () { return root.config.systemStyle })
    if ("calendarStyle" in item)
      item.calendarStyle = Qt.binding(function () { return root.config.calendarStyle })
    item.resizePreview.connect(function (cardId, w, h) { root.showCardResize(cardId, w, h) })
    item.resizeCommit.connect(function (cardId, w, h) { root.commitCardResize(cardId, w, h) })
    item.movePreview.connect(function (cardId, dx, dy) { root.showCardMove(cardId, dx, dy, screen) })
    item.moveCommit.connect(function (cardId, dx, dy) { root.commitCardMove(cardId, dx, dy, screen) })
  }

  readonly property var targetScreens: {
    var wanted = String(config.monitor || "")
    var all = Quickshell.screens
    if (wanted === "") return all
    var out = []
    for (var i = 0; i < all.length; i++) if (all[i] && all[i].name === wanted) out.push(all[i])
    return out
  }

  property var surfaces: []
  property string surfacesKey: ""

  function surfacesSignature() {
    var screens = root.targetScreens
    var list = root.displayWidgets || []
    var parts = []
    for (var s = 0; s < screens.length; s++)
      for (var i = 0; i < list.length; i++)
        if (root.isVisible(list[i])) parts.push(String(screens[s].name) + ":" + String(list[i]))
    return parts.join("|")
  }

  function refreshSurfaces() {
    if (root.interacting) {
      root.surfacesDirty = true
      return
    }
    root.surfacesDirty = false
    var key = root.surfacesSignature() + "::" + String(media ? media.hasMedia : false)
    if (key === root.surfacesKey) return
    root.surfacesKey = key
    var out = []
    var screens = root.targetScreens
    var list = root.displayWidgets || []
    for (var s = 0; s < screens.length; s++)
      for (var i = 0; i < list.length; i++)
        if (root.isVisible(list[i])) out.push({ screen: screens[s], id: list[i] })
    root.surfaces = out
  }

  onWidgetsChanged: root.refreshSurfaces()
  onDisplayWidgetsChanged: root.refreshSurfaces()
  onTargetScreensChanged: root.refreshSurfaces()
  onLivePositionsChanged: if (!root.interacting && root.surfacesDirty) root.refreshSurfaces()
  onLiveSizesChanged: if (!root.interacting && root.surfacesDirty) root.refreshSurfaces()
  Component.onCompleted: {
    root.refreshSurfaces()
    root.probeDocks()
  }

  // Load hygiene: pins written for a different screen state (resolution
  // change, a dock appearing, hand-edited shell.json, content growth) can
  // boot straight into overlaps. A few seconds after start — once card
  // heights are measured — every pinned card is resolved against its
  // neighbours through the normal write path: the fix is durable and
  // idempotent, so a clean layout writes nothing.
  Timer {
    id: hygieneTimer
    interval: 3000
    running: true
    repeat: false
    onTriggered: root.reconcileStalePins()
  }

  Timer {
    id: hygieneRetry
    interval: 1500
    onTriggered: root.reconcileStalePins()
  }

  function reconcileStalePins() {
    if (root.interacting) {
      hygieneRetry.restart()
      return
    }
    var screens = root.targetScreens
    for (var s = 0; s < screens.length; s++) {
      var screen = screens[s]
      var list = root.displayWidgets || []
      var rects = ({})
      var order = []
      for (var i = 0; i < list.length; i++) {
        var id = list[i]
        if (!root.isVisible(id)) continue
        var pos = root.positionFor(id, screen)
        rects[id] = { x: pos.x, y: pos.y, w: root.flowWidth(id), h: root.flowHeight(id) }
        order.push(id)
      }
      for (var k = 0; k < order.length; k++) {
        var pid = order[k]
        if (!root.pinnedFor(pid, screen)) continue
        var others = []
        for (var o = 0; o < order.length; o++)
          if (order[o] !== pid) others.push(rects[order[o]])
        var resolved = Placement.resolveDrop(rects[pid], others, root.screenBounds(screen))
        if (Math.round(resolved.x) !== rects[pid].x || Math.round(resolved.y) !== rects[pid].y) {
          rects[pid] = { x: Math.round(resolved.x), y: Math.round(resolved.y), w: rects[pid].w, h: rects[pid].h }
          root.moveCommit(pid, Math.round(resolved.x), Math.round(resolved.y), true, String(screen.name))
        }
      }
    }
  }

  // Right-edge floating docks (rosakodu.dock and friends) sit above the
  // bottom layer, so a card dragged under one ends up half-hidden. The
  // compositor's layer list is probed once at startup; a thin vertical
  // strip hugging a monitor's right edge reserves that monitor's drop and
  // flow placement. No dock, no reserve — nothing is clamped for anyone
  // who does not run one.
  property var dockReserve: ({})

  function reservedRightFor(screen) {
    if (!screen) return 0
    var r = root.dockReserve[String(screen.name)]
    return typeof r === "number" ? r : 0
  }

  function probeDocks() {
    if (!dockProbe.running) dockProbe.running = true
  }

  Process {
    id: dockProbe
    command: ["hyprctl", "layers"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.parseDocks(text)
    }
  }

  function parseDocks(text) {
    var screens = Quickshell.screens
    var widthByName = ({})
    for (var s = 0; s < screens.length; s++)
      widthByName[String(screens[s].name)] = screens[s].width
    var out = ({})
    var monitor = ""
    var lines = String(text || "").split("\n")
    for (var i = 0; i < lines.length; i++) {
      var line = lines[i]
      var mon = line.match(/^Monitor (\S+):/)
      if (mon) { monitor = mon[1]; continue }
      if (monitor === "" || !widthByName[monitor]) continue
      var ns = line.match(/namespace: (\S+)/)
      if (!ns || ns[1].toLowerCase().indexOf("dock") === -1) continue
      var xy = line.match(/xywh: (\d+) (\d+) (\d+) (\d+)/)
      if (!xy) continue
      var x = Number(xy[1])
      var w = Number(xy[3])
      var h = Number(xy[4])
      var screenW = widthByName[monitor]
      if (w > 0 && w <= 120 && h >= 200 && x >= screenW - w - 80) {
        var reserve = screenW - x
        if (!out[monitor] || out[monitor] < reserve) out[monitor] = reserve
      }
    }
    root.dockReserve = out
  }

  Variants {
    model: root.surfaces

    PanelWindow {
      id: surface
      required property var modelData

      readonly property var screenData: modelData.screen
      readonly property string widgetId: modelData.id
      readonly property var cardPosition: root.positionFor(widgetId, screenData)

      screen: screenData
      visible: root.show && !remapGuard.remapping
      color: "transparent"

      WlrLayershell.namespace: "unyxed-macos-glass"
      WlrLayershell.layer: WlrLayer.Bottom
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
      exclusionMode: ExclusionMode.Normal
      exclusiveZone: 0

      anchors {
        top: true
        left: true
      }

      margins {
        top: surface.cardPosition.y
        left: surface.cardPosition.x
      }

      implicitWidth: cardLoader.item ? cardLoader.item.width : root.cardWidth(widgetId)
      implicitHeight: cardLoader.item ? cardLoader.item.height : 0

      onImplicitWidthChanged: root.noteMetrics(widgetId, implicitWidth, implicitHeight)
      onImplicitHeightChanged: root.noteMetrics(widgetId, implicitWidth, implicitHeight)
      Component.onCompleted: root.noteMetrics(widgetId, implicitWidth, implicitHeight)

      ScreenMoveRemap {
        id: remapGuard
        window: surface
      }

      Loader {
        id: cardLoader
        source: root.sourceFor(surface.widgetId)
        onLoaded: root.configure(item, surface.widgetId, surface.screenData)
        // Ghost while dragging: the card dims so what is underneath stays
        // readable, and the drop is always resolved to a free spot anyway.
        opacity: root.gateHeld && root.livePositions[surface.widgetId] !== undefined ? 0.85 : 1.0
        Behavior on opacity { NumberAnimation { duration: Style.duration(120); easing.type: Easing.OutCubic } }
      }
    }
  }
}
