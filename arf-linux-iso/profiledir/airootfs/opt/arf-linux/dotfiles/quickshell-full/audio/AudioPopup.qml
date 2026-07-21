import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Layouts

PanelWindow {
  id: root
  visible: false
  property var theme: DefaultTheme {}
  property string font: "Hack Nerd Font"

  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
  WlrLayershell.namespace: "quickshell-audio"
  exclusionMode: ExclusionMode.Ignore

  color: "transparent"

  anchors {
    top: true
    bottom: true
    left: true
    right: true
  }

  property real openX: -1

  IpcHandler {
    target: "audio"
    function toggle(): void {
      root.visible = !root.visible
      root.openX = -1
      if (root.visible) {
        refreshDevices()
      }
    }
    function openAt(x: number): void {
      root.openX = x
      root.visible = true
      refreshDevices()
    }
  }

  // --- Volume ---

  property var sink: Pipewire.defaultAudioSink
  property bool muted: sink && sink.audio ? sink.audio.muted : false
  property real volume: sink && sink.audio ? sink.audio.volume : 0

  PwObjectTracker {
    objects: root.sink ? [root.sink] : []
  }

  // --- Device List ---

  property var devices: []

  Component.onCompleted: refreshDevices()

  function refreshDevices() {
    deviceListProc.running = true
  }

  function setVolume(val) {
    if (!sink || !sink.audio) return
    sink.audio.volume = Math.max(0, Math.min(1.5, val))
  }

  function toggleMute() {
    if (!sink || !sink.audio) return
    sink.audio.muted = !sink.audio.muted
  }

  Process {
    id: deviceListProc
    command: ["wpctl", "status"]
    stdout: SplitParser {
      onRead: data => {
        root.devices = root.parseDevices(data)
      }
    }
  }

  function parseDevices(raw) {
    const lines = raw.split("\n")
    const result = []
    let inSinks = false
    let defaultId = ""

    for (let i = 0; i < lines.length; i++) {
      const line = lines[i]
      if (line.trim().startsWith("Sinks:")) {
        inSinks = true
        continue
      }
      if (inSinks && (line.trim().startsWith("Sources:") || (line.trim().startsWith("Sinks") && !line.trim().startsWith("Sinks:")))) {
        if (inSinks) break
      }
      if (inSinks && line.trim().length === 0) {
        inSinks = false
      }
      if (inSinks) {
        const isDefault = line.includes("*")
        const cleaned = line.replace("*", "").trim()
        const match = cleaned.match(/^(\d+)\.\s+(.+?)\s*\[(.+?)\]$/)
        if (!match) continue
        const id = match[1]
        const name = match[2].trim()
        const volMatch = match[3]
        const volNum = parseFloat(volMatch)
        if (isDefault) defaultId = id
        result.push({
          id: id,
          name: name,
          volume: isNaN(volNum) ? 0 : volNum,
          isDefault: isDefault
        })
      }
    }

    return result
  }

  function setDefaultDevice(id) {
    setDefaultProc.command = ["wpctl", "set-default", id]
    setDefaultProc.running = true
  }

  Process {
    id: setDefaultProc
    onRunningChanged: {
      if (!running) root.refreshDevices()
    }
  }

  // Click outside to close
  MouseArea {
    anchors.fill: parent
    onClicked: root.visible = false

    Rectangle {
      anchors.fill: parent
      color: theme.bgOverlay
    }
  }

  // Popup box
  Rectangle {
    id: popupContent
    width: 380
    height: Math.min(contentCol.implicitHeight + 32, 700)
    radius: 16
    color: theme.bgBase
    border.color: theme.bgBorder
    border.width: 1

    x: root.openX >= 0 ? Math.max(16, Math.min(root.width - width - 16, root.openX - width / 2)) : root.width - width - 16
    anchors.top: parent.top
    anchors.topMargin: 44

    ColumnLayout {
      id: contentCol
      anchors.fill: parent
      anchors.margins: 16
      spacing: 0

      // ======== HEADER ========

      RowLayout {
        Layout.fillWidth: true
        spacing: 8

        Text {
          text: "󰕾"
          color: root.muted ? theme.textMuted : theme.accentGreen
          font.pixelSize: 16
          font.family: root.font
        }

        Text {
          text: "Audio"
          color: theme.accentPrimary
          font.pixelSize: 14
          font.family: root.font
          font.bold: true
          Layout.fillWidth: true
        }

        // Mute toggle button
        Rectangle {
          width: 28; height: 28; radius: 8
          color: muteArea.containsMouse ? theme.bgHover : "transparent"

          Text {
            anchors.centerIn: parent
            text: root.muted ? "󰝟" : "󰕾"
            color: root.muted ? theme.accentRed : theme.textSecondary
            font.pixelSize: 14
            font.family: root.font
          }

          MouseArea {
            id: muteArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.toggleMute()
          }
        }
      }

      // ======== VOLUME SECTION ========

      // Large percentage text
      Text {
        text: Math.round(root.volume * 100) + "%"
        color: root.muted ? theme.textMuted : theme.textPrimary
        font.pixelSize: 32
        font.family: root.font
        font.bold: true
        Layout.topMargin: 12
      }

      // Volume slider area
      Item {
        Layout.fillWidth: true
        Layout.preferredHeight: 32
        Layout.topMargin: 8

        // Track background
        Rectangle {
          anchors.verticalCenter: parent.verticalCenter
          anchors.left: parent.left
          anchors.right: parent.right
          height: 8
          radius: 4
          color: theme.bgSurface

          // Filled portion
          Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            width: Math.min(parent.width, parent.width * root.volume / 1.5)
            height: 8
            radius: 4
            color: root.muted ? theme.textMuted : theme.accentPrimary
          }

          // Handle
          Rectangle {
            x: Math.min(parent.width - 8, parent.width * root.volume / 1.5 - 8)
            anchors.verticalCenter: parent.verticalCenter
            width: 16; height: 16; radius: 8
            color: root.muted ? theme.textMuted : theme.accentPrimary
          }
        }

        // Click to set volume
        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            const ratio = Math.max(0, Math.min(1, mouse.x / width))
            root.setVolume(ratio * 1.5)
          }

          // Scroll wheel to adjust volume
          onWheel: {
            const delta = wheel.angleDelta.y > 0 ? 0.05 : -0.05
            root.setVolume(root.volume + delta)
          }
        }
      }

      // ======== SEPARATOR ========

      Rectangle { Layout.fillWidth: true; height: 1; color: theme.bgBorder; Layout.topMargin: 12; Layout.bottomMargin: 12 }

      // ======== DEVICES SECTION ========

      Text {
        text: "Output Devices"
        color: theme.textMuted
        font.pixelSize: 11
        font.family: root.font
        font.bold: true
      }

      Repeater {
        model: root.devices

        Rectangle {
          required property var modelData
          required property int index

          Layout.fillWidth: true
          Layout.preferredHeight: 40
          radius: 8
          color: deviceArea.containsMouse ? theme.bgHover : (modelData.isDefault ? theme.bgSelected : "transparent")

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 10

            Text {
              text: modelData.name
              color: modelData.isDefault ? theme.accentGreen : theme.textPrimary
              font.pixelSize: 12
              font.family: root.font
              font.bold: modelData.isDefault
              elide: Text.ElideRight
              Layout.fillWidth: true
            }

            Text {
              text: Math.round(modelData.volume) + "%"
              color: theme.textMuted
              font.pixelSize: 11
              font.family: root.font
            }

            Text {
              text: "✓"
              color: theme.accentGreen
              font.pixelSize: 14
              font.family: root.font
              font.bold: true
              visible: modelData.isDefault
            }
          }

          MouseArea {
            id: deviceArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.setDefaultDevice(modelData.id)
          }
        }
      }
    }
  }
}
