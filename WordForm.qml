import QtQuick
import qs.Commons
import qs.Ui

// A word, and optionally what the model mishears it as. Without a misheard
// spelling it is a plain vocabulary word.
Column {
  id: form

  required property var panel
  property string editingKey: ""
  readonly property Item input: wordField
  property alias word: wordField.text
  property alias misheard: misheardField.text
  readonly property bool valid: wordField.text.trim() !== ""

  signal submitted()
  signal cancelled()

  function load(word, misheard, key) {
    wordField.text = word
    misheardField.text = misheard
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

  TextField {
    id: misheardField
    width: wordField.width
    opacity: activeFocus || text !== "" ? 1 : 0.5
    placeholderText: "misheard as (optional)"
    foreground: form.panel.fg
    font.family: form.panel.fontFamily
    onAccepted: form.submit()
    Keys.onEscapePressed: form.cancelled()
  }
}
