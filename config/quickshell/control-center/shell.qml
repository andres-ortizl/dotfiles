//@ pragma UseQApplication

import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Services.SystemTray
import Quickshell.Wayland

ShellRoot {
    PanelWindow {
        id: controlBackdrop

        visible: popup.open
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "quickshell:control-backdrop"

        anchors {
            top: true
            left: true
            right: true
            bottom: true
        }

        BackgroundEffect.blurRegion: Region {
            item: backdropSurface
        }

        Rectangle {
            id: backdropSurface
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.22)

            MouseArea {
                anchors.fill: parent
                onClicked: popup.open = false
            }
        }
    }

    PanelWindow {
        id: popup

        property bool open: false
        property bool grabReady: false
        property bool changingPage: false
        property bool showWifi: false
        property bool showCalendar: false
        property int currentPage: 0
        property int openMenuCount: 0
        property real previousRx: 0
        property real previousTx: 0
        property real previousSampleTime: 0
        property real downloadRate: 0
        property real uploadRate: 0
        property var weather: ({
            temperature: "--",
            feels: "--",
            min: "--",
            max: "--",
            rain: "--",
            description: "Loading weather",
            icon: "󰖐"
        })
        property bool calendarAuthenticated: false
        property var calendarEvents: []
        property string calendarError: ""
        property var hardwareStats: ({
            cpu: 0,
            cpuTemp: 0,
            cpuModel: "CPU",
            memoryPercent: 0,
            memoryUsed: "0.0",
            memoryTotal: "0.0",
            gpu: 0,
            gpuTemp: 0,
            gpuMemoryUsed: 0,
            gpuMemoryTotal: 0,
            gpuModel: "GPU",
            nvme0: 0,
            nvme1: 0,
            nvme0Model: "NVMe 0",
            nvme1Model: "NVMe 1",
            pumpRpm: 0,
            aioFanRpm: 0,
            boardFan2Rpm: 0,
            boardFan7Rpm: 0,
            coolantTemp: 0,
            pumpModel: "Pump",
            boardModel: "Fans"
        })

        readonly property var networking: Networking
        readonly property int itemCount: SystemTray.items.values.length
        readonly property var networkDevices: Networking.devices.values
        readonly property var wifiDevice: findDevice(DeviceType.Wifi)
        readonly property var wifiNetworks: wifiDevice?.networks.values ?? []
        readonly property var wiredDevice: findDevice(DeviceType.Wired)
        readonly property var activeDevice: wiredDevice?.connected ? wiredDevice : wifiDevice?.connected ? wifiDevice : null
        readonly property var connectedWifi: wifiNetworks.find(network => network.connected) ?? null
        readonly property var bluetoothAdapter: Bluetooth.defaultAdapter
        readonly property var bluetoothDevices: bluetoothAdapter?.devices.values.filter(device => device.connected) ?? []

        function findDevice(type) {
            let fallback = null;
            for (const device of networkDevices) {
                if (device.type !== type)
                    continue;
                if (device.connected)
                    return device;
                if (!fallback)
                    fallback = device;
            }
            return fallback;
        }

        function formatRate(bytes) {
            if (bytes >= 1048576)
                return `${(bytes / 1048576).toFixed(1)} MiB/s`;
            if (bytes >= 1024)
                return `${(bytes / 1024).toFixed(0)} KiB/s`;
            return `${Math.max(0, bytes).toFixed(0)} B/s`;
        }

        function updateRates(raw) {
            const values = raw.trim().split(/\s+/).map(Number);
            if (values.length !== 2 || !values.every(Number.isFinite))
                return;
            const now = Date.now() / 1000;
            if (previousSampleTime > 0) {
                const elapsed = now - previousSampleTime;
                downloadRate = Math.max(0, (values[0] - previousRx) / elapsed);
                uploadRate = Math.max(0, (values[1] - previousTx) / elapsed);
            }
            previousRx = values[0];
            previousTx = values[1];
            previousSampleTime = now;
        }

        function sampleNetwork() {
            if (!activeDevice || netStats.running)
                return;
            netStats.command = ["bash", "-c", "read -r rx < /sys/class/net/$1/statistics/rx_bytes && read -r tx < /sys/class/net/$1/statistics/tx_bytes && printf '%s %s\\n' \"$rx\" \"$tx\"", "netstats", activeDevice.name];
            netStats.running = true;
        }

        function weatherDescription(code) {
            if (code === 0)
                return "Clear sky";
            if (code <= 3)
                return "Partly cloudy";
            if (code <= 48)
                return "Fog";
            if (code <= 67)
                return "Rain";
            if (code <= 77)
                return "Snow";
            if (code <= 82)
                return "Showers";
            if (code <= 86)
                return "Snow";
            return "Thunderstorm";
        }

        function weatherIcon(code) {
            if (code === 0)
                return "󰖙";
            if (code <= 3)
                return "󰖕";
            if (code <= 48)
                return "󰖑";
            if (code <= 67)
                return "󰖗";
            if (code <= 77)
                return "󰖘";
            if (code <= 82)
                return "󰖗";
            if (code <= 86)
                return "󰖘";
            return "󰙾";
        }

        function updateWeather(raw) {
            try {
                const data = JSON.parse(raw);
                if (!data.current || !data.daily)
                    return;
                const code = data.current.weather_code;
                weather = {
                    temperature: Math.round(data.current.temperature_2m),
                    feels: Math.round(data.current.apparent_temperature),
                    min: Math.round(data.daily.temperature_2m_min[0]),
                    max: Math.round(data.daily.temperature_2m_max[0]),
                    rain: Math.round(data.daily.precipitation_probability_max[0]),
                    description: weatherDescription(code),
                    icon: weatherIcon(code)
                };
            } catch (error) {
                console.warn("Could not parse weather:", error);
            }
        }

        function updateCalendar(raw) {
            try {
                const data = JSON.parse(raw);
                calendarAuthenticated = data.authenticated ?? false;
                calendarEvents = data.events ?? [];
                calendarError = data.error ?? "";
            } catch (error) {
                calendarError = String(error);
            }
        }

        function openCalendarSetup() {
            open = false;
            Quickshell.execDetached(["xdg-open", "https://github.com/insanum/gcalcli/blob/HEAD/docs/api-auth.md"]);
            Quickshell.execDetached(["ghostty", "-e", "gcalcli", "init"]);
        }

        function updateScanner() {
            if (wifiDevice)
                wifiDevice.scannerEnabled = open && showWifi && Networking.wifiEnabled;
        }

        function markPageChange() {
            changingPage = true;
            pageChangeTimer.restart();
        }

        onOpenChanged: {
            grabReady = false;
            previousSampleTime = 0;
            downloadRate = 0;
            uploadRate = 0;
            if (open) {
                currentPage = 0;
                showWifi = false;
                showCalendar = false;
                sampleNetwork();
                if (!systemStats.running)
                    systemStats.running = true;
                focusGrabDelay.restart();
            }
            updateScanner();
        }
        onShowWifiChanged: {
            markPageChange();
            if (showWifi)
                showCalendar = false;
            updateScanner();
        }
        onShowCalendarChanged: {
            markPageChange();
            if (showCalendar)
                showWifi = false;
        }
        onWifiDeviceChanged: updateScanner()
        onCurrentPageChanged: {
            markPageChange();
            if (currentPage === 1 && !systemStats.running)
                systemStats.running = true;
        }

        Connections {
            target: Networking
            function onWifiEnabledChanged() {
                popup.updateScanner();
            }
        }

        visible: open
        color: "transparent"
        implicitWidth: 880
        implicitHeight: 498
        exclusionMode: ExclusionMode.Ignore
        focusable: true
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell:control-center"

        anchors {
            top: true
        }

        margins {
            top: 78
        }

        mask: Region {
            item: card
            radius: 18
        }

        Rectangle {
            id: card
            anchors.fill: parent
            radius: 18
            color: Qt.rgba(33 / 255, 34 / 255, 44 / 255, 0.85)
            border.width: 1
            border.color: "#66414558"
        }

        Column {
            x: 18
            y: 18
            width: parent.width - 36
            spacing: Ui.gap

            Row {
                width: parent.width
                height: 44
                spacing: Ui.gap
                visible: !popup.showWifi && !popup.showCalendar

                TabButton {
                    width: (parent.width - 24) / 3
                    icon: "󰋜"
                    label: "Home"
                    active: popup.currentPage === 0
                    onClicked: popup.currentPage = 0
                }

                TabButton {
                    width: (parent.width - 24) / 3
                    icon: "󰍛"
                    label: "System"
                    active: popup.currentPage === 1
                    onClicked: popup.currentPage = 1
                }

                TabButton {
                    width: (parent.width - 24) / 3
                    icon: "󰒓"
                    label: "Config"
                    active: popup.currentPage === 2
                    onClicked: popup.currentPage = 2
                }
            }

            Item {
                width: parent.width
                height: popup.showWifi || popup.showCalendar ? 462 : 412

                Loader {
                    anchors.fill: parent
                    sourceComponent: popup.showWifi ? wifiComponent
                        : popup.showCalendar ? calendarComponent
                        : popup.currentPage === 1 ? systemComponent
                        : popup.currentPage === 2 ? configComponent
                        : homeComponent
                }

                Component {
                    id: homeComponent
                    HomePage { host: popup }
                }

                Component {
                    id: systemComponent
                    SystemPage { host: popup }
                }

                Component {
                    id: configComponent
                    ConfigPage { host: popup }
                }

                Component {
                    id: wifiComponent
                    WifiPage { host: popup }
                }

                Component {
                    id: calendarComponent
                    CalendarPage { host: popup }
                }
            }
        }

        Item {
            anchors.fill: parent
            focus: popup.open
            Keys.onEscapePressed: {
                if (popup.showWifi)
                    popup.showWifi = false;
                else if (popup.showCalendar)
                    popup.showCalendar = false;
                else
                    popup.open = false;
            }
        }

        Timer {
            id: focusGrabDelay
            interval: 150
            onTriggered: popup.grabReady = popup.open
        }

        Timer {
            id: pageChangeTimer
            interval: 350
            onTriggered: popup.changingPage = false
        }

        Timer {
            interval: 2000
            repeat: true
            running: popup.open
            onTriggered: popup.sampleNetwork()
        }

        Timer {
            interval: 5000
            repeat: true
            running: popup.open
            onTriggered: {
                if (!systemStats.running)
                    systemStats.running = true;
            }
        }

        Timer {
            interval: 900000
            repeat: true
            running: true
            triggeredOnStart: true
            onTriggered: {
                if (!weatherProcess.running)
                    weatherProcess.running = true;
            }
        }

        Timer {
            interval: 300000
            repeat: true
            running: true
            triggeredOnStart: true
            onTriggered: {
                if (!calendarProcess.running)
                    calendarProcess.running = true;
            }
        }

        Process {
            id: netStats
            stdout: SplitParser {
                onRead: data => popup.updateRates(data)
            }
        }

        Process {
            id: systemStats
            command: [Quickshell.env("HOME") + "/.config/quickshell/control-center/system-stats.sh"]
            stdout: SplitParser {
                onRead: data => {
                    try {
                        popup.hardwareStats = JSON.parse(data);
                    } catch (error) {
                        console.warn("Could not parse system stats:", error);
                    }
                }
            }
        }

        Process {
            id: weatherProcess
            command: [Quickshell.env("HOME") + "/.config/quickshell/control-center/weather.sh"]
            stdout: SplitParser {
                onRead: data => popup.updateWeather(data)
            }
        }

        Process {
            id: calendarProcess
            command: [Quickshell.env("HOME") + "/.config/quickshell/control-center/calendar-events.py"]
            stdout: SplitParser {
                onRead: data => popup.updateCalendar(data)
            }
        }

        HyprlandFocusGrab {
            windows: [popup, controlBackdrop]
            active: popup.grabReady && popup.openMenuCount === 0
            onCleared: {
                if (popup.grabReady && !popup.changingPage && popup.openMenuCount === 0)
                    popup.open = false;
            }
        }

    }

    PanelWindow {
        id: trayPopup

        property bool open: false
        property bool grabReady: false
        property int openMenuCount: 0
        readonly property int itemCount: SystemTray.items.values.length

        visible: open
        color: "transparent"
        implicitWidth: 330
        implicitHeight: 64 + Math.max(1, itemCount) * 74
        exclusionMode: ExclusionMode.Ignore
        focusable: true
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell:tray"

        anchors {
            top: true
            right: true
        }

        margins {
            top: 78
            right: 12
        }

        mask: Region {
            item: trayCard
            radius: 18
        }

        BackgroundEffect.blurRegion: Region {
            item: trayCard
            radius: 18
        }

        Rectangle {
            id: trayCard
            anchors.fill: parent
            radius: 18
            color: Qt.rgba(33 / 255, 34 / 255, 44 / 255, 0.90)
            border.width: 1
            border.color: "#66414558"
        }

        Column {
            x: 12
            y: 12
            width: parent.width - 24
            spacing: 4

            Item {
                width: parent.width
                height: 36

                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "SYSTEM TRAY"
                    color: "#a7abbe"
                    font.family: Ui.fontFamily
                    font.pixelSize: 12
                    font.bold: true
                    font.letterSpacing: 1
                }

                Rectangle {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 32
                    height: 22
                    radius: 8
                    color: "#339580ff"

                    Text {
                        anchors.centerIn: parent
                        text: trayPopup.itemCount
                        color: "#d4ccff"
                        font.family: Ui.fontFamily
                        font.pixelSize: Ui.caption
                        font.bold: true
                    }
                }
            }

            Repeater {
                model: SystemTray.items

                delegate: TrayRow {
                    required property var modelData
                    width: parent.width
                    trayItem: modelData
                    host: trayPopup
                }
            }

            Text {
                width: parent.width
                height: trayPopup.itemCount === 0 ? 52 : 0
                visible: trayPopup.itemCount === 0
                text: "No background apps"
                color: "#a7abbe"
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                font.family: Ui.fontFamily
                font.pixelSize: Ui.body
            }
        }

        Timer {
            id: trayFocusDelay
            interval: 150
            onTriggered: trayPopup.grabReady = trayPopup.open
        }

        onOpenChanged: {
            grabReady = false;
            if (open)
                trayFocusDelay.restart();
        }

        HyprlandFocusGrab {
            windows: [trayPopup]
            active: trayPopup.grabReady && trayPopup.openMenuCount === 0
            onCleared: {
                if (trayPopup.grabReady && trayPopup.openMenuCount === 0)
                    trayPopup.open = false;
            }
        }
    }

    IpcHandler {
        target: "controlCenter"

        function toggle(): void {
            trayPopup.open = false;
            popup.open = !popup.open;
        }

        function close(): void {
            popup.open = false;
        }

        function count(): int {
            return popup.itemCount;
        }

        function isOpen(): bool {
            return popup.open;
        }

        function openPage(page: string): void {
            trayPopup.open = false;
            popup.open = true;
            if (page === "wifi" || page === "calendar")
                popup.currentPage = 0;
            popup.showWifi = page === "wifi";
            popup.showCalendar = page === "calendar";
            if (page === "home")
                popup.currentPage = 0;
            else if (page === "system")
                popup.currentPage = 1;
            else if (page === "config")
                popup.currentPage = 2;
        }
    }

    IpcHandler {
        target: "tray"

        function toggle(): void {
            popup.open = false;
            trayPopup.open = !trayPopup.open;
        }

        function close(): void {
            trayPopup.open = false;
        }

        function count(): int {
            return trayPopup.itemCount;
        }
    }
}
