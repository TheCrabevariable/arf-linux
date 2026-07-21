import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

PanelWindow {
  id: root
  visible: false
  property var theme: DefaultTheme {}
  property string font: "Hack Nerd Font"

  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
  WlrLayershell.namespace: "quickshell-clipboard"
  exclusionMode: ExclusionMode.Ignore

  color: "transparent"

  anchors {
    top: true
    bottom: true
    left: true
    right: true
  }

  IpcHandler {
    target: "clipboard"
    function toggle(): void {
      root.visible = !root.visible
      if (root.visible) refreshClipboard()
    }
  }

  property var clipboardEntries: []
  property string searchText: ""
  property bool showSearch: false

  property var filteredEntries: {
    if (searchText.length === 0) return clipboardEntries
    return clipboardEntries.filter(e => e.text.toLowerCase().includes(searchText.toLowerCase()))
  }

  function refreshClipboard() {
    clipboardListProc.running = true
  }

  function copyEntry(entryId) {
    clipboardCopyProc.command = ["bash", "-c", "echo '" + entryId + "' | cliphist decode | wl-copy"]
    clipboardCopyProc.running = true
  }

  function deleteEntry(entryId) {
    clipboardDeleteProc.command = ["cliphist", "delete", entryId]
    clipboardDeleteProc.running = true
    refreshClipboard()
  }

  Timer {
    id: refreshTimer
    interval: 2000
    running: root.visible
    repeat: true
    onTriggered: {
      if (root.visible) root.refreshClipboard()
    }
  }

  Process {
    id: clipboardListProc
    command: ["cliphist", "list"]
    stdout: SplitParser {
      onRead: data => {
        const parts = data.split("\t")
        if (parts.length >= 2) {
          const entries = root.clipboardEntries.slice()
          entries.push({ id: parts[0].trim(), text: parts.slice(1).join("\t").trim() })
          root.clipboardEntries = entries
        }
      }
    }
    onRunningChanged: {
      if (running) root.clipboardEntries = []
    }
  }

  Process {
    id: clipboardCopyProc
    command: ["bash", "-c", ""]
    stdout: SplitParser {
      onRead: data => {}
    }
  }

  Process {
    id: clipboardDeleteProc
    command: ["cliphist", "delete", ""]
  }

  Process {
    id: clipboardClearProc
    command: ["cliphist", "wipe"]
    onRunningChanged: {
      if (!running) root.refreshClipboard()
    }
  }

  MouseArea {
    anchors.fill: parent
    onClicked: root.visible = false

    Rectangle {
      anchors.fill: parent
      color: theme.bgOverlay
    }
  }

  Rectangle {
    id: popupContent
    width: 400
    height: Math.min(600, headerRow.height + searchField.height + separator.height + clipboardList.height + 32)
    radius: 16
    color: theme.bgBase
    border.color: theme.bgBorder
    border.width: 1

    anchors.right: parent.right
    anchors.top: parent.top
    anchors.rightMargin: 16
    anchors.topMargin: 44

    ColumnLayout {
      id: mainCol
      anchors.fill: parent
      anchors.margins: 16
      spacing: 0

      // Header row
      RowLayout {
        id: headerRow
        Layout.fillWidth: true
        spacing: 8

        Text {
          text: "󰅗"
          color: theme.accentPrimary
          font.pixelSize: 16
          font.family: root.font
        }

        Text {
          text: "Clipboard"
          color: theme.accentPrimary
          font.pixelSize: 14
          font.family: root.font
          font.bold: true
          Layout.fillWidth: true
        }

        // Clear all button
        Rectangle {
          width: clearAllLabel.implicitWidth + 16
          height: 28
          radius: 6
          color: clearAllArea.containsMouse ? theme.accentRed : "transparent"
          border.color: theme.accentRed
          border.width: 1

          Text {
            id: clearAllLabel
            anchors.centerIn: parent
            text: "󰅖"
            color: clearAllArea.containsMouse ? theme.bgBase : theme.accentRed
            font.pixelSize: 14
            font.family: root.font
          }

          MouseArea {
            id: clearAllArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: clipboardClearProc.running = true
          }
        }
      }

      // Search field
      Rectangle {
        id: searchField
        Layout.fillWidth: true
        Layout.preferredHeight: 36
        Layout.topMargin: 8
        radius: 8
        color: theme.bgBase
        border.color: searchInput.activeFocus ? theme.accentPrimary : theme.bgBorder
        border.width: 1

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: 10
          anchors.rightMargin: 10
          spacing: 6

          Text {
            text: "󰍉"
            color: theme.textMuted
            font.pixelSize: 14
            font.family: root.font
          }

          TextInput {
            id: searchInput
            Layout.fillWidth: true
            color: theme.textPrimary
            font.pixelSize: 12
            font.family: root.font
            clip: true
            selectByMouse: true

            onTextChanged: root.searchText = text

            Text {
              text: "Search clipboard..."
              color: theme.textMuted
              font.pixelSize: 12
              font.family: root.font
              visible: searchInput.text.length === 0 && !searchInput.activeFocus
            }
          }
        }
      }

      // Separator
      Rectangle {
        id: separator
        Layout.fillWidth: true
        Layout.preferredHeight: 1
        Layout.topMargin: 12
        Layout.bottomMargin: 8
        color: theme.bgBorder
      }

      // Clipboard list
      ListView {
        id: clipboardList
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.preferredHeight: Math.min(root.filteredEntries.length * 42, 460)
        clip: true
        spacing: 2
        boundsBehavior: Flickable.StopAtBounds

        model: root.filteredEntries

        delegate: Rectangle {
          id: entryDelegate
          required property var modelData
          required property int index

          width: clipboardList.width
          height: 40
          radius: 8
          color: entryArea.containsMouse ? theme.bgHover : "transparent"

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 8
            spacing: 8

            Text {
              text: modelData.id
              color: theme.textMuted
              font.pixelSize: 10
              font.family: root.font
              Layout.preferredWidth: 32
              horizontalAlignment: Text.AlignRight
            }

            Text {
              text: modelData.text
              color: theme.textPrimary
              font.pixelSize: 12
              font.family: root.font
              elide: Text.ElideRight
              Layout.fillWidth: true
            }

            Rectangle {
              width: 24
              height: 24
              radius: 6
              color: deleteEntryArea.containsMouse ? theme.bgHover : "transparent"

              Text {
                anchors.centerIn: parent
                text: "󰅖"
                color: theme.textSecondary
                font.pixelSize: 12
                font.family: root.font
              }

              MouseArea {
                id: deleteEntryArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.deleteEntry(entryDelegate.modelData.id)
              }
            }
          }

          MouseArea {
            id: entryArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.copyEntry(entryDelegate.modelData.id)
          }
        }

        // Empty state
        Text {
          anchors.centerIn: parent
          text: "Clipboard is empty"
          color: theme.textMuted
          font.pixelSize: 13
          font.family: root.font
          visible: clipboardList.count === 0
        }

        // Scrollbar
        Rectangle {
          anchors.right: parent.right
          anchors.top: parent.top
          anchors.bottom: parent.bottom
          width: 4
          radius: 2
          color: theme.bgBorder
          visible: clipboardList.contentHeight > clipboardList.height
        }
      }
    }
  }
}
