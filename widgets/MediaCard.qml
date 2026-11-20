import QtQuick
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// macOS Media Widget with 4 selectable styles:
//   - "cover": Large rounded album art + title + artist + progress bar + controls
//   - "poster": Full-card album art backdrop with frosted bottom glass overlay
//   - "vinyl": Vinyl turntable where the album cover fills the entire record disc
//   - "lyrics": Apple-Music-style scrolling lyrics with live line highlight
//
// Double-click anywhere on the card flips it like a tile: the reverse side
// always shows the lyrics (or the cover when the front already shows lyrics).
GlassCard {
  id: root

  property var media: null
  property string mediaStyle: "cover"
  property bool flipped: false

  onDoubleClicked: root.flipped = !root.flipped


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
  readonly property string lyricsState: media ? String(media.lyricsState || "") : ""
  readonly property bool lyricsSynced: media ? media.lyricsSynced === true : false
  readonly property var lyricsLines: media ? media.lyricsLines : []
  readonly property var lyricsPlainLines: media ? media.lyricsPlainLines : []
  readonly property int lyricsIndex: media ? media.lyricsIndex : -1
  readonly property bool lyricsInstrumental: media ? media.lyricsInstrumental === true : false

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

  Flipable {
    id: flipper
    width: parent.width
    // Fixed at the taller side: the flip then turns in place with zero layout
    // motion (no per-frame surface resizes, no sibling reflow), which is what
    // keeps the animation smooth. Height still animates on style/content
    // changes via the Behavior below.
    height: Math.max(frontCol.implicitHeight, backCol.implicitHeight)
    Behavior on height { NumberAnimation { duration: Style.duration(220); easing.type: Easing.OutCubic } }

    // Flipable paints both sides unconditionally, so visibility is switched
    // explicitly at the edge-on point. Inner columns keep measuring while
    // hidden, so the height binding above stays valid on both sides.
    // First-flip warm-up: `visible: showingFront` means the back face is
    // never painted before the first flip, so its shaders (MultiEffect on
    // the mini-cover), delegates and glyphs would all compile *during*
    // that first animation — the classic one-time stutter. Paint the back
    // once at startup under opacity 0 (invisible), then revert to the
    // cheap visibility gating. Steady-state cost is unchanged.
    property bool warmingBack: true
    Timer {
      interval: 150
      running: flipper.warmingBack
      repeat: false
      onTriggered: flipper.warmingBack = false
    }

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

  // ==================== STYLE 4: LYRICS (Scrolling Lyrics + Highlight) ====================
  Column {
    width: parent.width
    visible: root.mediaStyle === "lyrics"
    spacing: Style.spacing.sm

    Row {
      width: parent.width
      spacing: Style.spacing.sm

      Column {
        width: parent.width - lyricsCtrls.implicitWidth - parent.spacing
        spacing: 0

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
          text: root.hasMedia && root.artist !== "" ? root.artist : "Lyrics"
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          elide: Text.ElideRight
          maximumLineCount: 1
        }
      }

      TransportControls {
        id: lyricsCtrls
        anchors.verticalCenter: parent.verticalCenter
      }
    }

    // Empty / loading / instrumental states (same height as the list so the
    // card never resizes when lyrics arrive)
    Text {
      width: parent.width
      visible: !root.hasMedia || root.lyricsState === "" || root.lyricsState === "loading"
      height: visible ? Style.space(150) : 0
      textFormat: Text.PlainText
      text: !root.hasMedia ? root.strings.t("media.idle") : root.strings.t("media.searching")
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      horizontalAlignment: Text.AlignHCenter
      verticalAlignment: Text.AlignVCenter
      wrapMode: Text.WordWrap
    }

    Text {
      width: parent.width
      visible: root.hasMedia && (root.lyricsState === "none" || (root.lyricsState === "ready" && root.lyricsInstrumental && root.lyricsLines.length === 0 && root.lyricsPlainLines.length === 0))
      height: visible ? Style.space(150) : 0
      textFormat: Text.PlainText
      text: root.lyricsInstrumental ? root.strings.t("media.instrumental") : root.strings.t("media.nolyrics")
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      font.italic: true
      horizontalAlignment: Text.AlignHCenter
      verticalAlignment: Text.AlignVCenter
      wrapMode: Text.WordWrap
    }

    // Synced lyrics: auto-following list with live highlight
    ListView {
      id: frontLyricsList
      width: parent.width
      visible: root.hasMedia && root.lyricsState === "ready" && root.lyricsSynced
      height: Style.space(150)
      clip: true
      model: root.lyricsLines
      currentIndex: root.lyricsIndex
      preferredHighlightBegin: height / 2 - Style.space(11)
      preferredHighlightEnd: height / 2 + Style.space(11)
      highlightRangeMode: ListView.ApplyRange
      highlightMoveDuration: Style.duration(220)
      spacing: Style.space(5)

      highlight: Rectangle {
        width: frontLyricsList.width
        height: Style.space(22)
        radius: Style.space(7)
        color: Util.alpha(root.accent, 0.22)
      }

      delegate: Item {
        width: frontLyricsList.width
        height: Math.max(lyricText.implicitHeight, Style.space(22))

        Text {
          id: lyricText
          anchors.fill: parent
          verticalAlignment: Text.AlignVCenter
          textFormat: Text.PlainText
          text: String(modelData.text || "")
          color: index === frontLyricsList.currentIndex ? root.fg : root.dim
          opacity: index === frontLyricsList.currentIndex ? 1.0 : (modelData.text === "" ? 0.35 : 0.75)
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          font.bold: index === frontLyricsList.currentIndex
          elide: Text.ElideRight
          maximumLineCount: 1
        }
      }
    }

    // Plain lyrics: scrollable text
    Flickable {
      width: parent.width
      visible: root.hasMedia && root.lyricsState === "ready" && !root.lyricsSynced && root.lyricsPlainLines.length > 0
      height: Style.space(150)
      clip: true
      contentWidth: width
      contentHeight: plainLyricsText.implicitHeight
      boundsBehavior: Flickable.StopAtBounds

      Text {
        id: plainLyricsText
        width: parent.width
        textFormat: Text.PlainText
        text: root.lyricsPlainLines.join("\n")
        color: root.fg
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        wrapMode: Text.WordWrap
      }
    }
  }
      } // frontCol
    } // front

    back: Item {
      id: backRoot
      anchors.fill: parent
      visible: !flipper.showingFront || flipper.warmingBack
      opacity: flipper.warmingBack && flipper.showingFront ? 0 : 1

      Column {
        id: backCol
        width: parent.width
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.spacing.sm

        // Mini cover: the reverse side when the front already shows lyrics
        Row {
          width: parent.width
          visible: root.mediaStyle === "lyrics"
          spacing: Style.spacing.sm

          Rectangle {
            width: Style.space(56)
            height: Style.space(56)
            radius: Style.space(10)
            color: Util.alpha(root.fg, 0.08)
            border.width: Style.space(1)
            border.color: Util.alpha("#ffffff", 0.18)

            AlbumArt {
              anchors.fill: parent
              url: root.hasMedia ? root.artUrl : ""
              round: false
              cornerRadius: Style.space(10)
            }
          }

          Column {
            width: parent.width - Style.space(56) - parent.spacing
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
        }

        // Compact lyrics: the reverse side of the cover/poster/vinyl fronts
        Column {
          width: parent.width
          visible: root.mediaStyle !== "lyrics"
          spacing: Style.spacing.xs

          Row {
            width: parent.width
            spacing: Style.spacing.sm

            Text {
              width: parent.width - backPlayDot.implicitWidth - parent.spacing
              textFormat: Text.PlainText
              text: root.hasMedia
                ? (root.trackTitle !== "" ? root.trackTitle + " — " + root.artist : root.strings.t("media.unknown"))
                : root.strings.t("media.idle")
              color: root.fg
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              elide: Text.ElideRight
              maximumLineCount: 1
              anchors.verticalCenter: parent.verticalCenter
            }

            Text {
              id: backPlayDot
              textFormat: Text.PlainText
              text: root.playing ? "●" : "○"
              color: root.playing ? root.accent : root.dim
              font.pixelSize: Style.font.caption
              anchors.verticalCenter: parent.verticalCenter
            }
          }

          // Empty / loading states share the list height so the card never
          // resizes when lyrics arrive mid-session.
          Text {
            width: parent.width
            visible: !root.hasMedia || root.lyricsState === "" || root.lyricsState === "loading"
            height: visible ? Style.space(96) : 0
            textFormat: Text.PlainText
            text: !root.hasMedia ? root.strings.t("media.idle") : root.strings.t("media.searching")
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            wrapMode: Text.WordWrap
          }

          Text {
            width: parent.width
            visible: root.hasMedia && (root.lyricsState === "none" || (root.lyricsState === "ready" && root.lyricsInstrumental && root.lyricsLines.length === 0 && root.lyricsPlainLines.length === 0))
            height: visible ? Style.space(96) : 0
            textFormat: Text.PlainText
            text: root.lyricsInstrumental ? root.strings.t("media.instrumental") : root.strings.t("media.nolyrics")
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            font.italic: true
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            wrapMode: Text.WordWrap
          }

          ListView {
            id: backLyricsList
            width: parent.width
            visible: root.hasMedia && root.lyricsState === "ready" && root.lyricsSynced
            height: Style.space(96)
            clip: true
            model: root.lyricsLines
            currentIndex: root.lyricsIndex
            preferredHighlightBegin: height / 2 - Style.space(10)
            preferredHighlightEnd: height / 2 + Style.space(10)
            highlightRangeMode: ListView.ApplyRange
            highlightMoveDuration: Style.duration(220)
            spacing: Style.space(3)

            highlight: Rectangle {
              width: backLyricsList.width
              height: Style.space(20)
              radius: Style.space(6)
              color: Util.alpha(root.accent, 0.22)
            }

            delegate: Item {
              width: backLyricsList.width
              height: Math.max(backLyricText.implicitHeight, Style.space(20))

              Text {
                id: backLyricText
                anchors.fill: parent
                verticalAlignment: Text.AlignVCenter
                textFormat: Text.PlainText
                text: String(modelData.text || "")
                color: index === backLyricsList.currentIndex ? root.fg : root.dim
                opacity: index === backLyricsList.currentIndex ? 1.0 : (modelData.text === "" ? 0.35 : 0.75)
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: index === backLyricsList.currentIndex
                elide: Text.ElideRight
                maximumLineCount: 1
              }
            }
          }

          Flickable {
            width: parent.width
            visible: root.hasMedia && root.lyricsState === "ready" && !root.lyricsSynced && root.lyricsPlainLines.length > 0
            height: Style.space(96)
            clip: true
            contentWidth: width
            contentHeight: backPlainText.implicitHeight
            boundsBehavior: Flickable.StopAtBounds

            Text {
              id: backPlainText
              width: parent.width
              textFormat: Text.PlainText
              text: root.lyricsPlainLines.join("\n")
              color: root.fg
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              wrapMode: Text.WordWrap
            }
          }
        }

        Text {
          width: parent.width
          textFormat: Text.PlainText
          text: root.strings.t("media.flipback")
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
