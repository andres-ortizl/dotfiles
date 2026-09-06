import QtQuick

Item {
    id: root

    property var dashboard: null
    property string usageRange: "today"
    property string sortKey: "cost"
    readonly property var runtimeData: root.dashboard ? root.dashboard.runtimeData : ({
    })
    readonly property var historyData: root.dashboard ? root.dashboard.historyData : ({
    })
    readonly property var activeModels: runtimeData.modelActivity || []
    readonly property var usageModels: sortedUsage()
    readonly property var selectedUsage: findUsage(root.dashboard ? root.dashboard.selectedModel : "")
    readonly property var selectedActivity: findActivity(root.dashboard ? root.dashboard.selectedModel : "")
    readonly property real usageMaximum: maximumUsage()

    function sourceUsage() {
        return usageRange === "today" ? historyData.modelUsageToday || [] : historyData.modelUsage7d || [];
    }

    function sortedUsage() {
        const records = sourceUsage().slice();
        records.sort((left, right) => {
            const difference = (Number(right[sortKey]) || 0) - (Number(left[sortKey]) || 0);
            return difference || String(left.model).localeCompare(String(right.model));
        });
        return records;
    }

    function maximumUsage() {
        let maximum = 0;
        for (let index = 0; index < usageModels.length; index++) maximum = Math.max(maximum, Number(usageModels[index][sortKey]) || 0)
        return Math.max(maximum, 1);
    }

    function findUsage(model) {
        if (!model)
            return null;

        const records = sourceUsage();
        for (let index = 0; index < records.length; index++) {
            if (records[index].model === model)
                return records[index];

        }
        return null;
    }

    function findActivity(model) {
        if (!model)
            return null;

        for (let index = 0; index < activeModels.length; index++) {
            if (activeModels[index].model === model)
                return activeModels[index];

        }
        return null;
    }

    function sortLabel(key) {
        return key === "responses" ? "RESPONSES" : key.toUpperCase();
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
            visible: root.selectedUsage === null && root.selectedActivity === null
            height: visible ? implicitHeight : 0

            Text {
                width: parent.width
                height: 20
                text: `ACTIVE NOW · ${root.activeModels.length}`
                color: root.dashboard ? root.dashboard.mutedText : "white"
                verticalAlignment: Text.AlignBottom
                font.family: root.dashboard ? root.dashboard.fontFamily : "monospace"
                font.pixelSize: root.dashboard ? root.dashboard.fontCaption : 10
                font.bold: true
                font.letterSpacing: 0.8
            }

            Repeater {
                model: root.activeModels

                delegate: Rectangle {
                    id: activeRow

                    required property var modelData

                    width: parent.width
                    height: root.dashboard ? root.dashboard.rowHeight : 64
                    radius: root.dashboard ? root.dashboard.cardRadius : 12
                    color: activeMouse.containsMouse && root.dashboard ? root.dashboard.alpha(root.dashboard.surfaceColor, 0.62) : root.dashboard ? root.dashboard.alpha(root.dashboard.surfaceColor, 0.3) : "transparent"

                    Text {
                        x: root.dashboard ? root.dashboard.cardPadding : 12
                        y: 10
                        width: parent.width - 120
                        text: root.dashboard.modelName(activeRow.modelData.model)
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
                        text: `${activeRow.modelData.liveCount} live`
                        color: root.dashboard ? root.dashboard.accentText : "white"
                        font.family: root.dashboard ? root.dashboard.fontFamily : "monospace"
                        font.pixelSize: root.dashboard ? root.dashboard.fontCaption : 10
                        font.bold: true
                    }

                    Text {
                        x: root.dashboard ? root.dashboard.cardPadding : 12
                        y: 38
                        width: parent.width - 24
                        text: `${root.dashboard.providerName(activeRow.modelData.model)} • ${root.dashboard.countLabel(activeRow.modelData.sessionCount, "session")} • ${root.dashboard.countLabel(activeRow.modelData.subagentCount, "subagent")}`
                        color: root.dashboard ? root.dashboard.mutedText : "white"
                        elide: Text.ElideRight
                        font.family: root.dashboard ? root.dashboard.fontFamily : "monospace"
                        font.pixelSize: root.dashboard ? root.dashboard.fontCaption : 10
                    }

                    MouseArea {
                        id: activeMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.dashboard.selectedModel = activeRow.modelData.model;
                            root.dashboard.scrollToTop();
                        }
                    }

                }

            }

            Text {
                width: parent.width
                height: root.activeModels.length === 0 ? 40 : 0
                visible: height > 0
                text: "No known models in live processes"
                color: root.dashboard ? root.dashboard.quietText : "white"
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                font.family: root.dashboard ? root.dashboard.fontFamily : "monospace"
                font.pixelSize: root.dashboard ? root.dashboard.fontBody : 11
            }

        }

        Column {
            width: parent.width
            spacing: root.dashboard ? root.dashboard.contentGap : 8
            visible: root.selectedUsage === null && root.selectedActivity === null
            height: visible ? implicitHeight : 0

            Item {
                width: parent.width
                height: 30

                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "RANKING"
                    color: root.dashboard ? root.dashboard.mutedText : "white"
                    font.family: root.dashboard ? root.dashboard.fontFamily : "monospace"
                    font.pixelSize: root.dashboard ? root.dashboard.fontCaption : 10
                    font.bold: true
                    font.letterSpacing: 0.8
                }

                Row {
                    anchors.right: parent.right
                    height: parent.height
                    spacing: 4

                    Repeater {
                        model: [{
                            "key": "today",
                            "label": "TODAY"
                        }, {
                            "key": "7d",
                            "label": "7D"
                        }]

                        delegate: Rectangle {
                            required property var modelData

                            width: 58
                            height: parent.height
                            radius: root.dashboard ? root.dashboard.controlRadius : 8
                            color: root.usageRange === modelData.key && root.dashboard ? root.dashboard.alpha(root.dashboard.accentColor, 0.13) : rangeMouse.containsMouse && root.dashboard ? root.dashboard.alpha(root.dashboard.surfaceColor, 0.5) : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: parent.modelData.label
                                color: root.usageRange === parent.modelData.key && root.dashboard ? root.dashboard.accentText : root.dashboard ? root.dashboard.mutedText : "white"
                                font.family: root.dashboard ? root.dashboard.fontFamily : "monospace"
                                font.pixelSize: root.dashboard ? root.dashboard.fontCaption : 10
                                font.bold: true
                            }

                            MouseArea {
                                id: rangeMouse

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.usageRange = parent.modelData.key
                            }

                        }

                    }

                }

            }

            Row {
                id: sortRow

                width: parent.width
                height: 30
                spacing: 4

                Repeater {
                    model: ["cost", "tokens", "responses", "sessions"]

                    delegate: Rectangle {
                        required property string modelData

                        width: (sortRow.width - sortRow.spacing * 3) / 4
                        height: sortRow.height
                        radius: root.dashboard ? root.dashboard.controlRadius : 8
                        color: sortMouse.containsMouse && root.dashboard ? root.dashboard.alpha(root.dashboard.surfaceColor, 0.45) : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: root.sortLabel(parent.modelData)
                            color: root.sortKey === parent.modelData && root.dashboard ? root.dashboard.accentText : root.dashboard ? root.dashboard.mutedText : "white"
                            font.family: root.dashboard ? root.dashboard.fontFamily : "monospace"
                            font.pixelSize: root.dashboard ? root.dashboard.fontCaption : 10
                            font.bold: true
                        }

                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            width: root.sortKey === parent.modelData ? 30 : 0
                            height: 2
                            radius: 1
                            color: root.dashboard ? root.dashboard.accentColor : "white"
                        }

                        MouseArea {
                            id: sortMouse

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.sortKey = parent.modelData
                        }

                    }

                }

            }

            Repeater {
                model: root.usageModels

                delegate: Rectangle {
                    id: usageRow

                    required property var modelData
                    required property int index
                    readonly property real metric: Number(modelData[root.sortKey]) || 0

                    width: parent.width
                    height: 68
                    radius: root.dashboard ? root.dashboard.cardRadius : 12
                    color: usageMouse.containsMouse && root.dashboard ? root.dashboard.alpha(root.dashboard.surfaceColor, 0.62) : root.dashboard ? root.dashboard.alpha(root.dashboard.surfaceColor, 0.3) : "transparent"

                    Text {
                        x: root.dashboard ? root.dashboard.cardPadding : 12
                        y: 9
                        width: parent.width - 132
                        text: `${index + 1}  ${root.dashboard.modelName(usageRow.modelData.model)}`
                        color: root.dashboard ? root.dashboard.primaryText : "white"
                        elide: Text.ElideRight
                        font.family: root.dashboard ? root.dashboard.fontFamily : "monospace"
                        font.pixelSize: root.dashboard ? root.dashboard.fontRowTitle : 13
                        font.bold: true
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.rightMargin: root.dashboard ? root.dashboard.cardPadding : 12
                        y: 10
                        text: root.sortKey === "cost" ? root.dashboard.cost(usageRow.modelData.cost) : root.dashboard.compact(usageRow.metric)
                        color: root.dashboard ? root.dashboard.accentText : "white"
                        font.family: root.dashboard ? root.dashboard.fontFamily : "monospace"
                        font.pixelSize: root.dashboard ? root.dashboard.fontBody : 11
                        font.bold: true
                    }

                    Rectangle {
                        x: root.dashboard ? root.dashboard.cardPadding : 12
                        y: 34
                        width: parent.width - 24
                        height: 4
                        radius: 2
                        color: root.dashboard ? root.dashboard.alpha(root.dashboard.quietText, 0.18) : "transparent"

                        Rectangle {
                            width: parent.width * usageRow.metric / root.usageMaximum
                            height: parent.height
                            radius: parent.radius
                            color: root.dashboard ? root.dashboard.alpha(root.dashboard.accentColor, 0.86) : "white"
                        }

                    }

                    Text {
                        x: root.dashboard ? root.dashboard.cardPadding : 12
                        y: 47
                        width: parent.width - 24
                        text: `${root.dashboard.compact(usageRow.modelData.tokens)} tokens • ${usageRow.modelData.responses} responses • ${usageRow.modelData.sessions} sessions`
                        color: root.dashboard ? root.dashboard.mutedText : "white"
                        elide: Text.ElideRight
                        font.family: root.dashboard ? root.dashboard.fontFamily : "monospace"
                        font.pixelSize: root.dashboard ? root.dashboard.fontCaption : 10
                    }

                    MouseArea {
                        id: usageMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.dashboard.selectedModel = usageRow.modelData.model;
                            root.dashboard.scrollToTop();
                        }
                    }

                }

            }

            Text {
                width: parent.width
                height: root.usageModels.length === 0 ? 40 : 0
                visible: height > 0
                text: `No model-attributed responses in ${root.usageRange === "today" ? "today" : "the last 7 days"}`
                color: root.dashboard ? root.dashboard.quietText : "white"
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                font.family: root.dashboard ? root.dashboard.fontFamily : "monospace"
                font.pixelSize: root.dashboard ? root.dashboard.fontBody : 11
            }

        }

        Column {
            width: parent.width
            spacing: root.dashboard ? root.dashboard.sectionGap : 16
            visible: root.selectedUsage !== null || root.selectedActivity !== null
            height: visible ? implicitHeight : 0

            Item {
                width: parent.width
                height: 28

                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "‹ MODELS"
                    color: root.dashboard ? root.dashboard.accentText : "white"
                    font.family: root.dashboard ? root.dashboard.fontFamily : "monospace"
                    font.pixelSize: root.dashboard ? root.dashboard.fontBody : 11
                    font.bold: true
                }

                MouseArea {
                    anchors.left: parent.left
                    width: 100
                    height: parent.height
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.dashboard.selectedModel = "";
                        root.dashboard.scrollToTop();
                    }
                }

            }

            Rectangle {
                width: parent.width
                height: root.dashboard ? root.dashboard.detailHeight : 104
                radius: root.dashboard ? root.dashboard.cardRadius : 12
                color: root.dashboard ? root.dashboard.alpha(root.dashboard.surfaceColor, 0.45) : "transparent"

                Text {
                    x: root.dashboard ? root.dashboard.cardPadding : 12
                    y: 11
                    width: parent.width - 24
                    text: root.dashboard ? root.dashboard.modelName(root.dashboard.selectedModel) : ""
                    color: root.dashboard ? root.dashboard.primaryText : "white"
                    elide: Text.ElideRight
                    font.family: root.dashboard ? root.dashboard.fontFamily : "monospace"
                    font.pixelSize: root.dashboard ? root.dashboard.fontTitle : 15
                    font.bold: true
                }

                Text {
                    x: root.dashboard ? root.dashboard.cardPadding : 12
                    y: 36
                    width: parent.width - 24
                    text: root.dashboard ? root.dashboard.providerName(root.dashboard.selectedModel) : ""
                    color: root.dashboard ? root.dashboard.mutedText : "white"
                    font.family: root.dashboard ? root.dashboard.fontFamily : "monospace"
                    font.pixelSize: root.dashboard ? root.dashboard.fontCaption : 10
                }

                Text {
                    x: root.dashboard ? root.dashboard.cardPadding : 12
                    y: 55
                    text: root.selectedUsage ? root.dashboard.cost(root.selectedUsage.cost) : "No retained usage"
                    color: root.dashboard ? root.dashboard.accentText : "white"
                    font.family: root.dashboard ? root.dashboard.fontFamily : "monospace"
                    font.pixelSize: root.dashboard ? root.dashboard.fontMetric : 20
                    font.bold: true
                }

                Text {
                    x: root.dashboard ? root.dashboard.cardPadding : 12
                    y: 83
                    width: parent.width - 24
                    text: root.selectedUsage ? `${root.dashboard.compact(root.selectedUsage.tokens)} tokens • ${root.selectedUsage.responses} responses • ${root.selectedUsage.sessions} sessions · ${root.usageRange === "today" ? "today" : "7d"}` : "No attributed assistant responses in this range"
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
                    text: "ACTIVE NOW"
                    color: root.dashboard ? root.dashboard.mutedText : "white"
                    verticalAlignment: Text.AlignBottom
                    font.family: root.dashboard ? root.dashboard.fontFamily : "monospace"
                    font.pixelSize: root.dashboard ? root.dashboard.fontCaption : 10
                    font.bold: true
                    font.letterSpacing: 0.8
                }

                Rectangle {
                    width: parent.width
                    height: root.dashboard ? root.dashboard.rowHeight : 64
                    radius: root.dashboard ? root.dashboard.cardRadius : 12
                    color: root.dashboard ? root.dashboard.alpha(root.dashboard.surfaceColor, 0.3) : "transparent"

                    Text {
                        x: root.dashboard ? root.dashboard.cardPadding : 12
                        y: 11
                        text: root.selectedActivity ? root.dashboard.countLabel(root.selectedActivity.liveCount, "live process") : "Not used by a live process"
                        color: root.dashboard ? root.dashboard.primaryText : "white"
                        font.family: root.dashboard ? root.dashboard.fontFamily : "monospace"
                        font.pixelSize: root.dashboard ? root.dashboard.fontRowTitle : 13
                        font.bold: true
                    }

                    Text {
                        x: root.dashboard ? root.dashboard.cardPadding : 12
                        y: 38
                        text: root.selectedActivity ? `${root.dashboard.countLabel(root.selectedActivity.sessionCount, "session")} • ${root.dashboard.countLabel(root.selectedActivity.subagentCount, "subagent")}` : "Live process models are reported independently"
                        color: root.dashboard ? root.dashboard.mutedText : "white"
                        font.family: root.dashboard ? root.dashboard.fontFamily : "monospace"
                        font.pixelSize: root.dashboard ? root.dashboard.fontCaption : 10
                    }

                }

            }

        }

    }

}
