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
  WlrLayershell.namespace: "quickshell-power-profile"
  exclusionMode: ExclusionMode.Ignore

  color: "transparent"

  anchors {
    top: true
    bottom: true
    left: true
    right: true
  }

  IpcHandler {
    target: "power-profile"
    function toggle(): void {
      root.visible = !root.visible
      if (root.visible) refreshProfile()
    }
  }

  property string currentProfile: "balanced"

  function refreshProfile() {
    getProfileProc.running = true
  }

  function setProfile(profile: string) {
    setProfileProc.command = ["powerprofilesctl", "set", profile]
    setProfileProc.running = true
    currentProfile = profile
    root.visible = false
  }

  Process {
    id: getProfileProc
    command: ["powerprofilesctl", "get"]
    running: false
    stdout: StdioCollector {
      onStreamFinished: { root.currentProfile = text.trim() }
    }
  }

  Process {
    id: setProfileProc
    running: false
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
    width: 260
    height: profileCol.implicitHeight + 32
    radius: 16
    color: theme.bgBase
    border.color: theme.bgBorder
    border.width: 1

    anchors.right: parent.right
    anchors.top: parent.top
    anchors.rightMargin: 16
    anchors.topMargin: 44

    ColumnLayout {
      id: profileCol
      anchors.fill: parent
      anchors.margins: 16
      spacing: 8

      // Header
      RowLayout {
        Layout.fillWidth: true
        spacing: 8

        Text {
          text: {
            if (root.currentProfile === "power-saver") return "󰾆"
            if (root.currentProfile === "performance") return "󰀠"
            return "󰓅"
          }
          color: {
            if (root.currentProfile === "power-saver") return theme.accentGreen
            if (root.currentProfile === "performance") return theme.accentRed
            return theme.accentPrimary
          }
          font.pixelSize: 16
          font.family: root.font
        }

        Text {
          text: "Power Profile"
          color: theme.accentPrimary
          font.pixelSize: 14
          font.family: root.font
          font.bold: true
          Layout.fillWidth: true
        }
      }

      Rectangle { Layout.fillWidth: true; height: 1; color: theme.bgBorder }

      // Power Saver
      Rectangle {
        Layout.fillWidth: true
        height: 40
        radius: 8
        color: saverArea.containsMouse ? theme.bgHover :
               root.currentProfile === "power-saver" ? theme.bgSelected : "transparent"

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: 12
          anchors.rightMargin: 12
          spacing: 10

          Text {
            text: "󰾆"
            color: root.currentProfile === "power-saver" ? theme.accentGreen : theme.textMuted
            font.pixelSize: 18
            font.family: root.font
          }

          ColumnLayout {
            Layout.fillWidth: true
            spacing: 1

            Text {
              text: "Power Saver"
              color: root.currentProfile === "power-saver" ? theme.accentGreen : theme.textPrimary
              font.pixelSize: 13
              font.family: root.font
              font.bold: root.currentProfile === "power-saver"
            }

            Text {
              text: "Limits CPU for longer battery"
              color: theme.textMuted
              font.pixelSize: 10
              font.family: root.font
              elide: Text.ElideRight
              Layout.fillWidth: true
            }
          }

          Text {
            text: "󰄬"
            color: theme.accentGreen
            font.pixelSize: 14
            font.family: root.font
            visible: root.currentProfile === "power-saver"
          }
        }

        MouseArea {
          id: saverArea
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.setProfile("power-saver")
        }
      }

      // Balanced
      Rectangle {
        Layout.fillWidth: true
        height: 40
        radius: 8
        color: balancedArea.containsMouse ? theme.bgHover :
               root.currentProfile === "balanced" ? theme.bgSelected : "transparent"

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: 12
          anchors.rightMargin: 12
          spacing: 10

          Text {
            text: "󰓅"
            color: root.currentProfile === "balanced" ? theme.accentPrimary : theme.textMuted
            font.pixelSize: 18
            font.family: root.font
          }

          ColumnLayout {
            Layout.fillWidth: true
            spacing: 1

            Text {
              text: "Balanced"
              color: root.currentProfile === "balanced" ? theme.accentPrimary : theme.textPrimary
              font.pixelSize: 13
              font.family: root.font
              font.bold: root.currentProfile === "balanced"
            }

            Text {
              text: "Default performance"
              color: theme.textMuted
              font.pixelSize: 10
              font.family: root.font
              elide: Text.ElideRight
              Layout.fillWidth: true
            }
          }

          Text {
            text: "󰄬"
            color: theme.accentPrimary
            font.pixelSize: 14
            font.family: root.font
            visible: root.currentProfile === "balanced"
          }
        }

        MouseArea {
          id: balancedArea
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.setProfile("balanced")
        }
      }

      // Performance
      Rectangle {
        Layout.fillWidth: true
        height: 40
        radius: 8
        color: perfArea.containsMouse ? theme.bgHover :
               root.currentProfile === "performance" ? theme.bgSelected : "transparent"

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: 12
          anchors.rightMargin: 12
          spacing: 10

          Text {
            text: "󰀠"
            color: root.currentProfile === "performance" ? theme.accentRed : theme.textMuted
            font.pixelSize: 18
            font.family: root.font
          }

          ColumnLayout {
            Layout.fillWidth: true
            spacing: 1

            Text {
              text: "Performance"
              color: root.currentProfile === "performance" ? theme.accentRed : theme.textPrimary
              font.pixelSize: 13
              font.family: root.font
              font.bold: root.currentProfile === "performance"
            }

            Text {
              text: "Maximum CPU performance"
              color: theme.textMuted
              font.pixelSize: 10
              font.family: root.font
              elide: Text.ElideRight
              Layout.fillWidth: true
            }
          }

          Text {
            text: "󰄬"
            color: theme.accentRed
            font.pixelSize: 14
            font.family: root.font
            visible: root.currentProfile === "performance"
          }
        }

        MouseArea {
          id: perfArea
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.setProfile("performance")
        }
      }
    }
  }
}
