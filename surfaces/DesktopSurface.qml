import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Ui
import "../widgets"
import "../model/Layout.js" as Layout

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
  signal moveCommit(string id, real x, real y)
  signal todoToggled(string id)

  readonly property var widgets: config && config.widgets ? config.widgets : []
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

  function flowHeight(id) {
    var size = explicitSize(id)
    if (size) return size.h
    return heights[id] !== undefined ? heights[id] : 0
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

  function flowEntries() {
    var out = []
    var list = root.widgets
    for (var i = 0; i < list.length; i++) {
      var id = list[i]
      if (id === "media" && config.hideMediaWhenIdle && media && !media.hasMedia) continue
      if (config.positions && config.positions[id]) continue
      out.push({ id: id, w: root.flowWidth(id), h: root.flowHeight(id) })
    }
    return out
  }

  function flowFor(screen) {
    return Layout.flowPositions(config.position, root.flowEntries(),
      config.spacing, config.marginX, config.marginY,
      screen ? screen.width : 0, screen ? screen.height : 0)
  }

  function basePositionFor(id, screen) {
    if (config.positions && config.positions[id]) return config.positions[id]
    var flow = root.flowFor(screen)
    return flow[id] || { x: config.marginX, y: config.marginY }
  }

  function positionFor(id, screen) {
    if (root.livePositions[id]) return root.livePositions[id]
    return root.basePositionFor(id, screen)
  }

  function clampPosition(id, screen, x, y) {
    var maxX = Math.max(0, (screen ? screen.width : 0) - root.flowWidth(id))
    var maxY = Math.max(0, (screen ? screen.height : 0) - root.flowHeight(id))
    return {
      x: Math.round(Math.max(0, Math.min(maxX, x))),
      y: Math.round(Math.max(0, Math.min(maxY, y)))
    }
  }

  function showCardMove(id, dx, dy, screen) {
    var base = root.basePositionFor(id, screen)
    var pos = root.clampPosition(id, screen, base.x + dx, base.y + dy)
    var next = {}
    for (var k in root.livePositions) next[k] = root.livePositions[k]
    next[id] = pos
    root.livePositions = next
  }

  function commitCardMove(id, dx, dy, screen) {
    root.showCardMove(id, dx, dy, screen)
    root.moveCommit(id, root.livePositions[id].x, root.livePositions[id].y)
  }

  function showCardResize(id, w, h) {
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
    var sizes = {}
    var sizeChanged = false
    for (var k in root.liveSizes) {
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
    return ""
  }

  function configure(item, id, screen) {
    if (!item) return
    item.widgetId = id
    item.title = Layout.widgetName(id)
    item.glyph = Layout.widgetGlyph(id)
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
    if ("showCores" in item)
      item.showCores = Qt.binding(function () { return root.config.showCpuCores })
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
    var list = root.widgets
    var parts = []
    for (var s = 0; s < screens.length; s++)
      for (var i = 0; i < list.length; i++)
        if (root.isVisible(list[i])) parts.push(String(screens[s].name) + ":" + String(list[i]))
    return parts.join("|")
  }

  function refreshSurfaces() {
    var key = root.surfacesSignature() + "::" + String(media ? media.hasMedia : false)
    if (key === root.surfacesKey) return
    root.surfacesKey = key
    var out = []
    var screens = root.targetScreens
    var list = root.widgets
    for (var s = 0; s < screens.length; s++)
      for (var i = 0; i < list.length; i++)
        if (root.isVisible(list[i])) out.push({ screen: screens[s], id: list[i] })
    root.surfaces = out
  }

  onWidgetsChanged: root.refreshSurfaces()
  onTargetScreensChanged: root.refreshSurfaces()
  Component.onCompleted: root.refreshSurfaces()

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
      }
    }
  }
}
