import QtQuick
import qs.Commons
import qs.Ui

// ButtonGroup with equal-width chips that fill the row.
Row {
  id: root

  property var options: []
  property string value: ""
  property color foreground: Color.foreground
  property string fontFamily: Style.font.family

  signal changed(string value)

  spacing: Style.space(6)

  Repeater {
    model: root.options

    Button {
      required property var modelData
      width: (root.width - root.spacing * (root.options.length - 1)) / root.options.length
      text: modelData.label
      selected: modelData.value === root.value
      enabled: modelData.enabled !== false
      opacity: enabled ? 1 : 0.38
      bordered: true
      focusable: true
      foreground: root.foreground
      fontFamily: root.fontFamily
      onClicked: root.changed(modelData.value)
    }
  }
}
