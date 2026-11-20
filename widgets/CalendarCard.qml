import QtQuick
import qs.Commons
import qs.Commons as Commons

// macOS Calendar Widget with 2 selectable styles:
//   - "split": Left column with weekday, large date, calendar feeds; right column with month grid
//   - "month": Centered full-width month grid with big month header (mac-aesthetic-3 look)
//
// Double-click flips the card: the reverse side is a live agenda pulled from
// the Google Calendar ICS feeds in ~/.config/omarchy/calendars.json.
GlassCard {
  id: root

  property var calendar: null
  property string calendarStyle: "split"
  property bool flipped: false




  onDoubleClicked: root.flipped = !root.flipped


  property date now: new Date()
  readonly property var loc: Qt.locale(Commons.I18n.formatLocale)
  readonly property int todayDay: now.getDate()
  readonly property string weekdayUpper: loc.toString(now, "dddd").toUpperCase()
  readonly property string monthUpper: loc.toString(now, "MMMM").toUpperCase()
  readonly property string monthTitle: loc.toString(now, "MMMM")
  readonly property var feeds: calendar ? calendar.calendars : []
  readonly property int enabledCount: calendar ? calendar.enabledCount : 0

  readonly property var agenda: calendar ? calendar.agendaEvents : []
  readonly property string agendaState: calendar ? String(calendar.agendaState || "") : ""
  readonly property int agendaFeeds: calendar ? Number(calendar.agendaFeeds || 0) : 0

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

  function dayLabel(iso) {
    var day = String(iso || "").substring(0, 10)
    if (day === "") return ""
    var t = new Date(now.getFullYear(), now.getMonth(), now.getDate())
    var parts = day.split("-")
    if (parts.length !== 3) return day
    var d = new Date(Number(parts[0]), Number(parts[1]) - 1, Number(parts[2]))
    if (isNaN(d.getTime())) return day
    var diff = Math.round((d - t) / 86400000)
    if (diff === 0) return root.strings.t("calendar.today")
    if (diff === 1) return root.strings.t("calendar.tomorrow")
    if (diff > 1 && diff < 7) return loc.toString(d, "dddd")
    return loc.toString(d, "d MMM")
  }

  function timeRange(ev) {
    if (!ev) return ""
    if (ev.allDay) return root.strings.t("calendar.allday")
    var s = String(ev.start || "")
    var e = String(ev.end || "")
    var st = s.length >= 16 ? s.substring(11, 16) : ""
    var en = e.length >= 16 ? e.substring(11, 16) : ""
    if (st === "") return ""
    return en !== "" && en !== st ? st + "–" + en : st
  }

  function pressRefresh() {
    if (calendar && typeof calendar.fetchAgenda === "function") calendar.fetchAgenda()
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

  Flipable {
    id: flipper
    width: parent.width
    // Fixed at the taller side so the turn animates in place with zero
    // layout motion (no per-frame resizes, no sibling reflow).
    // Locked to the front face (or an explicit user resize): the agenda
    // back fits this frame via bodyH, so flipping and late-arriving events
    // never resize the card.
    height: root.cardH > 0 ? Math.max(Style.space(40), root.cardH - 2 * root.pad)
      : frontCol.implicitHeight
    Behavior on height { NumberAnimation { duration: Style.duration(220); easing.type: Easing.OutCubic } }

    // Remaining vertical space inside this frame once the back header and
    // hint are laid out. Scroll areas bind to this instead of fixed heights.
    readonly property real bodyH: Math.max(Style.space(56),
      height - backHeadRow.implicitHeight - backHint.implicitHeight - Style.spacing.sm * 2)
    Behavior on height { NumberAnimation { duration: Style.duration(220); easing.type: Easing.OutCubic } }

    // Flipable paints both sides unconditionally, so visibility is switched
    // explicitly at the edge-on point.
    // First-flip warm-up: same rationale as MediaCard — paint the back
    // during a startup window long enough to outlast surface mapping, at
    // 0.01 opacity behind the front so it is invisible and cannot take
    // pointer events. A real flip mid-warm-up still renders normally.
    property bool warmingBack: true
    readonly property bool warmingHidden: flipper.warmingBack && flipper.showingFront
    Timer {
      interval: 5000
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
    }

    back: Item {
      id: backRoot
      anchors.fill: parent
      visible: !flipper.showingFront || flipper.warmingBack
      opacity: flipper.warmingHidden ? 0.01 : 1
      z: flipper.warmingHidden ? -1 : 0

      Column {
        id: backCol
        width: parent.width
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.spacing.sm

        Row {
          id: backHeadRow
          width: parent.width
          spacing: Style.spacing.sm

          Text {
            width: parent.width - refreshBtn.width - parent.spacing
            anchors.verticalCenter: parent.verticalCenter
            textFormat: Text.PlainText
            text: root.strings.t("calendar.upcoming")
            color: root.fg
            font.family: root.fontFamily
            font.pixelSize: Style.font.subtitle
            font.bold: true
            elide: Text.ElideRight
          }

          Rectangle {
            id: refreshBtn
            width: Style.space(26)
            height: Style.space(26)
            radius: width / 2
            anchors.verticalCenter: parent.verticalCenter
            color: Util.alpha(root.fg, refreshArea.containsMouse ? 0.16 : 0.07)
            border.width: Style.space(1)
            border.color: Util.alpha(root.fg, 0.25)

            Text {
              anchors.centerIn: parent
              textFormat: Text.PlainText
              text: "⟳"
              color: root.fg
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
            }

            MouseArea {
              id: refreshArea
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.pressRefresh()
            }
          }
        }

        // Loading and empty states share the list height so the card never
        // resizes when the agenda arrives mid-session.
        Text {
          width: parent.width
          visible: root.agendaState === "" || root.agendaState === "loading"
          height: visible ? flipper.bodyH : 0
          textFormat: Text.PlainText
          text: root.strings.t("calendar.searching")
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          horizontalAlignment: Text.AlignHCenter
          verticalAlignment: Text.AlignVCenter
          wrapMode: Text.WordWrap
        }

        Text {
          width: parent.width
          visible: root.agendaState === "none"
          height: visible ? flipper.bodyH : 0
          textFormat: Text.PlainText
          text: root.agendaFeeds === 0 ? root.strings.t("calendar.nofeed") : root.strings.t("calendar.nothing")
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          horizontalAlignment: Text.AlignHCenter
          verticalAlignment: Text.AlignVCenter
          wrapMode: Text.WordWrap
        }

        ListView {
          id: backAgendaList
          width: parent.width
          visible: root.agendaState === "ready"
          height: flipper.bodyH
          clip: true
          model: root.agenda
          spacing: Style.space(7)

          delegate: Item {
            width: backAgendaList.width
            height: Math.max(agendaRow.implicitHeight, Style.space(30))

            Row {
              id: agendaRow
              width: parent.width
              spacing: Style.spacing.sm

              Rectangle {
                width: Style.space(8)
                height: Style.space(8)
                radius: width / 2
                anchors.verticalCenter: parent.verticalCenter
                color: String(modelData.color || "#888888").substring(0, 16)
              }

              Column {
                width: parent.width - Style.space(8) - parent.spacing
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.space(1)

                Text {
                  width: parent.width
                  textFormat: Text.PlainText
                  text: String(modelData.title || "")
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
                  text: root.dayLabel(modelData.start) + " · " + root.timeRange(modelData)
                    + (modelData.calendar ? " · " + modelData.calendar : "")
                  color: root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  elide: Text.ElideRight
                  maximumLineCount: 1
                }
              }
            }
          }
        }

        Text {
          id: backHint
          width: parent.width
          textFormat: Text.PlainText
          text: root.strings.t("calendar.flipback")
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
