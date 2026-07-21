import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Mpris
import QtQuick
import QtQuick.Layouts

PanelWindow {
  id: root
  visible: false
  property var theme: DefaultTheme {}
  property string font: "Hack Nerd Font"

  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
  WlrLayershell.namespace: "quickshell-media"
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
    target: "media"
    function toggle(): void {
      root.visible = !root.visible
      root.openX = -1
    }
    function openAt(x: number): void {
      root.openX = x
      root.visible = true
    }
  }

  // --- Player Detection ---

  property var activePlayer: {
    const players = Mpris.players.values;
    if (!players || players.length === 0) return null;
    for (let i = 0; i < players.length; i++) {
      if (players[i].playbackState === MprisPlaybackState.Playing) return players[i];
    }
    return players[0];
  }

  property bool isPlaying: activePlayer ? activePlayer.playbackState === MprisPlaybackState.Playing : false

  property int _tick: 0

  property real progress: {
    root._tick;
    if (!activePlayer || activePlayer.length <= 0) return 0;
    return activePlayer.position / activePlayer.length;
  }

  property string positionText: {
    root._tick;
    if (!activePlayer) return "0:00";
    return formatTime(activePlayer.position);
  }

  property string lengthText: {
    if (!activePlayer) return "0:00";
    return formatTime(activePlayer.length);
  }

  property bool hasVolume: activePlayer && typeof activePlayer.volume === "number" && !isNaN(activePlayer.volume) && activePlayer.volume >= 0

  Timer {
    interval: 1000
    running: root.visible && root.activePlayer !== null
    repeat: true
    onTriggered: root._tick++
  }

  function formatTime(seconds) {
    const s = Math.max(0, Math.floor(seconds));
    const mins = Math.floor(s / 60);
    const secs = s % 60;
    return mins + ":" + (secs < 10 ? "0" : "") + secs;
  }

  // --- Background (click to close) ---

  MouseArea {
    anchors.fill: parent
    onClicked: root.visible = false

    Rectangle {
      anchors.fill: parent
      color: theme.bgOverlay
    }
  }

  // --- Popup Card ---

  Rectangle {
    id: popupContent
    width: 380
    height: Math.max(popupCol.implicitHeight + 32, 120)
    radius: 16
    color: theme.bgBase
    border.color: theme.bgBorder
    border.width: 1

    x: root.openX >= 0 ? Math.max(16, Math.min(root.width - width - 16, root.openX - width / 2)) : 16
    anchors.top: parent.top
    anchors.topMargin: 44

    ColumnLayout {
      id: popupCol
      anchors.fill: parent
      anchors.margins: 16
      spacing: 12

      // ======== EMPTY STATE ========

      Text {
        Layout.fillWidth: true
        Layout.preferredHeight: 88
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        text: "󰝠 No media playing"
        color: theme.textMuted
        font.pixelSize: 14
        font.family: root.font
        visible: !root.activePlayer
      }

      // ======== ALBUM ART ========

      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 200
        Layout.preferredWidth: 200
        Layout.alignment: Qt.AlignHCenter
        radius: 12
        color: "transparent"
        visible: root.activePlayer !== null
        clip: true

        Image {
          id: albumArtImage
          anchors.fill: parent
          source: {
            if (!root.activePlayer) return "";
            const url = root.activePlayer.metadata ? (root.activePlayer.metadata["mpris:artUrl"] || "") : "";
            return url;
          }
          fillMode: Image.PreserveAspectFit
          visible: status === Image.Ready
          asynchronous: true
        }

        Text {
          anchors.centerIn: parent
          text: "󰝠"
          color: theme.textMuted
          font.pixelSize: 64
          font.family: root.font
          visible: albumArtImage.status !== Image.Ready
        }
      }

      // ======== SONG INFO ========

      ColumnLayout {
        Layout.fillWidth: true
        visible: root.activePlayer !== null
        spacing: 2

        Text {
          Layout.fillWidth: true
          horizontalAlignment: Text.AlignHCenter
          text: root.activePlayer ? (root.activePlayer.trackTitle || "Unknown Title") : ""
          color: theme.textPrimary
          font.pixelSize: 14
          font.family: root.font
          font.bold: true
          elide: Text.ElideRight
        }

        Text {
          Layout.fillWidth: true
          horizontalAlignment: Text.AlignHCenter
          text: root.activePlayer ? (root.activePlayer.trackArtist || "Unknown Artist") : ""
          color: theme.textSecondary
          font.pixelSize: 12
          font.family: root.font
          elide: Text.ElideRight
        }

        Text {
          Layout.fillWidth: true
          horizontalAlignment: Text.AlignHCenter
          text: root.activePlayer ? (root.activePlayer.trackAlbum || "") : ""
          color: theme.textMuted
          font.pixelSize: 11
          font.family: root.font
          elide: Text.ElideRight
          visible: text.length > 0
        }
      }

      // ======== PROGRESS BAR ========

      ColumnLayout {
        Layout.fillWidth: true
        visible: root.activePlayer !== null
        spacing: 4

        Rectangle {
          Layout.fillWidth: true
          height: 20
          color: "transparent"

          Rectangle {
            id: progressTrack
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.right: parent.right
            height: 4
            radius: 2
            color: theme.bgSurface

            Rectangle {
              width: root.progress * parent.width
              height: parent.height
              radius: 2
              color: theme.accentPrimary
            }
          }

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              if (!root.activePlayer || root.activePlayer.length <= 0) return;
              const ratio = mouse.x / width;
              root.activePlayer.position = ratio * root.activePlayer.length;
            }
          }
        }

        RowLayout {
          Layout.fillWidth: true

          Text {
            text: root.positionText
            color: theme.textMuted
            font.pixelSize: 10
            font.family: root.font
          }

          Item { Layout.fillWidth: true }

          Text {
            text: root.lengthText
            color: theme.textMuted
            font.pixelSize: 10
            font.family: root.font
          }
        }
      }

      // ======== CONTROLS ========

      RowLayout {
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignHCenter
        visible: root.activePlayer !== null
        spacing: 24

        // Previous
        Rectangle {
          width: 40; height: 40; radius: 20
          color: prevArea.containsMouse ? theme.bgHover : theme.bgSurface

          Text {
            anchors.centerIn: parent
            text: "󰒮"
            color: theme.textPrimary
            font.pixelSize: 18
            font.family: root.font
          }

          MouseArea {
            id: prevArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              if (root.activePlayer) root.activePlayer.previous();
            }
          }
        }

        // Play / Pause
        Rectangle {
          width: 48; height: 48; radius: 24
          color: playArea.containsMouse ? theme.accentPrimary : theme.bgSurface

          Text {
            anchors.centerIn: parent
            text: root.isPlaying ? "󰏤" : "󰐊"
            color: playArea.containsMouse ? theme.bgBase : theme.textPrimary
            font.pixelSize: 22
            font.family: root.font
          }

          MouseArea {
            id: playArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              if (root.activePlayer) root.activePlayer.togglePlaying();
            }
          }
        }

        // Next
        Rectangle {
          width: 40; height: 40; radius: 20
          color: nextArea.containsMouse ? theme.bgHover : theme.bgSurface

          Text {
            anchors.centerIn: parent
            text: "󰒭"
            color: theme.textPrimary
            font.pixelSize: 18
            font.family: root.font
          }

          MouseArea {
            id: nextArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              if (root.activePlayer) root.activePlayer.next();
            }
          }
        }
      }

      // ======== VOLUME ========

      RowLayout {
        Layout.fillWidth: true
        visible: root.activePlayer !== null && root.hasVolume
        spacing: 8

        Text {
          text: "󰕾"
          color: theme.textSecondary
          font.pixelSize: 14
          font.family: root.font
        }

        Rectangle {
          Layout.fillWidth: true
          height: 20
          color: "transparent"

          Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.right: parent.right
            height: 4
            radius: 2
            color: theme.bgSurface

            Rectangle {
              width: (root.activePlayer ? root.activePlayer.volume : 0) * parent.width
              height: parent.height
              radius: 2
              color: theme.accentCyan
            }
          }

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              if (!root.activePlayer) return;
              root.activePlayer.volume = Math.max(0, Math.min(1, mouse.x / width));
            }
          }
        }
      }
    }
  }
}
