import QtQuick
import Quickshell
import qs.Commons
import qs.Ui

Column {
  id: page

  required property var panel
  readonly property var status: panel.status
  readonly property var memory: status ? status.memory : null
  readonly property real rowPadding: Style.space(4)

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
          ? [page.panel.committed.backend, page.panel.committed.device].filter(Boolean).join(" · ")
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

  // Rows never resize, so a click selects text where it lands; a long
  // transcript scrolls inside its row.
  Item {
    id: recentBox
    width: parent.width
    height: 3 * entryHeight + 2 * recentList.spacing
    readonly property real entryHeight: 2 * bodyMetrics.height + 2 * page.rowPadding

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

          width: recentList.width
          height: recentBox.entryHeight

          Rectangle {
            anchors.fill: parent
            color: rowHover.hovered ? Style.hoverFillFor(page.panel.fg, Color.accent) : "transparent"
          }

          HoverHandler { id: rowHover }

          Text {
            id: time
            x: page.rowPadding
            y: page.rowPadding
            text: Qt.formatTime(new Date(entry.modelData.ts * 1000), "hh:mm")
            color: page.panel.dim
            font.family: page.panel.fontFamily
            font.pixelSize: Style.font.body
          }

          Flickable {
            id: scroller
            anchors.left: time.right
            anchors.leftMargin: Style.space(10)
            anchors.right: copy.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.topMargin: page.rowPadding
            anchors.bottomMargin: page.rowPadding
            clip: true
            interactive: false
            contentHeight: body.contentHeight
            boundsBehavior: Flickable.StopAtBounds

            WheelHandler {
              onWheel: function(event) {
                scroller.contentY = Math.max(0, Math.min(scroller.contentHeight - scroller.height,
                                                         scroller.contentY - event.angleDelta.y / 2))
              }
            }

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
              onActiveFocusChanged: if (!activeFocus && !teach.visible) deselect()

              // Passive, so the TextEdit still makes the selection.
              PointHandler {
                onActiveChanged: if (!active && body.selectedText.trim() !== "") teach.teach(body.selectedText.trim())
              }
            }
          }

          TeachPopup {
            id: teach
            panel: page.panel
            onClosed: body.deselect()
          }

          Text {
            anchors.horizontalCenter: copy.horizontalCenter
            anchors.bottom: scroller.bottom
            visible: scroller.contentY + scroller.height < scroller.contentHeight - 1
            text: "…"
            color: page.panel.dim
            font.family: page.panel.fontFamily
            font.pixelSize: Style.font.body
          }

          Button {
            id: copy
            property bool copied: false
            anchors.right: parent.right
            anchors.rightMargin: page.rowPadding
            anchors.verticalCenter: parent.verticalCenter
            horizontalPadding: Style.space(4)
            verticalPadding: Style.space(2)
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
