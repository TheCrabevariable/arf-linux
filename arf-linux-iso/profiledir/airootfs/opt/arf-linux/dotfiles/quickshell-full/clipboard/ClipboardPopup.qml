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
      if (root.visible) loadEntries()
    }
  }

  property var entries: []
  property string searchText: ""

  property var filteredEntries: {
    if (searchText.length === 0) return entries
    return entries.filter(e => e.text.toLowerCase().includes(searchText.toLowerCase()))
  }

  function loadEntries() {
    entries = []
    decodeAllProc.running = true
  }

  function copyEntry(entryId, entryText) {
    copyProc.command = ["bash", "-c", "printf '%s' '" + entryId + "' | cliphist decode | wl-copy"]
    copyProc.running = true
    notifyProc.command = ["notify-send", "-a", "Clipboard", "-i", "edit-copy", "Copied to clipboard", entryText.substring(0, 80)]
    notifyProc.running = true
  }

  function deleteEntry(entryId) {
    delProc.command = ["cliphist", "delete", entryId]
    delProc.running = true
    loadEntries()
  }

  Process {
    id: decodeAllProc
    command: ["bash", "-c", "rm -f /tmp/cliphist-preview-*.png 2>/dev/null; cliphist list | while IFS= read -r line; do id=$(echo \"$line\" | cut -f1); printf '%s' \"$id\" | cliphist decode > /tmp/cliphist-preview-$id.png 2>/dev/null; done; cliphist list"]
    stdout: SplitParser {
      onRead: data => {
        var idx = data.indexOf("\t")
        if (idx < 0) return
        var id = data.substring(0, idx).trim()
        var text = data.substring(idx + 1).trim()
        var isImage = text.includes("binary data")
        var e = root.entries.slice()
        e.push({
          id: id,
          text: text,
          imagePath: isImage ? "file:///tmp/cliphist-preview-" + id + ".png" : ""
        })
        root.entries = e
      }
    }
  }

  Process {
    id: copyProc
    command: ["bash", "-c", "echo hi | cliphist decode | wl-copy"]
  }

  Process {
    id: delProc
    command: ["bash", "-c", "echo hi | cliphist delete"]
  }

  Process {
    id: notifyProc
    command: ["notify-send", "-a", "Clipboard", "Copied to clipboard"]
  }

  Process {
    id: wipeProc
    command: ["cliphist", "wipe"]
    onRunningChanged: { if (!running) root.loadEntries() }
  }

  Timer {
    interval: 3000
    running: root.visible
    repeat: true
    onTriggered: root.loadEntries()
  }

  MouseArea {
    anchors.fill: parent
    onClicked: root.visible = false
    Rectangle { anchors.fill: parent; color: theme.bgOverlay }
  }

  Rectangle {
    id: popupContent
    width: 400
    height: Math.min(600, headerCol.implicitHeight + 32)
    radius: 16
    color: theme.bgBase
    border.color: theme.bgBorder
    border.width: 1

    anchors.right: parent.right
    anchors.top: parent.top
    anchors.rightMargin: 16
    anchors.topMargin: 44

    ColumnLayout {
      id: headerCol
      anchors.fill: parent
      anchors.margins: 16
      spacing: 0

      // Header
      RowLayout {
        Layout.fillWidth: true
        spacing: 8

        Text {
          text: "󰅗"
          color: theme.accentOrange
          font.pixelSize: 18
          font.family: root.font
        }

        Text {
          text: "Clipboard"
          color: theme.textPrimary
          font.pixelSize: 14
          font.family: root.font
          font.bold: true
          Layout.fillWidth: true
        }

        Rectangle {
          width: 28; height: 28; radius: 8
          color: clearArea.containsMouse ? theme.bgHover : "transparent"

          Text {
            anchors.centerIn: parent
            text: "󰅖"
            color: clearArea.containsMouse ? theme.accentRed : theme.textSecondary
            font.pixelSize: 14
            font.family: root.font
          }

          MouseArea {
            id: clearArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: wipeProc.running = true
          }
        }
      }

      // Search
      Rectangle {
        Layout.fillWidth: true
        height: 32
        radius: 8
        color: theme.bgBase
        border.color: searchInput.activeFocus ? theme.accentOrange : theme.bgBorder
        border.width: 1

        TextInput {
          id: searchInput
          anchors.fill: parent
          anchors.margins: 8
          color: theme.textPrimary
          font.pixelSize: 12
          font.family: root.font
          clip: true
          onTextChanged: root.searchText = text

          Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: "Search..."
            color: theme.textMuted
            font.pixelSize: 12
            font.family: root.font
            visible: searchInput.text.length === 0 && !searchInput.activeFocus
          }
        }
      }

      // Separator
      Rectangle {
        Layout.fillWidth: true
        height: 1
        color: theme.bgBorder
        Layout.topMargin: 12
        Layout.bottomMargin: 12
      }

      // List
      ListView {
        id: clipList
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.preferredHeight: 400
        clip: true
        spacing: 4
        boundsBehavior: Flickable.StopAtBounds

        model: root.filteredEntries

        delegate: Rectangle {
          id: clipItem
          required property var modelData
          required property int index

          width: clipList.width
          height: modelData.imagePath !== "" ? 72 : 40
          radius: 8
          color: clipArea.containsMouse ? theme.bgHover : "transparent"

          // Image preview
          Image {
            id: thumbImage
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            width: 48
            height: 48
            source: modelData.imagePath || ""
            fillMode: Image.PreserveAspectFit
            visible: modelData.imagePath !== "" && status === Image.Ready
            asynchronous: true
            cache: false
          }

          // Text entry
          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: modelData.imagePath !== "" ? 68 : 12
            anchors.rightMargin: 8
            spacing: 8
            visible: modelData.imagePath === ""

            Text {
              text: "󰅗"
              color: theme.accentOrange
              font.pixelSize: 14
              font.family: root.font
            }

            Text {
              Layout.fillWidth: true
              text: modelData.text
              color: theme.textPrimary
              font.pixelSize: 12
              font.family: root.font
              elide: Text.ElideRight
            }
          }

          // Image entry text overlay
          ColumnLayout {
            anchors.left: thumbImage.visible ? thumbImage.right : parent.left
            anchors.leftMargin: thumbImage.visible ? 8 : 12
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            visible: modelData.imagePath !== ""

            Text {
              Layout.fillWidth: true
              text: "Screenshot"
              color: theme.textPrimary
              font.pixelSize: 12
              font.family: root.font
              font.bold: true
              elide: Text.ElideRight
            }

            Text {
              Layout.fillWidth: true
              text: modelData.text
              color: theme.textMuted
              font.pixelSize: 10
              font.family: root.font
              elide: Text.ElideRight
            }
          }

          // Delete button
          Rectangle {
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            width: 24; height: 24; radius: 6
            color: delArea.containsMouse ? theme.bgHover : "transparent"
            visible: clipArea.containsMouse

            Text {
              anchors.centerIn: parent
              text: "󰅖"
              color: theme.textMuted
              font.pixelSize: 12
              font.family: root.font
            }

            MouseArea {
              id: delArea
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.deleteEntry(modelData.id)
            }
          }

          MouseArea {
            id: clipArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.copyEntry(modelData.id, modelData.text)
          }
        }

        Text {
          anchors.centerIn: parent
          text: "  Clipboard is empty"
          color: theme.textMuted
          font.pixelSize: 13
          font.family: root.font
          visible: clipList.count === 0
        }
      }
    }
  }
}
