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
    property int panelMinHeight: 380
    property int panelMaxHeight: 700
    property int panelRadius: 18
    property int cardRadius: 12
    property int controlRadius: 8
    property int contentPadding: 12
    property int contentGap: 8
    property int sectionGap: 16
    property int cardPadding: 12
    property int rowHeight: 64
    property int detailHeight: 104
    property int fontCaption: 10
    property int fontBody: 11
    property int fontRowTitle: 13
    property int fontTitle: 15
    property int fontMetric: 20

    property string currentTab: "overview"
    property string selectedActivityIdentity: ""
    property string selectedModel: ""

    PiBeaconTheme {
        id: defaultTheme
    }

    property var snapshotData: ({
        runtime: {
            sessions: [],
            subagents: [],
            agents: [],
            activity: [],
            unattachedAgents: [],
            modelActivity: [],
            sessionCount: 0,
            subagentCount: 0,
            attentionCount: 0
        },
        today: { cost: 0, tokens: 0, sessions: 0, messages: 0, recent: [] },
        history: { dailyCost: [], modelUsageToday: [], modelUsage7d: [] },
        update: { currentVersion: "", latestVersion: "", available: false }
    })
    property string loadError: ""

    readonly property var runtimeData: snapshotData.runtime || ({})
    readonly property var todayData: snapshotData.today || ({})
    readonly property var historyData: snapshotData.history || ({})
    readonly property var updateData: snapshotData.update || ({})
    readonly property bool bodyScrollable: viewport.contentHeight > viewport.height + 1
    readonly property bool moreBelow: bodyScrollable && viewport.contentY < viewport.contentHeight - viewport.height - 2

    visible: open
    color: "transparent"
    implicitWidth: root.panelWidth
    implicitHeight: Math.min(
        root.panelMaxHeight,
        Math.max(
            root.panelMinHeight,
            root.contentPadding * 2 + 38 + root.contentGap + 34 + root.contentGap + bodyContent.implicitHeight
        )
    )
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
        if (state === "failed")
            return dangerColor;
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

    function descendantCount(node) {
        const children = node && node.children ? node.children : [];
        let count = children.length;
        for (let index = 0; index < children.length; index++)
            count += descendantCount(children[index]);
        return count;
    }

    function countLabel(value, singular) {
        const count = Number(value) || 0;
        return `${count} ${singular}${count === 1 ? "" : "s"}`;
    }

    function providerName(value) {
        const pieces = String(value || "").split("/");
        if (pieces.length < 2 || !pieces[0])
            return "";
        const provider = pieces[0].toLowerCase();
        const labels = {
            "github-copilot": "GitHub Copilot",
            "openai": "OpenAI",
            "openai-codex": "OpenAI Codex",
            "openrouter": "OpenRouter",
            "xai": "xAI"
        };
        return labels[provider] || provider.charAt(0).toUpperCase() + provider.slice(1);
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

    function scrollToTop() {
        viewport.contentY = 0;
    }

    Rectangle {
        id: card

        anchors.fill: parent
        radius: root.panelRadius
        color: root.panelColor
        border.width: 1
        border.color: root.borderColor
    }

    Item {
        id: layout

        anchors.fill: parent
        anchors.margins: root.contentPadding

        Item {
            id: header

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: 38

            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "PI BEACON"
                color: root.mutedText
                font.family: root.fontFamily
                font.pixelSize: root.fontBody
                font.bold: true
                font.letterSpacing: 1
            }

            Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: root.updateData.available
                    ? `UPDATE ${root.updateData.latestVersion} ↑`
                    : `${root.countLabel(root.runtimeData.sessionCount, "session")} • ${root.countLabel(root.runtimeData.subagentCount, "subagent")}`
                color: root.updateData.available ? root.accentText : root.quietText
                font.family: root.fontFamily
                font.pixelSize: root.fontCaption
                font.bold: root.updateData.available === true
            }
        }

        Row {
            id: tabRow

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: header.bottom
            anchors.topMargin: root.contentGap
            height: 34
            spacing: 4

            Repeater {
                model: [
                    { key: "overview", label: "OVERVIEW" },
                    { key: "activity", label: "ACTIVITY" },
                    { key: "models", label: "MODELS" }
                ]

                delegate: Rectangle {
                    required property var modelData

                    width: (tabRow.width - tabRow.spacing * 2) / 3
                    height: tabRow.height
                    radius: root.controlRadius
                    color: tabMouse.containsMouse ? root.alpha(root.surfaceColor, 0.42) : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: parent.modelData.label
                        color: root.currentTab === parent.modelData.key ? root.accentText : root.mutedText
                        font.family: root.fontFamily
                        font.pixelSize: root.fontCaption
                        font.bold: true
                        font.letterSpacing: 0.5
                    }

                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        width: root.currentTab === parent.modelData.key ? 42 : 0
                        height: 2
                        radius: 1
                        color: root.accentColor

                        Behavior on width {
                            NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
                        }
                    }

                    MouseArea {
                        id: tabMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.currentTab = parent.modelData.key
                    }
                }
            }
        }

        Flickable {
            id: viewport

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: tabRow.bottom
            anchors.topMargin: root.contentGap
            anchors.bottom: parent.bottom
            clip: true
            contentWidth: width
            contentHeight: bodyContent.implicitHeight
            interactive: root.bodyScrollable
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: bodyContent

                width: viewport.width
                spacing: root.contentGap

                Loader {
                    id: dashboardView

                    width: parent.width
                    sourceComponent: root.currentTab === "activity"
                        ? activityView
                        : root.currentTab === "models" ? modelsView : overviewView
                    onLoaded: {
                        if (item)
                            item.dashboard = root;
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
                    font.pixelSize: root.fontBody
                }

                Item {
                    width: parent.width
                    height: root.cardPadding
                }
            }
        }
    }

    Rectangle {
        anchors.right: card.right
        anchors.rightMargin: 4
        y: layout.y + viewport.y
        width: 3
        height: viewport.height
        radius: 2
        visible: root.bodyScrollable
        color: root.alpha(root.borderColor, 0.55)

        Rectangle {
            y: (parent.height - height) * viewport.contentY / Math.max(1, viewport.contentHeight - viewport.height)
            width: parent.width
            height: Math.max(28, parent.height * viewport.height / Math.max(viewport.contentHeight, viewport.height))
            radius: parent.radius
            color: root.alpha(root.mutedText, 0.62)
        }
    }

    Rectangle {
        anchors.left: card.left
        anchors.right: card.right
        anchors.bottom: card.bottom
        anchors.margins: 1
        height: 30
        visible: root.moreBelow
        color: "transparent"
        gradient: Gradient {
            GradientStop { position: 0; color: "transparent" }
            GradientStop { position: 1; color: root.panelColor }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 3
            text: "↓"
            color: root.quietText
            font.family: root.fontFamily
            font.pixelSize: root.fontBody
        }
    }

    Component {
        id: overviewView

        PiBeaconOverview {}
    }

    Component {
        id: activityView

        PiBeaconActivity {}
    }

    Component {
        id: modelsView

        PiBeaconModels {}
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

    Behavior on implicitHeight {
        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
    }

    onCurrentTabChanged: scrollToTop()

    onOpenChanged: {
        grabReady = false;
        if (open) {
            scrollToTop();
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
