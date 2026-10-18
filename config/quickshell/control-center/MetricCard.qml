import QtQuick
import QtQuick.Controls.Basic as Controls

Rectangle {
    id: root

    required property string icon
    required property string title
    required property string value
    required property string detail
    property string subtitle: ""
    property bool prominent: false
    property bool placeholder: false
    property bool critical: false
    property bool interactive: false

    signal clicked()

    implicitHeight: Math.max(prominent ? 132 : 96, metricButton.implicitHeight)
    height: implicitHeight
    radius: 14
    color: "transparent"

    Controls.Button {
        id: metricButton

        anchors.fill: parent
        implicitHeight: metricContent.implicitHeight + topPadding + bottomPadding
        padding: 12
        text: root.title
        enabled: root.interactive
        hoverEnabled: root.interactive
        focusPolicy: root.interactive ? Qt.StrongFocus : Qt.NoFocus
        Accessible.name: `${root.title}: ${root.value}`
        Accessible.description: (root.critical ? "Attention required. " : "") + (root.subtitle ? root.subtitle + ". " : "") + root.detail
        Accessible.role: root.interactive ? Accessible.Button : Accessible.StaticText
        Keys.onReturnPressed: metricButton.clicked()
        Keys.onEnterPressed: metricButton.clicked()
        onClicked: root.clicked()

        background: Rectangle {
            radius: root.radius
            color: metricButton.down ? Theme.alpha(Theme.surface, 0.55) : metricButton.hovered || root.prominent ? Theme.alpha(Theme.surface, 0.45) : Theme.alpha(Theme.surface, 0.30)
            border.width: metricButton.visualFocus ? 2 : root.critical ? 1 : 0
            border.color: root.critical ? Theme.alpha(Theme.danger, 0.60) : Theme.accent

            Behavior on color {
                ColorAnimation { duration: 120 }
            }
        }

        contentItem: Column {
            id: metricContent

            spacing: 4

            Item {
                width: parent.width
                height: Ui.icon

                Text {
                    id: metricIcon

                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.icon
                    color: root.critical ? Theme.danger : Theme.accent
                    font.family: Ui.fontFamily
                    font.pixelSize: Ui.icon
                }

                Text {
                    x: metricIcon.implicitWidth + 8
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - x - 24
                    text: root.title
                    color: Theme.mutedText
                    elide: Text.ElideRight
                    font.family: Ui.fontFamily
                    font.pixelSize: Ui.caption
                    font.bold: true
                    font.letterSpacing: 0.6
                }

                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.critical || root.interactive
                    text: root.critical ? "!" : "›"
                    color: root.critical ? Theme.danger : Theme.quietText
                    font.family: Ui.fontFamily
                    font.pixelSize: Ui.body
                    font.bold: root.critical
                }
            }

            Text {
                width: parent.width
                text: root.value
                color: root.placeholder ? Theme.mutedText : root.critical ? Theme.danger : Theme.primaryText
                wrapMode: Text.Wrap
                font.family: Ui.fontFamily
                font.pixelSize: root.prominent && !root.placeholder ? Math.round(Ui.heading * 1.75) : Ui.heading
                font.bold: true
            }

            Text {
                width: parent.width
                visible: root.subtitle !== ""
                text: root.subtitle
                color: Theme.mutedText
                wrapMode: Text.Wrap
                font.family: Ui.fontFamily
                font.pixelSize: Ui.caption
            }

            Text {
                width: parent.width
                text: root.detail
                color: Theme.mutedText
                wrapMode: Text.Wrap
                font.family: Ui.fontFamily
                font.pixelSize: Ui.caption
            }
        }

        HoverHandler {
            enabled: root.interactive
            cursorShape: Qt.PointingHandCursor
        }
    }
}
