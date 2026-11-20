import QtQuick
import qs.Commons
import qs.Commons as Commons

// macOS Clock Widget with 3 selectable styles:
//   - "hero": Frosted date pill at top, oversized time digits, weekday + date row below
//   - "glass": Huge centered translucent outlined numerals (mac-style-1 aesthetic)
//   - "minimal": Editorial left-aligned time with full weekday and date
GlassCard {
  id: root

  property string timeFormat: "24h"
  property bool showDate: true
  property string clockStyle: "hero"

  property date now: new Date()
  readonly property var loc: Qt.locale(Commons.I18n.formatLocale)
  readonly property string timeText: timeFormat === "12h"
    ? Qt.formatDateTime(now, "h:mm")
    : Qt.formatDateTime(now, "HH:mm")
  readonly property string ampmText: timeFormat === "12h"
    ? Qt.formatDateTime(now, "AP")
    : ""
  readonly property string weekdayText: loc.toString(now, "dddd")
  readonly property string monthDayText: loc.toString(now, "MMMM d").toUpperCase()
  readonly property string yearText: loc.toString(now, "yyyy")

  property Timer ticker: Timer {
    interval: 1000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.now = new Date()
  }

  // ==================== STYLE 1: HERO ====================
  Column {
    width: parent.width
    visible: root.clockStyle === "hero"
    spacing: Style.space(2)

    Row {
      width: parent.width
      spacing: Style.spacing.sm

      Rectangle {
        id: badgePill
        height: Style.space(22)
        width: badgeText.implicitWidth + Style.space(16)
        radius: height / 2
        color: Util.alpha(root.fg, 0.16)
        border.width: Style.space(1)
        border.color: Util.alpha("#ffffff", 0.28)

        Text {
          id: badgeText
          anchors.centerIn: parent
          textFormat: Text.PlainText
          text: root.ampmText !== "" ? (root.yearText + " · " + root.ampmText) : root.yearText
          color: root.fg
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          font.bold: true
        }
      }

      Item {
        width: Math.max(0, parent.width - badgePill.width - monthPill.implicitWidth - parent.spacing * 2)
        height: 1
      }

      Text {
        id: monthPill
        visible: root.showDate
        anchors.verticalCenter: badgePill.verticalCenter
        textFormat: Text.PlainText
        text: root.monthDayText
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        font.bold: true
        font.letterSpacing: 1.2
      }
    }

    Text {
      width: parent.width
      textFormat: Text.PlainText
      text: root.timeText
      color: Util.alpha(root.fg, 0.72)
      style: Text.Outline
      styleColor: Util.alpha("#ffffff", 0.35)
      font.family: root.fontFamily
      font.pixelSize: Math.max(Style.space(52), Math.round(root.width * 0.27))
      font.bold: true
      horizontalAlignment: Text.AlignHCenter
    }

    Text {
      width: parent.width
      visible: root.showDate
      textFormat: Text.PlainText
      text: root.weekdayText.toLowerCase()
      color: root.fg
      font.family: root.fontFamily
      font.pixelSize: Style.font.subtitle
      font.bold: true
      font.italic: true
      horizontalAlignment: Text.AlignHCenter
    }
  }

  // ==================== STYLE 2: GLASS DIGITS ====================
  Column {
    width: parent.width
    visible: root.clockStyle === "glass"
    spacing: Style.space(2)

    Text {
      width: parent.width
      visible: root.showDate
      textFormat: Text.PlainText
      text: root.weekdayText + " · " + root.monthDayText
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      font.bold: true
      horizontalAlignment: Text.AlignHCenter
    }

    Text {
      width: parent.width
      textFormat: Text.PlainText
      text: root.timeText
      color: Util.alpha(root.fg, 0.55)
      style: Text.Outline
      styleColor: Util.alpha("#ffffff", 0.42)
      font.family: root.fontFamily
      font.pixelSize: Math.max(Style.space(58), Math.round(root.width * 0.31))
      font.bold: true
      horizontalAlignment: Text.AlignHCenter
    }
  }

  // ==================== STYLE 3: MINIMAL ====================
  Column {
    width: parent.width
    visible: root.clockStyle === "minimal"
    spacing: Style.space(4)

    Text {
      width: parent.width
      textFormat: Text.PlainText
      text: root.timeText + (root.ampmText !== "" ? " " + root.ampmText : "")
      color: root.fg
      font.family: root.fontFamily
      font.pixelSize: Math.max(Style.space(40), Math.round(root.width * 0.21))
      font.bold: true
    }

    Text {
      width: parent.width
      visible: root.showDate
      textFormat: Text.PlainText
      text: root.weekdayText + ", " + root.monthDayText + " " + root.yearText
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      font.bold: true
      elide: Text.ElideRight
    }
  }
}
