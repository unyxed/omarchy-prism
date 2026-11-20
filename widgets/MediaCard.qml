import QtQuick
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// macOS Media Widget with 3 selectable styles:
//   - "cover": Large rounded album art + title + artist + progress bar + controls
//   - "poster": Full-card album art backdrop with frosted bottom glass overlay
//   - "vinyl": Vinyl turntable where the album cover fills the entire record disc
GlassCard {
  id: root

  property var media: null
  property string mediaStyle: "cover"

  readonly property string trackTitle: media ? String(media.title || "") : ""
  readonly property string artist: media ? String(media.artist || "") : ""
  readonly property string album: media ? String(media.album || "") : ""
  readonly property string artUrl: media ? String(media.artUrl || "") : ""
  readonly property bool playing: media ? media.playing === true : false
  readonly property bool hasMedia: media ? media.hasMedia === true : false
  readonly property bool canPrev: media ? media.canGoPrevious === true : false
  readonly property bool canNext: media ? media.canGoNext === true : false
  readonly property bool canToggle: media ? media.canTogglePlaying !== false : true
  readonly property real progress: media ? media.progress : -1
  readonly property real positionSec: media ? media.position : 0
  readonly property real lengthSec: media ? media.length : 0

  function press(action) {
    if (media && typeof media.control === "function") media.control(action)
  }

  function formatDuration(sec) {
    var s = Math.max(0, Math.floor(Number(sec) || 0))
    var m = Math.floor(s / 60)
    var r = s % 60
    return m + ":" + (r < 10 ? "0" + r : r)
  }

  component TransportControls: Row {
    id: ctrlRow
    spacing: Style.spacing.sm

    PanelActionButton {
      iconText: "󰒮"
      tooltipText: "Previous"
      foreground: root.fg
      enabled: root.hasMedia && root.canPrev
      opacity: enabled ? 1.0 : 0.38
      fontSize: Style.font.icon
      size: Style.space(28)
      onClicked: root.press("previous")
    }

    PanelActionButton {
      iconText: root.playing ? "󰏤" : "󰐊"
      tooltipText: root.playing ? "Pause" : "Play"
      foreground: root.fg
      bordered: true
      enabled: root.hasMedia && root.canToggle
      opacity: enabled ? 1.0 : 0.38
      fontSize: Style.font.icon
      size: Style.space(32)
      onClicked: root.press("play-pause")
    }

    PanelActionButton {
      iconText: "󰒭"
      tooltipText: "Next"
      foreground: root.fg
      enabled: root.hasMedia && root.canNext
      opacity: enabled ? 1.0 : 0.38
      fontSize: Style.font.icon
      size: Style.space(28)
      onClicked: root.press("next")
    }
  }

  // ==================== STYLE 1: COVER (Large Square Cover + Progress) ====================
  Row {
    width: parent.width
    visible: root.mediaStyle === "cover"
    spacing: Style.spacing.md

    // Full-area 84x84 rounded square album cover
    Rectangle {
      id: coverBox
      width: Style.space(84)
      height: Style.space(84)
      radius: Style.space(14)
      color: Util.alpha(root.fg, 0.08)
      border.width: Style.space(1)
      border.color: Util.alpha("#ffffff", 0.18)
      anchors.verticalCenter: parent.verticalCenter

      Text {
        anchors.centerIn: parent
        visible: !coverArt.ready
        textFormat: Text.PlainText
        text: "󰎆"
        color: root.accent
        font.family: root.fontFamily
        font.pixelSize: Style.space(30)
      }

      AlbumArt {
        id: coverArt
        anchors.fill: parent
        url: root.hasMedia && root.mediaStyle === "cover" ? root.artUrl : ""
        round: false
        cornerRadius: coverBox.radius
      }
    }

    Column {
      width: parent.width - coverBox.width - parent.spacing
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.space(5)

      Text {
        width: parent.width
        textFormat: Text.PlainText
        text: root.hasMedia
          ? (root.trackTitle !== "" ? root.trackTitle : root.strings.t("media.unknown"))
          : root.strings.t("media.idle")
        color: root.fg
        font.family: root.fontFamily
        font.pixelSize: Style.font.subtitle
        font.bold: true
        elide: Text.ElideRight
        maximumLineCount: 1
      }

      Text {
        width: parent.width
        textFormat: Text.PlainText
        text: root.hasMedia && root.artist !== "" ? root.artist : "MPRIS"
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        elide: Text.ElideRight
        maximumLineCount: 1
      }

      // Progress bar + timestamps
      Column {
        width: parent.width
        visible: root.hasMedia && root.progress >= 0
        spacing: Style.space(2)

        Rectangle {
          width: parent.width
          height: Style.space(5)
          radius: height / 2
          color: Util.alpha(root.fg, 0.14)

          Rectangle {
            width: parent.width * Math.max(0, Math.min(1, root.progress))
            height: parent.height
            radius: parent.radius
            color: root.accent
            Behavior on width { NumberAnimation { duration: Style.duration(180); easing.type: Easing.OutCubic } }
          }
        }

        Row {
          width: parent.width
          Text {
            id: posText
            textFormat: Text.PlainText
            text: root.formatDuration(root.positionSec)
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Math.max(9, Style.font.caption - 2)
          }
          Item {
            width: Math.max(0, parent.width - posText.implicitWidth - lenText.implicitWidth)
            height: 1
          }
          Text {
            id: lenText
            textFormat: Text.PlainText
            text: root.formatDuration(root.lengthSec)
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Math.max(9, Style.font.caption - 2)
          }
        }
      }

      TransportControls {
        anchors.horizontalCenter: parent.horizontalCenter
      }
    }
  }

  // ==================== STYLE 2: POSTER (Full-Bleed Album Cover Card) ====================
  Item {
    width: parent.width
    height: Style.space(136)
    visible: root.mediaStyle === "poster"

    Rectangle {
      anchors.fill: parent
      radius: Style.space(16)
      color: Util.alpha(root.fg, 0.08)

      AlbumArt {
        id: posterArt
        anchors.fill: parent
        url: root.hasMedia && root.mediaStyle === "poster" ? root.artUrl : ""
        round: false
        cornerRadius: Style.space(16)
      }

      // Frosted bottom overlay strip
      Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: Style.space(54)
        radius: Style.space(16)
        color: Util.alpha(Color.popups.background, 0.78)
        border.width: Style.space(1)
        border.color: Util.alpha("#ffffff", 0.16)

        Row {
          anchors.fill: parent
          anchors.leftMargin: Style.space(12)
          anchors.rightMargin: Style.space(10)
          spacing: Style.spacing.sm

          Column {
            width: parent.width - posterCtrls.implicitWidth - parent.spacing
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(1)

            Text {
              width: parent.width
              textFormat: Text.PlainText
              text: root.hasMedia
                ? (root.trackTitle !== "" ? root.trackTitle : root.strings.t("media.unknown"))
                : root.strings.t("media.idle")
              color: root.fg
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              font.bold: true
              elide: Text.ElideRight
              maximumLineCount: 1
            }

            Text {
              width: parent.width
              textFormat: Text.PlainText
              text: root.hasMedia && root.artist !== "" ? root.artist : "Now Playing"
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              elide: Text.ElideRight
              maximumLineCount: 1
            }
          }

          TransportControls {
            id: posterCtrls
            anchors.verticalCenter: parent.verticalCenter
          }
        }
      }
    }
  }

  // ==================== STYLE 3: VINYL (Full-Disc Cover Record) ====================
  Row {
    width: parent.width
    visible: root.mediaStyle === "vinyl"
    spacing: Style.spacing.md

    Item {
      id: turntable
      width: Style.space(84)
      height: Style.space(84)
      anchors.verticalCenter: parent.verticalCenter

      // Vinyl disc where the album cover fills the whole disc face (76x76 inside 84x84 rim)
      Rectangle {
        id: vinylDisc
        anchors.fill: parent
        radius: width / 2
        color: "#161618"
        border.width: Style.space(2)
        border.color: Util.alpha("#ffffff", 0.26)

        // Full-disc circular album art so the cover is large and clearly visible
        AlbumArt {
          id: vinylArt
          anchors.fill: parent
          anchors.margins: Style.space(4)
          url: root.hasMedia && root.mediaStyle === "vinyl" ? root.artUrl : ""
          round: true
        }

        // Subtle vinyl groove sheen over the disc
        Rectangle {
          width: parent.width * 0.76
          height: width
          radius: width / 2
          anchors.centerIn: parent
          color: "transparent"
          border.width: Style.space(1)
          border.color: Util.alpha("#ffffff", 0.14)
        }

        // Small center spindle ring
        Rectangle {
          width: Style.space(16)
          height: Style.space(16)
          radius: width / 2
          anchors.centerIn: parent
          color: Util.alpha("#161618", 0.75)
          border.width: Style.space(1)
          border.color: Util.alpha("#ffffff", 0.45)

          Rectangle {
            width: Style.space(5)
            height: Style.space(5)
            radius: width / 2
            anchors.centerIn: parent
            color: root.playing ? root.accent : root.dim
          }
        }
      }

      // Tonearm pivot badge at top-right
      Rectangle {
        width: Style.space(16)
        height: Style.space(16)
        radius: width / 2
        anchors.right: parent.right
        anchors.top: parent.top
        color: "#1e1e22"
        border.width: Style.space(1)
        border.color: Util.alpha("#ffffff", 0.38)

        Rectangle {
          width: Style.space(6)
          height: Style.space(6)
          radius: width / 2
          anchors.centerIn: parent
          color: root.playing ? root.accent : root.dim
        }
      }
    }

    Column {
      width: parent.width - turntable.width - parent.spacing
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.space(6)

      Text {
        width: parent.width
        textFormat: Text.PlainText
        text: root.hasMedia
          ? (root.trackTitle !== "" ? root.trackTitle : root.strings.t("media.unknown"))
          : root.strings.t("media.idle")
        color: root.fg
        font.family: root.fontFamily
        font.pixelSize: Style.font.subtitle
        font.bold: true
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        maximumLineCount: 1
      }

      Text {
        width: parent.width
        textFormat: Text.PlainText
        text: root.hasMedia && root.artist !== "" ? root.artist : "VinylPod"
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        maximumLineCount: 1
      }

      TransportControls {
        anchors.horizontalCenter: parent.horizontalCenter
      }
    }
  }
}
