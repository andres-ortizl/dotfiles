import Quickshell
import QtQuick
import Qt.labs.folderlistmodel
import Quickshell.Wayland

PanelWindow {
    id: picker

    property bool open: false
    readonly property string wallpaperDir: Quickshell.env("HOME") + "/.config/wallpaper/"
    readonly property string cacheDir: Quickshell.env("HOME") + "/.cache/quickshell/wallpaper-picker/"
    readonly property string pickerDir: Quickshell.env("HOME") + "/.config/quickshell/wallpaper-picker/"

    visible: open
    implicitWidth: Screen.width
    implicitHeight: Screen.height
    color: "transparent"
    aboveWindows: true
    exclusionMode: ExclusionMode.Ignore

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.namespace: "quickshell:wallpaper-picker"

    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }

    function prepare() {
        Quickshell.execDetached([
            "bash",
            pickerDir + "cache-thumbnails.sh",
            wallpaperDir,
            cacheDir,
        ])
    }

    onOpenChanged: {
        carousel.presented = false
        if (!open)
            return

        prepare()
        if (wallpapers.count > 0) {
            carousel.selectedIndex = carousel.clampIndex(carousel.selectedIndex)
            if (!carousel.initialized) {
                carousel.selectedIndex = Math.floor(wallpapers.count / 2)
                carousel.initialized = true
            }
            presentationTimer.restart()
        }
    }

    FolderListModel {
        id: wallpapers
        folder: "file://" + picker.wallpaperDir
        showDirs: false
        nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.webp"]
        sortField: FolderListModel.Name

        onCountChanged: {
            if (!carousel.initialized && count > 0) {
                carousel.selectedIndex = Math.floor(count / 2)
                carousel.initialized = true
            }
            if (picker.open && count > 0)
                presentationTimer.restart()
        }
    }

    Item {
        id: carousel
        anchors.fill: parent

        property int selectedIndex: 0
        property bool initialized: false
        property bool presented: false
        readonly property real baseTileWidth: picker.width / 9 - 10
        readonly property real baseTileHeight: 500
        readonly property real centerScale: 0.8
        readonly property real edgeScale: 0.3
        readonly property real spacing: 8

        function clampIndex(index) {
            return Math.max(0, Math.min(index, wallpapers.count - 1))
        }

        function select(index) {
            selectedIndex = clampIndex(index)
        }

        function scaleFor(index) {
            return Math.max(edgeScale, centerScale - Math.abs(index - selectedIndex) * 0.13)
        }

        function widthFor(index) {
            return baseTileWidth * scaleFor(index)
        }

        function xFor(index) {
            const selectedWidth = widthFor(selectedIndex)
            let position

            if (index === selectedIndex)
                return width / 2 - selectedWidth / 2

            if (index < selectedIndex) {
                position = width / 2 - selectedWidth / 2 - spacing
                for (let current = selectedIndex - 1; current >= index; current--) {
                    position -= widthFor(current)
                    if (current === index)
                        return position
                    position -= spacing
                }
            } else {
                position = width / 2 + selectedWidth / 2 + spacing
                for (let current = selectedIndex + 1; current <= index; current++) {
                    if (current === index)
                        return position
                    position += widthFor(current) + spacing
                }
            }

            return 0
        }

        function applySelected() {
            if (wallpapers.count === 0)
                return

            const path = wallpapers.get(selectedIndex, "filePath")
            Quickshell.execDetached(["bash", picker.pickerDir + "apply-wallpaper.sh", path])
            picker.open = false
        }

        Timer {
            id: presentationTimer
            interval: 100
            repeat: false
            onTriggered: carousel.presented = true
        }

        Repeater {
            model: wallpapers

            delegate: Item {
                id: tile
                required property string fileName
                required property int index

                readonly property real tileScale: carousel.scaleFor(index)
                x: carousel.xFor(index)
                y: (carousel.height - height) / 2
                z: 100 - Math.abs(index - carousel.selectedIndex)
                width: carousel.widthFor(index)
                height: carousel.baseTileHeight * tileScale
                opacity: 0.72 + tileScale * 0.35
                visible: carousel.presented

                Behavior on x {
                    enabled: carousel.presented
                    NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                }
                Behavior on y {
                    enabled: carousel.presented
                    NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                }
                Behavior on width {
                    enabled: carousel.presented
                    NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                }
                Behavior on height {
                    enabled: carousel.presented
                    NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                }
                Behavior on opacity {
                    enabled: carousel.presented
                    NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                }

                Image {
                    id: preview
                    anchors.fill: parent
                    asynchronous: true
                    cache: false
                    fillMode: Image.PreserveAspectCrop
                    smooth: true
                    source: "file://" + picker.cacheDir + tile.fileName
                    sourceSize.width: Math.round(carousel.baseTileWidth * carousel.centerScale)
                    sourceSize.height: Math.round(carousel.baseTileHeight * carousel.centerScale)

                    Timer {
                        id: retry
                        interval: 600
                        repeat: false
                        onTriggered: {
                            const previousSource = preview.source
                            preview.source = ""
                            preview.source = previousSource
                        }
                    }

                    onStatusChanged: {
                        if (status === Image.Error)
                            retry.restart()
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    visible: index === carousel.selectedIndex
                    color: "transparent"
                    border.width: 2
                    border.color: Theme.mauve
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: carousel.select(index)
                    onClicked: carousel.applySelected()
                    onWheel: wheel => {
                        carousel.select(carousel.selectedIndex + (wheel.angleDelta.y < 0 ? 1 : -1))
                        wheel.accepted = true
                    }
                }
            }
        }

        Text {
            anchors.centerIn: parent
            visible: wallpapers.count === 0
            text: "No wallpapers found"
            color: Theme.red
            font.family: Ui.fontFamily
            font.pixelSize: Ui.title
        }

        Item {
            anchors.fill: parent
            focus: picker.open

            Keys.onPressed: event => {
                switch (event.key) {
                case Qt.Key_J:
                case Qt.Key_Right:
                    carousel.select(carousel.selectedIndex + 1)
                    break
                case Qt.Key_K:
                case Qt.Key_Left:
                    carousel.select(carousel.selectedIndex - 1)
                    break
                case Qt.Key_D:
                    carousel.select(carousel.selectedIndex + 9)
                    break
                case Qt.Key_U:
                    carousel.select(carousel.selectedIndex - 9)
                    break
                case Qt.Key_Return:
                case Qt.Key_Enter:
                case Qt.Key_Space:
                    carousel.applySelected()
                    break
                case Qt.Key_Escape:
                    picker.open = false
                    break
                default:
                    return
                }

                event.accepted = true
            }
        }
    }
}
