import QtQuick
import QtQuick.Effects
import qs.Commons
import qs.Commons as Commons

// Photo tile: edge-to-edge image with properly rounded corners.
// NOTE: GlassCard's clip:true clips to the square bounding box, so a
// full-bleed image needs its own rounded-rect mask (MultiEffect, same
// pattern as AlbumArt) or the corners render square.
GlassCard {
  id: root

  property string filePath: ""

  fullBleed: true
  showHeader: false

  readonly property string sourceUrl: root.filePath !== "" ? "file://" + root.filePath : ""
  readonly property real aspect: photo.status === Image.Ready && photo.implicitHeight > 0
    ? photo.implicitWidth / Math.max(1, photo.implicitHeight)
    : 4 / 3

  Item {
    width: parent.width
    height: root.cardH > 0 ? root.cardH : Math.round(width / root.aspect)

    Image {
      id: photo
      anchors.fill: parent
      visible: false
      fillMode: Image.PreserveAspectCrop
      source: root.sourceUrl
      asynchronous: true
      cache: true
      smooth: true
      sourceSize.width: Math.min(1408, Math.max(568, Math.ceil(root.cardW * 2)))
    }

    // Rounded-rect mask matching the card chrome exactly.
    Item {
      id: photoMask
      anchors.fill: parent
      visible: false
      layer.enabled: true
      Rectangle {
        anchors.fill: parent
        radius: root.cardRadius
        color: "black"
      }
    }

    MultiEffect {
      anchors.fill: parent
      visible: photo.status === Image.Ready
      source: photo
      maskEnabled: true
      maskSource: photoMask
      maskThresholdMin: 0.5
      maskSpreadAtMin: 1.0
    }

    Text {
      anchors.centerIn: parent
      visible: photo.status !== Image.Ready
      textFormat: Text.PlainText
      text: photo.status === Image.Error ? "󰋓" : ""
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.space(32)
    }
  }
}
