import QtQuick
import qs.Commons
import qs.Commons as Commons

// macOS Calendar Widget with 2 selectable styles:
//   - "split": Left column with weekday, large date, calendar feeds; right column with month grid
//   - "month": Centered full-width month grid with big month header (mac-aesthetic-3 look)
GlassCard {
  id: root

  property var calendar: null
  property string calendarStyle: "split"

  property date now: new Date()
  readonly property var loc: Qt.locale(Commons.I18n.formatLocale)
  readonly property int todayDay: now.getDate()
  readonly property string weekdayUpper: loc.toString(now, "dddd").toUpperCase()
  readonly property string monthUpper: loc.toString(now, "MMMM").toUpperCase()
  readonly property string monthTitle: loc.toString(now, "MMMM")
  readonly property var feeds: calendar ? calendar.calendars : []
  readonly property int enabledCount: calendar ? calendar.enabledCount : 0

  readonly property var dayHeaders: ["S", "M", "T", "W", "T", "F", "S"]

  readonly property var monthCells: {
    var y = now.getFullYear()
    var m = now.getMonth()
    var firstDow = new Date(y, m, 1).getDay()
    var daysInMonth = new Date(y, m + 1, 0).getDate()
    var out = []
    for (var b = 0; b < firstDow; b++) out.push(0)
    for (var d = 1; d <= daysInMonth; d++) out.push(d)
    while (out.length % 7 !== 0) out.push(0)
    return out
  }

  property Timer ticker: Timer {
    interval: 30000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.now = new Date()
  }

  component MonthMatrix: Grid {
    id: calGrid
    columns: 7
    rowSpacing: Style.space(2)
    columnSpacing: 0
    readonly property real cellW: Math.floor(width / 7)
    readonly property real cellH: Style.space(18)

    Repeater {
      model: root.dayHeaders
      Item {
        width: calGrid.cellW
        height: calGrid.cellH
        Text {
          anchors.centerIn: parent
          textFormat: Text.PlainText
          text: modelData
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Math.max(9, Style.font.caption - 2)
          font.bold: true
        }
      }
    }

    Repeater {
      model: root.monthCells
      Item {
        width: calGrid.cellW
        height: calGrid.cellH
        readonly property bool isToday: modelData === root.todayDay

        Rectangle {
          visible: parent.isToday
          width: Style.space(18)
          height: Style.space(18)
          radius: width / 2
          anchors.centerIn: parent
          color: root.accent
        }

        Text {
          visible: modelData > 0
          anchors.centerIn: parent
          textFormat: Text.PlainText
          text: modelData > 0 ? String(modelData) : ""
          color: parent.isToday ? Color.popups.background : root.fg
          font.family: root.fontFamily
          font.pixelSize: Math.max(9, Style.font.caption - 2)
          font.bold: parent.isToday
        }
      }
    }
  }

  // ==================== STYLE 1: SPLIT ====================
  Row {
    width: parent.width
    visible: root.calendarStyle === "split"
    spacing: Style.spacing.md

    Column {
      id: leftCol
      width: Math.round(parent.width * 0.38)
      spacing: Style.space(2)

      Text {
        width: parent.width
        textFormat: Text.PlainText
        text: root.weekdayUpper
        color: root.accent
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        font.bold: true
        font.letterSpacing: 1.0
        elide: Text.ElideRight
      }

      Text {
        width: parent.width
        textFormat: Text.PlainText
        text: String(root.todayDay)
        color: root.fg
        font.family: root.fontFamily
        font.pixelSize: Math.round(Style.font.title * 1.35)
        font.bold: true
      }

      Column {
        width: parent.width
        spacing: Style.space(3)

        Text {
          width: parent.width
          visible: root.feeds.length === 0
          textFormat: Text.PlainText
          text: root.strings.tn("calendar.feeds", root.enabledCount).arg(Commons.I18n.formatNumber(root.enabledCount, 0))
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          elide: Text.ElideRight
        }

        Repeater {
          model: Math.min(3, root.feeds.length)
          Row {
            width: leftCol.width
            spacing: Style.space(5)
            Rectangle {
              width: Style.space(6)
              height: Style.space(6)
              radius: width / 2
              anchors.verticalCenter: parent.verticalCenter
              color: root.feeds[index] && !root.feeds[index].enabled
                ? Util.alpha(root.dim, 0.5)
                : String(root.feeds[index].color || "#888888").substring(0, 16)
            }
            Text {
              width: parent.width - Style.space(11)
              textFormat: Text.PlainText
              text: root.feeds[index] ? root.feeds[index].name : ""
              color: root.feeds[index] && !root.feeds[index].enabled ? root.dim : root.fg
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              elide: Text.ElideRight
              maximumLineCount: 1
            }
          }
        }
      }
    }

    Column {
      width: parent.width - leftCol.width - parent.spacing
      spacing: Style.space(4)

      Text {
        width: parent.width
        textFormat: Text.PlainText
        text: root.monthUpper
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        font.bold: true
        font.letterSpacing: 1.1
      }

      MonthMatrix {
        width: parent.width
      }
    }
  }

  // ==================== STYLE 2: MONTH ONLY ====================
  Column {
    width: parent.width
    visible: root.calendarStyle === "month"
    spacing: Style.space(4)

    Text {
      width: parent.width
      textFormat: Text.PlainText
      text: root.monthTitle
      color: Util.alpha(root.fg, 0.72)
      font.family: root.fontFamily
      font.pixelSize: Style.font.title
      font.bold: true
      horizontalAlignment: Text.AlignHCenter
    }

    MonthMatrix {
      width: parent.width
    }
  }
}
