import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Wayland

PanelWindow {
    id: root

    property bool open: false
    property bool grabReady: false
    readonly property var defaultSink: Pipewire.defaultAudioSink
    readonly property int defaultVolume: Math.round((defaultSink?.audio?.volume ?? 0) * 100)
    readonly property bool defaultMuted: defaultSink?.audio?.muted ?? false
    readonly property var outputNodes: [...Pipewire.nodes.values]
        .filter(node => node.audio !== null && node.isSink && !node.isStream)
        .sort((left, right) => rankOutput(left) - rankOutput(right))
    readonly property string switchScript: Quickshell.env("HOME") + "/.config/quickshell/control-center/switch-audio-output.sh"
    readonly property bool hyperxSelected: defaultSink !== null && outputName(defaultSink) === "HyperX Cloud Flight"
    readonly property string eqScript: Quickshell.env("HOME") + "/.config/quickshell/control-center/easyeffects-profile.sh"
    property bool eqActive: false

    visible: open
    color: "transparent"
    implicitWidth: 430
    implicitHeight: Math.min(650, content.implicitHeight + 24)
    exclusionMode: ExclusionMode.Ignore
    focusable: true
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell:audio"

    anchors {
        top: true
        right: true
    }

    margins {
        top: 78
        right: 12
    }

    mask: Region {
        item: card
        radius: 18
    }

    BackgroundEffect.blurRegion: Region {
        item: card
        radius: 18
    }

    function rankOutput(node) {
        const description = String(node?.description || node?.nickname || node?.name || "").toLowerCase();
        if (description.includes("hyperx") || description.includes("cloud flight"))
            return 0;
        if (description.includes("gb205"))
            return 1;
        return 10;
    }

    function outputName(node) {
        const description = String(node?.description || node?.nickname || node?.name || "Audio output");
        const normalized = description.toLowerCase();
        if (normalized.includes("hyperx") || normalized.includes("cloud flight"))
            return "HyperX Cloud Flight";
        if (normalized.includes("gb205"))
            return "GB205 monitor speakers";
        return description;
    }

    function outputIcon(node) {
        const description = outputName(node).toLowerCase();
        if (description.includes("headphone") || description.includes("headset") || description.includes("hyperx"))
            return "󰋋";
        if (description.includes("hdmi") || description.includes("monitor") || description.includes("gb205"))
            return "󰍹";
        if (description.includes("speaker"))
            return "󰓃";
        if (description.includes("s/pdif") || description.includes("digital"))
            return "󰝚";
        return "󰕾";
    }

    function isDefault(node) {
        return defaultSink !== null && node.name === defaultSink.name;
    }

    function selectOutput(node) {
        if (!node)
            return;
        Pipewire.preferredDefaultAudioSink = node;
        Quickshell.execDetached([switchScript, node.name]);
    }

    function setDefaultVolume(value) {
        if (!defaultSink?.audio)
            return;
        const normalized = Math.max(0, Math.min(1, value));
        defaultSink.audio.volume = normalized;
        if (normalized > 0 && defaultSink.audio.muted)
            defaultSink.audio.muted = false;
    }

    function refreshEqStatus() {
        if (!eqStatusProcess.running)
            eqStatusProcess.running = true;
    }

    function runEqAction(action) {
        if (eqActionProcess.running || (action !== "off" && !hyperxSelected))
            return;
        eqActionProcess.requestedAction = action;
        eqActionProcess.running = true;
    }

    PwObjectTracker {
        objects: root.outputNodes
    }

    Rectangle {
        id: card

        anchors.fill: parent
        radius: 18
        color: Theme.alpha(Theme.panel, 0.96)
        border.width: 1
        border.color: Theme.alpha(Theme.surface, 0.45)
    }

    Column {
        id: content

        x: 12
        y: 12
        width: parent.width - 24
        spacing: 8

        Item {
            width: parent.width
            height: 38

            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "AUDIO OUTPUT"
                color: Theme.mutedText
                font.family: Ui.fontFamily
                font.pixelSize: 12
                font.bold: true
                font.letterSpacing: 1
            }

            Rectangle {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 32
                height: 32
                radius: 10
                color: closeMouse.containsMouse ? Theme.alpha(Theme.dangerSurface, 0.70) : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: "×"
                    color: closeMouse.containsMouse ? Theme.danger : Theme.quietText
                    font.family: Ui.fontFamily
                    font.pixelSize: Ui.heading
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

        Rectangle {
            width: parent.width
            height: 106
            radius: 14
            color: Theme.alpha(Theme.surface, 0.30)

            Text {
                x: 14
                y: 12
                width: parent.width - 176
                text: root.defaultSink ? root.outputName(root.defaultSink) : "No audio output"
                color: Theme.primaryText
                elide: Text.ElideRight
                font.family: Ui.fontFamily
                font.pixelSize: Ui.title
                font.bold: true
            }

            Text {
                x: 14
                y: 37
                width: parent.width - 176
                elide: Text.ElideRight
                text: (root.defaultMuted ? "Muted" : `${root.defaultVolume}%`) + (root.hyperxSelected ? (eqActionProcess.running ? " • AUTOEQ • RAP …" : root.eqActive ? " • AUTOEQ • RAP ON" : " • AUTOEQ • RAP OFF") : "")
                color: root.defaultMuted ? Theme.danger : root.eqActive ? Theme.accentText : Theme.mutedText
                font.family: Ui.fontFamily
                font.pixelSize: Ui.caption
            }

            Rectangle {
                id: muteButton

                anchors.right: parent.right
                anchors.rightMargin: 12
                y: 12
                width: 44
                height: 38
                radius: 11
                color: muteMouse.containsMouse ? Theme.alpha(Theme.hoverSurface, 0.40) : Theme.alpha(Theme.surface, 0.28)

                Text {
                    anchors.centerIn: parent
                    text: root.defaultMuted ? "󰖁" : "󰕾"
                    color: root.defaultMuted ? Theme.danger : Theme.accentText
                    font.family: Ui.fontFamily
                    font.pixelSize: Ui.icon
                }

                MouseArea {
                    id: muteMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    enabled: root.defaultSink?.audio !== null
                    onClicked: root.defaultSink.audio.muted = !root.defaultSink.audio.muted
                }
            }

            Rectangle {
                id: eqButton

                anchors.right: muteButton.left
                anchors.rightMargin: 8
                y: 12
                width: 76
                height: 38
                radius: 11
                scale: eqButtonMouse.pressed ? 0.96 : 1
                color: root.eqActive ? Theme.alpha(Theme.accent, 0.30) : eqButtonMouse.containsMouse && root.hyperxSelected ? Theme.alpha(Theme.hoverSurface, 0.40) : Theme.alpha(Theme.surface, 0.28)
                border.width: 1
                border.color: root.eqActive ? Theme.accent : Theme.alpha(Theme.surface, 0.35)
                opacity: root.hyperxSelected ? 1 : 0.45

                Behavior on color {
                    ColorAnimation { duration: 140 }
                }

                Behavior on scale {
                    NumberAnimation { duration: 90; easing.type: Easing.OutCubic }
                }

                Text {
                    x: 10
                    anchors.verticalCenter: parent.verticalCenter
                    text: "󰇠"
                    color: root.eqActive ? Theme.accentText : Theme.mutedText
                    font.family: Ui.fontFamily
                    font.pixelSize: 18
                }

                Text {
                    x: 36
                    anchors.verticalCenter: parent.verticalCenter
                    text: eqActionProcess.running ? "…" : root.eqActive ? "ON" : "OFF"
                    color: root.eqActive ? Theme.accentText : Theme.mutedText
                    font.family: Ui.fontFamily
                    font.pixelSize: Ui.caption
                    font.bold: true
                }

                MouseArea {
                    id: eqButtonMouse
                    anchors.fill: parent
                    enabled: root.hyperxSelected && !eqActionProcess.running
                    hoverEnabled: true
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: root.runEqAction("toggle")
                }
            }

            Rectangle {
                id: volumeTrack

                x: 14
                y: 74
                width: parent.width - 28
                height: 10
                radius: 5
                color: Theme.surface1

                Rectangle {
                    width: parent.width * Math.min(root.defaultVolume, 100) / 100
                    height: parent.height
                    radius: parent.radius
                    color: Theme.accent

                    Behavior on width {
                        NumberAnimation { duration: 90; easing.type: Easing.OutCubic }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onPressed: mouse => root.setDefaultVolume(mouse.x / width)
                    onPositionChanged: mouse => {
                        if (pressed)
                            root.setDefaultVolume(mouse.x / width);
                    }
                }
            }
        }


        Text {
            width: parent.width
            height: 24
            text: "CHOOSE OUTPUT"
            color: Theme.mutedText
            verticalAlignment: Text.AlignBottom
            font.family: Ui.fontFamily
            font.pixelSize: Ui.caption
            font.bold: true
            font.letterSpacing: 0.8
        }

        Repeater {
            model: root.outputNodes

            delegate: Rectangle {
                id: outputRow

                required property var modelData
                readonly property bool active: root.isDefault(modelData)

                width: content.width
                height: 60
                radius: 13
                color: active ? Theme.alpha(Theme.activeSurface, 0.65) : outputMouse.containsMouse ? Theme.alpha(Theme.hoverSurface, 0.35) : Theme.alpha(Theme.surface, 0.20)
                border.width: 1
                border.color: active ? Theme.accent : Theme.alpha(Theme.surface, 0.30)

                Text {
                    x: 14
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.outputIcon(outputRow.modelData)
                    color: outputRow.active ? Theme.accentText : Theme.mutedText
                    font.family: Ui.fontFamily
                    font.pixelSize: 24
                }

                Text {
                    x: 52
                    y: 10
                    width: parent.width - 120
                    text: root.outputName(outputRow.modelData)
                    color: Theme.primaryText
                    elide: Text.ElideRight
                    font.family: Ui.fontFamily
                    font.pixelSize: Ui.body
                    font.bold: true
                }

                Text {
                    x: 52
                    y: 34
                    width: parent.width - 120
                    text: outputRow.active ? "ACTIVE • Discord stays on HyperX" : outputRow.modelData.name
                    color: outputRow.active ? Theme.success : outputMouse.containsMouse ? Theme.mutedText : Theme.quietText
                    elide: Text.ElideMiddle
                    font.family: Ui.fontFamily
                    font.pixelSize: Ui.caption
                }

                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    text: outputRow.active ? "✓" : "›"
                    color: outputRow.active ? Theme.success : Theme.mutedText
                    font.family: Ui.fontFamily
                    font.pixelSize: Ui.title
                    font.bold: true
                }

                MouseArea {
                    id: outputMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.selectOutput(outputRow.modelData)
                }
            }
        }

        Rectangle {
            width: parent.width
            height: 42
            radius: 12
            color: advancedMouse.containsMouse ? Theme.alpha(Theme.hoverSurface, 0.40) : "transparent"

            Text {
                anchors.centerIn: parent
                text: "󰒓  Advanced mixer"
                color: advancedMouse.containsMouse ? Theme.accentText : Theme.mutedText
                font.family: Ui.fontFamily
                font.pixelSize: Ui.body
            }

            MouseArea {
                id: advancedMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root.open = false;
                    Ui.launch(["pavucontrol"]);
                }
            }
        }
    }

    Process {
        id: eqStatusProcess
        command: [root.eqScript, "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.eqActive = text.trim() === "on";
                if (root.eqActive && !root.hyperxSelected)
                    root.runEqAction("off");
            }
        }
    }

    Process {
        id: eqActionProcess
        property string requestedAction: "toggle"
        command: [root.eqScript, requestedAction]
        stdout: StdioCollector {
            onStreamFinished: root.eqActive = text.trim() === "on"
        }
        onExited: eqRefreshDelay.restart()
    }

    Timer {
        id: eqRefreshDelay
        interval: 150
        onTriggered: root.refreshEqStatus()
    }

    Timer {
        interval: 3000
        repeat: true
        running: root.open
        onTriggered: root.refreshEqStatus()
    }

    onHyperxSelectedChanged: runEqAction(hyperxSelected ? "resume" : "suspend")

    Component.onCompleted: runEqAction(hyperxSelected ? "resume" : "suspend")

    Timer {
        id: focusDelay
        interval: 150
        onTriggered: root.grabReady = root.open
    }

    onOpenChanged: {
        grabReady = false;
        if (open) {
            refreshEqStatus();
            focusDelay.restart();
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
        active: root.grabReady
        onCleared: {
            if (root.grabReady)
                root.open = false;
        }
    }
}
