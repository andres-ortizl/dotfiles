import QtQuick
import QtQuick.Controls.Basic as Controls
import Quickshell

Item {
    id: root

    required property var host
    readonly property var stats: host.hardwareStats
    readonly property bool statsReady: stats !== null
    readonly property string statsPlaceholder: host.hardwareStatsFailed ? "Unavailable" : "Loading…"
    readonly property string statsStatus: host.hardwareStatsFailed ? "Retrying automatically" : "Waiting for first sample"

    function shortDriveName(name) {
        return String(name || "NVMe")
            .replace("Samsung SSD ", "")
            .replace(" 1TB", "");
    }

    Flickable {
        id: systemView

        anchors.fill: parent
        contentWidth: width
        contentHeight: systemContent.implicitHeight
        clip: true
        flickableDirection: Flickable.VerticalFlick
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height

        Controls.ScrollBar.vertical: Controls.ScrollBar {
            id: systemScrollBar

            width: 12
            padding: 3
            minimumSize: 0.12
            hoverEnabled: true
            policy: systemView.contentHeight > systemView.height ? Controls.ScrollBar.AlwaysOn : Controls.ScrollBar.AlwaysOff
            visible: policy === Controls.ScrollBar.AlwaysOn

            contentItem: Rectangle {
                implicitWidth: 6
                implicitHeight: 24
                radius: 3
                color: systemScrollBar.pressed ? Theme.accent : systemScrollBar.hovered ? Theme.primaryText : Theme.mutedText
                opacity: systemScrollBar.hovered || systemScrollBar.pressed ? 1 : 0.75
            }

            background: Rectangle {
                radius: width / 2
                color: Theme.alpha(Theme.surface, 0.25)
            }
        }

        Column {
            id: systemContent

            width: systemView.width - (systemScrollBar.visible ? 16 : 0)
            spacing: Ui.gap

            Row {
                id: usageRow

                width: parent.width
                height: Math.max(cpuCard.implicitHeight, gpuCard.implicitHeight, memoryCard.implicitHeight)
                spacing: Ui.gap

                MetricCard {
                    id: cpuCard

                    width: (usageRow.width - 2 * usageRow.spacing) / 3
                    height: usageRow.height
                    icon: "󰻠"
                    title: "CPU"
                    placeholder: !root.statsReady
                    value: root.statsReady ? `${root.stats.cpu}%` : root.statsPlaceholder
                    subtitle: root.statsReady ? root.stats.cpuModel : ""
                    detail: root.statsReady ? `${root.stats.cpuTemp} °C` : root.statsStatus
                    prominent: true
                    critical: root.statsReady && root.stats.cpuTemp >= 80
                    interactive: true
                    onClicked: {
                        root.host.open = false;
                        Ui.launch(["ghostty", "-e", "btop"]);
                    }
                }

                MetricCard {
                    id: gpuCard

                    width: (usageRow.width - 2 * usageRow.spacing) / 3
                    height: usageRow.height
                    icon: "󰢮"
                    title: "GPU"
                    placeholder: !root.statsReady
                    value: root.statsReady ? `${root.stats.gpu}%` : root.statsPlaceholder
                    subtitle: root.statsReady ? root.stats.gpuModel : ""
                    detail: root.statsReady ? `${root.stats.gpuTemp} °C · ${root.stats.gpuMemoryUsed} MiB VRAM` : root.statsStatus
                    prominent: true
                    critical: root.statsReady && root.stats.gpuTemp >= 85
                    interactive: true
                    onClicked: {
                        root.host.open = false;
                        Ui.launch(["ghostty", "-e", "watch", "-n", "1", "nvidia-smi"]);
                    }
                }

                MetricCard {
                    id: memoryCard

                    width: (usageRow.width - 2 * usageRow.spacing) / 3
                    height: usageRow.height
                    icon: ""
                    title: "RAM"
                    placeholder: !root.statsReady
                    value: root.statsReady ? `${root.stats.memoryPercent}%` : root.statsPlaceholder
                    subtitle: root.statsReady ? `Total ${root.stats.memoryTotal} GiB` : ""
                    detail: root.statsReady ? `Used ${root.stats.memoryUsed} GiB` : root.statsStatus
                    prominent: true
                    critical: root.statsReady && root.stats.memoryPercent >= 90
                    interactive: true
                    onClicked: {
                        root.host.open = false;
                        Ui.launch(["ghostty", "-e", "btop"]);
                    }
                }
            }

            Rectangle {
                id: networkStrip

                width: parent.width
                height: Math.max(40, Math.max(downloadText.implicitHeight, uploadText.implicitHeight) + 16)
                radius: 12
                color: Theme.alpha(Theme.surface, 0.20)

                Text {
                    x: 13
                    anchors.verticalCenter: parent.verticalCenter
                    text: "󰈀"
                    color: Theme.mutedText
                    font.family: Ui.fontFamily
                    font.pixelSize: Ui.title
                }

                Text {
                    x: 40
                    anchors.verticalCenter: parent.verticalCenter
                    text: "NETWORK"
                    color: Theme.mutedText
                    font.family: Ui.fontFamily
                    font.pixelSize: Ui.caption
                    font.bold: true
                }

                Row {
                    x: 136
                    width: parent.width - 148
                    height: parent.height
                    spacing: Ui.gap

                    Text {
                        id: downloadText

                        width: (parent.width - parent.spacing) / 2
                        anchors.verticalCenter: parent.verticalCenter
                        text: `↓ Download ${root.host.formatRate(root.host.downloadRate)}`
                        color: Theme.primaryText
                        wrapMode: Text.Wrap
                        font.family: Ui.fontFamily
                        font.pixelSize: Ui.body
                    }

                    Text {
                        id: uploadText

                        width: (parent.width - parent.spacing) / 2
                        anchors.verticalCenter: parent.verticalCenter
                        text: `↑ Upload ${root.host.formatRate(root.host.uploadRate)}`
                        color: Theme.primaryText
                        wrapMode: Text.Wrap
                        font.family: Ui.fontFamily
                        font.pixelSize: Ui.body
                    }
                }
            }

            Column {
                width: parent.width
                topPadding: Ui.gap
                spacing: Ui.gap

                Row {
                    id: storageRow

                    width: parent.width
                    height: Math.max(nvme1Card.implicitHeight, nvme0Card.implicitHeight)
                    spacing: Ui.gap

                    MetricCard {
                        id: nvme1Card

                        width: (storageRow.width - storageRow.spacing) / 2
                        height: storageRow.height
                        icon: "󰋊"
                        title: "NVMe 1"
                        placeholder: !root.statsReady
                        value: root.statsReady ? `${root.stats.nvme1} °C` : root.statsPlaceholder
                        detail: root.statsReady ? root.shortDriveName(root.stats.nvme1Model) : root.statsStatus
                        critical: root.statsReady && root.stats.nvme1 >= 80
                        interactive: true
                        onClicked: {
                            root.host.open = false;
                            Ui.launch(["ghostty", "-e", "watch", "-n", "2", "nvme", "smart-log", "/dev/nvme1n1"]);
                        }
                    }

                    MetricCard {
                        id: nvme0Card

                        width: (storageRow.width - storageRow.spacing) / 2
                        height: storageRow.height
                        icon: "󰋊"
                        title: "NVMe 0"
                        placeholder: !root.statsReady
                        value: root.statsReady ? `${root.stats.nvme0} °C` : root.statsPlaceholder
                        detail: root.statsReady ? root.shortDriveName(root.stats.nvme0Model) : root.statsStatus
                        critical: root.statsReady && root.stats.nvme0 >= 80
                        interactive: true
                        onClicked: {
                            root.host.open = false;
                            Ui.launch(["ghostty", "-e", "watch", "-n", "2", "nvme", "smart-log", "/dev/nvme0n1"]);
                        }
                    }
                }

                Row {
                    id: coolingRow

                    width: parent.width
                    height: Math.max(pumpCard.implicitHeight, fansCard.implicitHeight)
                    spacing: Ui.gap

                    MetricCard {
                        id: pumpCard

                        width: (coolingRow.width - coolingRow.spacing) / 2
                        height: coolingRow.height
                        icon: "󰾆"
                        title: "PUMP"
                        placeholder: !root.statsReady
                        value: root.statsReady ? `${root.stats.pumpRpm} RPM` : root.statsPlaceholder
                        detail: root.statsReady ? `${root.stats.coolantTemp} °C coolant · ${root.stats.pumpModel}` : root.statsStatus
                        interactive: true
                        critical: root.statsReady && root.stats.pumpRpm === 0
                        onClicked: {
                            root.host.open = false;
                            Ui.launch(["coolercontrol"]);
                        }
                    }

                    MetricCard {
                        id: fansCard

                        width: (coolingRow.width - coolingRow.spacing) / 2
                        height: coolingRow.height
                        icon: "󰈐"
                        title: "FANS"
                        placeholder: !root.statsReady
                        value: root.statsReady ? `Fan 2 ${root.stats.boardFan2Rpm} RPM · Fan 7 ${root.stats.boardFan7Rpm} RPM` : root.statsPlaceholder
                        detail: root.statsReady ? `AIO ${root.stats.aioFanRpm} RPM · ${root.stats.boardModel}` : root.statsStatus
                        interactive: true
                        onClicked: {
                            root.host.open = false;
                            Ui.launch(["coolercontrol"]);
                        }
                    }
                }
            }
        }
    }
}
