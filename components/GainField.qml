import QtQuick
import qs.Commons
import qs.Ui

// Gain readout that shows hundredths and can be edited by typing.
// Click the number, type a value (e.g. 8.03, -3.27, +12), press Enter to
// apply. Values are clamped to -12.00..+12.00. Escape or clicking elsewhere
// cancels without changing anything.
Item {
  id: root

  property real value: 0
  property string suffix: ""
  property color textColor: Color.menu.text
  property int pixelSize: Style.font.bodySmall
  property bool bold: false
  property int horizontalAlignment: Text.AlignHCenter
  readonly property bool editing: field.visible

  signal committed(real value)

  readonly property string displayText: (value >= 0 ? "+" : "") + value.toFixed(2) + suffix

  implicitWidth: label.implicitWidth
  implicitHeight: Math.max(label.implicitHeight, field.implicitHeight)

  function beginEdit() {
    field.text = value.toFixed(2)
    field.visible = true
    field.forceActiveFocus()
    field.selectAll()
  }

  function cancelEdit() {
    field.visible = false
  }

  function commitEdit() {
    var raw = field.text.trim()
    field.visible = false
    if (!/\d/.test(raw)) return
    var parsed = Number(raw)
    if (!isFinite(parsed)) return
    var gain = Math.round(Math.max(-12, Math.min(12, parsed)) * 100) / 100
    root.committed(gain)
  }

  Text {
    id: label
    anchors.fill: parent
    visible: !root.editing
    text: root.displayText
    color: labelMouse.containsMouse ? Color.accent : root.textColor
    font.family: Style.font.family
    font.pixelSize: root.pixelSize
    font.bold: root.bold
    horizontalAlignment: root.horizontalAlignment
    verticalAlignment: Text.AlignVCenter

    MouseArea {
      id: labelMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.IBeamCursor
      onClicked: root.beginEdit()
    }
  }

  TextField {
    id: field
    visible: false
    anchors.fill: parent
    foreground: Color.menu.text
    horizontalPadding: Style.space(2)
    verticalPadding: 0
    font.pixelSize: root.pixelSize
    font.bold: root.bold
    horizontalAlignment: root.horizontalAlignment
    verticalAlignment: TextInput.AlignVCenter
    inputMethodHints: Qt.ImhFormattedNumbersOnly
    validator: RegularExpressionValidator { regularExpression: /^[+-]?\d{0,2}(\.\d{0,2})?$/ }

    onAccepted: root.commitEdit()
    onActiveFocusChanged: if (!activeFocus && visible) root.cancelEdit()
    Keys.onEscapePressed: function(event) {
      root.cancelEdit()
      event.accepted = true
    }
  }
}
