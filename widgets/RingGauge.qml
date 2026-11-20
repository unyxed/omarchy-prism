import QtQuick
import qs.Commons

// macOS WidgetKit-style circular ring gauge with an icon or value in the center.
Item {
  id: root

  property real fraction: 0
  property real ringSize: Style.space(56)
  property real strokeWidth: Style.space(6)
  property color ringColor: Color.accent
  property color trackColor: Util.alpha(Color.popups.text, 0.14)
  property string centerGlyph: ""
  property string centerText: ""
  property color textColor: Color.popups.text
  property string fontFamily: Style.font.family

  readonly property real clamped: fraction >= 0 && fraction <= 1 ? fraction : 0

  width: ringSize
  height: ringSize
  implicitWidth: ringSize
  implicitHeight: ringSize

  onClampedChanged: canvas.requestPaint()
  onRingColorChanged: canvas.requestPaint()
  onTrackColorChanged: canvas.requestPaint()
  onRingSizeChanged: canvas.requestPaint()

  Canvas {
    id: canvas
    anchors.fill: parent
    antialiasing: true
    onPaint: {
      var ctx = getContext("2d")
      ctx.reset()
      var cx = width / 2
      var cy = height / 2
      var r = Math.max(4, (Math.min(width, height) - root.strokeWidth) / 2 - 1)
      var start = -Math.PI / 2
      var end = start + Math.PI * 2 * root.clamped

      // Track ring
      ctx.beginPath()
      ctx.arc(cx, cy, r, 0, Math.PI * 2, false)
      ctx.lineWidth = root.strokeWidth
      ctx.strokeStyle = root.trackColor
      ctx.stroke()

      // Active arc
      if (root.clamped > 0.005) {
        ctx.beginPath()
        ctx.arc(cx, cy, r, start, end, false)
        ctx.lineWidth = root.strokeWidth
        ctx.lineCap = "round"
        ctx.strokeStyle = root.ringColor
        ctx.stroke()
      }
    }
  }

  Text {
    anchors.centerIn: parent
    visible: root.centerGlyph !== ""
    textFormat: Text.PlainText
    text: root.centerGlyph
    color: root.textColor
    font.family: root.fontFamily
    font.pixelSize: Math.round(root.ringSize * 0.34)
  }

  Text {
    anchors.centerIn: parent
    visible: root.centerGlyph === "" && root.centerText !== ""
    textFormat: Text.PlainText
    text: root.centerText
    color: root.textColor
    font.family: root.fontFamily
    font.pixelSize: Math.round(root.ringSize * 0.24)
    font.bold: true
  }
}
