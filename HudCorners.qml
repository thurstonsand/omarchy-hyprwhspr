import QtQuick
import qs.Commons

// YoRHa-style corner brackets drawn inside the panel edge.
Item {
  id: root

  property color color: Color.accent
  property real arm: Style.space(12)
  property real thickness: Math.max(1, Style.space(1))

  Repeater {
    model: [[0, 0], [1, 0], [0, 1], [1, 1]]

    Item {
      required property var modelData
      x: modelData[0] ? root.width - root.arm : 0
      y: modelData[1] ? root.height - root.arm : 0
      width: root.arm
      height: root.arm

      Rectangle {
        y: modelData[1] ? parent.height - height : 0
        width: parent.width
        height: root.thickness
        color: root.color
      }

      Rectangle {
        x: modelData[0] ? parent.width - width : 0
        width: root.thickness
        height: parent.height
        color: root.color
      }
    }
  }
}
