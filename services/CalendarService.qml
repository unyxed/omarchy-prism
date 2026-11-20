import QtQuick
import Quickshell.Io
import "../model/Sanitize.js" as Sanitize

// Local calendar list only: reads ~/.config/omarchy/calendars.json,
// shows enabled calendar names and today's date. No network fetches.
Item {
  id: root

  property bool active: false

  property var calendars: []
  property int enabledCount: 0

  function applyJson(text) {
    var parsed = null
    try {
      parsed = JSON.parse(String(text || ""))
    } catch (e) {
      parsed = null
    }
    if (!parsed || typeof parsed.length !== "number") {
      root.calendars = []
      root.enabledCount = 0
      return
    }
    var out = []
    var enabled = 0
    var n = Math.min(parsed.length, 20)
    for (var i = 0; i < n; i++) {
      var entry = parsed[i]
      if (!entry || typeof entry !== "object") continue
      var name = Sanitize.cleanLine(entry.name, 60) || "Calendar"
      var color = String(entry.color || "#888888").substring(0, 16)
      var on = entry.enabled === undefined ? true : !!entry.enabled
      if (on) enabled++
      out.push({ name: name, color: color, enabled: on })
    }
    root.calendars = out
    root.enabledCount = enabled
  }

  onActiveChanged: if (active) calendarsFile.reload()

  Timer {
    interval: 30000
    running: root.active
    repeat: true
    onTriggered: calendarsFile.reload()
  }

  FileView {
    id: calendarsFile
    path: "/home/unyxed/.config/omarchy/calendars.json"
    printErrors: false
    onLoaded: root.applyJson(text())
  }
}
