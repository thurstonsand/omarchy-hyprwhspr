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
    form.load(selection, selection, "")
    form.misheardOpen = true
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

  contentItem: Column {
    spacing: Style.space(8)

    WordForm {
      id: form
      width: parent.width
      panel: popup.panel
      onSubmitted: popup.close()
      onCancelled: popup.close()
    }

    Text {
      text: "same spelling saves a vocabulary word · ↵ add · esc cancel"
      color: popup.panel.dim
      font.family: popup.panel.fontFamily
      font.pixelSize: Style.font.caption
    }
  }
}
