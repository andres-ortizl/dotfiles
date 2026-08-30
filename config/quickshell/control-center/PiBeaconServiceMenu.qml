import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: root

    property bool open: false
    property bool grabReady: false
    property bool closeOnFocusLoss: false
    property string serviceState: "unknown"
    property string pendingAction: ""
    property int topMargin: 46
    property int rightMargin: 12

    property var theme: defaultTheme
    property string fontFamily: theme.fontFamily
    property color panelColor: theme.panel
    property color surfaceColor: theme.surface
    property color raisedColor: theme.raised
    property color borderColor: theme.border
    property color primaryText: theme.primaryText
    property color mutedText: theme.mutedText
    property color quietText: theme.quietText
    property color accentColor: theme.accent
    property color successColor: theme.success
    property color warningColor: theme.warning
    property color dangerColor: theme.danger

    readonly property bool serviceActive: serviceState === "active"
    readonly property bool busy: controlProcess.running

    PiBeaconTheme {
        id: defaultTheme
    }

    visible: open
    color: "transparent"
    implicitWidth: 280
    implicitHeight: 304
    exclusionMode: ExclusionMode.Ignore
    focusable: true
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.namespace: "quickshell:pi-beacon-service-menu"

    anchors {
        top: true
        right: true
    }

    margins {
        top: root.topMargin
        right: root.rightMargin
    }

    mask: Region {
        item: background
        radius: 16
    }

    BackgroundEffect.blurRegion: Region {
        item: background
        radius: 16
    }

    function alpha(color, opacity) {
        return Qt.rgba(color.r, color.g, color.b, opacity);
    }

    function refreshStatus() {
        if (!statusProcess.running)
            statusProcess.running = true;
    }

    function showMenu() {
        open = true;
        forceActiveFocus();
        grabReady = false;
        refreshStatus();
        focusDelay.restart();
    }

    function hideMenu() {
        open = false;
        grabReady = false;
    }

    function toggleMenu() {
        if (open)
            hideMenu();
        else
            showMenu();
    }

    function runAction(action) {
        if (busy)
            return;
        pendingAction = action;
        if (action === "disable")
            controlProcess.command = ["systemctl", "--user", "disable", "--now", "pi-beacon.service"];
        else
            controlProcess.command = ["systemctl", "--user", action, "pi-beacon.service"];
        controlProcess.running = true;
    }

    Rectangle {
        id: background

        anchors.fill: parent
        radius: 16
        color: root.panelColor
        border.width: 1
        border.color: root.borderColor
    }

    Column {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 4

        Item {
            width: parent.width
            height: 42

            Column {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                Text {
                    text: "PI BEACON"
                    color: root.mutedText
                    font.family: root.fontFamily
                    font.pixelSize: 11
                    font.bold: true
                    font.letterSpacing: 0.8
                }

                Text {
                    text: root.serviceState === "active" ? "Service running" : "Service stopped"
                    color: root.serviceActive ? root.successColor : root.warningColor
                    font.family: root.fontFamily
                    font.pixelSize: 10
                }
            }

            Rectangle {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 30
                height: 30
                radius: 9
                color: closeMouse.containsMouse ? root.alpha(root.dangerColor, 0.18) : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: "×"
                    color: closeMouse.containsMouse ? root.dangerColor : root.quietText
                    font.family: root.fontFamily
                    font.pixelSize: 16
                }

                MouseArea {
                    id: closeMouse

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.hideMenu()
                }
            }
        }

        Repeater {
            model: [
                { label: "Start Pi Beacon", detail: "Start the local service", action: "start", danger: false },
                { label: "Restart service", detail: "Reconnect all dashboard clients", action: "restart", danger: false },
                { label: "Quit Pi Beacon", detail: "Stop now, keep login autostart", action: "stop", danger: true },
                { label: "Disable at login", detail: "Stop now and disable autostart", action: "disable", danger: true }
            ]

            delegate: Rectangle {
                id: actionRow

                required property var modelData
                readonly property bool actionEnabled: !root.busy
                    && (modelData.action === "start"
                        ? !root.serviceActive
                        : modelData.action === "disable" || root.serviceActive)

                width: parent.width
                height: 50
                radius: 11
                color: actionMouse.containsMouse && actionEnabled
                    ? root.alpha(modelData.danger ? root.dangerColor : root.accentColor, 0.15)
                    : root.surfaceColor
                opacity: actionEnabled ? 1 : 0.45

                Text {
                    x: 12
                    y: 8
                    text: actionRow.modelData.label
                    color: actionRow.modelData.danger ? root.dangerColor : root.primaryText
                    font.family: root.fontFamily
                    font.pixelSize: 11
                    font.bold: true
                }

                Text {
                    x: 12
                    y: 27
                    width: parent.width - 24
                    text: actionRow.modelData.detail
                    color: root.quietText
                    elide: Text.ElideRight
                    font.family: root.fontFamily
                    font.pixelSize: 9
                }

                MouseArea {
                    id: actionMouse

                    anchors.fill: parent
                    enabled: actionRow.actionEnabled
                    hoverEnabled: true
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: root.runAction(actionRow.modelData.action)
                }
            }
        }

        Text {
            width: parent.width
            height: 20
            text: root.busy ? `Running ${root.pendingAction}…` : "Right-click the Waybar module to reopen"
            color: root.busy ? root.accentColor : root.quietText
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            font.family: root.fontFamily
            font.pixelSize: 9
        }
    }

    Process {
        id: statusProcess

        command: ["systemctl", "--user", "is-active", "pi-beacon.service"]
        stdout: SplitParser {
            onRead: line => root.serviceState = String(line || "unknown").trim()
        }
    }

    Process {
        id: controlProcess

        onExited: statusRefresh.restart()
    }

    Timer {
        id: statusRefresh

        interval: 350
        repeat: false
        onTriggered: root.refreshStatus()
    }

    Timer {
        id: focusDelay

        interval: 120
        repeat: false
        onTriggered: root.grabReady = root.open
    }

    onOpenChanged: {
        if (open)
            refreshStatus();
    }

    IpcHandler {
        target: "piBeaconServiceMenu"

        function toggle(): void {
            root.toggleMenu();
        }

        function openMenu(): void {
            root.showMenu();
        }

        function close(): void {
            root.hideMenu();
        }

        function startService(): void {
            root.runAction("start");
        }

        function restartService(): void {
            root.runAction("restart");
        }

        function quit(): void {
            root.runAction("stop");
        }

        function disableAtLogin(): void {
            root.runAction("disable");
        }

        function isOpen(): bool {
            return root.open;
        }
    }

    Shortcut {
        sequence: "Escape"
        context: Qt.WindowShortcut
        enabled: root.open
        onActivated: root.hideMenu()
    }

    HyprlandFocusGrab {
        windows: [root]
        active: root.grabReady && root.closeOnFocusLoss
        onCleared: {
            if (root.grabReady && root.closeOnFocusLoss)
                root.hideMenu();
        }
    }
}
