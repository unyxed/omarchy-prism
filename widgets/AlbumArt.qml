import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import qs.Commons

// Safe album art loader with rounded-rect or circular masking.
Item {
  id: root

  property string url: ""
  property int maxBytes: 2 * 1024 * 1024
  property int decodeSize: 320
  property bool round: false
  property real cornerRadius: Style.space(14)

  readonly property bool ready: image.status === Image.Ready
  property string fetchedPath: ""

  onUrlChanged: {
    fetchedPath = ""
    fetcher.cancel()
    if (url !== "") debounce.restart()
    else debounce.stop()
  }

  Timer {
    id: debounce
    interval: 180
    onTriggered: fetcher.get(root.url)
  }

  Process {
    id: fetcher
    property string destination: ""

    function cancel() {
      if (running) running = false
    }

    function get(source) {
      var dir = (Quickshell.env("XDG_RUNTIME_DIR") || "") + "/unyxed-prism"
      if (dir === "/unyxed-prism" || String(source) === "") return
      destination = dir + "/art-" + Qt.md5(String(source)) + ".img"
      if (running) running = false
      command = ["bash", "--", Qt.resolvedUrl("../scripts/prism-art").toString().replace(/^file:\/\//, ""), String(source), destination, String(root.maxBytes)]
      running = true
    }

    onExited: function (code) {
      if (code === 0 && destination !== "") root.fetchedPath = destination
      else root.fetchedPath = ""
    }
  }

  Component.onDestruction: fetcher.cancel()

  Image {
    id: image
    anchors.fill: parent
    visible: false
    source: root.fetchedPath === "" ? "" : "file://" + root.fetchedPath + "?v=" + Qt.md5(root.fetchedPath)
    fillMode: Image.PreserveAspectCrop
    asynchronous: true
    cache: true
    smooth: true
    sourceSize.width: root.decodeSize
    sourceSize.height: root.decodeSize
  }

  Item {
    id: shapeMask
    anchors.fill: parent
    visible: false
    layer.enabled: true
    Rectangle {
      anchors.fill: parent
      radius: root.round ? width / 2 : root.cornerRadius
      color: "black"
    }
  }

  MultiEffect {
    anchors.fill: parent
    visible: root.ready
    source: image
    maskEnabled: true
    maskSource: shapeMask
    maskThresholdMin: 0.5
    maskSpreadAtMin: 1.0
  }
}
