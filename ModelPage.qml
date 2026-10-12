import QtQuick
import qs.Commons
import qs.Ui

Column {
  id: page

  required property var panel
  readonly property var staged: panel.staged
  // Verbatim from recording_mode's description in hyprwhspr's config.schema.json.
  readonly property var modes: [
    { value: "push_to_talk", label: "push to talk", hint: "hold to record" },
    { value: "toggle", label: "toggle", hint: "press to start/stop" },
    { value: "auto", label: "auto", hint: "hybrid tap/hold" },
    { value: "continuous", label: "continuous", hint: "keeps transcribing, auto-pastes on speech pause" },
    { value: "long_form", label: "long form", hint: "extended recording with pause/resume; requires long_form_submit_shortcut" }
  ]
  readonly property var selectedBackend: panel.localBackend(staged.backend)

  spacing: Style.space(8)

  PanelSectionHeader {
    width: parent.width
    text: "BACKEND"
    foreground: page.panel.fg
    fontFamily: page.panel.fontFamily
  }

  Column {
    width: parent.width
    spacing: Style.space(4)

    Repeater {
      model: page.panel.localBackends

      Button {
        id: backendButton
        required property var modelData
        readonly property var probe: page.panel.backendProbes[modelData.id] || null
        readonly property bool available: probe !== null && probe.installed
        readonly property bool inUse: page.panel.committed.backend === modelData.id
        width: parent.width
        leftAlign: true
        bordered: true
        selected: page.staged.backend === modelData.id
        enabled: available
        opacity: available ? 1 : 0.45
        foreground: page.panel.fg
        fontFamily: page.panel.fontFamily
        text: (selected ? "◉  " : "○  ") + modelData.name
        onClicked: page.panel.stageBackend(modelData)
        onRightClicked: modelMenu.opened ? modelMenu.close() : modelMenu.open()

        OptionsPopup {
          id: modelMenu
          width: Style.space(220)
          x: parent.width - width
          options: backendButton.inUse ? [{ value: "none", label: "in use · switch first" }]
            : backendButton.probe && backendButton.probe.size > 0
              ? [{ value: "remove", label: "remove " + page.panel.gib(backendButton.probe.size) }]
              : [{ value: "none", label: "nothing downloaded" }]
          foreground: page.panel.fg
          fontFamily: page.panel.fontFamily
          onPicked: function(value) { if (value === "remove") page.panel.removeModels(backendButton.modelData.id) }
        }

        Text {
          anchors.right: parent.right
          anchors.rightMargin: Style.spacing.controlPaddingX
          anchors.verticalCenter: parent.verticalCenter
          text: !parent.probe ? "" : !parent.available ? "not installed"
            : parent.probe.size > 0 ? page.panel.gib(parent.probe.size) : "downloads on apply"
          color: page.panel.dim
          font.family: page.panel.fontFamily
          font.pixelSize: Style.font.caption
        }
      }
    }
  }

  FormRow {
    panel: page.panel
    label: "Device"
    enabled: page.selectedBackend !== null && page.selectedBackend.devices.length > 0
    opacity: enabled ? 1 : 0.38

    Segmented {
      width: Style.space(260)
      value: page.staged.device || ""
      foreground: page.panel.fg
      fontFamily: page.panel.fontFamily
      options: ["auto", "cuda", "xpu", "cpu"].map(function(d) {
        return { value: d, label: d, enabled: page.selectedBackend !== null && page.selectedBackend.devices.indexOf(d) !== -1 }
      })
      onChanged: function(value) { page.panel.stage("device", value) }
    }
  }

  PanelSeparator { width: parent.width }

  PanelSectionHeader {
    width: parent.width
    text: "RECORDING"
    foreground: page.panel.fg
    fontFamily: page.panel.fontFamily
  }

  FormRow {
    panel: page.panel
    label: "Mode"

    Picker {
      width: Style.space(200)
      value: page.staged.mode || ""
      options: page.modes
      foreground: page.panel.fg
      fontFamily: page.panel.fontFamily
      onChanged: function(value) { page.panel.stage("mode", value) }
    }
  }

  FormRow {
    panel: page.panel
    label: "Strip fillers"

    ToggleSwitch {
      checked: page.staged.fillers === true
      foreground: page.panel.fg
      onToggled: page.panel.stage("fillers", !page.staged.fillers)
    }
  }

  FormRow {
    panel: page.panel
    label: "Language"

    Picker {
      width: Style.space(200)
      value: page.staged.language || ""
      options: ["auto", "en", "fr", "de", "es", "ja"]
      foreground: page.panel.fg
      fontFamily: page.panel.fontFamily
      onChanged: function(value) { page.panel.stage("language", value) }
    }
  }

  PanelSeparator { width: parent.width }

  Row {
    width: parent.width
    spacing: Style.space(8)

    Button {
      width: (parent.width - parent.spacing) * 2 / 3
      text: "APPLY NOW"
      bordered: true
      selected: page.panel.pendingKeys.length > 0
      enabled: page.panel.pendingKeys.length > 0
      opacity: enabled ? 1 : 0.38
      foreground: page.panel.fg
      fontFamily: page.panel.fontFamily
      onClicked: page.panel.apply()
    }

    Button {
      width: (parent.width - parent.spacing) / 3
      text: "REVERT"
      bordered: true
      enabled: page.panel.pendingKeys.length > 0
      opacity: enabled ? 1 : 0.38
      foreground: page.panel.fg
      fontFamily: page.panel.fontFamily
      onClicked: page.panel.revert()
    }
  }
}
