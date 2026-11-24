import QtQuick
import qs.Commons
import qs.Commons as Commons

// Reminders split card: count and list side by side.
// Left column: circular icon badge at top, big bold open count + label at bottom.
// Right column: interactive circular checkboxes + task rows.
GlassCard {
  id: root

  property var todos: []
  property int todoRows: 5

  signal toggleRequested(string id)

  readonly property int openCount: {
    var n = 0
    for (var i = 0; i < root.todos.length; i++) if (!root.todos[i].done) n++
    return n
  }

  readonly property var visibleTodos: {
    var out = []
    for (var i = 0; i < Math.min(root.todos.length, 50); i++) out.push(root.todos[i])
    return out.slice(0, Math.max(1, root.todoRows))
  }

  Row {
    width: parent.width
    spacing: Style.spacing.md

    // Left badge column (icon top, count + label bottom)
    Column {
      id: badgeCol
      width: Style.space(66)
      spacing: Style.spacing.sm

      Rectangle {
        width: Style.space(32)
        height: Style.space(32)
        radius: width / 2
        color: Util.alpha(root.accent, 0.25)
        border.width: Style.space(1)
        border.color: Util.alpha(root.accent, 0.75)

        Text {
          anchors.centerIn: parent
          textFormat: Text.PlainText
          text: "\uF0AE"
          color: root.fg
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
        }
      }

      Column {
        width: parent.width
        spacing: 0

        Text {
          width: parent.width
          textFormat: Text.PlainText
          text: Commons.I18n.formatNumber(root.openCount, 0)
          color: root.fg
          font.family: root.fontFamily
          font.pixelSize: Math.round(Style.font.title * 1.15)
          font.bold: true
        }

        Text {
          width: parent.width
          textFormat: Text.PlainText
          text: "Reminders"
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          font.bold: true
          elide: Text.ElideRight
        }
      }
    }

    // Vertical divider
    Rectangle {
      width: Style.space(1)
      height: Math.max(badgeCol.implicitHeight, listCol.implicitHeight)
      color: Util.alpha(root.fg, 0.12)
    }

    // Right task list column
    Column {
      id: listCol
      width: parent.width - badgeCol.width - Style.space(1) - parent.spacing * 2
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.space(7)

      Text {
        width: parent.width
        visible: root.todos.length === 0
        textFormat: Text.PlainText
        text: root.strings.t("todo.empty")
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        wrapMode: Text.WordWrap
      }

      Repeater {
        model: root.visibleTodos
        Row {
          width: listCol.width
          spacing: Style.spacing.sm

          Rectangle {
            width: Style.space(16)
            height: Style.space(16)
            radius: width / 2
            anchors.verticalCenter: parent.verticalCenter
            color: modelData.done ? root.accent : "transparent"
            border.width: Style.space(1.5)
            border.color: modelData.done ? root.accent : Util.alpha(root.fg, 0.45)

            Text {
              visible: modelData.done
              anchors.centerIn: parent
              textFormat: Text.PlainText
              text: "✓"
              color: Color.popups.background
              font.pixelSize: Style.font.caption - 2
              font.bold: true
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: root.toggleRequested(String(modelData.id))
            }
          }

          Text {
            width: parent.width - Style.space(16) - parent.spacing
            textFormat: Text.PlainText
            text: String(modelData.text || "")
            color: modelData.done ? root.dim : root.fg
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            font.strikeout: modelData.done
            elide: Text.ElideRight
            maximumLineCount: 1
            anchors.verticalCenter: parent.verticalCenter
          }
        }
      }
    }
  }
}
