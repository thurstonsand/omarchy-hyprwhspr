import QtQuick
import qs.Commons
import qs.Ui

// A word, and optionally what the model mishears it as. The same spelling
// in both, ignoring case, is a plain vocabulary word.
Column {
  id: form

  required property var panel
  property string editingKey: ""
  property bool misheardOpen: false
  readonly property Item input: wordField
  property alias word: wordField.text
  property alias misheard: misheardField.text
  readonly property bool valid: wordField.text.trim() !== ""

  signal submitted()
  signal cancelled()

  function load(word, misheard, key) {
    wordField.text = word
    misheardField.text = misheard
    misheardOpen = misheard !== ""
    editingKey = key
    focusWord()
  }

  function focusWord() {
    wordField.forceActiveFocus()
    wordField.selectAll()
  }

  function reset() {
    wordField.text = ""
    misheardField.text = ""
    misheardOpen = false
    editingKey = ""
  }

  function submit() {
    if (!valid) return
    panel.addWord(wordField.text, misheardField.text, editingKey)
    reset()
    submitted()
  }

  spacing: Style.space(6)

  Row {
    width: parent.width
    spacing: Style.space(8)

    TextField {
      id: wordField
      width: parent.width - addButton.width - parent.spacing
        - (cancelButton.visible ? cancelButton.width + parent.spacing : 0)
      placeholderText: "word or name"
      foreground: form.panel.fg
      font.family: form.panel.fontFamily
      onAccepted: form.submit()
      Keys.onEscapePressed: form.cancelled()
    }

    Button {
      id: addButton
      anchors.verticalCenter: wordField.verticalCenter
      text: form.editingKey ? "SAVE" : "ADD"
      bordered: true
      selected: enabled
      enabled: form.valid
      opacity: enabled ? 1 : 0.38
      foreground: form.panel.fg
      fontFamily: form.panel.fontFamily
      onClicked: form.submit()
    }

    Button {
      id: cancelButton
      anchors.verticalCenter: wordField.verticalCenter
      visible: form.editingKey !== ""
      text: "CANCEL"
      bordered: true
      foreground: form.panel.fg
      fontFamily: form.panel.fontFamily
      onClicked: form.reset()
    }
  }

  Text {
    text: (form.misheardOpen ? "󰅀" : "󰅂") + " misheard as" + (form.misheardOpen ? "" : "…")
    color: form.panel.dim
    font.family: form.panel.fontFamily
    font.pixelSize: Style.font.caption

    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      onClicked: {
        form.misheardOpen = !form.misheardOpen
        if (form.misheardOpen) misheardField.forceActiveFocus()
      }
    }
  }

  TextField {
    id: misheardField
    width: wordField.width
    visible: form.misheardOpen
    placeholderText: "what it writes instead (optional)"
    foreground: form.panel.fg
    font.family: form.panel.fontFamily
    onAccepted: form.submit()
    Keys.onEscapePressed: form.cancelled()
  }
}
