import Quickshell
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Bluetooth
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
  WlrLayershell.namespace: "quickshell-connectivity"
  exclusionMode: ExclusionMode.Ignore

  color: "transparent"

  anchors {
    top: true
    bottom: true
    left: true
    right: true
  }

  IpcHandler {
    target: "network"
    function toggle(): void {
      root.visible = !root.visible
      if (root.visible) {
        refreshScan()
        refreshWiredIp()
        refreshHotspot()
      }
    }
  }

  // --- Wifi ---

  property var wifiDevice: {
    for (let i = 0; i < Networking.devices.values.length; i++) {
      const dev = Networking.devices.values[i]
      if (dev.type === DeviceType.Wifi)
        return dev
    }
    return null
  }

  property bool scanning: wifiDevice ? wifiDevice.scannerEnabled : false

  function refreshScan() {
    if (wifiDevice) {
      wifiDevice.scannerEnabled = true
      scanTimer.start()
    }
  }

  Timer {
    id: scanTimer
    interval: 5000
    onTriggered: {
      if (wifiDevice)
        wifiDevice.scannerEnabled = false
    }
  }

  property bool showPassword: false
  property var pendingNetwork: null

  // --- Hotspot ---

  property bool hotspotActive: false
  property string hotspotSsid: ""
  property string hotspotPassword: ""
  property string hotspotIface: ""
  property int hotspotClients: 0
  property bool showHotspotCreate: false

  Component.onCompleted: { refreshHotspot(); refreshWiredIp() }

  function refreshHotspot() {
    hotspotStatusProc.running = true
  }

  function startHotspot(ssid, password) {
    const dev = wifiDevice || (wiredDevices.length > 0 ? wiredDevices[0] : null)
    if (!dev) return
    const iface = dev.name || "wlan0"
    hotspotStartProc.command = ["bash", "-c", "nmcli dev wifi hotspot ifname " + iface + " ssid \"" + ssid + "\" password \"" + password + "\" 2>&1"]
    hotspotStartProc.running = true
  }

  function stopHotspot() {
    hotspotStopProc.running = true
  }

  Process {
    id: hotspotStatusProc
    command: ["bash", "-c", "nmcli -t -f NAME,TYPE connection show --active | grep wireless || true"]
    stdout: SplitParser {
      onRead: data => {
        if (data.length > 0) {
          root.hotspotActive = true
          root.hotspotSsid = data.split(":")[0]
        } else {
          root.hotspotActive = false
          root.hotspotSsid = ""
        }
      }
    }
    onRunningChanged: {
      if (!running && !root.hotspotActive) {
        root.hotspotSsid = ""
        root.hotspotPassword = ""
        root.hotspotClients = 0
      }
    }
  }

  Process {
    id: hotspotStartProc
    stdout: SplitParser {
      onRead: data => {
        if (data.includes("successfully")) {
          root.hotspotActive = true
          root.showHotspotCreate = false
        }
        root.hotspotStatusProc.running = true
      }
    }
  }

  Process {
    id: hotspotStopProc
    command: ["nmcli", "connection", "down", "Hotspot"]
    onRunningChanged: {
      if (!running) {
        root.hotspotActive = false
        root.hotspotSsid = ""
        root.hotspotPassword = ""
        root.hotspotClients = 0
      }
    }
  }

  Timer {
    id: hotspotClientTimer
    interval: 5000
    running: root.hotspotActive
    repeat: true
    onTriggered: {
      if (root.hotspotActive) hotspotClientCountProc.running = true
    }
  }

  Process {
    id: hotspotClientCountProc
    command: ["bash", "-c", "nmcli device wifi list ifname " + (root.wifiDevice ? root.wifiDevice.name : "wlan0") + " 2>/dev/null | grep -c 'In-Range' || echo 0"]
    stdout: SplitParser {
      onRead: data => {
        const n = parseInt(data)
        if (!isNaN(n)) root.hotspotClients = n
      }
    }
  }

  // --- Wired ---

  property var wiredDevices: {
    const devs = Networking.devices.values
    return devs.filter(d => d.type === DeviceType.Wired)
  }

  property var activeWiredDevice: {
    for (let i = 0; i < wiredDevices.length; i++) {
      if (wiredDevices[i].connected) return wiredDevices[i]
    }
    return null
  }

  property string wiredIp: ""

  function refreshWiredIp() {
    if (activeWiredDevice) {
      wiredIpProc.command = ["nmcli", "-t", "-f", "IP4.ADDRESS", "dev", "show", activeWiredDevice.name]
      wiredIpProc.running = true
    } else {
      wiredIp = ""
    }
  }

  Connections {
    target: root
    function onActiveWiredDeviceChanged() { refreshWiredIp() }
  }

  Process {
    id: wiredIpProc
    stdout: SplitParser {
      onRead: data => {
        if (data.includes("/")) {
          root.wiredIp = data.split("/")[0]
        }
      }
    }
  }

  // --- Bluetooth ---

  property var btAdapter: Bluetooth.defaultAdapter
  property bool btEnabled: btAdapter ? btAdapter.enabled : false

  property var btDevices: {
    if (!btAdapter) return []
    const devs = btAdapter.devices.values
    return devs.filter(d => d.connected)
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

  // Popup box anchored to top-right
  Rectangle {
    id: popupContent
    width: 380
    height: 700
    radius: 16
    color: theme.bgBase
    border.color: theme.bgBorder
    border.width: 1

    anchors.right: parent.right
    anchors.top: parent.top
    anchors.rightMargin: 16
    anchors.topMargin: 44

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: 16
      spacing: 0

      // ======== WIRED SECTION ========

      RowLayout {
        Layout.fillWidth: true
        spacing: 8

        Text {
          text: "󰈀"
          color: root.activeWiredDevice ? theme.accentGreen : theme.textMuted
          font.pixelSize: 16
          font.family: root.font
        }

        Text {
          text: "Wired"
          color: theme.accentPrimary
          font.pixelSize: 14
          font.family: root.font
          font.bold: true
          Layout.fillWidth: true
        }
      }

      // Wired device details
      Repeater {
        model: root.wiredDevices

        Rectangle {
          required property var modelData
          required property int index

          Layout.fillWidth: true
          height: modelData.connected ? 56 : 40
          radius: 8
          color: wiredArea.containsMouse ? theme.bgHover : "transparent"

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 10

            ColumnLayout {
              Layout.fillWidth: true
              spacing: 1

              Text {
                text: modelData.name
                color: modelData.connected ? theme.accentGreen : theme.textSecondary
                font.pixelSize: 13
                font.family: root.font
                font.bold: modelData.connected
              }

              Text {
                text: {
                  if (!modelData.connected) return "Not connected"
                  let parts = ["Connected"]
                  if (modelData.linkSpeed) parts.push(modelData.linkSpeed + " Mbps")
                  if (root.wiredIp) parts.push(root.wiredIp)
                  return parts.join(" \u2022 ")
                }
                color: theme.textMuted
                font.pixelSize: 10
                font.family: root.font
              }
            }

            // Disconnect button
            Rectangle {
              width: 28; height: 28; radius: 8
              color: wiredDisconnectArea.containsMouse ? theme.bgHover : "transparent"
              visible: modelData.connected

              Text {
                anchors.centerIn: parent
                text: "󰅖"
                color: theme.textSecondary
                font.pixelSize: 14
                font.family: root.font
              }

              MouseArea {
                id: wiredDisconnectArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: modelData.disconnect()
              }
            }
          }

          MouseArea {
            id: wiredArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
          }
        }
      }

      // ======== SEPARATOR (wired) ========

      Rectangle { Layout.fillWidth: true; height: 1; color: theme.bgBorder; Layout.topMargin: 12; Layout.bottomMargin: 12; visible: root.wiredDevices.length > 0 }

      // ======== HOTSPOT SECTION ========

      RowLayout {
        Layout.fillWidth: true
        spacing: 8

        Text {
          text: "󰈀"
          color: root.hotspotActive ? theme.accentOrange : theme.textMuted
          font.pixelSize: 16
          font.family: root.font
        }

        Text {
          text: "Hotspot"
          color: theme.accentPrimary
          font.pixelSize: 14
          font.family: root.font
          font.bold: true
          Layout.fillWidth: true
        }

        // Toggle hotspot
        Rectangle {
          width: 40; height: 22; radius: 11
          color: root.hotspotActive ? theme.accentOrange : theme.bgSurface
          border.color: theme.bgBorder; border.width: 1
          visible: root.hotspotActive

          Rectangle {
            x: 20
            width: 18; height: 18; radius: 9
            color: root.hotspotActive ? theme.bgBase : theme.textMuted
          }

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.stopHotspot()
          }
        }

        // Create button (when not active)
        Rectangle {
          width: createLabel.implicitWidth + 16; height: 28; radius: 6
          color: createArea.containsMouse ? theme.accentOrange : "transparent"
          border.color: theme.accentOrange; border.width: 1
          visible: !root.hotspotActive

          Text {
            id: createLabel
            anchors.centerIn: parent
            text: "Create"
            color: createArea.containsMouse ? theme.bgBase : theme.accentOrange
            font.pixelSize: 11
            font.family: root.font
            font.bold: true
          }

          MouseArea {
            id: createArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              root.showHotspotCreate = !root.showHotspotCreate
              hotspotSsidInput.text = "Quickshell-Hotspot"
              hotspotPassInput.text = ""
            }
          }
        }
      }

      // Active hotspot info
      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: root.hotspotActive ? 48 : 0
        radius: 8
        color: "transparent"
        visible: root.hotspotActive
        clip: true

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: 12
          anchors.rightMargin: 12
          spacing: 10

          ColumnLayout {
            Layout.fillWidth: true
            spacing: 1

            Text {
              text: root.hotspotSsid || "Hotspot"
              color: theme.accentOrange
              font.pixelSize: 13
              font.family: root.font
              font.bold: true
            }

            Text {
              text: root.hotspotClients + " client" + (root.hotspotClients !== 1 ? "s" : "") + " connected"
              color: theme.textMuted
              font.pixelSize: 10
              font.family: root.font
            }
          }

          Rectangle {
            width: 28; height: 28; radius: 8
            color: hotspotStopArea.containsMouse ? theme.bgHover : "transparent"

            Text {
              anchors.centerIn: parent
              text: "󰅖"
              color: theme.textSecondary
              font.pixelSize: 14
              font.family: root.font
            }

            MouseArea {
              id: hotspotStopArea
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.stopHotspot()
            }
          }
        }
      }

      // Create hotspot form
      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: root.showHotspotCreate ? createFormCol.implicitHeight + 24 : 0
        radius: 10
        color: theme.bgSurface
        visible: root.showHotspotCreate
        border.color: theme.accentOrange
        border.width: 1
        clip: true

        Behavior on Layout.preferredHeight { NumberAnimation { duration: 150 } }

        ColumnLayout {
          id: createFormCol
          anchors.fill: parent
          anchors.margins: 12
          spacing: 8

          Text {
            text: "Create Hotspot"
            color: theme.textPrimary
            font.pixelSize: 12
            font.family: root.font
            font.bold: true
          }

          // SSID field
          RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
              text: "SSID"
              color: theme.textMuted
              font.pixelSize: 11
              font.family: root.font
              Layout.preferredWidth: 44
            }

            Rectangle {
              Layout.fillWidth: true
              height: 32
              radius: 6
              color: theme.bgBase
              border.color: hotspotSsidInput.activeFocus ? theme.accentOrange : theme.bgBorder
              border.width: 1

              TextInput {
                id: hotspotSsidInput
                anchors.fill: parent
                anchors.margins: 8
                color: theme.textPrimary
                font.pixelSize: 12
                font.family: root.font
                clip: true
                text: "Quickshell-Hotspot"
              }
            }
          }

          // Password field
          RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
              text: "Pass"
              color: theme.textMuted
              font.pixelSize: 11
              font.family: root.font
              Layout.preferredWidth: 44
            }

            Rectangle {
              Layout.fillWidth: true
              height: 32
              radius: 6
              color: theme.bgBase
              border.color: hotspotPassInput.activeFocus ? theme.accentOrange : theme.bgBorder
              border.width: 1

              TextInput {
                id: hotspotPassInput
                anchors.fill: parent
                anchors.margins: 8
                color: theme.textPrimary
                font.pixelSize: 12
                font.family: root.font
                echoMode: TextInput.Password
                clip: true

                Keys.onReturnPressed: {
                  if (hotspotSsidInput.text.length > 0 && hotspotPassInput.text.length >= 8)
                    root.startHotspot(hotspotSsidInput.text, hotspotPassInput.text)
                }
              }
            }
          }

          Text {
            text: "Minimum 8 characters"
            color: theme.textMuted
            font.pixelSize: 9
            font.family: root.font
            visible: hotspotPassInput.text.length > 0 && hotspotPassInput.text.length < 8
          }

          RowLayout {
            spacing: 8
            Item { Layout.fillWidth: true }

            Rectangle {
              width: cancelHotspotLabel.implicitWidth + 16; height: 28; radius: 6
              color: cancelHotspotArea.containsMouse ? theme.bgHover : "transparent"
              border.color: theme.bgBorder; border.width: 1

              Text {
                id: cancelHotspotLabel
                anchors.centerIn: parent
                text: "Cancel"
                color: theme.textSecondary
                font.pixelSize: 11
                font.family: root.font
              }

              MouseArea {
                id: cancelHotspotArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.showHotspotCreate = false
              }
            }

            Rectangle {
              width: startHotspotLabel.implicitWidth + 16; height: 28; radius: 6
              color: (startHotspotArea.containsMouse && hotspotPassInput.text.length >= 8) ? theme.accentOrange : "transparent"
              border.color: theme.accentOrange; border.width: 1

              Text {
                id: startHotspotLabel
                anchors.centerIn: parent
                text: "Start"
                color: (startHotspotArea.containsMouse && hotspotPassInput.text.length >= 8) ? theme.bgBase : theme.accentOrange
                font.pixelSize: 11
                font.family: root.font
                font.bold: true
              }

              MouseArea {
                id: startHotspotArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  if (hotspotSsidInput.text.length > 0 && hotspotPassInput.text.length >= 8)
                    root.startHotspot(hotspotSsidInput.text, hotspotPassInput.text)
                }
              }
            }
          }
        }
      }

      // ======== SEPARATOR (hotspot) ========

      Rectangle { Layout.fillWidth: true; height: 1; color: theme.bgBorder; Layout.topMargin: 12; Layout.bottomMargin: 12 }

      // ======== WIFI SECTION ========

      // Wifi header row
      RowLayout {
        Layout.fillWidth: true
        spacing: 8

        Text {
          text: "󰖩"
          color: Networking.wifiEnabled ? theme.accentGreen : theme.textMuted
          font.pixelSize: 16
          font.family: root.font
        }

        Text {
          text: "Wi-Fi"
          color: theme.accentPrimary
          font.pixelSize: 14
          font.family: root.font
          font.bold: true
          Layout.fillWidth: true
        }

        // Toggle wifi on/off
        Rectangle {
          width: 40; height: 22; radius: 11
          color: Networking.wifiEnabled ? theme.accentGreen : theme.bgSurface
          border.color: theme.bgBorder; border.width: 1

          Rectangle {
            x: Networking.wifiEnabled ? 20 : 2
            width: 18; height: 18; radius: 9
            color: Networking.wifiEnabled ? theme.bgBase : theme.textMuted

            Behavior on x { NumberAnimation { duration: 150 } }
          }

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: Networking.wifiEnabled = !Networking.wifiEnabled
          }
        }

        // Scan / refresh button
        Rectangle {
          width: 28; height: 28; radius: 8
          color: scanArea.containsMouse ? theme.bgHover : "transparent"

          Text {
            anchors.centerIn: parent
            text: "󰑐"
            color: theme.textSecondary
            font.pixelSize: 16
            font.family: root.font

            NumberAnimation on rotation {
              running: root.scanning
              loops: Animation.Infinite
              duration: 1000
              from: 0; to: 360
            }
          }

          MouseArea {
            id: scanArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.refreshScan()
          }
        }
      }

      // Available Networks header
      Text {
        text: "Available Networks"
        color: theme.textMuted
        font.pixelSize: 11
        font.family: root.font
        font.bold: true
        Layout.topMargin: 8
      }

      // Network list
      ListView {
        id: networkList
        Layout.fillWidth: true
        Layout.preferredHeight: 280
        clip: true
        spacing: 2
        boundsBehavior: Flickable.StopAtBounds

        model: {
          if (!root.wifiDevice) return []
          const nets = root.wifiDevice.networks.values
          return [...nets].sort((a, b) => {
            if (a.connected && !b.connected) return -1
            if (!a.connected && b.connected) return 1
            return (b.signalStrength || 0) - (a.signalStrength || 0)
          })
        }

        delegate: Rectangle {
          id: netDelegate
          required property var modelData
          required property int index

          width: networkList.width
          height: 48
          radius: 8
          color: netArea.containsMouse ? theme.bgHover :
                 modelData.connected ? theme.bgSelected : "transparent"

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 10

            Text {
              text: {
                if (modelData.connected) return "󰤨"
                const s = modelData.signalStrength || 0
                if (s > 0.75) return "󰤨"
                if (s > 0.5) return "󰤢"
                if (s > 0.25) return "󰤦"
                return "󰤯"
              }
              color: modelData.connected ? theme.accentGreen :
                     netArea.containsMouse ? theme.accentPrimary : theme.textSecondary
              font.pixelSize: 18
              font.family: root.font
            }

            ColumnLayout {
              Layout.fillWidth: true
              spacing: 1

              Text {
                text: modelData.name || "Hidden Network"
                color: modelData.connected ? theme.accentGreen : theme.textPrimary
                font.pixelSize: 13
                font.family: root.font
                font.bold: modelData.connected
                elide: Text.ElideRight
                Layout.fillWidth: true
              }

              Text {
                text: {
                  if (modelData.connected) return "Connected \u2022 " + modelData.device.address
                  if (modelData.known) return "Saved"
                  const sec = modelData.security
                  if (sec !== undefined && sec === WifiSecurityType.None) return "Open"
                  return "Secured"
                }
                color: theme.textMuted
                font.pixelSize: 10
                font.family: root.font
              }
            }

            Row {
              spacing: 2
              layoutDirection: Qt.RightToLeft
              Repeater {
                model: 4
                Rectangle {
                  width: 3
                  height: 6 + index * 3
                  radius: 1
                  anchors.bottom: parent.bottom
                  color: {
                    const s = netDelegate.modelData.signalStrength || 0
                    const filled = (4 - index) / 4 <= s
                    return filled ? (netDelegate.modelData.connected ? theme.accentGreen : theme.accentPrimary) : theme.bgBorder
                  }
                }
              }
            }
          }

          MouseArea {
            id: netArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              const net = netDelegate.modelData
              if (net.connected) {
                net.disconnect()
              } else if (net.known) {
                net.connect()
              } else {
                root.pendingNetwork = net
                root.showPassword = true
                passwordInput.text = ""
                passwordInput.forceActiveFocus()
              }
            }
          }
        }

        // Empty state
        Text {
          anchors.centerIn: parent
          text: root.scanning ? "  Scanning..." :
                !Networking.wifiEnabled ? "  Wi-Fi is disabled" :
                "  No networks found"
          color: theme.textMuted
          font.pixelSize: 13
          font.family: root.font
          visible: networkList.count === 0
        }
      }

      // Password prompt
      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: root.showPassword ? showPwCol.implicitHeight + 24 : 0
        radius: 10
        color: theme.bgSurface
        visible: root.showPassword
        border.color: theme.accentPrimary
        border.width: 1
        clip: true

        Behavior on Layout.preferredHeight { NumberAnimation { duration: 150 } }

        ColumnLayout {
          id: showPwCol
          anchors.fill: parent
          anchors.margins: 12
          spacing: 8

          Text {
            text: "Password for " + (root.pendingNetwork ? root.pendingNetwork.name : "")
            color: theme.textPrimary
            font.pixelSize: 12
            font.family: root.font
            font.bold: true
            elide: Text.ElideRight
            Layout.fillWidth: true
          }

          Rectangle {
            Layout.fillWidth: true
            height: 36
            radius: 8
            color: theme.bgBase
            border.color: passwordInput.activeFocus ? theme.accentPrimary : theme.bgBorder
            border.width: 1

            TextInput {
              id: passwordInput
              anchors.fill: parent
              anchors.margins: 8
              color: theme.textPrimary
              font.pixelSize: 13
              font.family: root.font
              echoMode: TextInput.Password
              clip: true

              Keys.onReturnPressed: submitPassword()
              Keys.onEscapePressed: { root.showPassword = false; root.pendingNetwork = null }
            }
          }

          RowLayout {
            spacing: 8
            Item { Layout.fillWidth: true }

            Rectangle {
              width: cancelLabel.implicitWidth + 16; height: 28; radius: 6
              color: cancelArea.containsMouse ? theme.bgHover : "transparent"
              border.color: theme.bgBorder; border.width: 1

              Text {
                id: cancelLabel
                anchors.centerIn: parent
                text: "Cancel"
                color: theme.textSecondary
                font.pixelSize: 11
                font.family: root.font
              }

              MouseArea {
                id: cancelArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: { root.showPassword = false; root.pendingNetwork = null }
              }
            }

            Rectangle {
              width: connectLabel.implicitWidth + 16; height: 28; radius: 6
              color: connectArea.containsMouse ? theme.accentPrimary : "transparent"
              border.color: theme.accentPrimary; border.width: 1

              Text {
                id: connectLabel
                anchors.centerIn: parent
                text: "Connect"
                color: connectArea.containsMouse ? theme.bgBase : theme.accentPrimary
                font.pixelSize: 11
                font.family: root.font
                font.bold: true
              }

              MouseArea {
                id: connectArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: submitPassword()
              }
            }
          }
        }
      }

      // ======== SEPARATOR ========

      Rectangle { Layout.fillWidth: true; height: 1; color: theme.bgBorder; Layout.topMargin: 12; Layout.bottomMargin: 12 }

      // ======== BLUETOOTH SECTION ========

      // Bluetooth header row
      RowLayout {
        Layout.fillWidth: true
        spacing: 8

        Text {
          text: "󰂯"
          color: root.btEnabled ? theme.accentCyan : theme.textMuted
          font.pixelSize: 16
          font.family: root.font
        }

        Text {
          text: "Bluetooth"
          color: theme.accentPrimary
          font.pixelSize: 14
          font.family: root.font
          font.bold: true
          Layout.fillWidth: true
        }

        // Toggle bluetooth on/off
        Rectangle {
          width: 40; height: 22; radius: 11
          color: root.btEnabled ? theme.accentCyan : theme.bgSurface
          border.color: theme.bgBorder; border.width: 1

          Rectangle {
            x: root.btEnabled ? 20 : 2
            width: 18; height: 18; radius: 9
            color: root.btEnabled ? theme.bgBase : theme.textMuted
            Behavior on x { NumberAnimation { duration: 150 } }
          }

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              if (root.btAdapter)
                root.btAdapter.enabled = !root.btEnabled
            }
          }
        }
      }

      // Connected devices header
      Text {
        text: root.btDevices.length > 0 ? "Connected Devices" : "No Connected Devices"
        color: theme.textMuted
        font.pixelSize: 11
        font.family: root.font
        font.bold: true
        Layout.topMargin: 8
      }

      // Bluetooth device list
      Repeater {
        model: root.btDevices

        Rectangle {
          required property var modelData
          required property int index

          Layout.fillWidth: true
          height: 48
          radius: 8
          color: btItemArea.containsMouse ? theme.bgHover : "transparent"

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 10

            // Device icon
            Text {
              text: {
                const devName = (modelData.name || "").toLowerCase()
                if (devName.includes("headphone") || devName.includes("headset") || devName.includes("earbuds") || devName.includes("airpods"))
                  return "󰋋"
                if (devName.includes("mouse"))
                  return "󰍹"
                if (devName.includes("keyboard"))
                  return "󰌌"
                if (devName.includes("controller") || devName.includes("gamepad"))
                  return "󰊴"
                if (devName.includes("speaker"))
                  return "󰝟"
                return "󰂯"
              }
              color: theme.accentCyan
              font.pixelSize: 18
              font.family: root.font
            }

            // Device name + battery
            ColumnLayout {
              Layout.fillWidth: true
              spacing: 1

              Text {
                text: modelData.name || modelData.deviceName || "Unknown Device"
                color: theme.textPrimary
                font.pixelSize: 13
                font.family: root.font
                elide: Text.ElideRight
                Layout.fillWidth: true
              }

              Text {
                text: {
                  let status = modelData.connected ? "Connected" : "Disconnected"
                  if (modelData.batteryAvailable)
                    status += " \u2022 " + Math.round(modelData.battery * 100) + "%"
                  return status
                }
                color: modelData.connected ? theme.accentCyan : theme.textMuted
                font.pixelSize: 10
                font.family: root.font
              }
            }

            // Disconnect button
            Rectangle {
              width: 28; height: 28; radius: 8
              color: btDisconnectArea.containsMouse ? theme.bgHover : "transparent"
              visible: modelData.connected

              Text {
                anchors.centerIn: parent
                text: "󰅖"
                color: theme.textSecondary
                font.pixelSize: 14
                font.family: root.font
              }

              MouseArea {
                id: btDisconnectArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: modelData.disconnect()
              }
            }
          }

          MouseArea {
            id: btItemArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
          }
        }
      }
    }
  }

  function submitPassword() {
    if (root.pendingNetwork && passwordInput.text.length > 0) {
      root.pendingNetwork.connectWithPsk(passwordInput.text)
    }
    root.showPassword = false
    root.pendingNetwork = null
  }
}
