import QtQuick
import qs.Commons
import qs.Commons as Commons

// macOS-style photo tile: edge-to-edge image clipped to the card's rounded
// corners, drag to move and corner-drag to resize like every other card.
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
      fillMode: Image.PreserveAspectCrop
      source: root.sourceUrl
      asynchronous: true
      cache: true
      smooth: true
      sourceSize.width: Math.min(1408, Math.max(568, Math.ceil(root.cardW * 2)))
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
