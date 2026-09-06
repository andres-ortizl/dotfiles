import QtQuick

Item {
    id: root

    property var dashboard: null
    readonly property var runtimeData: root.dashboard ? root.dashboard.runtimeData : ({
    })
    readonly property var activityRoots: runtimeData.activity || []
    readonly property var unattachedAgents: runtimeData.unattachedAgents || []
    readonly property var selectedNode: findActivity(activityRoots, root.dashboard ? root.dashboard.selectedActivityIdentity : "")
    readonly property var selectedRows: flattenChildren(root.selectedNode)

    function flattenChildren(node) {
        if (!node)
            return [];

        const rows = [];
        const children = node.children || [];
        const pending = [];
        for (let index = children.length - 1; index >= 0; index--) pending.push({
            "node": children[index],
            "depth": 0
        })
        while (pending.length > 0) {
            const entry = pending.pop();
            rows.push(entry);
            const descendants = entry.node.children || [];
            for (let index = descendants.length - 1; index >= 0; index--) {
                pending.push({
                    "node": descendants[index],
                    "depth": entry.depth + 1
                });
            }
        }
        return rows;
    }

    function findActivity(nodes, identity) {
        if (!identity)
            return null;

        for (let index = 0; index < nodes.length; index++) {
            const node = nodes[index];
            if (node.identity === identity)
                return node;

            const child = findActivity(node.children || [], identity);
            if (child)
                return child;

        }
        return null;
    }

    width: parent ? parent.width : 0
    implicitHeight: content.implicitHeight

    Column {
        id: content

        width: parent.width
        spacing: root.dashboard ? root.dashboard.sectionGap : 16

        Column {
            width: parent.width
            spacing: root.dashboard ? root.dashboard.contentGap : 8
            visible: root.selectedNode === null
            height: visible ? implicitHeight : 0

            Text {
                width: parent.width
                height: 20
                text: "LIVE SESSIONS"
                color: root.dashboard ? root.dashboard.mutedText : "white"
                verticalAlignment: Text.AlignBottom
                font.family: root.dashboard ? root.dashboard.fontFamily : "monospace"
                font.pixelSize: root.dashboard ? root.dashboard.fontCaption : 10
                font.bold: true
                font.letterSpacing: 0.8
            }

            Repeater {
                model: root.activityRoots

                delegate: Rectangle {
                    id: sessionRow

                    required property var modelData

                    width: parent.width
                    height: root.dashboard ? root.dashboard.rowHeight : 64
                    radius: root.dashboard ? root.dashboard.cardRadius : 12
                    color: sessionMouse.containsMouse && root.dashboard ? root.dashboard.alpha(root.dashboard.surfaceColor, 0.62) : root.dashboard ? root.dashboard.alpha(root.dashboard.surfaceColor, 0.32) : "transparent"
                    border.width: 1
                    border.color: root.dashboard ? root.dashboard.alpha(root.dashboard.stateColor(modelData.state), 0.5) : "transparent"

                    Rectangle {
                        x: root.dashboard ? root.dashboard.cardPadding : 12
                        y: 17
                        width: 8
                        height: 8
                        radius: 4
                        color: root.dashboard ? root.dashboard.stateColor(sessionRow.modelData.state) : "white"
                    }

                    Text {
                        x: 34
                        y: 10
                        width: parent.width - 122
                        text: sessionRow.modelData.displayName || "Pi session"
                        color: root.dashboard ? root.dashboard.primaryText : "white"
                        elide: Text.ElideRight
                        font.family: root.dashboard ? root.dashboard.fontFamily : "monospace"
                        font.pixelSize: root.dashboard ? root.dashboard.fontRowTitle : 13
                        font.bold: true
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.rightMargin: root.dashboard ? root.dashboard.cardPadding : 12
                        y: 11
                        text: sessionRow.modelData.state || "open"
                        color: root.dashboard ? root.dashboard.stateColor(sessionRow.modelData.state) : "white"
                        font.family: root.dashboard ? root.dashboard.fontFamily : "monospace"
                        font.pixelSize: root.dashboard ? root.dashboard.fontCaption : 10
                        font.bold: true
                    }

                    Text {
                        x: 34
                        y: 37
                        width: parent.width - 48
                        text: `${root.dashboard.modelName(sessionRow.modelData.model)} • ${root.dashboard.countLabel(root.dashboard.descendantCount(sessionRow.modelData), "subagent")}${sessionRow.modelData.elapsed ? " • " + sessionRow.modelData.elapsed : ""}`
                        color: root.dashboard ? root.dashboard.mutedText : "white"
                        elide: Text.ElideRight
                        font.family: root.dashboard ? root.dashboard.fontFamily : "monospace"
                        font.pixelSize: root.dashboard ? root.dashboard.fontCaption : 10
                    }

                    MouseArea {
                        id: sessionMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.dashboard.selectedActivityIdentity = sessionRow.modelData.identity;
                            root.dashboard.scrollToTop();
                        }
                    }

                }

            }

            Text {
                width: parent.width
                height: root.activityRoots.length === 0 ? 48 : 0
                visible: height > 0
                text: "No live parent sessions. Run /reload inside Pi."
                color: root.dashboard ? root.dashboard.mutedText : "white"
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                font.family: root.dashboard ? root.dashboard.fontFamily : "monospace"
                font.pixelSize: root.dashboard ? root.dashboard.fontBody : 11
            }

            Text {
                width: parent.width
                height: root.unattachedAgents.length > 0 ? 36 : 0
                visible: height > 0
                text: `${root.unattachedAgents.length} live subagent${root.unattachedAgents.length === 1 ? "" : "s"} could not be associated safely`
                color: root.dashboard ? root.dashboard.warningColor : "white"
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                font.family: root.dashboard ? root.dashboard.fontFamily : "monospace"
                font.pixelSize: root.dashboard ? root.dashboard.fontCaption : 10
                wrapMode: Text.WordWrap
            }

        }

        Column {
            width: parent.width
            spacing: root.dashboard ? root.dashboard.sectionGap : 16
            visible: root.selectedNode !== null
            height: visible ? implicitHeight : 0

            Item {
                width: parent.width
                height: 28

                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "‹ ACTIVITY"
                    color: root.dashboard ? root.dashboard.accentText : "white"
                    font.family: root.dashboard ? root.dashboard.fontFamily : "monospace"
                    font.pixelSize: root.dashboard ? root.dashboard.fontBody : 11
                    font.bold: true
                }

                MouseArea {
                    anchors.left: parent.left
                    width: 110
                    height: parent.height
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.dashboard.selectedActivityIdentity = "";
                        root.dashboard.scrollToTop();
                    }
                }

            }

            Rectangle {
                width: parent.width
                height: root.dashboard ? root.dashboard.detailHeight : 104
                radius: root.dashboard ? root.dashboard.cardRadius : 12
                color: root.dashboard ? root.dashboard.alpha(root.dashboard.surfaceColor, 0.45) : "transparent"
                border.width: 1
                border.color: root.dashboard && root.selectedNode ? root.dashboard.alpha(root.dashboard.stateColor(root.selectedNode.state), 0.5) : "transparent"

                Text {
                    x: root.dashboard ? root.dashboard.cardPadding : 12
                    y: 11
                    width: parent.width - 140
                    text: root.selectedNode ? root.selectedNode.displayName : ""
                    color: root.dashboard ? root.dashboard.primaryText : "white"
                    elide: Text.ElideRight
                    font.family: root.dashboard ? root.dashboard.fontFamily : "monospace"
                    font.pixelSize: root.dashboard ? root.dashboard.fontTitle : 15
                    font.bold: true
                }

                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: root.dashboard ? root.dashboard.cardPadding : 12
                    y: 13
                    text: root.selectedNode ? root.selectedNode.state : ""
                    color: root.dashboard && root.selectedNode ? root.dashboard.stateColor(root.selectedNode.state) : "white"
                    font.family: root.dashboard ? root.dashboard.fontFamily : "monospace"
                    font.pixelSize: root.dashboard ? root.dashboard.fontCaption : 10
                    font.bold: true
                }

                Text {
                    x: root.dashboard ? root.dashboard.cardPadding : 12
                    y: 39
                    width: parent.width - 24
                    text: root.selectedNode ? `${root.dashboard.modelName(root.selectedNode.model)}${root.selectedNode.thinking ? " • " + root.selectedNode.thinking : ""}` : ""
                    color: root.dashboard ? root.dashboard.mutedText : "white"
                    elide: Text.ElideRight
                    font.family: root.dashboard ? root.dashboard.fontFamily : "monospace"
                    font.pixelSize: root.dashboard ? root.dashboard.fontBody : 11
                }

                Text {
                    x: root.dashboard ? root.dashboard.cardPadding : 12
                    y: 62
                    width: parent.width - 24
                    text: {
                        if (!root.selectedNode)
                            return "";

                        const usage = root.selectedNode.usage || {
                        };
                        const context = root.selectedNode.context || {
                        };
                        const values = [`${root.dashboard.compact(usage.totalTokens)} tokens`, root.dashboard.cost(usage.cost)];
                        if (root.dashboard.showContext && context.percent !== undefined && context.percent !== null)
                            values.push(`${Number(context.percent).toFixed(1)}% context`);

                        if (root.selectedNode.elapsed)
                            values.push(root.selectedNode.elapsed);

                        return values.join(" • ");
                    }
                    color: root.dashboard ? root.dashboard.quietText : "white"
                    elide: Text.ElideRight
                    font.family: root.dashboard ? root.dashboard.fontFamily : "monospace"
                    font.pixelSize: root.dashboard ? root.dashboard.fontCaption : 10
                }

                Text {
                    x: root.dashboard ? root.dashboard.cardPadding : 12
                    y: 83
                    width: parent.width - 24
                    text: root.selectedNode ? root.selectedNode.task || "Ready" : ""
                    color: root.dashboard ? root.dashboard.mutedText : "white"
                    elide: Text.ElideRight
                    font.family: root.dashboard ? root.dashboard.fontFamily : "monospace"
                    font.pixelSize: root.dashboard ? root.dashboard.fontCaption : 10
                }

            }

            Column {
                width: parent.width
                spacing: root.dashboard ? root.dashboard.contentGap : 8

                Text {
                    width: parent.width
                    height: 20
                    text: root.selectedNode ? `SUBAGENTS · ${root.dashboard.descendantCount(root.selectedNode)}` : "SUBAGENTS"
                    color: root.dashboard ? root.dashboard.mutedText : "white"
                    verticalAlignment: Text.AlignBottom
                    font.family: root.dashboard ? root.dashboard.fontFamily : "monospace"
                    font.pixelSize: root.dashboard ? root.dashboard.fontCaption : 10
                    font.bold: true
                    font.letterSpacing: 0.8
                }

                Repeater {
                    model: root.selectedRows

                    delegate: PiBeaconActivityNode {
                        required property var modelData

                        width: parent.width
                        dashboard: root.dashboard
                        node: modelData.node
                        depth: modelData.depth
                    }

                }

                Text {
                    width: parent.width
                    height: root.selectedRows.length === 0 ? 40 : 0
                    visible: height > 0
                    text: "No associated subagents"
                    color: root.dashboard ? root.dashboard.quietText : "white"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    font.family: root.dashboard ? root.dashboard.fontFamily : "monospace"
                    font.pixelSize: root.dashboard ? root.dashboard.fontBody : 11
                }

            }

            Text {
                width: parent.width
                height: 28
                text: root.selectedNode ? `Started ${root.dashboard.formatTime(root.selectedNode.startedAt)} • Last activity ${root.dashboard.formatTime(root.selectedNode.lastMessageAt)}` : ""
                color: root.dashboard ? root.dashboard.quietText : "white"
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
                font.family: root.dashboard ? root.dashboard.fontFamily : "monospace"
                font.pixelSize: root.dashboard ? root.dashboard.fontCaption : 10
            }

        }

    }

}
