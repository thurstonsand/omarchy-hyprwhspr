import QtQuick
import qs.Commons
import qs.Ui

// Live spectrum and level of the default source, captured while the status
// page is open, independent of the daemon.
Rectangle {
  id: strip

  required property var panel
  readonly property real current: panel.level
  // cava's auto-gain inflates silence into full bars, so the loudness
  // fades them in.
  readonly property real presence: Math.min(1, 0.15 + Math.sqrt(current) * 1.6)
  readonly property int segments: 16

  implicitHeight: body.implicitHeight + Style.space(20)
  color: "transparent"
  border.color: Util.alpha(panel.fg, 0.3)
  border.width: 1

  Column {
    id: body
    anchors.fill: parent
    anchors.margins: Style.space(10)
    spacing: Style.space(8)

    Row {
      spacing: Style.space(8)

      Text {
        text: "MIC"
        color: strip.panel.fg
        font.family: strip.panel.fontFamily
        font.pixelSize: Style.font.caption
        font.letterSpacing: Style.space(2)
      }

      Text {
        width: strip.width - Style.space(80)
        text: strip.panel.status ? strip.panel.status.mic : ""
        elide: Text.ElideRight
        color: strip.panel.dim
        font.family: strip.panel.fontFamily
        font.pixelSize: Style.font.caption
      }
    }

    Item {
      id: wave
      width: parent.width
      height: Style.space(72)

      Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: 1
        color: Util.alpha(strip.panel.fg, 0.15)
      }

      Row {
        anchors.fill: parent
        spacing: 0
        visible: !strip.panel.cavaMissing

        Repeater {
          model: strip.panel.spectrumBars

          Item {
            required property int index
            readonly property real band: strip.panel.spectrum[index] || 0
            width: wave.width / strip.panel.spectrumBars
            height: wave.height

            Rectangle {
              anchors.centerIn: parent
              width: Math.max(1, parent.width * 0.6)
              height: Math.max(1, wave.height * band)
              color: strip.panel.fg
              opacity: strip.presence
            }
          }
        }
      }

      Button {
        anchors.centerIn: parent
        visible: strip.panel.cavaMissing
        text: "INSTALL CAVA FOR THE SPECTRUM"
        bordered: true
        foreground: strip.panel.fg
        fontFamily: strip.panel.fontFamily
        onClicked: strip.panel.installCava()
      }
    }

    Row {
      spacing: Style.space(10)

      Row {
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(2)

        Repeater {
          model: strip.segments

          Rectangle {
            required property int index
            readonly property real threshold: (index + 1) / strip.segments
            width: Style.space(8)
            height: Style.space(8)
            color: Math.sqrt(strip.current) >= threshold
              ? (index >= strip.segments - 2 ? Color.urgent : strip.panel.fg)
              : Util.alpha(strip.panel.fg, 0.15)
            border.width: Math.abs(Math.sqrt(strip.panel.peak) - threshold) < 0.5 / strip.segments ? 1 : 0
            border.color: strip.panel.fg
          }
        }
      }

      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: "level " + strip.panel.dbText(strip.current) + " · peak " + strip.panel.dbText(strip.panel.peak)
        color: strip.panel.dim
        font.family: strip.panel.fontFamily
        font.pixelSize: Style.font.caption
      }
    }
  }
}
