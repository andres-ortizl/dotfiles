import QtQuick
import Quickshell

Item {
    id: root

    required property var host

    function shortDriveName(name) {
        return String(name || "NVMe")
            .replace("Samsung SSD ", "")
            .replace(" 1TB", "");
    }

    Column {
        width: parent.width
        spacing: Ui.gap

        Text {
            width: parent.width
            height: 28
            text: "SYSTEM HEALTH"
            color: "#a7abbe"
            verticalAlignment: Text.AlignVCenter
            font.family: Ui.fontFamily
            font.pixelSize: 12
            font.bold: true
            font.letterSpacing: 1
        }

        Row {
            width: parent.width
            height: 84
            spacing: Ui.gap

            MetricCard {
                width: (parent.width - parent.spacing) / 2
                icon: "󰻠"
                title: root.host.hardwareStats.cpuModel || "CPU"
                value: `${root.host.hardwareStats.cpu}%`
                detail: `${root.host.hardwareStats.cpuTemp} C`
                critical: root.host.hardwareStats.cpuTemp >= 80
                interactive: true
                onClicked: {
                    root.host.open = false;
                    Quickshell.execDetached(["ghostty", "-e", "btop"]);
                }
            }

            MetricCard {
                width: (parent.width - parent.spacing) / 2
                icon: "󰢮"
                title: root.host.hardwareStats.gpuModel || "GPU"
                value: `${root.host.hardwareStats.gpu}%`
                detail: `${root.host.hardwareStats.gpuTemp} C | ${root.host.hardwareStats.gpuMemoryUsed} MiB`
                critical: root.host.hardwareStats.gpuTemp >= 85
                interactive: true
                onClicked: {
                    root.host.open = false;
                    Quickshell.execDetached(["ghostty", "-e", "watch", "-n", "1", "nvidia-smi"]);
                }
            }
        }

        Row {
            width: parent.width
            height: 84
            spacing: Ui.gap

            MetricCard {
                width: (parent.width - parent.spacing) / 2
                icon: ""
                title: `MEMORY ${root.host.hardwareStats.memoryTotal} GiB`
                value: `${root.host.hardwareStats.memoryPercent}%`
                detail: `${root.host.hardwareStats.memoryUsed} / ${root.host.hardwareStats.memoryTotal} GiB`
                critical: root.host.hardwareStats.memoryPercent >= 90
                interactive: true
                onClicked: {
                    root.host.open = false;
                    Quickshell.execDetached(["ghostty", "-e", "btop"]);
                }
            }

            MetricCard {
                width: (parent.width - parent.spacing) / 2
                icon: "󰈀"
                title: "NETWORK"
                value: `RX ${root.host.formatRate(root.host.downloadRate)}`
                detail: `TX ${root.host.formatRate(root.host.uploadRate)}`
            }
        }

        Row {
            width: parent.width
            height: 84
            spacing: Ui.gap

            MetricCard {
                width: (parent.width - parent.spacing) / 2
                icon: "󰋊"
                title: root.shortDriveName(root.host.hardwareStats.nvme1Model)
                value: `${root.host.hardwareStats.nvme1} C`
                detail: "NVMe 1"
                critical: root.host.hardwareStats.nvme1 >= 80
                interactive: true
                onClicked: {
                    root.host.open = false;
                    Quickshell.execDetached(["ghostty", "-e", "watch", "-n", "2", "nvme", "smart-log", "/dev/nvme1n1"]);
                }
            }

            MetricCard {
                width: (parent.width - parent.spacing) / 2
                icon: "󰋊"
                title: root.shortDriveName(root.host.hardwareStats.nvme0Model)
                value: `${root.host.hardwareStats.nvme0} C`
                detail: "NVMe 0"
                critical: root.host.hardwareStats.nvme0 >= 80
                interactive: true
                onClicked: {
                    root.host.open = false;
                    Quickshell.execDetached(["ghostty", "-e", "watch", "-n", "2", "nvme", "smart-log", "/dev/nvme0n1"]);
                }
            }
        }

        Row {
            width: parent.width
            height: 84
            spacing: Ui.gap

            MetricCard {
                width: (parent.width - parent.spacing) / 2
                icon: "󰾆"
                title: root.host.hardwareStats.pumpModel || "PUMP"
                value: `${root.host.hardwareStats.pumpRpm} RPM`
                detail: `${root.host.hardwareStats.coolantTemp} C coolant`
                interactive: true
                critical: root.host.hardwareStats.pumpRpm === 0
                onClicked: {
                    root.host.open = false;
                    Quickshell.execDetached(["coolercontrol"]);
                }
            }

            MetricCard {
                width: (parent.width - parent.spacing) / 2
                icon: "󰈐"
                title: root.host.hardwareStats.boardModel || "FANS"
                value: `${root.host.hardwareStats.boardFan2Rpm} / ${root.host.hardwareStats.boardFan7Rpm}`
                detail: `AIO ${root.host.hardwareStats.aioFanRpm} RPM`
                interactive: true
                onClicked: {
                    root.host.open = false;
                    Quickshell.execDetached(["coolercontrol"]);
                }
            }
        }
    }
}
