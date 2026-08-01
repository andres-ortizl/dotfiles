import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets

Rectangle {
    id: root

    required property var trayItem
    required property var host

    function focusKnownWindow() {
        const id = String(trayItem.id || "").toLowerCase();
        if (id.includes("steam"))
            Quickshell.execDetached(["hyprctl", "dispatch", "focuswindow", "class:.*steam.*"]);
        else if (id.includes("discord"))
            Quickshell.execDetached(["hyprctl", "dispatch", "focuswindow", "class:.*discord.*"]);
    }

    height: 70
    radius: 13
    color: itemMouse.containsMouse ? "#73414558" : "transparent"

    Behavior on color {
        ColorAnimation { duration: 120 }
    }

    Rectangle {
        x: 9
        y: 9
        width: 44
        height: 44
        radius: 12
        color: root.trayItem.status === Status.NeedsAttention ? "#33ff80bf" : "#33414558"
        border.width: 1
        border.color: root.trayItem.status === Status.NeedsAttention ? "#99ff80bf" : "#33414558"

        IconImage {
            anchors.centerIn: parent
            implicitSize: 27
            source: root.trayItem.icon
            asynchronous: true
            mipmap: true
        }
    }

    Text {
        x: 65
        y: 11
        width: parent.width - 96
        text: root.trayItem.tooltipTitle || root.trayItem.title || root.trayItem.id || "Application"
        elide: Text.ElideRight
        color: "#f8f8f2"
        font.family: Ui.fontFamily
        font.pixelSize: Ui.title
        font.bold: true
    }

    Text {
        x: 65
        y: 39
        text: root.trayItem.status === Status.NeedsAttention ? "Needs attention" : root.trayItem.status === Status.Passive ? "Idle" : "Running"
        color: root.trayItem.status === Status.NeedsAttention ? "#ff80bf" : "#a7abbe"
        font.family: Ui.fontFamily
        font.pixelSize: Ui.caption
    }

    Rectangle {
        id: menuButton

        anchors.right: parent.right
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        width: 34
        height: 34
        radius: 10
        color: menuMouse.containsMouse ? "#665f5575" : "transparent"
        z: 2

        Text {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -3
            text: "..."
            color: menuMouse.containsMouse ? "#d4ccff" : "#626784"
            font.family: Ui.fontFamily
            font.pixelSize: Ui.title
        }

        MouseArea {
            id: menuMouse

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: {
                if (root.trayItem.hasMenu)
                    trayMenu.open();
            }
        }
    }

    MouseArea {
        id: itemMouse

        anchors.left: parent.left
        anchors.right: menuButton.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

        onClicked: mouse => {
            if (mouse.button === Qt.MiddleButton) {
                root.trayItem.secondaryActivate();
            } else if (mouse.button === Qt.RightButton || root.trayItem.onlyMenu) {
                if (root.trayItem.hasMenu)
                    trayMenu.open();
            } else {
                root.trayItem.activate();
                Qt.callLater(root.focusKnownWindow);
                root.host.open = false;
            }
        }

        onWheel: wheel => root.trayItem.scroll(wheel.angleDelta.y, false)
    }

    QsMenuAnchor {
        id: trayMenu

        menu: root.trayItem.menu
        anchor.item: root
        anchor.edges: Edges.Left | Edges.Bottom
        anchor.gravity: Edges.Right | Edges.Bottom

        onOpened: root.host.openMenuCount++
        onClosed: root.host.openMenuCount = Math.max(0, root.host.openMenuCount - 1)
    }
}
