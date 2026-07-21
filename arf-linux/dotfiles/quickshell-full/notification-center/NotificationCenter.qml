import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts

PanelWindow {
    id: root
    visible: false
    property var theme: DefaultTheme {}
    property string font: "Hack Nerd Font"
    property var hiddenSeqIds: []
    property var notifications: []

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.namespace: "quickshell-notification-center"
    exclusionMode: ExclusionMode.Ignore

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    color: "transparent"

    IpcHandler {
        target: "notification-center"
        function toggle(): void {
            root.visible = !root.visible
            if (root.visible) refreshNotifs()
        }
    }

    FileView {
        path: "/tmp/quickshell-notifs.json"
        watchChanges: true
        onFileChanged: refreshNotifs()
    }

    function refreshNotifs() {
        readFileProc.running = true
    }

    Process {
        id: readFileProc
        command: ["cat", "/tmp/quickshell-notifs.json"]
        stdout: SplitParser {
            onRead: data => {
                try {
                    var parsed = JSON.parse(data)
                    root.notifications = parsed
                } catch(e) {}
            }
        }
    }

    function getVisibleNotifs() {
        return root.notifications.filter(function(n) {
            return !root.hiddenSeqIds.includes(n.seqId);
        })
    }

    function hideNotif(seqId) {
        root.hiddenSeqIds = [...root.hiddenSeqIds, seqId]
    }

    Component.onCompleted: refreshNotifs()

    MouseArea {
        anchors.fill: parent
        onClicked: root.visible = false

        Rectangle {
            anchors.fill: parent
            color: theme.bgOverlay
        }
    }

    Rectangle {
        id: card
        width: 400
        height: 600
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

            // ======== HEADER ========

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: "󰂜"
                    color: theme.accentPrimary
                    font.pixelSize: 18
                    font.family: root.font
                }

                Text {
                    text: "Notifications"
                    color: theme.textPrimary
                    font.pixelSize: 14
                    font.family: root.font
                    font.bold: true
                    Layout.fillWidth: true
                }

                // Count badge
                Rectangle {
                    width: Math.max(20, countLabel.implicitWidth + 12)
                    height: 20
                    radius: 10
                    color: theme.bgSurface
                    visible: root.getVisibleNotifs().length > 0

                    Text {
                        id: countLabel
                        anchors.centerIn: parent
                        text: root.getVisibleNotifs().length
                        color: theme.textMuted
                        font.pixelSize: 11
                        font.family: root.font
                    }
                }

                // Clear all button
                Rectangle {
                    width: 28; height: 28; radius: 8
                    color: clearAllArea.containsMouse ? theme.bgHover : "transparent"
                    visible: root.getVisibleNotifs().length > 0

                    Text {
                        anchors.centerIn: parent
                        text: "󰅖"
                        color: clearAllArea.containsMouse ? theme.accentRed : theme.textSecondary
                        font.pixelSize: 14
                        font.family: root.font
                    }

                    MouseArea {
                        id: clearAllArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: clearAllProc.running = true
                    }

                    Process {
                        id: clearAllProc
                        command: ["qs", "ipc", "call", "notifications", "dismiss-all"]
                    }
                }
            }

            // ======== COUNT TEXT ========

            Text {
                text: {
                    var count = root.getVisibleNotifs().length
                    return count === 0 ? "No notifications" : count + " notification" + (count !== 1 ? "s" : "")
                }
                color: theme.textMuted
                font.pixelSize: 11
                font.family: root.font
                Layout.topMargin: 8
            }

            // ======== SEPARATOR ========

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: theme.bgBorder
                Layout.topMargin: 12
                Layout.bottomMargin: 12
            }

            // ======== NOTIFICATION LIST ========

            ListView {
                id: notifList
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 8
                boundsBehavior: Flickable.StopAtBounds

                model: root.getVisibleNotifs()

                delegate: Rectangle {
                    id: notifCard
                    required property var modelData
                    required property int index

                    width: notifList.width
                    height: cardCol.implicitHeight + 24
                    radius: 12
                    color: notifCardArea.containsMouse ? theme.bgHover : theme.bgBase
                    border.color: theme.bgBorder
                    border.width: 1
                    clip: true

                    // Left accent bar
                    Rectangle {
                        width: 3
                        height: parent.height - 16
                        radius: 2
                        anchors.left: parent.left
                        anchors.leftMargin: 6
                        anchors.verticalCenter: parent.verticalCenter
                        color: theme.urgencyNormal
                    }

                    ColumnLayout {
                        id: cardCol
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 12
                        anchors.topMargin: 12
                        anchors.bottomMargin: 12
                        spacing: 6

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Text {
                                text: {
                                    const name = (modelData.appName || "").toLowerCase();
                                    if (name.includes("discord"))  return "󰙯";
                                    if (name.includes("firefox"))  return "󰈹";
                                    if (name.includes("spotify"))  return "󰓇";
                                    return "󰂚";
                                }
                                color: theme.urgencyNormal
                                font.pixelSize: 14
                                font.family: root.font
                            }

                            Text {
                                text: modelData.appName || "Notification"
                                color: theme.textMuted
                                font.pixelSize: 11
                                font.family: root.font
                                Layout.alignment: Qt.AlignVCenter
                            }

                            Item { Layout.fillWidth: true }

                            Rectangle {
                                width: 20; height: 20; radius: 10
                                color: dismissHover.containsMouse ? theme.bgBorder : "transparent"
                                Layout.alignment: Qt.AlignVCenter

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰅖"
                                    color: dismissHover.containsMouse ? theme.accentRed : theme.textMuted
                                    font.pixelSize: 12
                                    font.family: root.font
                                }

                                MouseArea {
                                    id: dismissHover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.hideNotif(modelData.seqId)
                                }
                            }
                        }

                        Text {
                            text: modelData.summary || ""
                            color: theme.textPrimary
                            font.pixelSize: 13
                            font.family: root.font
                            font.bold: true
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                            visible: text !== ""
                        }

                        Text {
                            text: modelData.body || ""
                            color: theme.textSecondary
                            font.pixelSize: 12
                            font.family: root.font
                            wrapMode: Text.Wrap
                            maximumLineCount: 3
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                            visible: text !== ""
                            textFormat: Text.PlainText
                        }
                    }

                    MouseArea {
                        id: notifCardArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        z: -1
                        onClicked: root.hideNotif(modelData.seqId)
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: "  No notifications"
                    color: theme.textMuted
                    font.pixelSize: 13
                    font.family: root.font
                    visible: notifList.count === 0
                }
            }
        }
    }
}
