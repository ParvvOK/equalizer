import QtQuick
import qs.Ui
import qs.Commons

BarWidget {
  id: root

  moduleName: "equalizer"

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  // The bar owns the panel identity. Quattro's panel routing expects
  // open/close/opened on the bar-widget root.
  readonly property bool opened:
    panelLoader.item ? panelLoader.item.opened === true : false

  function open() {
    if (panelLoader.item)
      panelLoader.item.open()
  }

  function close() {
    if (panelLoader.item)
      panelLoader.item.close()
  }

  function togglePanel() {
    if (panelLoader.item)
      panelLoader.item.toggle()
  }

  function injectPanel() {
    var target = panelLoader.item
    if (!target)
      return

    if ("bar" in target)
      target.bar = root.bar

    if ("settings" in target)
      target.settings = root.settings

    if ("anchorItem" in target)
      target.anchorItem = button

    if ("hostWidget" in target)
      target.hostWidget = root
  }

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  Loader {
    id: panelLoader

    active: true
    visible: false
    source: Qt.resolvedUrl("EqualizerPanel.qml")

    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  BarIconButton {
    id: button

    anchors.fill: parent
    bar: root.bar

    // Font Awesome's sliders glyph is part of Omarchy's configured Nerd Font
    // family and reads as an equalizer without inventing a custom bar mark.
    text: "\uf1de"
    slotSize: Style.bar.iconSlot

    tooltipText: panelLoader.item
      ? panelLoader.item.barTooltip
      : "Equalizer"

    active: root.opened
    useActiveColor: false

    onPressed: function(mouseButton) {
      if (mouseButton === Qt.LeftButton)
        root.togglePanel()
    }
  }
}
