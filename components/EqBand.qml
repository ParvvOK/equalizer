import QtQuick
import qs.Commons
import qs.Ui

Item {
  id: root

  property string label: ""
  property real value: 0
  property bool dragging: false
  signal changed(real value)

  implicitWidth: Style.space(46)
  implicitHeight: Style.space(176)

  Column {
    anchors.fill: parent
    spacing: Style.spacing.xs

    Text {
      width: parent.width
      text: (root.value >= 0 ? "+" : "") + root.value.toFixed(1)
      color: root.dragging ? Color.accent : Color.menu.text
      font.family: Style.font.family
      font.pixelSize: Style.font.bodySmall
      font.bold: true
      horizontalAlignment: Text.AlignHCenter
    }

    Item {
      id: trackArea
      width: parent.width
      height: Math.max(Style.space(108), parent.height - Style.space(48))
      focus: true
      activeFocusOnTab: true

      Rectangle {
        anchors.fill: parent
        visible: trackArea.activeFocus
        color: "transparent"
        radius: Style.cornerRadius
        border.color: Color.accent
        border.width: Style.spacing.hairline
      }

      Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 0
        width: Style.space(3)
        height: parent.height
        radius: width / 2
        color: Qt.rgba(Color.menu.text.r, Color.menu.text.g, Color.menu.text.b, 0.25)
      }

      Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height / 2 - Style.spacing.hairline
        width: Style.space(16)
        height: Style.spacing.hairline
        color: Qt.rgba(Color.menu.text.r, Color.menu.text.g, Color.menu.text.b, 0.42)
      }

      BorderSurface {
        width: Style.space(14)
        height: Style.space(14)
        radius: width / 2
        y: Math.min(parent.height - height, Math.max(0, (12 - root.value) / 24 * parent.height - height / 2))
        anchors.horizontalCenter: parent.horizontalCenter
        color: root.dragging || trackArea.activeFocus ? Color.accent : Color.menu.text
        borderSpec: Border.flat(Color.menu.background, Style.spacing.hairline)
      }

      MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        function set(v) { root.changed(Math.max(-12, Math.min(12, 12 - v / height * 24))) }
        onPressed: function(m) { root.forceActiveFocus(); set(m.y); root.dragging = true }
        onPositionChanged: function(m) { if (pressed) set(m.y) }
        onReleased: root.dragging = false
      }

      Keys.onPressed: function(e) {
        var d = (e.key === Qt.Key_Up || e.key === Qt.Key_Right || e.key === Qt.Key_PageUp) ? 1 : -1
        if ([Qt.Key_Up, Qt.Key_Down, Qt.Key_Left, Qt.Key_Right, Qt.Key_PageUp, Qt.Key_PageDown].indexOf(e.key) >= 0) {
          root.changed(Math.max(-12, Math.min(12, root.value + d * (e.key === Qt.Key_PageUp || e.key === Qt.Key_PageDown ? 3 : 0.5))))
          e.accepted = true
        }
      }
    }

    Text {
      width: parent.width
      text: root.label
      color: Qt.rgba(Color.menu.text.r, Color.menu.text.g, Color.menu.text.b, 0.72)
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
      font.bold: true
      horizontalAlignment: Text.AlignHCenter
    }
  }
}
