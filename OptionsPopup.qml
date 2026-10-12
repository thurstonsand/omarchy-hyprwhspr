import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Ui

// The kit Dropdown's option list, attached to its parent item. It opens
// upward when it would run off the bottom of the screen; the kit's always
// opens below. An option's `hint` shows as a tooltip on hover.
Popup {
  id: popup

  property var options: []
  property string value: ""
  property color foreground: Color.popups.text
  property color accent: Color.accent
  property string fontFamily: Style.font.family
  readonly property real gap: Style.spacing.xxs
  property bool opensUp: false

  signal picked(string value)

  function optionValue(o) { return (o && typeof o === "object") ? String(o.value) : String(o) }
  function optionLabel(o) { return (o && typeof o === "object") ? String(o.label) : String(o) }

  width: parent.width
  padding: Style.spacing.hairline + Style.normalBorderWidth
  y: opensUp ? -height - gap : parent.height + gap

  onAboutToShow: {
    var window = parent.Window.window
    var bottom = parent.mapToItem(null, 0, parent.height).y + gap + implicitHeight
    opensUp = window !== null && bottom > window.height - Style.gapsOut
  }

  background: BorderSurface {
    color: Color.popups.background
    borderSpec: Border.surfaceSpec("popups", "border", Color.popups.border, Style.normalBorderWidth)
    radius: Style.cornerRadius
  }

  contentItem: ListView {
    implicitHeight: contentHeight
    spacing: Style.spacing.labelGap
    interactive: false
    model: popup.options

    delegate: Rectangle {
      required property var modelData
      width: ListView.view.width
      height: Style.spacing.popupRowHeight
      color: row.containsMouse ? Style.hoverFillFor(popup.foreground, popup.accent) : "transparent"

      Text {
        anchors.fill: parent
        anchors.leftMargin: Style.spacing.controlPaddingX
        anchors.rightMargin: Style.spacing.controlPaddingX
        verticalAlignment: Text.AlignVCenter
        text: popup.optionLabel(modelData)
        color: popup.foreground
        font.family: popup.fontFamily
        font.pixelSize: Style.font.body
        font.bold: popup.optionValue(modelData) === popup.value
        elide: Text.ElideRight
      }

      MouseArea {
        id: row
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
          popup.picked(popup.optionValue(modelData))
          popup.close()
        }
      }

      PanelToolTip {
        visible: row.containsMouse && modelData.hint !== undefined
        text: modelData.hint || ""
        x: -width - Style.space(8)
        y: (parent.height - height) / 2
        fontFamily: popup.fontFamily
      }
    }
  }
}
