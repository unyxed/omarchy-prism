import QtQuick
import qs.Commons
import qs.Commons as Commons

// macOS System Widget with 2 selectable styles:
//   - "rings": Circular ring gauges with percentage inside the ring + label/GiB below (never truncates)
//   - "bars": Full-width horizontal macOS metric bars
//
// Double-click flips the card: the reverse side is per-thread load detail.
GlassCard {
  id: root

  property var system: null
  property string systemStyle: "rings"
  property bool flipped: false



  onDoubleClicked: root.flipped = !root.flipped

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

  Flipable {
    id: flipper
    width: parent.width
    // Fixed at the taller side so the turn animates in place with zero
    // layout motion (no per-frame resizes, no sibling reflow).
    // Follows the visible face (never max): pinning the taller face leaves
    // dead space on the short one. Honors an explicit user resize minus the
    // card frame, with faces centered inside; content taller than a resized
    // frame clips until reset.
    height: root.cardH > 0 ? Math.max(Style.space(40), root.cardH - 2 * root.pad)
      : (root.flipped ? backCol.implicitHeight : frontCol.implicitHeight)
    Behavior on height { NumberAnimation { duration: Style.duration(220); easing.type: Easing.OutCubic } }

    // Flipable paints both sides unconditionally, so visibility is switched
    // explicitly at the edge-on point.
    readonly property bool showingFront: {
      var a = ((flipRot.angle % 360) + 360) % 360
      return a <= 90 || a >= 270
    }

    front: Item {
      anchors.fill: parent
      visible: flipper.showingFront

      Column {
        id: frontCol
        width: parent.width
        anchors.verticalCenter: parent.verticalCenter

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
      }
    }

    back: Item {
      id: backRoot
      anchors.fill: parent
      visible: !flipper.showingFront

      Column {
        id: backCol
        width: parent.width
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.spacing.sm

        // Per-thread load detail, scrollable for many-core machines.
        Row {
          width: parent.width
          spacing: Style.spacing.sm

          Text {
            width: parent.width - backCoreCount.implicitWidth - parent.spacing
            anchors.verticalCenter: parent.verticalCenter
            textFormat: Text.PlainText
            text: root.strings.t("system.threads")
            color: root.fg
            font.family: root.fontFamily
            font.pixelSize: Style.font.subtitle
            font.bold: true
            elide: Text.ElideRight
          }

          Text {
            id: backCoreCount
            anchors.verticalCenter: parent.verticalCenter
            textFormat: Text.PlainText
            text: Commons.I18n.formatNumber(root.coreLoads.length, 0)
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
          }
        }

        Text {
          width: parent.width
          visible: root.coreLoads.length === 0
          height: visible ? Style.space(120) : 0
          textFormat: Text.PlainText
          text: root.strings.t("system.nocores")
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          horizontalAlignment: Text.AlignHCenter
          verticalAlignment: Text.AlignVCenter
          wrapMode: Text.WordWrap
        }

        ListView {
          id: backCoreList
          width: parent.width
          visible: root.coreLoads.length > 0
          height: Style.space(120)
          clip: true
          model: root.coreLoads
          spacing: Style.space(4)

          delegate: Item {
            width: backCoreList.width
            height: Style.space(16)

            Row {
              anchors.fill: parent
              spacing: Style.spacing.sm

              Text {
                width: Style.space(28)
                anchors.verticalCenter: parent.verticalCenter
                textFormat: Text.PlainText
                text: "C" + index
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
                elide: Text.ElideRight
              }

              Rectangle {
                width: parent.width - Style.space(28) - backCorePct.implicitWidth - parent.spacing * 2
                height: Style.space(6)
                radius: height / 2
                anchors.verticalCenter: parent.verticalCenter
                color: Util.alpha(root.fg, 0.14)

                Rectangle {
                  width: parent.width * Math.max(0, Math.min(1, modelData < 0 ? 0 : modelData))
                  height: parent.height
                  radius: parent.radius
                  color: modelData > 0.85 ? Color.urgent : root.accent
                }
              }

              Text {
                id: backCorePct
                anchors.verticalCenter: parent.verticalCenter
                textFormat: Text.PlainText
                text: root.percentText(modelData)
                color: root.fg
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
              }
            }
          }
        }

        Text {
          width: parent.width
          textFormat: Text.PlainText
          text: root.strings.t("system.memory") + "  " + root.gibShort(root.memUsedKib) + " / " + root.gibShort(root.memTotalKib)
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          font.bold: true
          elide: Text.ElideRight
        }

        Text {
          width: parent.width
          textFormat: Text.PlainText
          text: root.strings.t("system.flipback")
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Math.max(9, Style.font.caption - 2)
          font.italic: true
          horizontalAlignment: Text.AlignHCenter
        }
      }
    }

    transform: Rotation {
      id: flipRot
      origin.x: flipper.width / 2
      origin.y: flipper.height / 2
      axis.x: 0
      axis.y: 1
      axis.z: 0
      angle: 0
    }

    states: State {
      name: "back"
      when: root.flipped
      PropertyChanges { target: flipRot; angle: 180 }
    }

    transitions: Transition {
      NumberAnimation { target: flipRot; property: "angle"; duration: Style.duration(320); easing.type: Easing.OutCubic }
    }
  }
}
