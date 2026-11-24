import QtQuick
import Quickshell
import Quickshell.Io
import "../model/Sanitize.js" as Sanitize

// Local calendar list (names for the front face) plus a bounded Google
// Calendar agenda fetch (LRClrc-style helper pattern: fixed local config,
// timeout + size caps, JSON validated on read) for the flipped back face.
Item {
  id: root

  property bool active: false

  property var calendars: []
  property int enabledCount: 0

  // Agenda state: "" (idle), "loading", "ready", "none".
  //
  // Privacy gate: agendaAllowed is true only while the calendar widget
  // itself is enabled. Disabling wipes fetched events and kills any
  // in-flight request, so no calendar data is fetched or retained for a
  // widget the user turned off (the popup alone must never trigger it).
  property bool agendaAllowed: false
  property string agendaState: ""
  property var agendaEvents: []
  property int agendaFeeds: 0

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

  function clearAgenda() {
    if (agendaFetch.running) agendaFetch.running = false
    root.agendaState = ""
    root.agendaEvents = []
    root.agendaFeeds = 0
  }

  onAgendaAllowedChanged: {
    // Re-enabling re-arms the next fetch; disabling wipes everything.
    if (!root.agendaAllowed) {
      root.clearAgenda()
      return
    }
    if (root.agendaState === "") root.fetchAgenda()
  }

  function fetchAgenda() {
    if (agendaFetch.running || !root.active || !root.agendaAllowed) return
    root.agendaState = "loading"
    agendaFetch.command = ["python3", agendaScript]
    agendaFetch.running = true
  }

  readonly property string agendaScript: Qt.resolvedUrl("../scripts/prism-agenda").toString().replace(/^file:\/\//, "")

  onActiveChanged: {
    if (active) {
      calendarsFile.reload()
      if (root.agendaState === "") root.fetchAgenda()
    }
  }

  Timer {
    interval: 30000
    running: root.active
    repeat: true
    onTriggered: calendarsFile.reload()
  }

  // Re-fetch the agenda every 15 minutes while the card is shown.
  Timer {
    interval: 900000
    running: root.active
    repeat: true
    triggeredOnStart: false
    onTriggered: root.fetchAgenda()
  }

  FileView {
    id: calendarsFile
    path: (Quickshell.env("HOME") || "/home/unyxed") + "/.config/omarchy/calendars.json"
    printErrors: false
    onLoaded: root.applyJson(text())
  }

  Process {
    id: agendaFetch
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        // Drop completions that arrive after a disable.
        if (!root.agendaAllowed) return
        var parsed = null
        try {
          parsed = JSON.parse(String(text || ""))
        } catch (e) {
          parsed = null
        }
        if (!parsed || !parsed.events || typeof parsed.events.length !== "number") {
          root.agendaEvents = []
          root.agendaFeeds = 0
          root.agendaState = "none"
          return
        }
        var out = []
        var n = Math.min(parsed.events.length, 50)
        for (var i = 0; i < n; i++) {
          var e = parsed.events[i]
          if (!e || typeof e !== "object") continue
          out.push({
            title: Sanitize.cleanLine(e.title, 200),
            start: String(e.start || "").substring(0, 16),
            end: String(e.end || "").substring(0, 16),
            allDay: !!e.allDay,
            calendar: Sanitize.cleanLine(e.calendar, 60),
            color: String(e.color || "#888888").substring(0, 16)
          })
        }
        root.agendaEvents = out
        root.agendaFeeds = Number(parsed.feeds) || 0
        root.agendaState = out.length > 0 ? "ready" : "none"
      }
    }
    onExited: function (code) {
      if (code !== 0 && root.agendaAllowed && root.agendaState === "loading") root.agendaState = "none"
    }
  }
}
