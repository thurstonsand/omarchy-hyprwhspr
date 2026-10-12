import QtQuick
import qs.Commons

// Label on the left, control column at a fixed offset.
Item {
  id: row

  required property var panel
  property string label: ""
  default property alias control: slot.data

  width: parent ? parent.width : 0
  implicitHeight: Math.max(labelText.implicitHeight, slot.childrenRect.height)

  Text {
    id: labelText
    anchors.verticalCenter: parent.verticalCenter
    text: row.label
    color: row.panel.fg
    font.family: row.panel.fontFamily
    font.pixelSize: Style.font.body
  }

  Item {
    id: slot
    x: Style.space(130)
    width: row.width - x
    height: childrenRect.height
    anchors.verticalCenter: parent.verticalCenter
  }
}
