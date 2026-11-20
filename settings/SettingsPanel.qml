import QtQuick
import qs.Commons
import qs.Ui

// Popup content: per-card toggles, glass tuning, layout reset.
Column {
  id: root

  required property var config
  property bool glassAvailable: false
  property var todos: []
  property int todoRows: 5

  signal widgetToggled(string id)
  signal positionPicked(string position)
  signal settingChanged(string key, var value)
  signal flagToggled(string key)
  signal todoToggled(string id)
  signal todoAdded(string text)
  signal resetLayoutRequested()
  signal installGlassRequested()

  spacing: Style.spacing.md
  property bool sliderDragging: false

  readonly property color foreground: Color.popups.text
  readonly property color dim: Util.alpha(foreground, 0.6)
  readonly property string fontFamily: Style.font.family

  readonly property var positions: [
    "top-left", "top-center", "top-right",
    "middle-left", "", "middle-right",
    "bottom-left", "bottom-center", "bottom-right"
  ]

  function widgetEnabled(id) {
    return root.config.widgets.indexOf(id) !== -1
  }

  SectionHeader { title: "Widgets" }

  Toggle {
    width: parent.width
    label: "Clock"
    description: "Time, and the date beneath it."
    checked: root.widgetEnabled("clock")
    foreground: root.foreground
    onClicked: root.widgetToggled("clock")
  }

  Toggle {
    width: parent.width
    label: "System"
    description: "CPU load, per-thread bars and memory."
    checked: root.widgetEnabled("system")
    foreground: root.foreground
    onClicked: root.widgetToggled("system")
  }

  Toggle {
    width: parent.width
    label: "Graphics"
    description: "GPU load, VRAM and temperature."
    checked: root.widgetEnabled("gpu")
    foreground: root.foreground
    onClicked: root.widgetToggled("gpu")
  }

  Toggle {
    width: parent.width
    label: "Now Playing"
    description: "Media controls for the active player."
    checked: root.widgetEnabled("media")
    foreground: root.foreground
    onClicked: root.widgetToggled("media")
  }

  Toggle {
    width: parent.width
    label: "Calendar"
    description: "Today with your enabled calendars."
    checked: root.widgetEnabled("calendar")
    foreground: root.foreground
    onClicked: root.widgetToggled("calendar")
  }

  Toggle {
    width: parent.width
    label: "Reminders"
    description: "Fast local todo list."
    checked: root.widgetEnabled("todo")
    foreground: root.foreground
    onClicked: root.widgetToggled("todo")
  }

  SectionHeader { title: "Widget Styles" }

  StyleRow {
    label: "Music"
    selected: root.config.mediaStyle
    options: [
      { value: "cover", label: "Cover" },
      { value: "poster", label: "Poster" },
      { value: "vinyl", label: "Vinyl" }
    ]
    onPicked: function (v) { root.settingChanged("mediaStyle", v) }
  }

  StyleRow {
    label: "Clock"
    selected: root.config.clockStyle
    options: [
      { value: "hero", label: "Hero" },
      { value: "glass", label: "Glass" },
      { value: "minimal", label: "Minimal" }
    ]
    onPicked: function (v) { root.settingChanged("clockStyle", v) }
  }

  StyleRow {
    label: "System & GPU"
    selected: root.config.systemStyle
    options: [
      { value: "rings", label: "Rings" },
      { value: "bars", label: "Bars" }
    ]
    onPicked: function (v) { root.settingChanged("systemStyle", v) }
  }

  StyleRow {
    label: "Calendar"
    selected: root.config.calendarStyle
    options: [
      { value: "split", label: "Split" },
      { value: "month", label: "Month" }
    ]
    onPicked: function (v) { root.settingChanged("calendarStyle", v) }
  }

  SectionHeader { title: "Glass"; detail: glassAvailable ? "hyprglass active" : "flat translucency" }

  Text {
    width: parent.width
    textFormat: Text.PlainText
    text: glassAvailable
      ? "Liquid glass is active: cards are real glass."
      : "Install hyprglass for real liquid glass. Cards still render as frosted panels without it."
    color: root.dim
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
    wrapMode: Text.WordWrap
  }

  Rectangle {
    width: parent.width
    height: Style.spacing.controlHeight + Style.space(8)
    radius: Style.space(10)
    visible: !glassAvailable
    color: Util.alpha(Color.accent, 0.18)
    border.width: Style.space(1)
    border.color: Util.alpha(Color.accent, 0.7)

    Text {
      anchors.centerIn: parent
      textFormat: Text.PlainText
      text: "Install hyprglass"
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.body
      font.bold: true
    }

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: root.installGlassRequested()
    }
  }

  SectionHeader { title: "Position"; detail: root.config.position }
  Spacer { width: parent.width }

  Grid {
    width: parent.width
    columns: 3
    spacing: Style.spacing.xs

    readonly property real cell: (width - spacing * 2) / 3

    Repeater {
      model: root.positions

      Item {
        width: parent.cell
        height: parent.cell

        Rectangle {
          anchors.fill: parent
          visible: modelData !== ""
          radius: Style.space(6)
          color: modelData === root.config.position
            ? Util.alpha(Color.accent, 0.28)
            : Util.alpha(root.foreground, posArea.containsMouse ? 0.12 : 0.05)
          border.width: Style.space(1)
          border.color: modelData === root.config.position
            ? Util.alpha(Color.accent, 0.9)
            : Util.alpha(root.foreground, 0.15)

          MouseArea {
            id: posArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.positionPicked(modelData)
          }
        }
      }
    }
  }

  SectionHeader { title: "Appearance" }
  Spacer { width: parent.width }

  LabeledSlider {
    width: parent.width
    label: "Background opacity"
    value: root.config.opacity
    minimum: 0.05
    maximum: 1
    step: 0.05
    display: Math.round(current * 100) + "%"
    onMoved: function (value) { root.settingChanged("opacity", value) }
  }

  LabeledSlider {
    width: parent.width
    label: "Default width"
    value: root.config.cardWidth
    minimum: 140
    maximum: 520
    step: 4
    integer: true
    display: Math.round(current) + " px"
    onMoved: function (value) { root.settingChanged("cardWidth", value) }
  }

  LabeledSlider {
    width: parent.width
    label: "Gap between widgets"
    value: root.config.spacing
    minimum: 0
    maximum: 48
    step: 1
    integer: true
    display: Math.round(current) + " px"
    onMoved: function (value) { root.settingChanged("spacing", value) }
  }

  LabeledSlider {
    width: parent.width
    label: "Corner radius"
    value: root.config.radius
    minimum: 0
    maximum: 64
    step: 1
    integer: true
    display: Math.round(current) + " px"
    onMoved: function (value) { root.settingChanged("radius", value) }
  }

  Toggle {
    width: parent.width
    label: "Widget titles"
    checked: root.config.showLabels
    foreground: root.foreground
    onClicked: root.flagToggled("showLabels")
  }

  Toggle {
    width: parent.width
    label: "Clock date"
    checked: root.config.showDate
    foreground: root.foreground
    onClicked: root.flagToggled("showDate")
  }

  Toggle {
    width: parent.width
    label: "Per-thread CPU bars"
    checked: root.config.showCpuCores
    foreground: root.foreground
    onClicked: root.flagToggled("showCpuCores")
  }

  Toggle {
    width: parent.width
    label: "Hide media when idle"
    checked: root.config.hideMediaWhenIdle
    foreground: root.foreground
    onClicked: root.flagToggled("hideMediaWhenIdle")
  }

  readonly property int openTodos: {
    var n = 0
    for (var i = 0; i < root.todos.length; i++) if (!root.todos[i].done) n++
    return n
  }

  SectionHeader { title: "Reminders"; detail: root.openTodos + " open" }

  Column {
    width: parent.width
    spacing: Style.spacing.xs

    Text {
      width: parent.width
      visible: root.todos.length === 0
      textFormat: Text.PlainText
      text: "No reminders yet. Add your first below."
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      wrapMode: Text.WordWrap
    }

    Repeater {
      model: Math.min(10, root.todos.length)

      Row {
        width: parent.width
        spacing: Style.spacing.sm

        Rectangle {
          width: Style.space(18)
          height: Style.space(18)
          radius: width / 2
          anchors.verticalCenter: parent.verticalCenter
          color: root.todos[index].done ? Color.accent : "transparent"
          border.width: Style.space(1)
          border.color: root.todos[index].done ? Util.alpha(Color.accent, 1) : Util.alpha(root.foreground, 0.4)

          Text {
            visible: root.todos[index].done
            anchors.centerIn: parent
            textFormat: Text.PlainText
            text: "✓"
            color: Color.popups.background
            font.pixelSize: Style.font.caption
            font.bold: true
          }

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.todoToggled(String(root.todos[index].id))
          }
        }

        Text {
          width: parent.width - Style.space(18) - parent.spacing
          textFormat: Text.PlainText
          text: String(root.todos[index].text || "")
          color: root.todos[index].done ? root.dim : root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          font.strikeout: root.todos[index].done
          elide: Text.ElideRight
          maximumLineCount: 1
          anchors.verticalCenter: parent.verticalCenter
        }
      }
    }
  }

  Spacer { width: parent.width }

  Row {
    width: parent.width
    spacing: Style.spacing.sm

    TextField {
      id: todoInput
      width: parent.width - addTodoButton.width - parent.spacing
      placeholderText: "New reminder…"
      maximumLength: 200
      onAccepted: {
        var value = text.trim()
        if (value !== "") {
          root.todoAdded(value)
          text = ""
        }
      }
    }

    Button {
      id: addTodoButton
      text: "+"
      onClicked: {
        var value = todoInput.text.trim()
        if (value !== "") {
          root.todoAdded(value)
          todoInput.text = ""
        }
      }
    }
  }

  Spacer { width: parent.width }

  SectionHeader { title: "Layout" }

  Toggle {
    width: parent.width
    label: "Reset positions and sizes"
    description: "Cards dragged or resized return to the stack."
    checked: false
    foreground: root.foreground
    onClicked: root.resetLayoutRequested()
  }

  component SectionHeader: Item {
    property string title: ""
    property string detail: ""
    width: parent ? parent.width : 0
    height: titleText.implicitHeight
    Text {
      id: titleText
      textFormat: Text.PlainText
      text: title + (detail !== "" ? "  ·  " + detail : "")
      color: Util.alpha(Color.popups.text, 0.75)
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
      font.bold: true
      font.letterSpacing: 1.1
    }
  }

  component Spacer: Rectangle {
    width: 1
    height: Style.space(2)
    color: "transparent"
  }

  component StyleRow: Column {
    id: styleBlock
    property string label: ""
    property string selected: ""
    property var options: []
    signal picked(string value)

    width: parent ? parent.width : 0
    spacing: Style.spacing.xs

    Text {
      textFormat: Text.PlainText
      text: styleBlock.label
      color: Color.popups.text
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
    }

    Row {
      id: segRow
      width: parent.width
      spacing: Style.spacing.xs
      readonly property int count: Math.max(1, styleBlock.options.length)
      readonly property real cellW: (width - spacing * (count - 1)) / count

      Repeater {
        model: styleBlock.options
        Rectangle {
          width: segRow.cellW
          height: Style.spacing.controlHeight + Style.space(4)
          radius: Style.space(8)
          color: modelData.value === styleBlock.selected
            ? Util.alpha(Color.accent, 0.30)
            : Util.alpha(Color.popups.text, segArea.containsMouse ? 0.12 : 0.05)
          border.width: Style.space(1)
          border.color: modelData.value === styleBlock.selected
            ? Util.alpha(Color.accent, 0.9)
            : Util.alpha(Color.popups.text, 0.15)

          Text {
            anchors.centerIn: parent
            textFormat: Text.PlainText
            text: modelData.label
            color: Color.popups.text
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            font.bold: modelData.value === styleBlock.selected
          }

          MouseArea {
            id: segArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: styleBlock.picked(modelData.value)
          }
        }
      }
    }
  }

  component LabeledSlider: Column {
    id: sliderBlock
    property string label: ""
    property real value: 0
    property real minimum: 0
    property real maximum: 1
    property real step: 0.05
    property bool integer: false
    property string display: ""
    signal moved(real value)

    property real current: value
    property bool dragging: false
    onValueChanged: if (!dragging) current = value
    onDraggingChanged: root.sliderDragging = dragging

    spacing: Style.spacing.xs
    width: parent ? parent.width : 0

    Row {
      width: parent.width
      spacing: Style.spacing.sm

      Text {
        id: nameText
        textFormat: Text.PlainText
        text: sliderBlock.label
        color: Color.popups.text
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
      }
      Item {
        width: Math.max(0, parent.width - nameText.width - valueText.width)
        height: 1
      }
      Text {
        id: valueText
        textFormat: Text.PlainText
        text: sliderBlock.display
        color: Util.alpha(Color.popups.text, 0.6)
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
      }
    }

    PanelSlider {
      width: parent.width
      minimum: sliderBlock.minimum
      maximum: sliderBlock.maximum
      step: sliderBlock.step
      integer: sliderBlock.integer
      value: sliderBlock.current
      trackColor: Util.alpha(Color.popups.text, 0.15)
      fillColor: Color.accent
      knobColor: Color.popups.text
      onDraggingChanged: sliderBlock.dragging = dragging
      onMoved: function (value) {
        sliderBlock.current = value
        sliderBlock.moved(value)
      }
      onReleased: function (value) {
        sliderBlock.current = value
        sliderBlock.moved(value)
      }
    }
  }
}
