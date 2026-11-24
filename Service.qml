import QtQuick
import "services"
import "surfaces"
import "model/Settings.js" as Settings

// The plugin's single long-lived instance: owns every sampler, holds the
// desktop surface, and is what the bar widget reads from.
//
// One instance means one set of timers no matter how many surfaces are showing.
// Sampling is gated on `sampling`: with no desktop cards and nothing open, every
// timer is stopped and the plugin costs nothing but the memory it occupies.
Item {
  id: root

  // Injected by the shell host. `shell` is the capability-scoped facade, not the
  // shell itself.
  property var shell: null
  property var manifest: null
  property string omarchyPath: ""

  readonly property string pluginId: manifest && manifest.id
    ? String(manifest.id) : "unyxed.prism"

  // Settings, from the bar widget when one is mounted and from the host's bar
  // config snapshot before that.
  //
  // The snapshot cannot be the live source: `shell.barConfig` is pushed onto the
  // plugin facade by the host, and only when the plugin registry or the widget
  // registry changes — not when a setting is written. The bar widget's own
  // `settings` are re-injected by the bar host as soon as they change, so it
  // pushes them here and the cards move on the click that asked them to.
  property var pushedSettings: null

  readonly property var config: Settings.normalize(pushedSettings !== null
    ? pushedSettings
    : (shell ? Settings.fromBarConfig(shell.barConfig, pluginId) : ({})))

  // Called by the bar widget whenever its injected settings change. Idempotent,
  // because one bar widget instance exists per monitor and each one pushes.
  //
  // An empty push is not an answer. The bar host injects `settings` after the
  // widget is constructed, so the widget's first push can carry nothing.
  // Storing that pinned the defaults over real saved settings, so empty pushes
  // are ignored.
  function applySettings(next) {
    if (next === undefined || next === null) return
    if (Object.keys(next).length === 0) return
    pushedSettings = next
  }

  // Set by the popup while it is open, so sampling keeps running then.
  property bool panelViewing: false

  readonly property bool sampling: config.widgets.length > 0 || panelViewing
  readonly property int effectiveIntervalMs: panelViewing
    ? Math.min(1000, config.intervalMs) : config.intervalMs

  readonly property alias system: systemService
  readonly property alias gpu: gpuService
  readonly property alias media: mediaService
  readonly property alias calendar: calendarService

  // Desktop interactions only re-emit here. Persisting happens in the bar
  // widget, the only thing that writes shell.json. pinned=false asks the
  // writer to remove the pin (rejoin the flow); screen scopes the pin to
  // one monitor.
  signal resizeCommitted(string id, real w, real h)
  signal positionCommitted(string id, real x, real y, bool pinned, string screen)
  signal todoToggleRequested(string id)

  SystemService {
    id: systemService
    active: root.sampling
    intervalMs: root.effectiveIntervalMs
  }

  GpuService {
    id: gpuService
    active: root.config.widgets.indexOf("gpu") !== -1 || root.panelViewing
    intervalMs: root.effectiveIntervalMs
  }

  MediaService {
    id: mediaService
    active: root.config.widgets.indexOf("media") !== -1 || root.panelViewing
    intervalMs: root.effectiveIntervalMs
    preferredPlayer: root.config.preferredPlayer
    lyricsAllowed: root.config.widgets.indexOf("media") !== -1
  }

  CalendarService {
    id: calendarService
    active: root.config.widgets.indexOf("calendar") !== -1 || root.panelViewing
    agendaAllowed: root.config.widgets.indexOf("calendar") !== -1
  }

  DesktopSurface {
    config: root.config
    system: systemService
    gpu: gpuService
    media: mediaService
    calendar: calendarService
    todos: root.config.todos
    todoRows: root.config.todoRows
    show: root.config.widgets.length > 0

    onResizeCommit: function (id, w, h) { root.resizeCommitted(id, w, h) }
    onMoveCommit: function (id, x, y, pinned, screen) { root.positionCommitted(id, x, y, pinned, screen) }
    onTodoToggled: function (id) { root.todoToggleRequested(id) }
  }
}
