import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "settings"
import "model/Settings.js" as Settings
import "model/Sanitize.js" as Sanitize

// Bar widget: icon in the bar, popup to toggle cards and tune the glass.
//
// It is also the plugin's only write path to shell.json. The service reads the
// same entry but never edits it, so a setting can only change in one place.
Panel {
  id: root

  ipcTarget: "unyxed-macos-glass"
  manageIpc: false

  // The host injects `bar` as a capability-scoped facade whose `shell` can look
  // up this plugin's own service and nothing else. Under a replacement bar that
  // facade is service-less by design, so every read here tolerates a null.
  readonly property var service: bar && bar.shell && typeof bar.shell.serviceFor === "function"
    ? bar.shell.serviceFor(moduleName) : null
  readonly property var config: Settings.normalize(settings)

  Commons.Translations { id: strings; directory: Qt.resolvedUrl("i18n") }

  property bool glassAvailable: false

  readonly property bool active: config.widgets.length > 0

  // updateEntryInline replaces the whole entry, so a write sends the full
  // object, and normalising on the way out repairs a hand-edited file.
  //
  // The base is a faithful copy of what the host injected, not a normalised
  // one: normalising first makes every write a rewrite of every field, so
  // anything the normaliser misreads is persisted as a default. Copy, merge,
  // normalise.
  function write(changes) {
    if (!bar || !bar.shell || typeof bar.shell.updateEntryInline !== "function") return
    var merged = ({})
    for (var key in settings) merged[key] = settings[key]
    for (var c in changes) merged[c] = changes[c]
    var next = Settings.normalize(merged)
    settings = next
    bar.shell.updateEntryInline(moduleName, next)
  }

  function writeOne(key, value) {
    var change = ({})
    change[key] = value
    write(change)
  }

  function toggleWidget(id) {
    var list = config.widgets.slice()
    var at = list.indexOf(id)
    if (at === -1) list.push(id)
    else list.splice(at, 1)
    // Keep canonical order from Settings known widgets:
    var order = Settings.KNOWN_WIDGETS.slice()
    var seen = {}
    for (var i = 0; i < list.length; i++) seen[list[i]] = true
    var out = []
    for (var k = 0; k < order.length; k++) if (seen[order[k]]) out.push(order[k])
    write({ widgets: out })
  }

  function toggleTodo(id) {
    var list = config.todos ? config.todos.slice() : []
    for (var i = 0; i < list.length; i++) {
      if (String(list[i].id) === String(id)) {
        list[i] = ({ id: list[i].id, text: list[i].text, done: !list[i].done })
        break
      }
    }
    write({ todos: list })
  }

  function addTodo(text) {
    var clean = String(text || "").trim().substring(0, 200)
    if (clean === "") return
    var list = config.todos ? config.todos.slice() : []
    if (list.length >= 50) return
    list.unshift({ id: "t" + Date.now() + "_" + Math.floor(Math.random() * 100000), text: clean, done: false })
    write({ todos: list })
  }

  function writeSizes(id, w, h) {
    var sizes = ({})
    var current = config.sizes ? config.sizes : {}
    for (var k in current) sizes[k] = current[k]
    sizes[id] = { w: w, h: h }
    write({ sizes: sizes })
  }

  function writePositions(id, x, y) {
    var positions = ({})
    var current = config.positions ? config.positions : {}
    for (var k in current) positions[k] = current[k]
    positions[id] = { x: x, y: y }
    write({ positions: positions })
  }

  // The bar host re-injects `settings` as soon as they change on disk. The
  // service's own snapshot updates a beat later, so the settings are pushed
  // there rather than read back — otherwise the desktop cards act on the
  // previous write.
  function pushSettings() {
    if (service) service.applySettings(settings)
  }

  onSettingsChanged: pushSettings()
  onServiceChanged: pushSettings()

  // Drags and resizes happen on the desktop surface, which the service owns;
  // persisting the result happens here, because this widget is the only thing
  // that writes shell.json.
  Connections {
    target: root.service
    ignoreUnknownSignals: true
    function onResizeCommitted(id, w, h) { root.writeSizes(id, w, h) }
    function onPositionCommitted(id, x, y) { root.writePositions(id, x, y) }
    function onTodoToggleRequested(id) { root.toggleTodo(id) }
  }

  function removePhoto(id) {
    var list = config.photos ? config.photos.slice() : []
    var out = []
    for (var i = 0; i < list.length; i++)
      if (String(list[i].id) !== String(id)) out.push(list[i])
    write({ photos: out })
  }

  // Photo flow: system picker -> extension + duplicate guard -> size/regular
  // file check in a fixed command (path travels as data in $1, never
  // interpolated into shell) -> persist. Max 12 photos.
  property string pendingPhotoPath: ""

  function addPhoto() {
    if (photoPicker.running || photoValidator.running) return
    photoPicker.command = ["omarchy", "file", "select",
      "--title", "Choose a photo",
      "--extensions", "jpg jpeg png webp gif bmp avif"]
    photoPicker.running = true
  }

  function gotPickedPhoto(raw) {
    var path = String(raw || "").split("\n")[0].trim()
    if (path === "") return
    var dot = path.lastIndexOf(".")
    var ext = dot !== -1 ? path.substring(dot + 1).toLowerCase() : ""
    if (["jpg", "jpeg", "png", "webp", "gif", "bmp", "avif"].indexOf(ext) === -1) return
    var list = config.photos ? config.photos.slice() : []
    if (list.length >= 12) return
    for (var i = 0; i < list.length; i++)
      if (String(list[i].path) === path) return
    root.pendingPhotoPath = path
    photoValidator.command = ["bash", "-c",
      'p="$1"; [ -f "$p" ] && [ ! -L "$p" ] && [ "$(stat -c%s "$p")" -le 20971520 ]',
      "photo-check", path]
    photoValidator.running = true
  }

  Process {
    id: photoPicker
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.gotPickedPhoto(text)
    }
  }

  Process {
    id: photoValidator
    onExited: function (code) {
      if (code === 0 && root.pendingPhotoPath !== "") {
        var list = root.config.photos ? root.config.photos.slice() : []
        if (list.length < 12) {
          list.push({ id: "p" + Date.now() + "_" + Math.floor(Math.random() * 100000), path: root.pendingPhotoPath })
          root.write({ photos: list })
        }
      }
      root.pendingPhotoPath = ""
    }
  }

  function probeGlass() {
    if (!glassProbe.running) glassProbe.running = true
  }

  function installGlass() {
    if (glassInstall.running) return
    var script = [
      "echo 'Installing hyprglass (Liquid Glass) for the macOS Glass plugin...'",
      "echo",
      "if hyprpm add https://github.com/hyprnux/hyprglass && hyprpm enable hyprglass && hyprctl reload; then",
      "  echo",
      "  echo 'Done. hyprglass is installed and loaded.'",
      "  echo 'Reopen the widget settings to see the liquid glass.'",
      "else",
      "  echo",
      "  echo 'Installation did not finish. See the messages above.'",
      "fi",
      "echo",
      "read -n1 -s -r -p 'Press any key to close this window.'"
    ].join("\n")
    glassInstall.command = ["omarchy-launch-terminal", "bash", "-lc", script]
    glassInstall.running = true
  }

  onOpenedChanged: {
    if (service) service.panelViewing = opened
    if (opened) root.probeGlass()
  }
  Component.onDestruction: if (service) service.panelViewing = false

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  // Neutralize markup before handing dynamic text to the bar tooltip sink,
  // which the plugin does not own.
  readonly property string tooltipTextRaw: root.active
    ? strings.t("bar.tooltip")
    : strings.t("bar.hidden")

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "◫"
    foreground: root.active ? barForeground : Qt.darker(barForeground, 1.55)
    tooltipText: Sanitize.escapeMarkup(root.tooltipTextRaw, 120)
    onPressed: function (pressedButton) {
      if (pressedButton === Qt.RightButton)
        root.write({ widgets: root.active ? [] : Settings.DEFAULTS.widgets.slice() })
      else root.toggle()
    }
  }

  Process {
    id: glassProbe
    command: ["hyprctl", "plugin", "list"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.glassAvailable = text.indexOf("hyprglass") !== -1
    }
  }

  Process {
    id: glassInstall
  }

  Component.onCompleted: {
    root.probeGlass()
    root.pushSettings()
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    popoutSwitching: root.popoutSwitching
    popoutSwitchClosing: root.popoutSwitchClosing
    contentWidth: panel.fittedContentWidth(Style.space(340))
    contentHeight: panel.fittedContentHeight(content.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()

      Flickable {
        id: flick
        anchors.fill: parent
        contentWidth: width
        contentHeight: content.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: !content.sliderDragging && content.implicitHeight > flick.height

        SettingsPanel {
          id: content
          width: parent.width
          config: root.config
          glassAvailable: root.glassAvailable
          todos: root.config.todos
          todoRows: root.config.todoRows
          photos: root.config.photos
          onWidgetToggled: function (id) { root.toggleWidget(id) }
          onPositionPicked: function (position) { root.write({ position: position }) }
          onSettingChanged: function (key, value) { root.writeOne(key, value) }
          onFlagToggled: function (key) { root.writeOne(key, !root.config[key]) }
          onTodoToggled: function (id) { root.toggleTodo(id) }
          onTodoAdded: function (text) { root.addTodo(text) }
          onPhotoAddRequested: function () { root.addPhoto() }
          onPhotoRemoved: function (id) { root.removePhoto(id) }
          onResetLayoutRequested: function () { root.write({ positions: ({}), sizes: ({}) }) }
          onInstallGlassRequested: root.installGlass()
        }
      }
    }
  }
}
