import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Ui

// Teaches the words selected in a recent transcript, after MiniWhisper's
// quick add. Opens below its parent, or above when that would run off screen.
Popup {
  id: popup

  required property var panel
  readonly property real gap: Style.spacing.xxs
  property bool opensUp: false

  function teach(selection) {
    form.load(selection, "", "")
    open()
  }

  width: Style.space(320)
  padding: Style.space(12)
  focus: true
  y: opensUp ? -height - gap : parent.height + gap

  onAboutToShow: {
    var window = parent.Window.window
    var bottom = parent.mapToItem(null, 0, parent.height).y + gap + implicitHeight
    opensUp = window !== null && bottom > window.height - Style.gapsOut
  }
  onOpened: form.focusWord()

  background: BorderSurface {
    color: Color.popups.background
    borderSpec: Border.surfaceSpec("popups", "border", Color.popups.border, Style.normalBorderWidth)
    radius: Style.cornerRadius
  }

  contentItem: WordForm {
    id: form
    panel: popup.panel
    onSubmitted: popup.close()
    onCancelled: popup.close()
  }
}
