import QtQuick
import qs.Commons
import qs.Ui

// The kit Dropdown's trigger, opening an OptionsPopup.
Item {
  id: root

  property string value: ""
  property var options: []
  property string placeholder: ""
  property color foreground: Color.popups.text
  property color accent: Color.accent
  property string fontFamily: Style.font.family

  signal changed(string value)

  function currentLabel() {
    for (var i = 0; i < options.length; i++)
      if (popup.optionValue(options[i]) === value) return popup.optionLabel(options[i])
    return value
  }

  implicitWidth: Style.spacing.dropdownWidth
  implicitHeight: Style.spacing.controlHeight

  BorderSurface {
    id: trigger
    anchors.fill: parent
    radius: Style.cornerRadius

    readonly property bool _hot: triggerHover.hovered || popup.opened
    color: Style.controlFill(false, trigger._hot, root.foreground, root.accent)
    borderSpec: Border.controlSpec(trigger._hot ? "hover-cursor" : "normal", root.foreground, root.accent)

    HoverHandler { id: triggerHover }

    Text {
      anchors.left: parent.left
      anchors.right: chevron.left
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: trigger.borderLeft + Style.spacing.controlPaddingX
      anchors.rightMargin: Style.spacing.md
      text: root.value !== "" ? root.currentLabel() : root.placeholder
      color: root.value !== "" ? root.foreground : Qt.darker(root.foreground, 1.6)
      font.family: root.fontFamily
      font.pixelSize: Style.font.body
      elide: Text.ElideRight
    }

    Text {
      id: chevron
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.rightMargin: trigger.borderRight + Style.spacing.controlGap
      text: popup.opensUp ? "󰅃" : "󰅀"
      color: Qt.darker(root.foreground, 1.2)
      font.family: root.fontFamily
      font.pixelSize: Style.font.body
    }

    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      onClicked: popup.opened ? popup.close() : popup.open()
    }
  }

  OptionsPopup {
    id: popup
    options: root.options
    value: root.value
    foreground: root.foreground
    accent: root.accent
    fontFamily: root.fontFamily
    // The caller updates its source of truth, which keeps `value` bound.
    onPicked: function(value) { root.changed(value) }
  }
}
