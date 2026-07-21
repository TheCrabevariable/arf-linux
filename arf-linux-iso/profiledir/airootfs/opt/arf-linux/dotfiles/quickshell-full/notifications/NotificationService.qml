pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Io

Singleton {
    id: root

    property list<var> notifications: []
    property list<var> history: []
    property bool doNotDisturb: false
    readonly property int count: notifications.length
    property int _seqCounter: 0

    Component {
        id: notifDataComp
        NotificationData {}
    }

    NotificationServer {
        id: server
        actionsSupported:    true
        bodySupported:       true
        bodyMarkupSupported: true
        imageSupported:      true
        keepOnReload:        false

        onNotification: function(notification) {
            if (root.doNotDisturb) return;

            if (!notification.appName && !notification.summary
                && !notification.body && !notification.image) return;

            notification.tracked = true;

            const idStr = String(notification.id || "");
            if (idStr !== "") {
                const existing = root.notifications.find(function(n) {
                    return n.notifId === idStr;
                });
                if (existing && !existing.closed) {
                    existing.closed = true;
                    root.notifications = root.notifications.filter(function(n) {
                        return n !== existing;
                    });
                    existing.destroy();
                }
            }

            const data = notifDataComp.createObject(root, {
                notification: notification,
                seqId: String(root._seqCounter++)
            });

            root.notifications = [data, ...root.notifications];

            root.history = [{ seqId: data.seqId, summary: data.summary, body: data.body, appName: data.appName, appIcon: data.appIcon }, ...root.history]

            if (root.history.length > 50) root.history = root.history.slice(0, 50)

            root._writeFile()

            if (root.notifications.length > 5) {
                root.notifications[root.notifications.length - 1].dismiss();
            }
        }
    }

    onNotificationsChanged: _writeFile()

    function _writeFile() {
        _writeProc.command = ["bash", "-c", "cat > /tmp/quickshell-notifs.json << 'JSONEOF'\n" + JSON.stringify(root.history) + "\nJSONEOF"]
        _writeProc.running = true
    }

    Process {
        id: _writeProc
        running: false
    }

    function _remove(notifData): void {
        root.notifications = root.notifications.filter(function(n) {
            return n !== notifData;
        });
        root._writeFile()
    }

    function dismiss(notifData): void {
        if (notifData) notifData.dismiss();
        root._writeFile()
    }

    function dismissAll(): void {
        const toRemove = [...root.notifications];
        root.notifications = [];
        for (const n of toRemove) {
            if (!n.closed) {
                n.closed = true;
                if (n.notification) try { n.notification.dismiss(); } catch(e) {}
                n.destroy();
            }
        }
        root._writeFile()
    }
}
