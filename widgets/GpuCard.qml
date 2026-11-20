import QtQuick
import qs.Commons
import qs.Commons as Commons

// macOS GPU Widget with 2 selectable styles ("rings" and "bars") — zero text truncation.
GlassCard {
  id: root

  property var gpu: null
  property string systemStyle: "rings"

  readonly property bool present: gpu ? gpu.present : false
  readonly property real load: gpu ? gpu.utilization : -1
  readonly property real vram: gpu ? gpu.vramFraction : -1
  readonly property real temp: gpu ? gpu.temperature : -1
  readonly property string gpuName: gpu && gpu.name ? String(gpu.name).substring(0, 60) : ""

  function percentText(value) {
    if (!(value >= 0 && value <= 1)) return "--"
    return Commons.I18n.formatNumber(Math.round(value * 100), 0) + "%"
  }

  function tempText(value) {
    var n = Number(value)
    if (!isFinite(n) || n < 0) return "--"
    return Commons.I18n.formatNumber(Math.round(n), 0) + "°C"
  }

  function gib(bytes) {
    var n = Number(bytes) || 0
    if (!(n > 0)) return "--"
    return Commons.I18n.formatNumber(n / 1073741824, 1) + " GiB"
  }

  Text {
    width: parent.width
    visible: !root.present
    textFormat: Text.PlainText
    text: root.strings.t("gpu.absent")
    color: root.dim
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
    wrapMode: Text.WordWrap
  }

  Column {
    width: parent.width
    visible: root.present
    spacing: Style.spacing.sm

    // ==================== STYLE 1: RINGS ====================
    Row {
      width: parent.width
      visible: root.systemStyle === "rings"
      spacing: Style.spacing.md

      // Left tile: GPU Load Ring + Temp below
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
            fraction: root.load
            ringColor: root.load > 0.88 ? Color.urgent : root.accent
            centerText: root.percentText(root.load)
          }

          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            textFormat: Text.PlainText
            text: "󰢮  GPU · " + root.tempText(root.temp)
            color: root.fg
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
          }
        }
      }

      // Right tile: VRAM Ring + Used GiB below
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
            fraction: root.vram
            ringColor: root.vram > 0.90 ? Color.urgent : root.accent
            centerText: root.percentText(root.vram)
          }

          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            textFormat: Text.PlainText
            text: "VRAM · " + root.gib(root.gpu ? root.gpu.vramUsed : 0)
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
          id: gpuLabel
          textFormat: Text.PlainText
          text: "󰢮  GPU · " + root.tempText(root.temp)
          color: root.fg
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          font.bold: true
        }
        Item {
          width: Math.max(0, parent.width - gpuLabel.implicitWidth - gpuVal.implicitWidth)
          height: 1
        }
        Text {
          id: gpuVal
          textFormat: Text.PlainText
          text: root.percentText(root.load)
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
          width: parent.width * Math.max(0, Math.min(1, root.load < 0 ? 0 : root.load))
          height: parent.height
          radius: parent.radius
          color: root.load > 0.88 ? Color.urgent : root.accent
          Behavior on width { NumberAnimation { duration: Style.duration(180); easing.type: Easing.OutCubic } }
        }
      }

      Row {
        width: parent.width
        Text {
          id: vramLabel
          textFormat: Text.PlainText
          text: "VRAM"
          color: root.fg
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          font.bold: true
        }
        Item {
          width: Math.max(0, parent.width - vramLabel.implicitWidth - vramVal.implicitWidth)
          height: 1
        }
        Text {
          id: vramVal
          textFormat: Text.PlainText
          text: root.gib(root.gpu ? root.gpu.vramUsed : 0) + " / " + root.gib(root.gpu ? root.gpu.vramTotal : 0)
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
          width: parent.width * Math.max(0, Math.min(1, root.vram < 0 ? 0 : root.vram))
          height: parent.height
          radius: parent.radius
          color: root.vram > 0.90 ? Color.urgent : root.accent
          Behavior on width { NumberAnimation { duration: Style.duration(180); easing.type: Easing.OutCubic } }
        }
      }
    }

    Text {
      width: parent.width
      visible: root.gpuName !== ""
      textFormat: Text.PlainText
      text: root.gpuName
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      elide: Text.ElideRight
    }
  }
}
