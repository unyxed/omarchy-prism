import QtQuick
import qs.Commons
import qs.Commons as Commons

// Frosted glass card with a soft specular rim.
// Theme-aware translucent fill; when hyprglass is bound to the
// `unyxed-prism` layer namespace, the background blurs and refracts
// the wallpaper underneath.
Rectangle {
  id: root

  property var strings: Commons.Translations { directory: Qt.resolvedUrl("../i18n") }

  property string widgetId: ""
  property string title: ""
  property string glyph: ""
  property string meta: ""
  property bool showHeader: false
  property real bgOpacity: 0.42
  property int cardRadius: 24
  property real cardW: 280
  property real cardH: 0
  property bool resizable: true
  // Full-bleed content (photo tiles): the body spans edge to edge under the
  // rounded clip instead of sitting inside the padded frame.
  property bool fullBleed: false

  signal resizePreview(string id, real w, real h)
  signal resizeCommit(string id, real w, real h)
  signal movePreview(string id, real dx, real dy)
  signal moveCommit(string id, real x, real y)
  signal doubleClicked
  // Fired on left-button double-click. Cards that flip (media, calendar)
  // handle this; plain cards ignore it.

  readonly property color fg: Color.popups.text
  readonly property color dim: Util.alpha(fg, 0.58)
  readonly property color subtle: Util.alpha(fg, 0.14)
  readonly property color accent: Color.accent
  readonly property string fontFamily: Style.font.family
  readonly property int pad: Style.space(16)

  default property alias content: column.children

  // Pointer handling lives in `data` so these are direct visual children of
  // the card: the default property alias would swallow bare children into
  // the content column, and property-held MouseAreas may never join the
  // visual tree at all (silently receiving no events). Declared first so
  // content, buttons and the resize grip (later siblings) get first shot
  // at every press. Dragging is right-button only, by design: it never
  // interferes with left-click controls, text, or the corner grip.
  data: [
    MouseArea {
      id: dragArea
      anchors.fill: parent
      acceptedButtons: Qt.RightButton
      property point startGlobal: Qt.point(0, 0)
      onPressed: function (mouse) {
        startGlobal = dragArea.mapToGlobal(mouse.x, mouse.y)
      }
      onPositionChanged: function (mouse) {
        if (!pressed) return
        var now = dragArea.mapToGlobal(mouse.x, mouse.y)
        root.movePreview(root.widgetId, now.x - startGlobal.x, now.y - startGlobal.y)
      }
      onReleased: function (mouse) {
        var now = dragArea.mapToGlobal(mouse.x, mouse.y)
        root.moveCommit(root.widgetId, now.x - startGlobal.x, now.y - startGlobal.y)
      }
    },
    MouseArea {
      id: flipCatcher
      anchors.fill: parent
      acceptedButtons: Qt.LeftButton
      onDoubleClicked: root.doubleClicked()
    }
  ]

  width: cardW
  height: cardH > 0 ? cardH : implicitHeight
  implicitWidth: cardW
  implicitHeight: column.implicitHeight + (fullBleed ? 0 : pad * 2)
  radius: cardRadius
  color: Util.alpha(Color.popups.background, bgOpacity)
  border.width: Style.space(1)
  border.color: Util.alpha("#ffffff", 0.22)
  clip: true

  // Subtle top glass rim highlight
  Rectangle {
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.margins: Style.space(1)
    height: Math.max(Style.space(24), parent.height * 0.35)
    radius: Math.max(0, root.cardRadius - 1)
    gradient: Gradient {
      GradientStop { position: 0.0; color: Util.alpha("#ffffff", 0.10) }
      GradientStop { position: 1.0; color: "transparent" }
    }
  }

  Column {
    id: column
    x: fullBleed ? 0 : root.pad
    y: fullBleed ? 0 : root.pad
    width: fullBleed ? root.width : root.width - root.pad * 2
    spacing: Style.spacing.sm

    Row {
      id: header
      visible: root.showHeader && root.title !== ""
      width: parent.width
      height: visible ? implicitHeight : 0
      spacing: Style.spacing.xs

      Text {
        textFormat: Text.PlainText
        visible: root.glyph !== ""
        text: root.glyph
        color: root.accent
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        anchors.verticalCenter: titleText.verticalCenter
      }

      Text {
        id: titleText
        textFormat: Text.PlainText
        width: parent.width - (root.glyph !== "" ? Style.font.caption + parent.spacing : 0)
          - (metaText.visible ? metaText.implicitWidth + parent.spacing : 0)
        text: root.title.toUpperCase()
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        font.bold: true
        font.letterSpacing: 1.2
        elide: Text.ElideRight
      }

      Text {
        id: metaText
        textFormat: Text.PlainText
        visible: root.meta !== ""
        text: root.meta.toUpperCase()
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        font.bold: true
        font.letterSpacing: 1.1
      }
    }
  }

  // Invisible corner resize handle: no pixels ever change on hover, so there
  // is no flicker as the pointer crosses the corner. The diagonal-resize
  // cursor still signals that the corner can be dragged (no visible handle,
  // just cursor feedback).
  MouseArea {
    id: grip
    visible: root.resizable
    width: Style.space(18)
    height: Style.space(18)
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    hoverEnabled: true
    cursorShape: Qt.SizeFDiagCursor
    acceptedButtons: Qt.LeftButton
    property real startW: 0
    property real startH: 0
    property point startGlobal: Qt.point(0, 0)
    onPressed: function (mouse) {
      startW = root.cardW
      startH = root.cardH > 0 ? root.cardH : root.implicitHeight
      startGlobal = grip.mapToGlobal(mouse.x, mouse.y)
    }
    onPositionChanged: function (mouse) {
      if (!pressed) return
      var now = grip.mapToGlobal(mouse.x, mouse.y)
      var w = Math.max(Style.space(150), startW + (now.x - startGlobal.x))
      var h = Math.max(Style.space(80), startH + (now.y - startGlobal.y))
      root.resizePreview(root.widgetId, Math.round(w), Math.round(h))
    }
    onReleased: function (mouse) {
      var now = grip.mapToGlobal(mouse.x, mouse.y)
      var w = Math.max(Style.space(150), startW + (now.x - startGlobal.x))
      var h = Math.max(Style.space(80), startH + (now.y - startGlobal.y))
      root.resizeCommit(root.widgetId, Math.round(w), Math.round(h))
    }
  }
}
