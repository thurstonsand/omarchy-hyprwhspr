import QtQuick
import Quickshell
import qs.Commons
import qs.Ui

Column {
  id: page

  required property var panel
  readonly property var status: panel.status
  readonly property var memory: status ? status.memory : null
  // The RECENT row shown in full, or -1.
  property int expanded: -1
  readonly property real rowPadding: Style.space(4)

  function collapsedHeight(lines) { return lines * bodyMetrics.height + 2 * rowPadding }

  Connections {
    target: page.panel
    function onRecentChanged() { page.expanded = -1 }
  }

  FontMetrics {
    id: bodyMetrics
    font.family: page.panel.fontFamily
    font.pixelSize: Style.font.body
  }

  spacing: Style.space(10)

  MicStrip {
    width: parent.width
    panel: page.panel
  }

  Row {
    spacing: Style.space(10)

    Rectangle {
      anchors.verticalCenter: parent.verticalCenter
      width: Style.space(9)
      height: width
      radius: width / 2
      color: page.status && page.status.state === "active" ? page.panel.fg : Color.urgent
    }

    Column {
      Text {
        text: page.status
          ? page.panel.committed.backend + " · " + page.panel.committed.device
          : "probing…"
        color: page.panel.fg
        font.family: page.panel.fontFamily
        font.pixelSize: Style.font.body
      }

      Text {
        text: page.status ? page.status.state + " · " + page.panel.phase : ""
        color: page.panel.dim
        font.family: page.panel.fontFamily
        font.pixelSize: Style.font.caption
      }
    }
  }

  PanelSeparator { width: parent.width }

  PanelSectionHeader {
    width: parent.width
    text: "MEMORY"
    foreground: page.panel.fg
    fontFamily: page.panel.fontFamily
  }

  Item {
    width: parent.width
    height: Style.space(14)

    Rectangle {
      anchors.fill: parent
      color: "transparent"
      border.color: Util.alpha(page.panel.fg, 0.3)
      border.width: 1
    }

    Row {
      anchors.fill: parent
      anchors.margins: 1

      Rectangle {
        height: parent.height
        width: page.memory ? parent.width * page.memory.service / page.memory.total : 0
        color: Util.alpha(page.panel.fg, 0.75)
      }

      Rectangle {
        height: parent.height
        width: page.memory ? parent.width * page.memory.gpu / page.memory.total : 0
        color: Util.alpha(page.panel.fg, 0.35)
      }
    }
  }

  Item {
    width: parent.width
    height: legend.implicitHeight

    Row {
      id: legend
      spacing: Style.space(14)

      Repeater {
        model: [
          { label: "service", key: "service", alpha: 0.75 },
          { label: "gpu", key: "gpu", alpha: 0.35 }
        ]

        Row {
          required property var modelData
          spacing: Style.space(6)

          Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: Style.space(9)
            height: width
            color: Util.alpha(page.panel.fg, modelData.alpha)
          }

          Text {
            text: modelData.label + " " + (page.memory ? page.panel.gib(page.memory[modelData.key]) : "–")
            color: page.panel.fg
            font.family: page.panel.fontFamily
            font.pixelSize: Style.font.caption
          }
        }
      }
    }

    Text {
      anchors.right: parent.right
      text: page.memory
        ? page.panel.gib(page.memory.service + page.memory.gpu) + " of " + page.panel.gib(page.memory.total)
          + " · " + page.panel.gib(page.memory.available) + " free"
        : ""
      color: page.panel.dim
      font.family: page.panel.fontFamily
      font.pixelSize: Style.font.caption
    }
  }

  PanelSeparator { width: parent.width }

  PanelSectionHeader {
    width: parent.width
    text: "RECENT"
    foreground: page.panel.fg
    fontFamily: page.panel.fontFamily
  }

  // A fixed height, so expanding a transcript never resizes the panel.
  Item {
    id: recentBox
    width: parent.width
    height: 3 * page.collapsedHeight(2) + 2 * recentList.spacing

    Text {
      visible: page.panel.recent.length === 0
      text: "nothing dictated since login"
      color: page.panel.dim
      font.family: page.panel.fontFamily
      font.pixelSize: Style.font.body
    }

    Column {
      id: recentList
      width: parent.width
      spacing: Style.space(6)

      Repeater {
        model: page.panel.recent

        Item {
          id: entry
          required property var modelData
          required property int index
          readonly property bool expanded: page.expanded === index
          readonly property int others: page.panel.recent.length - 1

          width: recentList.width
          height: expanded
            ? Math.min(recentBox.height - others * (page.collapsedHeight(1) + recentList.spacing),
                       body.contentHeight + 2 * page.rowPadding)
            : page.collapsedHeight(page.expanded >= 0 ? 1 : 2)

          Rectangle {
            anchors.fill: parent
            color: entry.expanded || rowHover.containsMouse ? Style.hoverFillFor(page.panel.fg, Color.accent) : "transparent"
          }

          MouseArea {
            id: rowHover
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: entry.expanded ? Qt.ArrowCursor : Qt.PointingHandCursor
            onClicked: page.expanded = entry.expanded ? -1 : entry.index
          }

          Text {
            id: time
            x: page.rowPadding
            y: page.rowPadding
            text: Qt.formatTime(new Date(entry.modelData.ts * 1000), "hh:mm")
            color: page.panel.dim
            font.family: page.panel.fontFamily
            font.pixelSize: Style.font.body
          }

          Text {
            anchors.left: time.right
            anchors.leftMargin: Style.space(10)
            anchors.right: copy.left
            y: page.rowPadding
            visible: !entry.expanded
            text: entry.modelData.text
            wrapMode: Text.Wrap
            maximumLineCount: page.expanded >= 0 ? 1 : 2
            elide: Text.ElideRight
            color: page.panel.fg
            font.family: page.panel.fontFamily
            font.pixelSize: Style.font.body
          }

          Flickable {
            anchors.left: time.right
            anchors.leftMargin: Style.space(10)
            anchors.right: copy.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.topMargin: page.rowPadding
            anchors.bottomMargin: page.rowPadding
            visible: entry.expanded
            clip: true
            contentHeight: body.contentHeight
            boundsBehavior: Flickable.StopAtBounds

            TextEdit {
              id: body
              width: parent.width
              text: entry.modelData.text
              readOnly: true
              selectByMouse: true
              wrapMode: TextEdit.Wrap
              color: page.panel.fg
              selectionColor: Style.selectionFillFor(page.panel.fg, Color.accent)
              selectedTextColor: page.panel.fg
              font.family: page.panel.fontFamily
              font.pixelSize: Style.font.body

              // Passive, so the TextEdit still makes the selection.
              PointHandler {
                onActiveChanged: if (!active && body.selectedText.trim() !== "") teach.teach(body.selectedText.trim())
              }
            }

            TeachPopup {
              id: teach
              panel: page.panel
              onClosed: body.deselect()
            }
          }

          Button {
            id: copy
            property bool copied: false
            anchors.right: parent.right
            y: page.rowPadding + (time.height - height) / 2
            iconText: copied ? "󰄬" : "󰆏"
            foreground: copied ? page.panel.fg : page.panel.dim
            fontFamily: page.panel.fontFamily
            tooltipText: "copy"
            onClicked: {
              Quickshell.execDetached(["wl-copy", "--", entry.modelData.text])
              copied = true
            }

            Timer {
              running: copy.copied
              interval: 1500
              onTriggered: copy.copied = false
            }
          }
        }
      }
    }
  }

  Text {
    text: "kept in memory until logout" + (page.panel.today ? " · " + page.panel.today.dictations + " today" : "")
    color: page.panel.dim
    font.family: page.panel.fontFamily
    font.pixelSize: Style.font.caption
  }
}
