import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Services.Notifications
import QtQuick
import QtQuick.Layouts
import "../notifications"

PanelWindow {
    id: root
    visible: false
    property var theme: DefaultTheme {}
    property string font: "Hack Nerd Font"
    property var hiddenSeqIds: []

    property bool dndEnabled: typeof NotificationService !== "undefined" ? NotificationService.doNotDisturb : false
    property int notifCount: typeof NotificationService !== "undefined" ? NotificationService.count : 0
    property var filteredNotifications: {
        if (typeof NotificationService === "undefined") return [];
        return NotificationService.notifications.filter(function(n) {
            return !root.hiddenSeqIds.includes(n.seqId);
        });
    }

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
        }
    }

    function hideNotif(seqId): void {
        root.hiddenSeqIds = [...root.hiddenSeqIds, seqId];
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
                    visible: root.notifCount > 0

                    Text {
                        id: countLabel
                        anchors.centerIn: parent
                        text: root.notifCount
                        color: theme.textMuted
                        font.pixelSize: 11
                        font.family: root.font
                    }
                }

                // DND toggle pill
                Rectangle {
                    width: 40; height: 22; radius: 11
                    color: root.dndEnabled ? theme.accentRed : theme.bgSurface
                    border.color: theme.bgBorder; border.width: 1

                    Rectangle {
                        x: root.dndEnabled ? 20 : 2
                        width: 18; height: 18; radius: 9
                        color: root.dndEnabled ? theme.bgBase : theme.textMuted
                        Behavior on x { NumberAnimation { duration: 150 } }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: dndToggleProc.running = true
                    }

                    Process {
                        id: dndToggleProc
                        command: ["qs", "ipc", "call", "notifications", "dnd-toggle"]
                        onRunningChanged: {
                            if (!running) {
                                root.dndEnabled = typeof NotificationService !== "undefined"
                                    ? NotificationService.doNotDisturb : root.dndEnabled;
                            }
                        }
                    }
                }

                // Clear all button
                Rectangle {
                    width: 28; height: 28; radius: 8
                    color: clearAllArea.containsMouse ? theme.bgHover : "transparent"
                    visible: root.notifCount > 0

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
                text: root.notifCount === 0 ? "No notifications" : root.notifCount + " notification" + (root.notifCount !== 1 ? "s" : "")
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

                model: ScriptModel {
                    values: root.filteredNotifications
                    objectProp: "seqId"
                }

                delegate: Rectangle {
                    id: notifCard
                    required property var modelData
                    required property int index

                    width: notifList.width
                    height: cardCol.implicitHeight + 24
                    radius: 12
                    color: notifCardArea.containsMouse ? theme.bgHover : theme.bgBase
                    border.color: modelData.urgency === NotificationUrgency.Critical ? theme.urgencyCritical :
                                  modelData.urgency === NotificationUrgency.Low     ? theme.urgencyLow     : theme.bgBorder
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
                        color: modelData.urgency === NotificationUrgency.Critical ? theme.urgencyCritical :
                               modelData.urgency === NotificationUrgency.Low      ? theme.urgencyLow      : theme.urgencyNormal
                    }

                    ColumnLayout {
                        id: cardCol
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 12
                        anchors.topMargin: 12
                        anchors.bottomMargin: 12
                        spacing: 6

                        // App icon + name + dismiss
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Item {
                                Layout.preferredWidth: 16
                                Layout.preferredHeight: 16
                                Layout.alignment: Qt.AlignVCenter

                                IconImage {
                                    anchors.centerIn: parent
                                    source: Quickshell.iconPath(modelData.appIcon, true)
                                    implicitSize: 16
                                    visible: modelData.appIcon !== ""
                                }

                                Text {
                                    anchors.centerIn: parent
                                    visible: modelData.appIcon === ""
                                    text: {
                                        const name = (modelData.appName || "").toLowerCase();
                                        if (modelData.urgency === NotificationUrgency.Critical) return "󰀦";
                                        if (name.includes("discord"))  return "󰙯";
                                        if (name.includes("firefox"))  return "󰈹";
                                        if (name.includes("chrome"))   return "";
                                        if (name.includes("telegram")) return "";
                                        if (name.includes("spotify"))  return "󰓇";
                                        if (name.includes("terminal") || name.includes("kitty") || name.includes("alacritty")) return "";
                                        return "󰂚";
                                    }
                                    color: modelData.urgency === NotificationUrgency.Critical
                                           ? theme.urgencyCritical : theme.urgencyNormal
                                    font.pixelSize: 14
                                    font.family: root.font
                                }
                            }

                            Text {
                                text: modelData.appName || "Notification"
                                color: theme.textMuted
                                font.pixelSize: 11
                                font.family: root.font
                                Layout.alignment: Qt.AlignVCenter
                            }

                            Item { Layout.fillWidth: true }

                            // Dismiss button
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

                        // Summary
                        Text {
                            text: modelData.summary
                            color: theme.textPrimary
                            font.pixelSize: 13
                            font.family: root.font
                            font.bold: true
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                            visible: text !== ""
                        }

                        // Body
                        Text {
                            text: modelData.body
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

                // Empty state
                Text {
                    anchors.centerIn: parent
                    text: root.dndEnabled ? "  Do Not Disturb is on" : "  No notifications"
                    color: theme.textMuted
                    font.pixelSize: 13
                    font.family: root.font
                    visible: notifList.count === 0
                }
            }
        }
    }
}
