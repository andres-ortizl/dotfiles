import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets

Rectangle {
    id: root

    required property var trayItem
    required property var host
    readonly property string itemIdentity: (String(trayItem.id || "") + " " + String(trayItem.title || "") + " " + String(trayItem.tooltipTitle || "")).toLowerCase()
    readonly property bool isSteam: itemIdentity.includes("steam")
    readonly property bool hasMenuActions: trayItem.hasMenu || isSteam

    function focusKnownWindow() {
        const id = String(trayItem.id || "").toLowerCase();
        if (id.includes("steam"))
            Quickshell.execDetached(["hyprctl", "dispatch", "focuswindow", "class:.*steam.*"]);
        else if (id.includes("discord"))
            Quickshell.execDetached(["hyprctl", "dispatch", "focuswindow", "class:.*discord.*"]);
    }

    function openMenu() {
        if (hasMenuActions)
            trayMenu.showMenu();
    }

    function quitSteam() {
        if (isSteam)
            Quickshell.execDetached(["steam", "-shutdown"]);
    }

    height: 70
    radius: 13
    color: itemMouse.containsMouse ? Theme.alpha(Theme.surface, 0.45) : "transparent"

    Behavior on color {
        ColorAnimation { duration: 120 }
    }

    Rectangle {
        x: 9
        y: 9
        width: 44
        height: 44
        radius: 12
        color: root.trayItem.status === Status.NeedsAttention ? Theme.alpha(Theme.danger, 0.20) : Theme.alpha(Theme.surface, 0.20)
        border.width: 1
        border.color: root.trayItem.status === Status.NeedsAttention ? Theme.alpha(Theme.danger, 0.60) : Theme.alpha(Theme.surface, 0.20)

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
        color: Theme.primaryText
        font.family: Ui.fontFamily
        font.pixelSize: Ui.title
        font.bold: true
    }

    Text {
        x: 65
        y: 39
        text: root.trayItem.status === Status.NeedsAttention ? "Needs attention" : root.trayItem.status === Status.Passive ? "Idle" : "Running"
        color: root.trayItem.status === Status.NeedsAttention ? Theme.danger : Theme.mutedText
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
        color: menuMouse.containsMouse ? Theme.alpha(Theme.hoverSurface, 0.40) : "transparent"
        z: 2

        Text {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -3
            text: "..."
            color: menuMouse.containsMouse ? Theme.accentText : Theme.quietText
            font.family: Ui.fontFamily
            font.pixelSize: Ui.title
        }

        MouseArea {
            id: menuMouse

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: root.openMenu()
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
                root.openMenu();
            } else {
                root.trayItem.activate();
                Qt.callLater(root.focusKnownWindow);
                root.host.open = false;
            }
        }

        onWheel: wheel => root.trayItem.scroll(wheel.angleDelta.y, false)
    }

    TrayMenu {
        id: trayMenu

        host: root.host
        anchorItem: menuButton
        menu: root.trayItem.menu
        title: root.trayItem.tooltipTitle || root.trayItem.title || root.trayItem.id || "Application"
        extraActionText: root.isSteam ? "Exit Steam" : ""
        onExtraActionTriggered: root.quitSteam()
        onActionTriggered: root.host.open = false
    }
}
