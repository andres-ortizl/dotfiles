import QtQuick
import Quickshell
import Quickshell.Hyprland
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

    PwObjectTracker {
        objects: root.outputNodes
    }

    Rectangle {
        id: card

        anchors.fill: parent
        radius: 18
        color: Theme.alpha(Theme.panel, 0.94)
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
                width: parent.width - 92
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
                text: root.defaultMuted ? "Muted" : `${root.defaultVolume}%`
                color: root.defaultMuted ? Theme.danger : Theme.mutedText
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
                    color: outputRow.active ? Theme.success : Theme.quietText
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

    Timer {
        id: focusDelay
        interval: 150
        onTriggered: root.grabReady = root.open
    }

    onOpenChanged: {
        grabReady = false;
        if (open)
            focusDelay.restart();
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
