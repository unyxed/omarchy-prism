import QtQuick
import qs.Commons
import qs.Commons as Commons

// macOS System Widget with 2 selectable styles:
//   - "rings": Circular ring gauges with percentage inside the ring + label/GiB below (never truncates)
//   - "bars": Full-width horizontal macOS metric bars + per-core sparkbars
GlassCard {
  id: root

  property var system: null
  property bool showCores: true
  property string systemStyle: "rings"

  readonly property real cpuLoad: system ? system.cpuLoad : -1
  readonly property var coreLoads: system ? system.coreLoads : []
  readonly property real memFraction: system && system.memory ? system.memory.fraction : -1
  readonly property real memUsedKib: system && system.memory ? system.memory.usedKib : 0
  readonly property real memTotalKib: system && system.memory ? system.memory.totalKib : 0

  function percentText(value) {
    if (!(value >= 0 && value <= 1)) return "--"
    return Commons.I18n.formatNumber(Math.round(value * 100), 0) + "%"
  }

  function gibShort(value) {
    var n = Number(value) || 0
    if (!(n > 0)) return "--"
    return Commons.I18n.formatNumber(n / 1048576, 1) + " GiB"
  }

  // ==================== STYLE 1: RINGS ====================
  Row {
    width: parent.width
    visible: root.systemStyle === "rings"
    spacing: Style.spacing.md

    // Left tile: CPU Ring (percentage inside ring, label below -> zero truncation)
    Rectangle {
      width: (parent.width - parent.spacing) / 2
      height: Style.space(98)
      radius: Style.space(16)
      color: Util.alpha(root.fg, 0.06)
      border.width: Style.space(1)
      border.color: Util.alpha("#ffffff", 0.12)

      Column {
        anchors.centerIn: parent
        spacing: Style.space(6)

        RingGauge {
          anchors.horizontalCenter: parent.horizontalCenter
          ringSize: Style.space(58)
          strokeWidth: Style.space(6)
          fraction: root.cpuLoad
          ringColor: root.cpuLoad > 0.85 ? Color.urgent : root.accent
          centerText: root.percentText(root.cpuLoad)
        }

        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          textFormat: Text.PlainText
          text: "󰍛  CPU"
          color: root.fg
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          font.bold: true
        }
      }
    }

    // Right tile: Memory Ring (percentage inside ring, GiB below -> zero truncation)
    Rectangle {
      width: (parent.width - parent.spacing) / 2
      height: Style.space(98)
      radius: Style.space(16)
      color: Util.alpha(root.fg, 0.06)
      border.width: Style.space(1)
      border.color: Util.alpha("#ffffff", 0.12)

      Column {
        anchors.centerIn: parent
        spacing: Style.space(6)

        RingGauge {
          anchors.horizontalCenter: parent.horizontalCenter
          ringSize: Style.space(58)
          strokeWidth: Style.space(6)
          fraction: root.memFraction
          ringColor: root.memFraction > 0.88 ? Color.urgent : root.accent
          centerText: root.percentText(root.memFraction)
        }

        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          textFormat: Text.PlainText
          text: "󰘚  " + root.gibShort(root.memUsedKib)
          color: root.fg
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          font.bold: true
        }
      }
    }
  }

  // ==================== STYLE 2: BARS ====================
  Column {
    width: parent.width
    visible: root.systemStyle === "bars"
    spacing: Style.spacing.sm

    Row {
      width: parent.width
      Text {
        id: cpuLabel
        textFormat: Text.PlainText
        text: "󰍛  CPU"
        color: root.fg
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        font.bold: true
      }
      Item {
        width: Math.max(0, parent.width - cpuLabel.implicitWidth - cpuVal.implicitWidth)
        height: 1
      }
      Text {
        id: cpuVal
        textFormat: Text.PlainText
        text: root.percentText(root.cpuLoad)
        color: root.accent
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        font.bold: true
      }
    }

    Rectangle {
      width: parent.width
      height: Style.space(7)
      radius: height / 2
      color: Util.alpha(root.fg, 0.14)
      Rectangle {
        width: parent.width * Math.max(0, Math.min(1, root.cpuLoad < 0 ? 0 : root.cpuLoad))
        height: parent.height
        radius: parent.radius
        color: root.cpuLoad > 0.85 ? Color.urgent : root.accent
        Behavior on width { NumberAnimation { duration: Style.duration(180); easing.type: Easing.OutCubic } }
      }
    }

    Row {
      width: parent.width
      Text {
        id: memLabel
        textFormat: Text.PlainText
        text: "󰘚  Memory"
        color: root.fg
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        font.bold: true
      }
      Item {
        width: Math.max(0, parent.width - memLabel.implicitWidth - memVal.implicitWidth)
        height: 1
      }
      Text {
        id: memVal
        textFormat: Text.PlainText
        text: root.gibShort(root.memUsedKib) + " / " + root.gibShort(root.memTotalKib)
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        font.bold: true
      }
    }

    Rectangle {
      width: parent.width
      height: Style.space(7)
      radius: height / 2
      color: Util.alpha(root.fg, 0.14)
      Rectangle {
        width: parent.width * Math.max(0, Math.min(1, root.memFraction < 0 ? 0 : root.memFraction))
        height: parent.height
        radius: parent.radius
        color: root.memFraction > 0.88 ? Color.urgent : root.accent
        Behavior on width { NumberAnimation { duration: Style.duration(180); easing.type: Easing.OutCubic } }
      }
    }
  }

  // Per-thread mini spark bars
  Grid {
    id: coreGrid
    width: parent.width
    visible: root.showCores && root.coreLoads.length > 0
    height: visible ? implicitHeight : 0
    columns: Math.min(8, Math.max(1, root.coreLoads.length))
    spacing: Style.spacing.xs
    readonly property real cellWidth: (coreGrid.width - spacing * (columns - 1)) / columns

    Repeater {
      model: root.coreLoads
      Rectangle {
        width: coreGrid.cellWidth
        height: Style.space(4)
        radius: height / 2
        color: Util.alpha(root.fg, 0.12)
        Rectangle {
          width: parent.width * Math.max(0, Math.min(1, modelData < 0 ? 0 : modelData))
          height: parent.height
          radius: parent.radius
          color: modelData > 0.85 ? Color.urgent : root.accent
        }
      }
    }
  }
}
