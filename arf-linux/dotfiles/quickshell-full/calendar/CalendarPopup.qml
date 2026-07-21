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
  WlrLayershell.namespace: "quickshell-calendar"
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
    target: "calendar"
    function toggle(): void {
      root.visible = !root.visible
      root.openX = -1
    }
    function openAt(x: number): void {
      root.openX = x
      root.visible = true
    }
  }

  property int currentYear: new Date().getFullYear()
  property int currentMonth: new Date().getMonth()
  property var today: new Date()

  function getDaysInMonth(year, month) {
    return new Date(year, month + 1, 0).getDate()
  }

  function getFirstDayOfMonth(year, month) {
    let day = new Date(year, month, 1).getDay()
    return day === 0 ? 6 : day - 1
  }

  function getMonthName(month) {
    const names = ["January", "February", "March", "April", "May", "June",
                   "July", "August", "September", "October", "November", "December"]
    return names[month]
  }

  function prevMonth() {
    if (currentMonth === 0) {
      currentMonth = 11
      currentYear--
    } else {
      currentMonth--
    }
  }

  function nextMonth() {
    if (currentMonth === 11) {
      currentMonth = 0
      currentYear++
    } else {
      currentMonth++
    }
  }

  function goToToday() {
    currentYear = today.getFullYear()
    currentMonth = today.getMonth()
  }

  function buildGrid() {
    var days = []
    var firstDay = getFirstDayOfMonth(currentYear, currentMonth)
    var daysInMonth = getDaysInMonth(currentYear, currentMonth)
    var prevMonthDays = getDaysInMonth(currentYear, currentMonth === 0 ? 11 : currentMonth - 1)

    for (var i = firstDay - 1; i >= 0; i--) {
      days.push({ day: prevMonthDays - i, outside: true })
    }
    for (var d = 1; d <= daysInMonth; d++) {
      days.push({ day: d, outside: false })
    }
    var remaining = 42 - days.length
    for (var r = 1; r <= remaining; r++) {
      days.push({ day: r, outside: true })
    }
    return days
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

  // Popup card
  Rectangle {
    width: 320
    height: calendarCol.implicitHeight + 32
    radius: 16
    color: theme.bgBase
    border.color: theme.bgBorder
    border.width: 1

    x: root.openX >= 0 ? Math.max(16, Math.min(root.width - width - 16, root.openX - width / 2)) : 16
    anchors.top: parent.top
    anchors.topMargin: 44

    ColumnLayout {
      id: calendarCol
      anchors.fill: parent
      anchors.margins: 16
      spacing: 8

      // Header: < Month Year >
      RowLayout {
        Layout.fillWidth: true
        spacing: 4

        Rectangle {
          width: 28
          height: 28
          radius: 6
          color: prevMouse.containsMouse ? theme.bgHover : "transparent"

          Text {
            anchors.centerIn: parent
            text: "◀"
            color: theme.textSecondary
            font.pixelSize: 14
            font.family: root.font
          }

          MouseArea {
            id: prevMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.prevMonth()
          }
        }

        Item { Layout.fillWidth: true }

        Rectangle {
          height: 28
          width: monthLabel.implicitWidth + 16
          radius: 6
          color: monthMouse.containsMouse ? theme.bgHover : "transparent"

          Text {
            id: monthLabel
            anchors.centerIn: parent
            text: root.getMonthName(root.currentMonth) + " " + root.currentYear
            color: theme.textPrimary
            font.pixelSize: 14
            font.family: root.font
            font.bold: true
          }

          MouseArea {
            id: monthMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.goToToday()
          }
        }

        Item { Layout.fillWidth: true }

        Rectangle {
          width: 28
          height: 28
          radius: 6
          color: nextMouse.containsMouse ? theme.bgHover : "transparent"

          Text {
            anchors.centerIn: parent
            text: "▶"
            color: theme.textSecondary
            font.pixelSize: 14
            font.family: root.font
          }

          MouseArea {
            id: nextMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.nextMonth()
          }
        }
      }

      // Day-of-week headers
      Row {
        Layout.fillWidth: true
        spacing: 0

        Repeater {
          model: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

          Rectangle {
            width: 40
            height: 24
            color: "transparent"

            Text {
              anchors.centerIn: parent
              text: modelData
              color: theme.textMuted
              font.pixelSize: 11
              font.family: root.font
              font.bold: true
            }
          }
        }
      }

      // Day grid
      Grid {
        columns: 7
        spacing: 0

        Repeater {
          model: root.buildGrid()

          Rectangle {
            width: 40
            height: 36
            radius: 6
            color: {
              var data = modelData
              if (dayMouseArea.containsMouse) return theme.bgHover
              if (!data.outside && root.today.getDate() === data.day &&
                  root.today.getMonth() === root.currentMonth &&
                  root.today.getFullYear() === root.currentYear) {
                return theme.accentPrimary
              }
              return "transparent"
            }

            property var dayData: modelData

            Text {
              anchors.centerIn: parent
              text: modelData.day
              color: {
                var data = modelData
                if (!data.outside && root.today.getDate() === data.day &&
                    root.today.getMonth() === root.currentMonth &&
                    root.today.getFullYear() === root.currentYear) {
                  return theme.bgBase
                }
                if (data.outside) return theme.textMuted
                return theme.textPrimary
              }
              font.pixelSize: 12
              font.family: root.font
            }

            MouseArea {
              id: dayMouseArea
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
            }
          }
        }
      }
    }
  }
}
