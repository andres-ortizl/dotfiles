import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets

PanelWindow {
    id: root

    required property var host
    required property var anchorItem
    property var menu: null
    property string title: "Application"
    property string extraActionText: ""
    property var currentMenu: menu
    property string currentTitle: title
    property var history: []
    readonly property bool hasExtraAction: extraActionText !== ""
    readonly property point anchorPosition: anchorItem ? anchorItem.mapToItem(null, 0, 0) : Qt.point(0, 0)

    signal actionTriggered
    signal extraActionTriggered

    visible: false
    color: "transparent"
    implicitWidth: 260
    implicitHeight: Math.min(360, 52 + menuItems.implicitHeight)
    exclusionMode: ExclusionMode.Ignore
    focusable: true
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell:tray-menu"

    anchors {
        top: true
        right: true
    }

    margins {
        top: host.margins.top + anchorPosition.y
        right: host.margins.right + host.width + 8
    }

    mask: Region {
        item: menuBackground
        radius: 14
    }

    BackgroundEffect.blurRegion: Region {
        item: menuBackground
        radius: 14
    }

    function resetMenu() {
        history = [];
        currentMenu = menu;
        currentTitle = title;
    }

    function showMenu() {
        host.showContextMenu(root);
        resetMenu();
        visible = true;
        forceActiveFocus();
    }

    function hideMenu() {
        visible = false;
        host.clearContextMenu(root);
        resetMenu();
    }

    function openChild(entry) {
        history = history.concat([{ menu: currentMenu, title: currentTitle }]);
        currentMenu = entry;
        currentTitle = entry.text || "Menu";
    }

    function goBack() {
        if (history.length === 0)
            return;
        const previous = history[history.length - 1];
        history = history.slice(0, -1);
        currentMenu = previous.menu;
        currentTitle = previous.title;
    }

    onMenuChanged: resetMenu()
    onTitleChanged: {
        if (history.length === 0)
            currentTitle = title;
    }

    Connections {
        target: root.host
        function onOpenChanged() {
            if (!root.host.open)
                root.hideMenu();
        }
    }

    QsMenuOpener {
        id: menuOpener
        menu: root.currentMenu
    }

    Rectangle {
        id: menuBackground

        anchors.fill: parent
        radius: 14
        color: Theme.alpha(Theme.panel, 0.96)
        border.width: 1
        border.color: Theme.alpha(Theme.surface, 0.55)
    }

    Item {
        id: header

        x: 10
        y: 5
        width: parent.width - 20
        height: 40

        Rectangle {
            id: backButton

            visible: root.history.length > 0
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: 32
            height: 32
            radius: 9
            color: backMouse.containsMouse ? Theme.alpha(Theme.hoverSurface, 0.40) : "transparent"

            Text {
                anchors.centerIn: parent
                text: "‹"
                color: backMouse.containsMouse ? Theme.accentText : Theme.mutedText
                font.family: Ui.fontFamily
                font.pixelSize: Ui.heading
                font.bold: true
            }

            MouseArea {
                id: backMouse

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.goBack()
            }
        }

        Text {
            anchors.left: backButton.visible ? backButton.right : parent.left
            anchors.leftMargin: backButton.visible ? 8 : 4
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: root.currentTitle
            elide: Text.ElideRight
            color: Theme.mutedText
            font.family: Ui.fontFamily
            font.pixelSize: Ui.caption
            font.bold: true
            font.letterSpacing: 0.6
        }
    }

    Flickable {
        x: 8
        y: 45
        width: parent.width - 16
        height: parent.height - 53
        clip: true
        contentHeight: menuItems.implicitHeight
        interactive: contentHeight > height

        Column {
            id: menuItems

            width: parent.width
            spacing: 2

            Repeater {
                model: menuOpener.children ? [...menuOpener.children.values] : []

                delegate: Item {
                    id: entry

                    required property var modelData

                    width: menuItems.width
                    height: modelData?.isSeparator ? 9 : 40
                    opacity: (modelData?.enabled ?? true) ? 1 : 0.45

                    Rectangle {
                        visible: entry.modelData?.isSeparator ?? false
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        height: 1
                        color: Theme.alpha(Theme.surface, 0.55)
                    }

                    Rectangle {
                        visible: !(entry.modelData?.isSeparator ?? false)
                        anchors.fill: parent
                        radius: 10
                        color: entryMouse.containsMouse ? Theme.alpha(Theme.hoverSurface, 0.40) : "transparent"

                        Item {
                            id: indicator

                            anchors.left: parent.left
                            anchors.leftMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            width: 22
                            height: 22
                            visible: entry.modelData?.buttonType !== QsMenuButtonType.None

                            readonly property bool checked: entry.modelData?.checkState === Qt.Checked
                            readonly property bool radio: entry.modelData?.buttonType === QsMenuButtonType.RadioButton

                            Rectangle {
                                anchors.centerIn: parent
                                width: 16
                                height: 16
                                radius: indicator.radio ? 8 : 4
                                color: indicator.checked ? Theme.accent : "transparent"
                                border.width: 1
                                border.color: indicator.checked ? Theme.accent : Theme.mutedText

                                Rectangle {
                                    visible: indicator.radio && indicator.checked
                                    anchors.centerIn: parent
                                    width: 6
                                    height: 6
                                    radius: 3
                                    color: Theme.panel
                                }

                                Text {
                                    visible: !indicator.radio && indicator.checked
                                    anchors.centerIn: parent
                                    text: "✓"
                                    color: Theme.panel
                                    font.family: Ui.fontFamily
                                    font.pixelSize: 11
                                    font.bold: true
                                }
                            }
                        }

                        IconImage {
                            visible: entry.modelData?.buttonType === QsMenuButtonType.None && (entry.modelData?.icon ?? "") !== ""
                            anchors.left: parent.left
                            anchors.leftMargin: 11
                            anchors.verticalCenter: parent.verticalCenter
                            implicitSize: 20
                            source: entry.modelData?.icon ?? ""
                            asynchronous: true
                            mipmap: true
                        }

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 42
                            anchors.right: childArrow.left
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            text: (entry.modelData?.text || "Unnamed action").replace(/[\n\r]+/g, " ")
                            elide: Text.ElideRight
                            color: entryMouse.containsMouse ? Theme.accentText : Theme.primaryText
                            font.family: Ui.fontFamily
                            font.pixelSize: Ui.body
                        }

                        Text {
                            id: childArrow

                            anchors.right: parent.right
                            anchors.rightMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            visible: entry.modelData?.hasChildren ?? false
                            text: "›"
                            color: entryMouse.containsMouse ? Theme.accentText : Theme.mutedText
                            font.family: Ui.fontFamily
                            font.pixelSize: Ui.title
                            font.bold: true
                        }

                        MouseArea {
                            id: entryMouse

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            enabled: (entry.modelData?.enabled ?? true) && !(entry.modelData?.isSeparator ?? false)
                            onClicked: {
                                if (entry.modelData.hasChildren) {
                                    root.openChild(entry.modelData);
                                } else {
                                    entry.modelData.triggered();
                                    root.hideMenu();
                                    root.actionTriggered();
                                }
                            }
                        }
                    }
                }
            }

            Item {
                width: parent.width
                height: root.hasExtraAction && root.history.length === 0 && menuOpener.children && menuOpener.children.values.length > 0 ? 9 : 0
                visible: height > 0

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    height: 1
                    color: Theme.alpha(Theme.surface, 0.55)
                }
            }

            Item {
                id: extraAction

                width: parent.width
                height: root.hasExtraAction && root.history.length === 0 ? 40 : 0
                visible: height > 0

                Rectangle {
                    anchors.fill: parent
                    radius: 10
                    color: extraActionMouse.containsMouse ? Theme.alpha(Theme.hoverSurface, 0.40) : "transparent"

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        text: "⏻"
                        color: extraActionMouse.containsMouse ? Theme.accentText : Theme.mutedText
                        font.family: Ui.fontFamily
                        font.pixelSize: Ui.body
                    }

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 42
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.extraActionText
                        elide: Text.ElideRight
                        color: extraActionMouse.containsMouse ? Theme.accentText : Theme.primaryText
                        font.family: Ui.fontFamily
                        font.pixelSize: Ui.body
                    }

                    MouseArea {
                        id: extraActionMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.extraActionTriggered();
                            root.hideMenu();
                            root.actionTriggered();
                        }
                    }
                }
            }

            Text {
                width: parent.width
                height: menuOpener.children && menuOpener.children.values.length === 0 && !(root.hasExtraAction && root.history.length === 0) ? 44 : 0
                visible: height > 0
                text: "No actions"
                color: Theme.mutedText
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                font.family: Ui.fontFamily
                font.pixelSize: Ui.body
            }
        }
    }

    Shortcut {
        sequence: "Escape"
        context: Qt.WindowShortcut
        onActivated: root.hideMenu()
    }

    HyprlandFocusGrab {
        windows: [root, root.host]
        active: root.visible
        onCleared: {
            root.hideMenu();
            root.host.open = false;
        }
    }
}
