import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "thurstonsand.hyprwhspr"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root

  readonly property color fg: bar ? bar.foreground : Color.foreground
  readonly property color dim: Util.alpha(fg, 0.56)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property string runtimeDir: Quickshell.env("XDG_RUNTIME_DIR") + "/hyprwhspr"
  readonly property string configDir: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/hyprwhspr"
  readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/hyprwhspr"

  property string tab: "status"
  property var status: null
  property var backendProbes: ({})
  property var today: null

  // The panel's own settings, and the provider table they extend.
  property var settings: ({})
  property var builtinProviders: ({})
  readonly property var providers: Object.assign({}, builtinProviders, settings.providers || {})
  readonly property var cleanup: settings.cleanup || {}
  readonly property int autoHibernateMinutes: settings.auto_hibernate_minutes || 0
  property var cleanupRuns: []
  readonly property var lastCleanup: cleanupRuns.length ? cleanupRuns[cleanupRuns.length - 1] : null

  // Model tab: what hyprwhspr's config says vs what the user has staged.
  // xpu is outside upstream's device enum, but torch accepts it for Cohere.
  readonly property var localBackends: [
    { id: "cohere-transcribe", name: "Cohere Transcribe 03-2026", deviceKey: "cohere_transcribe_device", devices: ["auto", "cuda", "xpu", "cpu"] },
    { id: "onnx-asr", name: "Parakeet TDT 0.6B v3", deviceKey: "", devices: [] },
    { id: "faster-whisper", name: "faster-whisper", deviceKey: "faster_whisper_device", devices: ["auto", "cuda", "cpu"] }
  ]
  property var config: ({})
  property var committed: ({})
  property var staged: ({})
  readonly property var pendingKeys: diffKeys(committed, staged)

  // Words tab: hyprwhspr's word_overrides, misheard (lowercase) → word. A
  // vocabulary word maps to itself. Upstream's default applies while unset.
  readonly property var committedWords: config.word_overrides !== undefined ? config.word_overrides : { "hyper whisper": "hyprwhspr" }
  property var stagedWords: null
  readonly property var words: stagedWords || committedWords
  readonly property bool wordsPending: stagedWords !== null && JSON.stringify(stagedWords) !== JSON.stringify(committedWords)

  property var recent: []

  // Mic strip: instant level and spectrum of the default source.
  property real level: 0
  property real peak: 0
  readonly property int spectrumBars: 40
  property var spectrum: []
  property bool cavaMissing: false
  readonly property bool listening: opened && tab === "status"

  readonly property bool modelUnloaded: status !== null && status.unloaded
  readonly property bool modelActive: status !== null && status.state === "active" && !status.unloaded
  // From a reload or restart until the daemon reports the model loaded.
  property bool waking: false
  property bool loadingInBackground: false
  property real wakePulse: 0
  // Upstream's tray_state is written by its Waybar script, which isn't running.
  property bool recording: false
  readonly property string phase: waking ? "waking" : recording ? "recording" : modelUnloaded ? "hibernating" : "idle"

  function diffKeys(a, b) {
    var keys = []
    for (var k in b) if (b[k] !== a[k]) keys.push(k)
    return keys
  }

  function stage(key, value) {
    var next = Object.assign({}, staged)
    next[key] = value
    staged = next
  }

  function revert() { staged = Object.assign({}, committed) }

  function localBackend(id) {
    return localBackends.find(function(b) { return b.id === id }) || null
  }

  function stageBackend(backend) {
    stage("backend", backend.id)
    if (backend.devices.indexOf(staged.device) === -1) stage("device", backend.devices[0] || "")
  }

  function addWord(word, misheard, replacingKey) {
    var next = Object.assign({}, words)
    if (replacingKey) delete next[replacingKey]
    next[(misheard.trim() || word.trim()).toLowerCase()] = word.trim()
    stagedWords = next
  }

  function removeWord(key) {
    var next = Object.assign({}, words)
    delete next[key]
    stagedWords = next
  }

  // Upstream replaces entries one after another in file order, so longer
  // phrases go first and win over a word inside them.
  function orderedWords(map) {
    var ordered = {}
    Object.keys(map).sort(function(a, b) {
      return b.split(" ").length - a.split(" ").length || b.length - a.length || a.localeCompare(b)
    }).forEach(function(k) { ordered[k] = map[k] })
    return ordered
  }

  // hyprwhspr reads its config once at startup, so every change restarts it.
  function apply() {
    if (pendingKeys.length === 0 && !wordsPending) return
    var next = JSON.parse(JSON.stringify(config))
    if (pendingKeys.length > 0) {
      next.transcription_backend = staged.backend
      var backend = localBackend(staged.backend)
      if (backend && backend.deviceKey) next[backend.deviceKey] = staged.device
      next.recording_mode = staged.mode
      next.filter_filler_words = staged.fillers
      if (staged.language === "auto") delete next.language
      else next.language = staged.language
      committed = Object.assign({}, staged)
    }
    if (wordsPending) next.word_overrides = orderedWords(stagedWords)
    stagedWords = null
    configFile.setText(JSON.stringify(next, null, 2) + "\n")
    waking = true
    Quickshell.execDetached(["systemctl", "--user", "restart", "hyprwhspr"])
  }

  function readConfig(text) {
    if (text.trim() === "") return
    config = JSON.parse(text)
    var backend = localBackend(config.transcription_backend)
    var live = {
      backend: config.transcription_backend,
      device: backend && backend.deviceKey ? (config[backend.deviceKey] || "auto") : "",
      mode: config.recording_mode,
      fillers: config.filter_filler_words === true,
      language: config.language || "auto"
    }
    var wasClean = pendingKeys.length === 0
    committed = live
    if (wasClean) staged = Object.assign({}, live)
  }

  function saveSettings(mutate) {
    var next = JSON.parse(JSON.stringify(settings))
    mutate(next)
    settings = next
    settingsFile.setText(JSON.stringify(next, null, 2) + "\n")
  }

  function setCleanup(changes) {
    saveSettings(function(s) { s.cleanup = Object.assign(s.cleanup || {}, changes) })
  }

  function readCleanupRuns(text) {
    cleanupRuns = text.split("\n").filter(function(l) { return l.trim() !== "" }).map(JSON.parse)
  }

  function selectTab(next) {
    if (next !== tab) apply()
    tab = next
  }

  function sendControl(verb) {
    Quickshell.execDetached(["sh", "-c", "printf '%s' \"$1\" | timeout 1 tee \"$2\" >/dev/null", "sh", verb, runtimeDir + "/recording_control"])
  }

  function reload() {
    waking = true
    sendControl("model_reload")
  }

  function removeModels(id) {
    removeModelsProc.command = [bin("backends"), "remove", id]
    removeModelsProc.running = true
  }

  function removeProvider(id) {
    saveSettings(function(s) {
      delete s.providers[id]
      if (s.cleanup && s.cleanup.provider === id) Object.assign(s.cleanup, { provider: "", model: "", effort: "" })
    })
    Quickshell.execDetached(["rm", "-f", configDir + "/keys/" + id])
  }

  // hyprwhspr refuses to record while unloaded, so a press wakes it instead.
  function wake() { reload() }

  function onJournalLine(line) {
    // restart() would also start a timer its binding holds off.
    if (line.indexOf("Recording started") !== -1) {
      waking = false
      recording = true
      if (hibernateTimer.running) hibernateTimer.restart()
    }
    else if (line.indexOf("Recording stopped") !== -1 || line.indexOf("Recording cancelled") !== -1) recording = false
    else if (line.indexOf("Recording blocked: model is unloaded") !== -1) wake()
    // Slow backends announce a background load before "hyprwhspr ready";
    // the rest load before it.
    else if (line.indexOf("[INIT] Loading model in background") !== -1) { waking = true; loadingInBackground = true }
    else if (line.indexOf("[READY] hyprwhspr ready") !== -1) { if (!loadingInBackground) waking = false }
    else if (line.indexOf("[READY] Model ready") !== -1 || line.indexOf("Model reloaded successfully") !== -1
             || line.indexOf("[MODEL] ERROR") !== -1 || line.indexOf("Failed to initialize backend") !== -1) {
      waking = false
      loadingInBackground = false
      statusSoon.restart()
    }
    else if (line.indexOf("[MODEL] Reloading model") !== -1) waking = true
    else if (line.indexOf("Injection dispatched") !== -1) {
      todayProc.running = true
      cleanupLog.reload()
      recentFile.reload()
    }
    else if (line.indexOf("[MODEL]") !== -1) statusSoon.restart()
  }

  function dbText(level) {
    // audio_level is the daemon's display scale: raw RMS × 10, clamped to 1.
    var db = 20 * Math.log(Math.max(level / 10, 0.00001)) / Math.LN10
    return Math.round(db) + " dB"
  }

  function gib(bytes) { return (bytes / 1073741824).toFixed(1) + " G" }

  function readStatus(text) {
    if (text.trim() === "") return
    status = JSON.parse(text)
    if (status.state !== "active") { waking = false; recording = false }
  }

  function bin(name) { return String(Qt.resolvedUrl("bin/" + name)).replace("file://", "") }

  function open() { root.controller.show() }
  function close() { root.controller.hide() }
  function toggle() { root.opened ? root.close() : root.open() }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.barIdentity, direction)
    return false
  }

  onOpenedChanged: {
    if (opened) {
      backendsProc.running = true
      todayProc.running = true
      recentFile.reload()
    } else apply()
  }

  Component.onCompleted: statusProc.running = true

  IpcHandler {
    target: "hyprwhspr"

    function show(name: string): void {
      root.selectTab(name)
      root.open()
    }
  }

  FileView {
    path: Qt.resolvedUrl("share/providers.json")
    printErrors: false
    onLoaded: root.builtinProviders = JSON.parse(text())
  }

  // Written in place: the file may be a symlink into a dotfiles repo.
  FileView {
    id: settingsFile
    path: root.configDir + "/panel.json"
    watchChanges: true
    atomicWrites: false
    printErrors: false
    onLoaded: if (text().trim() !== "") root.settings = JSON.parse(text())
    onFileChanged: reload()
  }

  FileView {
    id: configFile
    path: root.configDir + "/config.json"
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onLoaded: root.readConfig(text())
    onFileChanged: reload()
  }

  FileView {
    id: recentFile
    path: root.runtimeDir + "/recent.json"
    watchChanges: true
    printErrors: false
    onLoaded: root.recent = text().trim() === "" ? [] : JSON.parse(text())
    onFileChanged: reload()
  }

  FileView {
    id: cleanupLog
    path: root.stateDir + "/cleanup.jsonl"
    watchChanges: true
    printErrors: false
    onLoaded: root.readCleanupRuns(text())
    onFileChanged: reload()
  }

  Process {
    id: statusProc
    command: [root.bin("status")]
    stdout: StdioCollector { onStreamFinished: root.readStatus(text) }
  }

  // The unloaded marker file trails the log line slightly.
  Timer {
    id: statusSoon
    interval: 750
    onTriggered: statusProc.running = true
  }

  Timer {
    interval: 5000
    repeat: true
    triggeredOnStart: true
    running: root.opened
    onTriggered: statusProc.running = true
  }

  Process {
    id: removeModelsProc
    command: []
    onExited: backendsProc.running = true
  }

  SequentialAnimation on wakePulse {
    running: root.waking
    loops: Animation.Infinite
    onRunningChanged: if (!running) root.wakePulse = 0
    NumberAnimation { to: 1; duration: 650; easing.type: Easing.InOutSine }
    NumberAnimation { to: 0; duration: 650; easing.type: Easing.InOutSine }
  }

  Process {
    id: backendsProc
    command: [root.bin("backends")]
    stdout: StdioCollector { onStreamFinished: if (text.trim() !== "") root.backendProbes = JSON.parse(text) }
  }

  Process {
    id: todayProc
    command: [root.bin("today")]
    running: true
    stdout: StdioCollector { onStreamFinished: if (text.trim() !== "") root.today = JSON.parse(text) }
  }

  // Follows the daemon for the whole session, panel open or not: it drives
  // auto-hibernate, wake-on-press, and the counters.
  Process {
    command: ["journalctl", "--user", "-u", "hyprwhspr", "-f", "-n0", "-o", "cat"]
    running: true
    stdout: SplitParser { onRead: function(line) { root.onJournalLine(line) } }
  }

  Timer {
    id: hibernateTimer
    interval: root.autoHibernateMinutes * 60000
    running: root.autoHibernateMinutes > 0 && root.modelActive
    onTriggered: root.sendControl("model_unload")
  }

  Process {
    id: meter
    command: [root.bin("meter")]
    running: root.listening
    onRunningChanged: if (!running) { root.level = 0; root.peak = 0 }
    stdout: SplitParser {
      onRead: function(line) {
        root.level = Number(line) || 0
        root.peak = Math.max(root.peak * 0.97, root.level)
      }
    }
  }

  Process {
    id: spectrumProc
    command: [root.bin("spectrum"), String(root.spectrumBars)]
    running: root.listening && !root.cavaMissing
    onRunningChanged: if (!running) root.spectrum = []
    onExited: function(code) { if (code === 127) root.cavaMissing = true }
    stdout: SplitParser {
      onRead: function(line) {
        root.spectrum = line.trim().split(" ").map(function(v) { return Number(v) / 1000 })
      }
    }
  }

  function installCava() {
    Quickshell.execDetached(["omarchy-launch-floating-terminal-with-presentation", "omarchy-pkg-add cava"])
    root.cavaMissing = false
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    focusTarget: root.tab === "words" ? wordsPage.focusItem : keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(480))
    contentHeight: panel.fittedContentHeight(content.implicitHeight + content.anchors.margins * 2)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      HudCorners {
        anchors.fill: parent
        color: Color.accent
      }

      Column {
        id: content
        anchors.fill: parent
        anchors.margins: Style.space(16)
        spacing: Style.space(12)

        Item {
          width: parent.width
          height: Math.max(title.implicitHeight, power.implicitHeight)

          Button {
            id: power
            anchors.verticalCenter: title.verticalCenter
            width: height
            iconText: "󰐥"
            iconSize: Math.round(Style.font.title * 1.6)
            foreground: root.waking ? Util.alpha(root.fg, 0.35 + 0.65 * root.wakePulse)
              : root.modelActive ? root.fg : root.dim
            fontFamily: root.fontFamily
            tooltipText: (root.waking ? "Waking the model…" : root.modelActive ? "Hibernate the model" : "Wake the model")
              + " · right-click: auto-hibernate ("
              + (root.autoHibernateMinutes > 0 ? root.autoHibernateMinutes + " min idle" : "never") + ")"
            onClicked: if (!root.waking) root.modelActive ? root.sendControl("model_unload") : root.reload()
            onRightClicked: hibernateMenu.opened ? hibernateMenu.close() : hibernateMenu.open()

            OptionsPopup {
              id: hibernateMenu
              width: Style.space(170)
              value: String(root.autoHibernateMinutes)
              options: [
                { value: "0", label: "never auto-hibernate" },
                { value: "10", label: "after 10 min idle" },
                { value: "30", label: "after 30 min idle" },
                { value: "120", label: "after 2 h idle" }
              ]
              foreground: root.fg
              fontFamily: root.fontFamily
              onPicked: function(value) { root.saveSettings(function(s) { s.auto_hibernate_minutes = Number(value) }) }
            }
          }

          Text {
            id: title
            anchors.left: power.right
            anchors.leftMargin: Style.space(8)
            text: "hyprwhspr"
            color: Color.accent
            font.family: root.fontFamily
            font.pixelSize: Style.font.title
            font.letterSpacing: Style.space(6)
          }

          Text {
            anchors.right: parent.right
            anchors.baseline: title.baseline
            text: root.status ? "v" + root.status.version : ""
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }
        }

        Segmented {
          width: parent.width
          value: root.tab
          foreground: root.fg
          fontFamily: root.fontFamily
          options: [
            { value: "status", label: "STATUS" },
            { value: "model", label: "MODEL" + (root.pendingKeys.length ? " •" : "") },
            { value: "words", label: "WORDS" + (root.wordsPending ? " •" : "") },
            { value: "cleanup", label: "CLEANUP" }
          ]
          onChanged: function(value) { root.selectTab(value) }
        }

        // Every page stays laid out so the panel is as tall as the tallest
        // one and keeps its size across tabs.
        Item {
          width: parent.width
          height: Math.max(statusPage.implicitHeight, modelPage.implicitHeight, wordsPage.implicitHeight, cleanupPage.implicitHeight)

          StatusPage {
            id: statusPage
            width: parent.width
            panel: root
            opacity: root.tab === "status" ? 1 : 0
            enabled: opacity === 1
          }

          ModelPage {
            id: modelPage
            width: parent.width
            panel: root
            opacity: root.tab === "model" ? 1 : 0
            enabled: opacity === 1
          }

          // Its list fills whatever height the other pages leave it.
          WordsPage {
            id: wordsPage
            width: parent.width
            height: parent.height
            panel: root
            opacity: root.tab === "words" ? 1 : 0
            enabled: opacity === 1
          }

          CleanupPage {
            id: cleanupPage
            width: parent.width
            panel: root
            opacity: root.tab === "cleanup" ? 1 : 0
            enabled: opacity === 1
          }
        }
      }
    }
  }
}
