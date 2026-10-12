import QtQuick
import qs.Commons
import qs.Ui

Item {
  id: page

  required property var panel
  // Sorted by word, so a word's corrections sit together. Upstream keeps
  // no timestamps, so there is no newest-first.
  readonly property var entries: Object.keys(panel.words).map(function(key) {
    var word = panel.words[key]
    return { key: key, word: word, misheard: key === word.toLowerCase() ? "" : key }
  }).sort(function(a, b) {
    return a.word.toLowerCase().localeCompare(b.word.toLowerCase()) || a.misheard.localeCompare(b.misheard)
  })
  readonly property int corrections: entries.filter(function(e) { return e.misheard !== "" }).length
  readonly property bool shown: panel.opened && panel.tab === "words"
  readonly property Item focusItem: form.input

  function plural(n, noun) { return n + " " + noun + (n === 1 ? "" : "s") }

  onShownChanged: if (shown) Qt.callLater(form.focusWord)

  implicitHeight: header.implicitHeight + Style.space(160)

  Column {
    id: header
    width: parent.width
    spacing: Style.space(10)

    WordForm {
      id: form
      width: parent.width
      panel: page.panel
      onCancelled: {
        if (word === "" && misheard === "") page.panel.close()
        else reset()
      }
    }

    Text {
      text: page.plural(page.entries.length - page.corrections, "word") + " · " + page.plural(page.corrections, "correction")
      color: page.panel.dim
      font.family: page.panel.fontFamily
      font.pixelSize: Style.font.caption
    }

    PanelSeparator { width: parent.width }
  }

  Text {
    anchors.top: header.bottom
    anchors.topMargin: Style.space(10)
    visible: page.entries.length === 0
    text: "no words yet"
    color: page.panel.dim
    font.family: page.panel.fontFamily
    font.pixelSize: Style.font.body
  }

  ListView {
    anchors.top: header.bottom
    anchors.topMargin: Style.space(6)
    anchors.bottom: parent.bottom
    width: parent.width
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    model: page.entries

    delegate: Rectangle {
      id: row
      required property var modelData
      width: ListView.view.width
      height: Style.spacing.popupRowHeight
      color: hover.containsMouse || form.editingKey === modelData.key
        ? Style.hoverFillFor(page.panel.fg, Color.accent) : "transparent"

      MouseArea {
        id: hover
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: form.load(row.modelData.word, row.modelData.misheard, row.modelData.key)
      }

      Row {
        anchors.left: parent.left
        anchors.leftMargin: Style.spacing.controlPaddingX
        anchors.right: trash.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(8)

        Text {
          visible: row.modelData.misheard !== ""
          text: row.modelData.misheard + "  →"
          color: page.panel.dim
          font.family: page.panel.fontFamily
          font.pixelSize: Style.font.body
        }

        Text {
          text: row.modelData.word
          color: page.panel.fg
          font.family: page.panel.fontFamily
          font.pixelSize: Style.font.body
        }
      }

      Button {
        id: trash
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        visible: hover.containsMouse || hot
        iconText: "󰆴"
        foreground: page.panel.dim
        fontFamily: page.panel.fontFamily
        tooltipText: "remove"
        onClicked: {
          if (form.editingKey === row.modelData.key) form.reset()
          page.panel.removeWord(row.modelData.key)
        }
      }
    }
  }
}
