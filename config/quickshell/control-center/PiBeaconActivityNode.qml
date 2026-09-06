import QtQuick

Item {
    id: root

    property var dashboard: null
    property var node
    property int depth: 0

    width: parent ? parent.width : 0
    implicitHeight: (root.dashboard ? root.dashboard.rowHeight : 64) + 4

    Item {
        anchors.fill: parent

        Rectangle {
            x: root.depth * 16 + 4
            y: 0
            width: 1
            height: parent.height
            color: root.dashboard ? root.dashboard.alpha(root.dashboard.mutedText, 0.25) : "transparent"
        }

        Text {
            x: root.depth * 16
            anchors.verticalCenter: parent.verticalCenter
            text: "↳"
            color: root.dashboard ? root.dashboard.quietText : "white"
            font.family: root.dashboard ? root.dashboard.fontFamily : "monospace"
            font.pixelSize: root.dashboard ? root.dashboard.fontBody : 11
        }

        Rectangle {
            id: nodeCard

            x: root.depth * 16 + 18
            width: parent.width - x
            height: root.dashboard ? root.dashboard.rowHeight : 64
            radius: root.dashboard ? root.dashboard.cardRadius : 12
            color: root.dashboard ? root.dashboard.alpha(root.dashboard.surfaceColor, 0.26) : "transparent"

            Rectangle {
                x: root.dashboard ? root.dashboard.cardPadding : 12
                y: 17
                width: 8
                height: 8
                radius: 4
                color: root.dashboard && root.node ? root.dashboard.stateColor(root.node.state) : "white"
            }

            Text {
                x: 34
                y: 10
                width: parent.width - 118
                text: root.node ? root.node.displayName || "Pi work" : "Pi work"
                color: root.dashboard ? root.dashboard.primaryText : "white"
                elide: Text.ElideRight
                font.family: root.dashboard ? root.dashboard.fontFamily : "monospace"
                font.pixelSize: root.dashboard ? root.dashboard.fontRowTitle : 13
                font.bold: true
            }

            Text {
                anchors.right: parent.right
                anchors.rightMargin: root.dashboard ? root.dashboard.cardPadding : 12
                y: 12
                text: root.node ? root.node.elapsed || root.node.state : ""
                color: root.dashboard && root.node ? root.dashboard.stateColor(root.node.state) : "white"
                font.family: root.dashboard ? root.dashboard.fontFamily : "monospace"
                font.pixelSize: root.dashboard ? root.dashboard.fontCaption : 10
                font.bold: true
            }

            Text {
                x: 34
                y: 37
                width: parent.width - 46
                text: {
                    if (!root.node)
                        return "";

                    const values = [];
                    if (root.node.model)
                        values.push(root.dashboard.modelName(root.node.model));

                    if (root.node.task)
                        values.push(root.node.task);

                    return values.join(" • ") || root.node.state;
                }
                color: root.dashboard ? root.dashboard.mutedText : "white"
                elide: Text.ElideRight
                font.family: root.dashboard ? root.dashboard.fontFamily : "monospace"
                font.pixelSize: root.dashboard ? root.dashboard.fontCaption : 10
            }

        }

    }

}
