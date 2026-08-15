import QtQuick
import QtQuick.Controls
import Quickshell.Io
import qs.Ui
import qs.Commons
import "components"

Panel {
  id: root

  moduleName: "equalizer"
  ipcTarget: "equalizer"

  property var anchorItem: null
  property var hostWidget: null
  property bool advanced: false
  property string errorMessage: ""
  property var pendingCommands: []
  property var pendingBands: ({})
  property var presetNames: ["Flat", "Acoustic", "Bass Boost", "Classical", "Electronic", "Jazz", "Pop", "Rock", "Treble Boost", "Vocal"]
  property string backendPath: String(Qt.resolvedUrl("backend/eqctl")).replace(/^file:\/\//, "")
  property var state: ({
    ready: false,
    audioAvailable: false,
    graphAvailable: false,
    routed: false,
    enabled: true,
    preset: "Flat",
    deviceName: "Detecting audio…",
    bands: [0, 0, 0, 0, 0, 0],
    preamp: 0,
    auto: false
  })

  readonly property var frequencies: ["60", "250", "1k", "4k", "8k", "16k"]
  readonly property string barLabel: state.audioAvailable ? (state.enabled ? "EQ" : "EQ·") : "EQ?"
  readonly property string barTooltip: state.audioAvailable
    ? "Equalizer · " + (state.enabled ? "ON" : "OFF") + " · " + state.preset + " · " + state.deviceName
    : "Equalizer · PipeWire unavailable"
  readonly property bool mutationBusy: mutationProcess.running || pendingCommands.length > 0
  readonly property string statusText: state.audioAvailable
    ? (state.graphAvailable
        ? (state.routed ? "Audio is routed through the EQ" : "EQ ready; waiting for an audio stream")
        : "Audio detected; EQ is starting")
    : "PipeWire audio is unavailable"

  function open(payload) {
    refresh()
    root.controller.show()
  }

  function close() {
    root.controller.hide()
  }

  function toggle() {
    root.opened ? root.close() : root.open({})
  }

  function copyState(next) {
    return {
      ready: next.ready === true,
      audioAvailable: next.audioAvailable === true || (next.audio && next.audio.available === true),
      graphAvailable: next.graphAvailable === true || (next.audio && next.audio.graph && next.audio.graph.present === true),
      routed: next.routed === true || (next.audio && next.audio.route && next.audio.route.routed === true),
      enabled: next.enabled !== false,
      preset: String(next.preset || "Flat"),
      deviceName: String(next.deviceName || (next.device || {}).name || "No audio output"),
      bands: next.bands && next.bands.length === 6
        ? next.bands.map(function(b) { return typeof b === "object" ? Number(b.gain) || 0 : Number(b) || 0 })
        : [0, 0, 0, 0, 0, 0],
      preamp: Number((next.preamp || {}).value) || 0,
      auto: Boolean((next.preamp || {}).auto),
      autoValue: Number((next.preamp || {}).autoValue || next.autoPreamp) || 0
    }
  }

  function showError(message) {
    errorMessage = String(message || "The equalizer command failed")
  }

  function applyStatus(next) {
    if (!next || next.error) {
      if (next && next.error) showError(next.error)
      return
    }
    state = copyState(next)
    errorMessage = ""
  }

  function parseResult(text, isMutation) {
    var raw = String(text || "").trim()
    if (!raw) {
      if (isMutation) showError("The equalizer backend returned no result")
      return
    }
    try {
      var result = JSON.parse(raw)
      if (result.error) {
        showError(result.error)
        if (isMutation) refreshTimer.restart()
        return
      }
      if (result.bands || result.audio) applyStatus(result)
    } catch (e) {
      showError("Invalid response from eqctl")
      if (isMutation) refreshTimer.restart()
    }
  }

  function refresh() {
    if (!statusProcess.running)
      statusProcess.running = true
  }

  function enqueue(args) {
    var queue = pendingCommands.slice()
    queue.push(args)
    pendingCommands = queue
    runNextMutation()
  }

  function runNextMutation() {
    if (mutationProcess.running || pendingCommands.length === 0)
      return
    var queue = pendingCommands.slice()
    var args = queue.shift()
    pendingCommands = queue
    mutationProcess.command = [backendPath, "--json"].concat(args)
    mutationProcess.running = true
  }

  function setBand(index, value) {
    var gain = Math.max(-12, Math.min(12, Number(value) || 0))
    var bands = state.bands.slice()
    bands[index] = gain
    state = {
      ready: state.ready,
      audioAvailable: state.audioAvailable,
      graphAvailable: state.graphAvailable,
      routed: state.routed,
      enabled: state.enabled,
      preset: state.preset,
      deviceName: state.deviceName,
      bands: bands,
      preamp: state.preamp,
      auto: false,
      autoValue: state.autoValue
    }
    var next = ({})
    for (var key in pendingBands) next[key] = pendingBands[key]
    next[index] = gain
    pendingBands = next
    bandDebounce.restart()
  }

  function flushBands() {
    var values = pendingBands
    pendingBands = ({})
    var indexes = Object.keys(values)
    for (var i = 0; i < indexes.length; i++) {
      var index = Number(indexes[i])
      enqueue(["set-band", String(index), Number(values[index]).toFixed(2)])
    }
  }

  function setPreamp(value) {
    var gain = Math.max(-12, Math.min(12, Number(value) || 0))
    state = {
      ready: state.ready,
      audioAvailable: state.audioAvailable,
      graphAvailable: state.graphAvailable,
      routed: state.routed,
      enabled: state.enabled,
      preset: state.preset,
      deviceName: state.deviceName,
      bands: state.bands,
      preamp: gain,
      auto: false,
      autoValue: state.autoValue
    }
    enqueue(["set-preamp", gain.toFixed(2)])
  }

  function applyPreset(name) {
    enqueue(["preset", "apply", String(name)])
  }

  Process {
    id: statusProcess
    command: [root.backendPath, "--json", "status"]

    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.parseResult(text, false)
    }
  }

  Process {
    id: mutationProcess

    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.parseResult(text, true)
    }

    onExited: {
      root.runNextMutation()
      if (!root.mutationProcess.running && root.pendingCommands.length === 0 && root.errorMessage !== "")
        root.refreshTimer.restart()
    }
  }

  Timer {
    id: bandDebounce
    interval: 90
    repeat: false
    onTriggered: root.flushBands()
  }

  Timer {
    id: refreshTimer
    interval: 280
    repeat: false
    onTriggered: root.refresh()
  }

  Timer {
    interval: 15000
    running: root.opened
    repeat: true
    onTriggered: root.refresh()
  }

  Component.onCompleted: refresh()

  KeyboardPanel {
    id: popup
    anchorItem: root.anchorItem
    owner: root.hostWidget || root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    // KeyboardPanel now positions the card from the actual EQ button and
    // clamps it to the screen edge for every bar orientation.
    centerOnBar: false
    contentWidth: popup.fittedContentWidth(Style.space(520), Style.space(620))
    contentHeight: popup.fittedContentHeight(panelColumn.implicitHeight + Style.spacing.panelPadding * 2, Style.space(root.advanced ? 760 : 660))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
    }

    BorderSurface {
      anchors.fill: parent
      color: Color.menu.background
      radius: Style.cornerRadius
      borderSpec: Border.surfaceSpec("menu", "border", Color.menu.border, Math.max(1, Style.space(2)))

      ScrollView {
        id: scrollArea
        anchors.fill: parent
        anchors.margins: Style.spacing.panelPadding
        clip: true
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        ScrollBar.vertical.policy: ScrollBar.AsNeeded

        Column {
          id: panelColumn
          width: scrollArea.availableWidth
          spacing: Style.spacing.md

          Item {
            width: parent.width
            implicitHeight: Math.max(headerCopy.implicitHeight, onOffButton.implicitHeight)

            Column {
              id: headerCopy
              anchors.left: parent.left
              anchors.right: onOffButton.left
              anchors.rightMargin: Style.spacing.md
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.spacing.xxs

              Text {
                text: "Equalizer"
                color: Color.menu.text
                font.family: Style.font.family
                font.pixelSize: Style.font.title
                font.bold: true
              }

              Text {
                width: parent.width
                text: root.state.deviceName
                color: Qt.rgba(Color.menu.text.r, Color.menu.text.g, Color.menu.text.b, 0.68)
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                elide: Text.ElideRight
              }
            }

            Button {
              id: onOffButton
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              text: root.state.enabled ? "ON" : "OFF"
              selected: root.state.enabled
              focusable: true
              onClicked: root.enqueue([root.state.enabled ? "disable" : "enable"])
            }
          }

          Text {
            width: parent.width
            text: root.errorMessage !== "" ? root.errorMessage : root.statusText
            color: root.errorMessage !== "" ? Color.urgent : Qt.rgba(Color.menu.text.r, Color.menu.text.g, Color.menu.text.b, 0.62)
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            elide: Text.ElideRight
          }

          PanelSeparator { foreground: Color.menu.text }

          BorderSurface {
            width: parent.width
            height: Style.space(92)
            color: Qt.rgba(Color.menu.text.r, Color.menu.text.g, Color.menu.text.b, 0.035)
            radius: Style.cornerRadius
            borderSpec: Border.controlSpec("normal", Color.menu.text, Color.accent)
            padding: Style.spacing.sm

            EqCurve {
              anchors.fill: parent
              gains: root.state.bands
            }
          }

          PanelSeparator { foreground: Color.menu.text }

          Row {
            id: bandsRow
            width: parent.width
            height: Style.space(184)
            spacing: Style.spacing.sm

            Repeater {
              model: 6

              delegate: EqBand {
                required property int index
                width: Math.max(1, (bandsRow.width - bandsRow.spacing * 5) / 6)
                height: bandsRow.height
                label: root.frequencies[index]
                value: root.state.bands[index] || 0
                onChanged: function(value) { root.setBand(index, value) }
              }
            }
          }

          PanelSeparator { foreground: Color.menu.text }

          Row {
            width: parent.width
            spacing: Style.spacing.md
            height: presetDropdown.implicitHeight

            Text {
              width: Style.space(68)
              text: "Preset"
              color: Color.menu.text
              font.family: Style.font.family
              font.pixelSize: Style.font.body
              anchors.verticalCenter: parent.verticalCenter
            }

            Dropdown {
              id: presetDropdown
              width: Math.max(Style.space(180), parent.width - Style.space(68) - parent.spacing)
              showLabel: false
              value: root.state.preset
              options: root.presetNames
              onChanged: root.applyPreset(value)
            }
          }

          Item {
            width: parent.width
            implicitHeight: Math.max(Style.spacing.controlHeight, preampSlider.implicitHeight, preampValue.implicitHeight, autoPreampButton.implicitHeight)

            Text {
              id: preampLabel
              width: Style.space(68)
              text: "Preamp"
              color: Color.menu.text
              font.family: Style.font.family
              font.pixelSize: Style.font.body
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
            }

            Button {
              id: autoPreampButton
              text: root.state.auto ? "AUTO" : "Auto"
              selected: root.state.auto
              focusable: true
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              onClicked: root.enqueue(["auto-preamp"])
            }

            Text {
              id: preampValue
              width: Style.space(66)
              text: (root.state.preamp >= 0 ? "+" : "") + Number(root.state.preamp).toFixed(1) + " dB"
              color: Color.menu.text
              font.family: Style.font.family
              font.pixelSize: Style.font.bodySmall
              horizontalAlignment: Text.AlignRight
              anchors.right: autoPreampButton.left
              anchors.rightMargin: Style.spacing.md
              anchors.verticalCenter: parent.verticalCenter
            }

            PanelSlider {
              id: preampSlider
              bar: root.bar
              minimum: -12
              maximum: 12
              step: 0.5
              value: root.state.preamp
              anchors.left: preampLabel.right
              anchors.leftMargin: Style.spacing.md
              anchors.right: preampValue.left
              anchors.rightMargin: Style.spacing.md
              anchors.verticalCenter: parent.verticalCenter
              onMoved: function(nextValue) { root.setPreamp(nextValue) }
            }
          }

          Item {
            width: parent.width
            implicitHeight: Math.max(abButton.implicitHeight, resetButton.implicitHeight, advancedButton.implicitHeight)

            Button {
              id: abButton
              text: "A/B"
              tooltipText: "A = bypassed · B = EQ active"
              focusable: true
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              onClicked: root.enqueue(["toggle"])
            }

            Button {
              id: resetButton
              text: "Reset"
              focusable: true
              anchors.left: abButton.right
              anchors.leftMargin: Style.spacing.sm
              anchors.verticalCenter: parent.verticalCenter
              onClicked: root.enqueue(["reset"])
            }

            Button {
              id: advancedButton
              text: root.advanced ? "Basic" : "Advanced"
              selected: root.advanced
              focusable: true
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              onClicked: root.advanced = !root.advanced
            }
          }

          Column {
            visible: root.advanced
            width: parent.width
            spacing: Style.spacing.sm

            TextField {
              id: userPresetName
              width: parent.width
              placeholderText: "User preset name"
            }

            Row {
              width: parent.width
              spacing: Style.spacing.sm

              Button {
                text: "Apply"
                focusable: true
                onClicked: if (userPresetName.text.trim() !== "") root.applyPreset(userPresetName.text.trim())
              }

              Button {
                text: "Save"
                focusable: true
                onClicked: if (userPresetName.text.trim() !== "") root.enqueue(["preset", "save", userPresetName.text.trim()])
              }

              Button {
                text: "Delete"
                focusable: true
                onClicked: if (userPresetName.text.trim() !== "") root.enqueue(["preset", "delete", userPresetName.text.trim()])
              }
            }

            Text {
              width: parent.width
              text: "Positive boosts are compensated conservatively."
              color: Qt.rgba(Color.menu.text.r, Color.menu.text.g, Color.menu.text.b, 0.58)
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              elide: Text.ElideRight
            }
          }
        }
      }
    }
  }
}
