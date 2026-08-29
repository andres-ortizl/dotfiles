import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: root

    property bool open: false
    property bool grabReady: false
    property string executable: Quickshell.env("PI_BEACON_EXECUTABLE") || Quickshell.env("HOME") + "/.local/bin/pi-beacon"
    property string streamExecutable: Quickshell.env("PI_BEACON_STREAM_EXECUTABLE") || Quickshell.env("HOME") + "/.local/bin/pi-beacon-stream"
    property int refreshInterval: 3000
    property int topMargin: 78
    property int rightMargin: 12
    property int recentLimit: 3
    property bool showCost: true
    property bool showContext: true
    property bool showRecent: true
    property bool closeOnFocusLoss: true

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
    property color accentText: theme.accentText
    property color successColor: theme.success
    property color warningColor: theme.warning
    property color dangerColor: theme.danger

    property int panelWidth: 470
    property int panelMaxHeight: 700
    property int panelRadius: 18
    property int cardRadius: 13
    property int contentPadding: 12
    property int contentGap: 9

    PiBeaconTheme {
        id: defaultTheme
    }

    property var snapshotData: ({
        runtime: { sessions: [], subagents: [], sessionCount: 0, subagentCount: 0 },
        today: { cost: 0, tokens: 0, sessions: 0, messages: 0, recent: [] }
    })
    property string loadError: ""
    property string expandedSessionId: ""

    readonly property var runtimeData: snapshotData.runtime || ({})
    readonly property var todayData: snapshotData.today || ({})
    readonly property var liveSessions: runtimeData.sessions || []
    readonly property var subagents: runtimeData.agents !== undefined ? runtimeData.agents : runtimeData.subagents || []
    readonly property var recentSessions: todayData.recent || []

    visible: open
    color: "transparent"
    implicitWidth: root.panelWidth
    implicitHeight: Math.min(root.panelMaxHeight, content.implicitHeight + root.contentPadding * 2)
    exclusionMode: ExclusionMode.Ignore
    focusable: true
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.namespace: "quickshell:pi-beacon"

    anchors {
        top: true
        right: true
    }

    margins {
        top: root.topMargin
        right: root.rightMargin
    }

    mask: Region {
        item: card
        radius: root.panelRadius
    }

    BackgroundEffect.blurRegion: Region {
        item: card
        radius: root.panelRadius
    }

    function alpha(color, opacity) {
        return Qt.rgba(color.r, color.g, color.b, opacity);
    }

    function stateColor(state) {
        if (state === "running")
            return successColor;
        if (state === "waiting" || state === "paused" || state === "needs_attention")
            return warningColor;
        return quietText;
    }

    function compact(value) {
        const number = Number(value) || 0;
        if (number >= 1000000)
            return (number / 1000000).toFixed(1) + "M";
        if (number >= 1000)
            return (number / 1000).toFixed(1) + "k";
        return String(Math.round(number));
    }

    function cost(value) {
        return "$" + (Number(value) || 0).toFixed(2);
    }

    function modelName(value) {
        const model = String(value || "Unknown model");
        const pieces = model.split("/");
        return pieces[pieces.length - 1];
    }

    function formatTime(value) {
        if (value === undefined || value === null || value === "")
            return "unknown";
        const date = new Date(value);
        if (Number.isNaN(date.getTime()))
            return "unknown";
        return date.toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" });
    }

    function refresh() {
        if (!snapshotProcess.running)
            snapshotProcess.running = true;
    }

    Rectangle {
        id: card

        anchors.fill: parent
        radius: root.panelRadius
        color: root.panelColor
        border.width: 1
        border.color: root.borderColor
    }

    Flickable {
        anchors.fill: parent
        anchors.margins: root.contentPadding
        clip: true
        contentHeight: content.implicitHeight
        interactive: contentHeight > height

        Column {
            id: content

            width: parent.width
            spacing: root.contentGap

            Item {
                width: parent.width
                height: 38

                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "PI BEACON"
                    color: root.mutedText
                    font.family: root.fontFamily
                    font.pixelSize: 12
                    font.bold: true
                    font.letterSpacing: 1
                }

                Text {
                    anchors.right: closeButton.left
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    text: `${root.runtimeData.sessionCount || 0} live • ${root.runtimeData.subagentCount || 0} agents`
                    color: root.quietText
                    font.family: root.fontFamily
                    font.pixelSize: 11
                }

                Rectangle {
                    id: closeButton

                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 32
                    height: 32
                    radius: 10
                    color: closeMouse.containsMouse ? root.alpha(root.dangerColor, 0.18) : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: "×"
                        color: closeMouse.containsMouse ? root.dangerColor : root.quietText
                        font.family: root.fontFamily
                        font.pixelSize: 17
                    }

                    MouseArea {
                        id: closeMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.open = false
                    }
                }
            }

            Row {
                width: parent.width
                height: 72
                spacing: 8

                Repeater {
                    model: [
                        { label: "COST", value: root.showCost ? root.cost(root.todayData.cost) : "hidden" },
                        { label: "TOKENS", value: root.compact(root.todayData.tokens) },
                        { label: "SESSIONS", value: String(root.todayData.sessions || 0) },
                        { label: "MESSAGES", value: String(root.todayData.messages || 0) }
                    ]

                    delegate: Rectangle {
                        required property var modelData
                        width: (parent.width - parent.spacing * 3) / 4
                        height: parent.height
                        radius: root.cardRadius
                        color: root.alpha(root.surfaceColor, 0.58)

                        Text {
                            x: 10
                            y: 10
                            text: parent.modelData.label
                            color: root.quietText
                            font.family: root.fontFamily
                            font.pixelSize: 10
                            font.bold: true
                        }

                        Text {
                            x: 10
                            y: 35
                            width: parent.width - 20
                            text: parent.modelData.value
                            color: root.primaryText
                            elide: Text.ElideRight
                            font.family: root.fontFamily
                            font.pixelSize: 14
                            font.bold: true
                        }
                    }
                }
            }

            Text {
                width: parent.width
                height: 22
                text: "LIVE SESSIONS"
                color: root.mutedText
                verticalAlignment: Text.AlignBottom
                font.family: root.fontFamily
                font.pixelSize: 11
                font.bold: true
                font.letterSpacing: 0.8
            }

            Repeater {
                model: root.liveSessions

                delegate: Rectangle {
                    id: sessionRow

                    required property var modelData
                    readonly property bool expanded: root.expandedSessionId === String(modelData.sessionId || "")
                    width: content.width
                    height: expanded ? 136 : 86
                    radius: root.cardRadius
                    color: sessionMouse.containsMouse ? root.alpha(root.surfaceColor, 0.55) : root.alpha(root.surfaceColor, 0.30)
                    border.width: 1
                    border.color: root.alpha(root.stateColor(modelData.state), 0.60)

                    Rectangle {
                        x: 14
                        y: 17
                        width: 9
                        height: 9
                        radius: 5
                        color: root.stateColor(sessionRow.modelData.state)
                    }

                    Text {
                        x: 34
                        y: 10
                        width: parent.width - 150
                        text: sessionRow.modelData.displayName || sessionRow.modelData.sessionName || sessionRow.modelData.project || "Pi session"
                        color: root.primaryText
                        elide: Text.ElideRight
                        font.family: root.fontFamily
                        font.pixelSize: 14
                        font.bold: true
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.rightMargin: 14
                        y: 11
                        text: sessionRow.modelData.state || "open"
                        color: root.stateColor(sessionRow.modelData.state)
                        font.family: root.fontFamily
                        font.pixelSize: 11
                        font.bold: true
                    }

                    Text {
                        x: 34
                        y: 35
                        width: parent.width - 48
                        text: `${root.modelName(sessionRow.modelData.model)} • ${sessionRow.modelData.thinking || "default"} • ${sessionRow.modelData.detail || "Ready"}`
                        color: root.mutedText
                        elide: Text.ElideRight
                        font.family: root.fontFamily
                        font.pixelSize: 11
                    }

                    Text {
                        x: 34
                        y: 58
                        width: parent.width - 48
                        text: {
                            const usage = sessionRow.modelData.usage || {};
                            const context = sessionRow.modelData.context || {};
                            const values = [`${root.compact(usage.totalTokens)} tokens`, root.cost(usage.cost)];
                            if (root.showContext && context.percent !== undefined && context.percent !== null)
                                values.push(`${Number(context.percent).toFixed(1)}% context`);
                            if (sessionRow.modelData.elapsed)
                                values.push(sessionRow.modelData.elapsed);
                            return values.join(" • ");
                        }
                        color: root.quietText
                        elide: Text.ElideRight
                        font.family: root.fontFamily
                        font.pixelSize: 10
                    }

                    Text {
                        x: 34
                        y: 84
                        width: parent.width - 48
                        visible: sessionRow.expanded
                        text: `Path  ${sessionRow.modelData.sessionFile || sessionRow.modelData.cwd || "not persisted"}`
                        color: root.mutedText
                        elide: Text.ElideMiddle
                        font.family: root.fontFamily
                        font.pixelSize: 10
                    }

                    Text {
                        x: 34
                        y: 108
                        width: parent.width - 48
                        visible: sessionRow.expanded
                        text: `Started ${root.formatTime(sessionRow.modelData.startedAt)} • Last message ${root.formatTime(sessionRow.modelData.lastMessageAt)} • ID ${String(sessionRow.modelData.sessionId || "").slice(0, 8)}`
                        color: root.quietText
                        elide: Text.ElideRight
                        font.family: root.fontFamily
                        font.pixelSize: 10
                    }

                    Behavior on height {
                        NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
                    }

                    MouseArea {
                        id: sessionMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            const id = String(sessionRow.modelData.sessionId || "");
                            root.expandedSessionId = sessionRow.expanded ? "" : id;
                        }
                    }
                }
            }

            Text {
                width: parent.width
                height: root.liveSessions.length === 0 ? 48 : 0
                visible: height > 0
                text: "No live session bridge yet. Run /reload inside Pi."
                color: root.mutedText
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                font.family: root.fontFamily
                font.pixelSize: 12
            }

            Text {
                width: parent.width
                height: root.subagents.length > 0 ? 22 : 0
                visible: height > 0
                text: "ACTIVE SUBAGENTS"
                color: root.mutedText
                verticalAlignment: Text.AlignBottom
                font.family: root.fontFamily
                font.pixelSize: 11
                font.bold: true
                font.letterSpacing: 0.8
            }

            Repeater {
                model: root.subagents

                delegate: Rectangle {
                    id: agentRow

                    required property var modelData
                    width: content.width
                    height: 52
                    radius: root.cardRadius
                    color: root.alpha(root.surfaceColor, 0.24)

                    Text {
                        x: 14
                        anchors.verticalCenter: parent.verticalCenter
                        text: "↳"
                        color: root.stateColor(agentRow.modelData.state)
                        font.family: root.fontFamily
                        font.pixelSize: 15
                        font.bold: true
                    }

                    Text {
                        x: 40
                        y: 8
                        width: parent.width - 120
                        text: agentRow.modelData.agent || "agent"
                        color: root.primaryText
                        font.family: root.fontFamily
                        font.pixelSize: 12
                        font.bold: true
                    }

                    Text {
                        x: 40
                        y: 29
                        width: parent.width - 54
                        text: agentRow.modelData.task || agentRow.modelData.state || "running"
                        color: root.mutedText
                        elide: Text.ElideRight
                        font.family: root.fontFamily
                        font.pixelSize: 10
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.rightMargin: 14
                        y: 9
                        text: agentRow.modelData.elapsed || agentRow.modelData.state
                        color: root.stateColor(agentRow.modelData.state)
                        font.family: root.fontFamily
                        font.pixelSize: 10
                    }
                }
            }

            Text {
                width: parent.width
                height: root.showRecent && root.recentSessions.length > 0 ? 22 : 0
                visible: height > 0
                text: "RECENT TODAY"
                color: root.mutedText
                verticalAlignment: Text.AlignBottom
                font.family: root.fontFamily
                font.pixelSize: 11
                font.bold: true
                font.letterSpacing: 0.8
            }

            Repeater {
                model: root.showRecent ? root.recentSessions.slice(0, root.recentLimit) : []

                delegate: Item {
                    id: recentRow

                    required property var modelData
                    width: content.width
                    height: 38

                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 170
                        text: recentRow.modelData.project || "session"
                        color: root.mutedText
                        elide: Text.ElideRight
                        font.family: root.fontFamily
                        font.pixelSize: 11
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: `${root.compact(recentRow.modelData.tokens)} • ${root.cost(recentRow.modelData.cost)}`
                        color: root.quietText
                        font.family: root.fontFamily
                        font.pixelSize: 10
                    }
                }
            }

            Text {
                width: parent.width
                height: root.loadError ? 38 : 0
                visible: height > 0
                text: root.loadError
                color: root.dangerColor
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                font.family: root.fontFamily
                font.pixelSize: 11
            }
        }
    }

    Process {
        id: snapshotProcess
        command: [root.streamExecutable, "--format", "snapshot"]
        stdout: SplitParser {
            onRead: line => {
                try {
                    root.snapshotData = JSON.parse(line);
                    root.loadError = "";
                } catch (error) {
                    root.loadError = "Invalid Pi Beacon snapshot";
                }
            }
        }
        stderr: SplitParser {
            onRead: line => root.loadError = String(line || "Pi Beacon failed").trim()
        }
        onExited: {
            if (root.open)
                reconnectTimer.restart();
        }
    }

    Timer {
        id: reconnectTimer
        interval: root.refreshInterval
        repeat: false
        onTriggered: root.refresh()
    }

    Timer {
        id: focusDelay
        interval: 150
        onTriggered: root.grabReady = root.open
    }

    onOpenChanged: {
        grabReady = false;
        if (open) {
            refresh();
            focusDelay.restart();
        } else {
            reconnectTimer.stop();
            snapshotProcess.running = false;
        }
    }

    IpcHandler {
        target: "piBeacon"

        function toggle(): void {
            root.open = !root.open;
        }

        function close(): void {
            root.open = false;
        }

        function refresh(): void {
            root.refresh();
        }
    }

    Shortcut {
        sequence: "Escape"
        context: Qt.WindowShortcut
        enabled: root.open
        onActivated: root.open = false
    }

    HyprlandFocusGrab {
        windows: [root]
        active: root.grabReady && root.closeOnFocusLoss
        onCleared: {
            if (root.grabReady && root.closeOnFocusLoss)
                root.open = false;
        }
    }
}
