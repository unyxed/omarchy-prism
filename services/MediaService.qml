import QtQuick
import Quickshell.Services.Mpris
import "../model/Sanitize.js" as Sanitize

// Signal-driven MPRIS media service: attaches Connections to every player on
// the bus so play/pause, track skips, cover art changes, and progress updates
// react immediately without waiting for players to appear or disappear.
Item {
  id: root

  property bool active: false
  property int intervalMs: 2000
  property string preferredPlayer: ""

  readonly property var players: Mpris.players ? Mpris.players.values : []
  property int revision: 0

  function hasTrack(p) {
    if (!p) return false
    return Sanitize.cleanLine(p.trackTitle, 120) !== "" || Sanitize.cleanLine(p.trackArtist, 120) !== ""
  }

  function matchesPreferred(p) {
    var wanted = String(root.preferredPlayer || "").trim().toLowerCase()
    if (wanted === "" || !p) return false
    var identity = String(p.identity || "").toLowerCase()
    var dbusName = String(p.dbusName || "").toLowerCase()
    var entry = String(p.desktopEntry || "").toLowerCase()
    return identity.indexOf(wanted) !== -1 || dbusName.indexOf(wanted) !== -1
      || entry.indexOf(wanted) !== -1
  }

  function artUrlOf(raw) {
    var text = String(raw || "")
    if (text.length > 2048) return ""
    if (/[\u0000-\u001F\u007F]/.test(text)) return ""
    text = text.trim()
    if (text === "") return ""
    if (!/^(https|http|file):\/\//i.test(text)) return ""
    return text
  }

  readonly property var activePlayer: {
    root.revision
    var list = root.players
    var n = list && typeof list.length === "number" ? Math.min(list.length, 64) : 0
    var preferredPlaying = null
    var preferredAny = null
    var playingP = null
    var loadedP = null

    for (var i = 0; i < n; i++) {
      var p = list[i]
      if (!p) continue
      var track = root.hasTrack(p)
      var isPlay = p.isPlaying === true
      var named = root.matchesPreferred(p)
      if (named && isPlay && !preferredPlaying) preferredPlaying = p
      if (named && track && !preferredAny) preferredAny = p
      if (isPlay && track && !playingP) playingP = p
      if (track && !loadedP) loadedP = p
    }
    return preferredPlaying || preferredAny || playingP || loadedP || null
  }

  readonly property string title: {
    root.revision
    return activePlayer ? Sanitize.cleanLine(activePlayer.trackTitle, 120) : ""
  }

  readonly property string artist: {
    root.revision
    return activePlayer ? Sanitize.cleanLine(activePlayer.trackArtist, 120) : ""
  }

  readonly property string album: {
    root.revision
    return activePlayer ? Sanitize.cleanLine(activePlayer.trackAlbum, 120) : ""
  }

  readonly property string player: {
    root.revision
    return activePlayer ? Sanitize.cleanLine(activePlayer.identity, 64) : ""
  }

  readonly property bool playing: {
    root.revision
    return activePlayer ? activePlayer.isPlaying === true : false
  }

  readonly property string status: playing ? "Playing" : "Stopped"
  readonly property bool hasMedia: title !== "" || artist !== ""

  readonly property string artUrl: {
    root.revision
    return activePlayer ? root.artUrlOf(activePlayer.trackArtUrl) : ""
  }

  readonly property bool canGoNext: {
    root.revision
    return activePlayer ? (activePlayer.canControl === true && activePlayer.canGoNext === true) : false
  }

  readonly property bool canGoPrevious: {
    root.revision
    return activePlayer ? (activePlayer.canControl === true && activePlayer.canGoPrevious === true) : false
  }

  readonly property bool canTogglePlaying: {
    root.revision
    return activePlayer ? (activePlayer.canControl === true && activePlayer.canTogglePlaying !== false) : false
  }

  readonly property real position: {
    root.revision
    var v = activePlayer ? Number(activePlayer.position) : 0
    return isFinite(v) && v > 0 ? v : 0
  }

  readonly property real length: {
    root.revision
    var v = activePlayer ? Number(activePlayer.length) : 0
    return isFinite(v) && v > 0 ? v : 0
  }

  readonly property real progress: length > 0 ? Math.max(0, Math.min(1, position / length)) : -1

  function control(action) {
    var p = root.activePlayer
    if (!p) return
    if (action === "play-pause" && root.canTogglePlaying) p.togglePlaying()
    else if (action === "next" && root.canGoNext) p.next()
    else if (action === "previous" && root.canGoPrevious) p.previous()
    root.revision++
  }

  Instantiator {
    model: root.players

    delegate: QtObject {
      required property var modelData

      property Connections watcher: Connections {
        target: modelData
        ignoreUnknownSignals: true
        function onTrackTitleChanged() { root.revision++ }
        function onTrackArtistChanged() { root.revision++ }
        function onTrackAlbumChanged() { root.revision++ }
        function onTrackArtUrlChanged() { root.revision++ }
        function onIsPlayingChanged() { root.revision++ }
        function onPlaybackStateChanged() { root.revision++ }
        function onCanControlChanged() { root.revision++ }
        function onCanGoNextChanged() { root.revision++ }
        function onCanGoPreviousChanged() { root.revision++ }
        function onCanTogglePlayingChanged() { root.revision++ }
        function onLengthChanged() { root.revision++ }
      }

      Component.onCompleted: root.revision++
      Component.onDestruction: root.revision++
    }
  }

  // Update progress bar once per second while actively playing.
  Timer {
    interval: 1000
    running: root.active && root.playing && root.length > 0
    repeat: true
    onTriggered: root.revision++
  }
}
