import QtQuick
import QtQuick.Controls as QQC
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Column {
  id: page

  required property var panel
  readonly property var cleanup: panel.cleanup
  readonly property var provider: panel.providers[cleanup.provider] || null
  readonly property var last: panel.lastCleanup
  property var models: []
  property string modelsNote: ""
  property string loadedProvider: ""
  readonly property bool customProvider: !!cleanup.provider && !(cleanup.provider in panel.builtinProviders)
  readonly property var protocolNames: ({ messages: "anthropic messages", responses: "openai responses", chat: "openai chat" })

  // The custom provider form.
  property bool adding: false
  property string keyMode: "paste"
  property string protocol: "auto"
  property string addNote: ""

  function providerId(name) {
    var base = name.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "") || "custom"
    var id = base
    for (var n = 2; id in panel.providers; n++) id = base + "-" + n
    return id
  }

  function addProvider() {
    var id = providerId(nameField.text)
    addProc.label = nameField.text.trim()
    addProc.environment = {
      HYPRWHSPR_URL: urlField.text.trim(),
      HYPRWHSPR_KEY: keyMode === "paste" ? keyField.text.trim() : "",
      HYPRWHSPR_KEY_ENV: keyMode === "env" ? keyField.text.trim() : "",
      HYPRWHSPR_PROTOCOL: protocol === "auto" ? "" : protocol
    }
    addProc.command = [panel.bin("add-provider"), id]
    addNote = "detecting…"
    addProc.running = true
  }

  function finishAdding(id, entry) {
    entry.label = addProc.label
    panel.saveSettings(function(s) {
      s.providers = s.providers || {}
      s.providers[id] = entry
      s.cleanup = Object.assign(s.cleanup || {}, { provider: id, model: "", effort: "" })
    })
    stopAdding()
  }

  function stopAdding() {
    adding = false
    addNote = ""
    nameField.text = ""
    urlField.text = ""
    keyField.text = ""
  }

  function loadModels() {
    loadedProvider = cleanup.provider
    models = []
    modelsNote = "discovering…"
    modelsProc.command = [page.panel.bin("models"), cleanup.provider]
    modelsProc.running = true
  }

  onCleanupChanged: if (cleanup.provider && cleanup.provider !== loadedProvider) loadModels()

  Process {
    id: modelsProc
    command: []
    stdout: StdioCollector {
      onStreamFinished: {
        if (text.trim() === "") return
        page.models = JSON.parse(text)
        page.modelsNote = ""
      }
    }
    stderr: StdioCollector {
      onStreamFinished: {
        var lines = text.trim().split("\n")
        if (text.trim() !== "") page.modelsNote = "discovery failed: " + lines[lines.length - 1]
      }
    }
  }

  Process {
    id: addProc
    property string label: ""
    command: []
    stdout: StdioCollector {
      onStreamFinished: if (text.trim() !== "") page.finishAdding(addProc.command[1], JSON.parse(text))
    }
    stderr: StdioCollector {
      onStreamFinished: {
        var lines = text.trim().split("\n")
        if (text.trim() !== "") page.addNote = lines[lines.length - 1]
      }
    }
  }

  spacing: Style.space(10)

  FormRow {
    panel: page.panel
    label: "Enabled"

    ToggleSwitch {
      checked: page.cleanup.enabled === true
      foreground: page.panel.fg
      onToggled: page.panel.setCleanup({ enabled: !page.cleanup.enabled })
    }
  }

  Column {
    width: parent.width
    spacing: Style.space(10)
    enabled: page.cleanup.enabled === true
    opacity: enabled ? 1 : 0.38

    FormRow {
      panel: page.panel
      label: "Provider"

      Row {
        spacing: Style.space(10)

        Picker {
          width: Style.space(220)
          value: page.adding ? "+" : (page.cleanup.provider || "")
          placeholder: "pick a provider"
          options: Object.keys(page.panel.providers).map(function(id) {
            return { value: id, label: page.panel.providers[id].label }
          }).concat([{ value: "+", label: "+ custom provider…" }])
          foreground: page.panel.fg
          fontFamily: page.panel.fontFamily
          onChanged: function(value) {
            if (value === "+") page.adding = true
            else {
              page.stopAdding()
              page.panel.setCleanup({ provider: value, model: "", effort: "" })
            }
          }
        }

        // A second click within a few seconds confirms.
        Button {
          id: removeProvider
          property bool armed: false
          anchors.verticalCenter: parent.verticalCenter
          visible: page.customProvider && !page.adding
          iconText: armed ? "" : "󰆴"
          text: armed ? "remove?" : ""
          foreground: armed ? Color.urgent : page.panel.dim
          fontFamily: page.panel.fontFamily
          tooltipText: armed ? "" : "remove this provider"
          onClicked: {
            if (armed) page.panel.removeProvider(page.cleanup.provider)
            armed = !armed
          }

          Timer {
            running: removeProvider.armed
            interval: 3000
            onTriggered: removeProvider.armed = false
          }
        }
      }
    }

    Column {
      width: parent.width
      spacing: Style.space(10)
      visible: page.adding

      FormRow {
        panel: page.panel
        label: "Name"

        TextField {
          id: nameField
          width: Style.space(220)
          placeholderText: "OpenRouter"
          foreground: page.panel.fg
          font.family: page.panel.fontFamily
        }
      }

      FormRow {
        panel: page.panel
        label: "URL"

        TextField {
          id: urlField
          width: parent.width
          placeholderText: "https://openrouter.ai/api/v1"
          foreground: page.panel.fg
          font.family: page.panel.fontFamily
        }
      }

      FormRow {
        panel: page.panel
        label: "Key"

        Segmented {
          width: Style.space(260)
          value: page.keyMode
          options: [{ value: "paste", label: "paste" }, { value: "env", label: "env var" }, { value: "none", label: "none" }]
          foreground: page.panel.fg
          fontFamily: page.panel.fontFamily
          onChanged: function(value) { page.keyMode = value }
        }
      }

      FormRow {
        panel: page.panel
        visible: page.keyMode !== "none"

        TextField {
          id: keyField
          width: parent.width
          password: page.keyMode === "paste"
          placeholderText: page.keyMode === "paste" ? "saved to ~/.config/hyprwhspr/keys" : "set in hyprwhspr's service environment"
          foreground: page.panel.fg
          font.family: page.panel.fontFamily
        }
      }

      FormRow {
        panel: page.panel
        label: "API"

        Segmented {
          width: parent.width
          value: page.protocol
          options: [{ value: "auto", label: "detect" }, { value: "messages", label: "messages" },
                    { value: "responses", label: "responses" }, { value: "chat", label: "chat" }]
          foreground: page.panel.fg
          fontFamily: page.panel.fontFamily
          onChanged: function(value) { page.protocol = value }
        }
      }

      FormRow {
        panel: page.panel

        Row {
          spacing: Style.space(8)

          Button {
            text: "ADD"
            bordered: true
            selected: enabled
            enabled: !addProc.running && nameField.text.trim() !== "" && urlField.text.trim() !== ""
              && (page.keyMode === "none" || keyField.text.trim() !== "")
            opacity: enabled ? 1 : 0.38
            foreground: page.panel.fg
            fontFamily: page.panel.fontFamily
            onClicked: page.addProvider()
          }

          Button {
            text: "CANCEL"
            bordered: true
            foreground: page.panel.fg
            fontFamily: page.panel.fontFamily
            onClicked: page.stopAdding()
          }

          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: page.addNote
            color: page.panel.dim
            font.family: page.panel.fontFamily
            font.pixelSize: Style.font.caption
          }
        }
      }
    }

    Column {
      width: parent.width
      spacing: Style.space(10)
      visible: !page.adding

      FormRow {
        panel: page.panel
        label: "API"
        visible: page.provider !== null

        Text {
          text: page.provider ? page.protocolNames[page.provider.protocol] : ""
          color: page.panel.dim
          font.family: page.panel.fontFamily
          font.pixelSize: Style.font.body
        }
      }

      FormRow {
        panel: page.panel
        label: "Model"

        Row {
          spacing: Style.space(10)

          Picker {
            width: Style.space(220)
            value: page.cleanup.model || ""
            options: page.models
            placeholder: "pick a model"
            foreground: page.panel.fg
            fontFamily: page.panel.fontFamily
            onChanged: function(value) { page.panel.setCleanup({ model: value }) }
          }

          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: page.modelsNote
            color: page.panel.dim
            font.family: page.panel.fontFamily
            font.pixelSize: Style.font.caption
          }
        }
      }

      FormRow {
        panel: page.panel
        label: "Effort"
        // Only OpenAI-style APIs take a reasoning effort.
        enabled: page.provider !== null && page.provider.protocol !== "messages"
        opacity: enabled ? 1 : 0.38

        Segmented {
          width: Style.space(260)
          value: page.cleanup.effort || ""
          foreground: page.panel.fg
          fontFamily: page.panel.fontFamily
          options: [{ value: "", label: "default" }].concat(["low", "medium", "high"].map(function(e) { return { value: e, label: e } }))
          onChanged: function(value) { page.panel.setCleanup({ effort: value }) }
        }
      }

      FormRow {
        panel: page.panel
        label: "Timeout"

        Row {
          spacing: Style.space(8)

          TextField {
            width: Style.space(70)
            text: page.cleanup.timeout !== undefined ? String(page.cleanup.timeout) : ""
            // hyprwhspr kills the hook at 5 s; the rest is interpreter startup and logging.
            validator: DoubleValidator { bottom: 0.5; top: 4.5; decimals: 1; notation: DoubleValidator.StandardNotation }
            foreground: page.panel.fg
            font.family: page.panel.fontFamily
            onEditingFinished: if (acceptableInput) page.panel.setCleanup({ timeout: Number(text) })
          }

          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "s"
            color: page.panel.dim
            font.family: page.panel.fontFamily
            font.pixelSize: Style.font.body
          }
        }
      }

      PanelSeparator { width: parent.width }

      PanelSectionHeader {
        width: parent.width
        text: "YOUR PROMPT"
        foreground: page.panel.fg
        fontFamily: page.panel.fontFamily
      }

      QQC.TextArea {
        id: prompt
        width: parent.width
        height: Style.space(110)
        text: page.cleanup.prompt || ""
        wrapMode: TextEdit.Wrap
        placeholderText: "extra instructions for the cleanup model…"
        color: page.panel.fg
        placeholderTextColor: page.panel.dim
        selectionColor: Style.selectionFillFor(page.panel.fg, Color.accent)
        font.family: page.panel.fontFamily
        font.pixelSize: Style.font.body
        padding: Style.spacing.controlPaddingX
        onEditingFinished: if (text !== (page.cleanup.prompt || "")) page.panel.setCleanup({ prompt: text })

        readonly property var borderSpec: Border.controlSpec(activeFocus ? "focus" : (hovered ? "hover-cursor" : "normal"), page.panel.fg, Color.accent)
        background: BorderSurface {
          color: Style.controlFill(prompt.activeFocus, prompt.hovered, page.panel.fg, Color.accent)
          borderSpec: prompt.borderSpec
          radius: Style.cornerRadius
        }
      }

      Button {
        text: "open system prompt ↗"
        bordered: true
        foreground: page.panel.fg
        fontFamily: page.panel.fontFamily
        onClicked: {
          page.panel.close()
          // Seed the user's override from the shipped prompt on first open.
          Quickshell.execDetached(["sh", "-c", "[ -e \"$1\" ] || cp \"$2\" \"$1\"; exec omarchy-launch-editor \"$1\"", "sh",
            page.panel.configDir + "/system.md", String(Qt.resolvedUrl("share/system.md")).replace("file://", "")])
        }
      }
    }
  }

  PanelSeparator { width: parent.width }

  FormRow {
    panel: page.panel
    label: "Last run"

    Text {
      width: parent.width
      elide: Text.ElideRight
      text: !page.last ? "–"
        : page.last.error ? "failed · " + page.last.error
        : page.last.seconds.toFixed(2) + " s · " + page.last.chars_in + " → " + page.last.chars_out + " chars"
      color: page.panel.fg
      font.family: page.panel.fontFamily
      font.pixelSize: Style.font.body
    }
  }
}
