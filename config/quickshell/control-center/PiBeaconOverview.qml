import QtQuick

Item {
    id: root

    property var dashboard: null
    readonly property var runtimeData: root.dashboard ? root.dashboard.runtimeData : ({
    })
    readonly property var todayData: root.dashboard ? root.dashboard.todayData : ({
    })
    readonly property var historyData: root.dashboard ? root.dashboard.historyData : ({
    })
    readonly property var activityRoots: runtimeData.activity || []
    readonly property var visibleRoots: activityRoots.slice(0, 2)
    readonly property var dailyCost: historyData.dailyCost || []
    readonly property var recentSessions: todayData.recent || []
    readonly property var topModel: (historyData.modelUsageToday || [])[0] || null
    readonly property real trendMaximum: maximumCost()

    function maximumCost() {
        let maximum = 0;
        for (let index = 0; index < dailyCost.length; index++) maximum = Math.max(maximum, Number(dailyCost[index].cost) || 0)
        return Math.max(maximum, 1);
    }

    function chartCost(value) {
        const amount = Number(value) || 0;
        if (amount >= 1000)
            return "$" + (amount / 1000).toFixed(amount >= 10000 ? 0 : 1) + "k";

        if (amount >= 100)
            return "$" + amount.toFixed(0);

        if (amount >= 10)
            return "$" + amount.toFixed(1);

        return "$" + amount.toFixed(2);
    }

    function dayLabel(value) {
        const date = new Date(String(value || "") + "T00:00:00");
        if (Number.isNaN(date.getTime()))
            return "";

        return ["SU", "MO", "TU", "WE", "TH", "FR", "SA"][date.getDay()];
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

            Text {
                width: parent.width
                height: 20
                text: "RIGHT NOW"
                color: root.dashboard ? root.dashboard.mutedText : "white"
                verticalAlignment: Text.AlignBottom
                font.family: root.dashboard ? root.dashboard.fontFamily : "monospace"
                font.pixelSize: root.dashboard ? root.dashboard.fontCaption : 10
                font.bold: true
                font.letterSpacing: 0.8
            }

            Row {
                width: parent.width
                height: root.dashboard ? root.dashboard.rowHeight : 64
                spacing: root.dashboard ? root.dashboard.contentGap : 8

                Rectangle {
                    width: (parent.width - parent.spacing) / 2
                    height: parent.height
                    radius: root.dashboard ? root.dashboard.cardRadius : 12
                    color: root.dashboard ? root.dashboard.alpha(root.dashboard.surfaceColor, 0.5) : "transparent"

                    Text {
                        x: root.dashboard ? root.dashboard.cardPadding : 12
                        y: 10
                        text: "LIVE SESSIONS"
                        color: root.dashboard ? root.dashboard.quietText : "white"
                        font.family: root.dashboard ? root.dashboard.fontFamily : "monospace"
                        font.pixelSize: root.dashboard ? root.dashboard.fontCaption : 10
                        font.bold: true
                    }

                    Text {
                        x: root.dashboard ? root.dashboard.cardPadding : 12
                        y: 29
                        text: String(root.runtimeData.sessionCount || 0)
                        color: root.dashboard ? root.dashboard.primaryText : "white"
                        font.family: root.dashboard ? root.dashboard.fontFamily : "monospace"
                        font.pixelSize: root.dashboard ? root.dashboard.fontMetric : 20
                        font.bold: true
                    }

                }

                Rectangle {
                    width: (parent.width - parent.spacing) / 2
                    height: parent.height
                    radius: root.dashboard ? root.dashboard.cardRadius : 12
                    color: root.dashboard ? root.dashboard.alpha(root.dashboard.surfaceColor, 0.5) : "transparent"

                    Text {
                        x: root.dashboard ? root.dashboard.cardPadding : 12
                        y: 10
                        text: "SUBAGENTS"
                        color: root.dashboard ? root.dashboard.quietText : "white"
                        font.family: root.dashboard ? root.dashboard.fontFamily : "monospace"
                        font.pixelSize: root.dashboard ? root.dashboard.fontCaption : 10
                        font.bold: true
                    }

                    Text {
                        x: root.dashboard ? root.dashboard.cardPadding : 12
                        y: 29
                        text: String(root.runtimeData.subagentCount || 0)
                        color: root.dashboard ? root.dashboard.primaryText : "white"
                        font.family: root.dashboard ? root.dashboard.fontFamily : "monospace"
                        font.pixelSize: root.dashboard ? root.dashboard.fontMetric : 20
                        font.bold: true
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.rightMargin: root.dashboard ? root.dashboard.cardPadding : 12
                        y: 38
                        visible: Number(root.runtimeData.attentionCount || 0) > 0
                        text: Number(root.runtimeData.attentionCount) === 1 ? "1 needs attention" : `${root.runtimeData.attentionCount} need attention`
                        color: root.dashboard ? root.dashboard.warningColor : "white"
                        font.family: root.dashboard ? root.dashboard.fontFamily : "monospace"
                        font.pixelSize: root.dashboard ? root.dashboard.fontCaption : 10
                        font.bold: true
                    }

                }

            }

            Repeater {
                model: root.visibleRoots

                delegate: Rectangle {
                    id: sessionRow

                    required property var modelData

                    width: parent.width
                    height: root.dashboard ? root.dashboard.rowHeight : 64
                    radius: root.dashboard ? root.dashboard.cardRadius : 12
                    color: sessionMouse.containsMouse && root.dashboard ? root.dashboard.alpha(root.dashboard.surfaceColor, 0.62) : root.dashboard ? root.dashboard.alpha(root.dashboard.surfaceColor, 0.3) : "transparent"
                    border.width: 1
                    border.color: root.dashboard ? root.dashboard.alpha(root.dashboard.stateColor(modelData.state), 0.48) : "transparent"

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
                        width: parent.width - 74
                        text: sessionRow.modelData.displayName || "Pi session"
                        color: root.dashboard ? root.dashboard.primaryText : "white"
                        elide: Text.ElideRight
                        font.family: root.dashboard ? root.dashboard.fontFamily : "monospace"
                        font.pixelSize: root.dashboard ? root.dashboard.fontRowTitle : 13
                        font.bold: true
                    }

                    Text {
                        x: 34
                        y: 36
                        width: parent.width - 74
                        text: `${root.dashboard ? root.dashboard.modelName(sessionRow.modelData.model) : "Unknown model"} • ${root.dashboard ? root.dashboard.countLabel(root.dashboard.descendantCount(sessionRow.modelData), "subagent") : "0 subagents"}`
                        color: root.dashboard ? root.dashboard.mutedText : "white"
                        elide: Text.ElideRight
                        font.family: root.dashboard ? root.dashboard.fontFamily : "monospace"
                        font.pixelSize: root.dashboard ? root.dashboard.fontCaption : 10
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.rightMargin: root.dashboard ? root.dashboard.cardPadding : 12
                        anchors.verticalCenter: parent.verticalCenter
                        text: "›"
                        color: root.dashboard ? root.dashboard.quietText : "white"
                        font.family: root.dashboard ? root.dashboard.fontFamily : "monospace"
                        font.pixelSize: 18
                    }

                    MouseArea {
                        id: sessionMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.dashboard.selectedActivityIdentity = sessionRow.modelData.identity;
                            root.dashboard.currentTab = "activity";
                        }
                    }

                }

            }

            Item {
                width: parent.width
                height: root.activityRoots.length > root.visibleRoots.length ? 28 : 0
                visible: height > 0

                Text {
                    anchors.centerIn: parent
                    text: `VIEW ALL ${root.activityRoots.length} SESSIONS  →`
                    color: root.dashboard ? root.dashboard.accentText : "white"
                    font.family: root.dashboard ? root.dashboard.fontFamily : "monospace"
                    font.pixelSize: root.dashboard ? root.dashboard.fontCaption : 10
                    font.bold: true
                    font.letterSpacing: 0.4
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.dashboard.currentTab = "activity"
                }

            }

            Text {
                width: parent.width
                height: root.activityRoots.length === 0 ? 40 : 0
                visible: height > 0
                text: "No live session bridge yet. Run /reload inside Pi."
                color: root.dashboard ? root.dashboard.mutedText : "white"
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                font.family: root.dashboard ? root.dashboard.fontFamily : "monospace"
                font.pixelSize: root.dashboard ? root.dashboard.fontBody : 11
            }

        }

        Column {
            width: parent.width
            spacing: root.dashboard ? root.dashboard.contentGap : 8

            Text {
                width: parent.width
                height: 20
                text: "TODAY"
                color: root.dashboard ? root.dashboard.mutedText : "white"
                verticalAlignment: Text.AlignBottom
                font.family: root.dashboard ? root.dashboard.fontFamily : "monospace"
                font.pixelSize: root.dashboard ? root.dashboard.fontCaption : 10
                font.bold: true
                font.letterSpacing: 0.8
            }

            Row {
                id: todayMetricRow

                width: parent.width
                height: root.dashboard ? root.dashboard.rowHeight : 64
                spacing: 6

                Repeater {
                    model: [{
                        "label": "COST",
                        "value": root.dashboard && root.dashboard.showCost ? root.dashboard.cost(root.todayData.cost) : "hidden"
                    }, {
                        "label": "TOKENS",
                        "value": root.dashboard ? root.dashboard.compact(root.todayData.tokens) : "0"
                    }, {
                        "label": "SESSIONS",
                        "value": String(root.todayData.sessions || 0)
                    }, {
                        "label": "RESPONSES",
                        "value": String(root.todayData.messages || 0)
                    }]

                    delegate: Rectangle {
                        required property var modelData

                        width: (todayMetricRow.width - todayMetricRow.spacing * 3) / 4
                        height: todayMetricRow.height
                        radius: root.dashboard ? root.dashboard.cardRadius : 12
                        color: root.dashboard ? root.dashboard.alpha(root.dashboard.surfaceColor, 0.46) : "transparent"

                        Text {
                            x: 10
                            y: 10
                            text: parent.modelData.label
                            color: root.dashboard ? root.dashboard.quietText : "white"
                            font.family: root.dashboard ? root.dashboard.fontFamily : "monospace"
                            font.pixelSize: root.dashboard ? root.dashboard.fontCaption : 10
                            font.bold: true
                        }

                        Text {
                            x: 10
                            y: 34
                            width: parent.width - 20
                            text: parent.modelData.value
                            color: root.dashboard ? root.dashboard.primaryText : "white"
                            elide: Text.ElideRight
                            font.family: root.dashboard ? root.dashboard.fontFamily : "monospace"
                            font.pixelSize: 13
                            font.bold: true
                        }

                    }

                }

            }

        }

        Column {
            width: parent.width
            spacing: root.dashboard ? root.dashboard.contentGap : 8

            Text {
                width: parent.width
                height: 20
                text: "TOP MODEL TODAY"
                color: root.dashboard ? root.dashboard.mutedText : "white"
                verticalAlignment: Text.AlignBottom
                font.family: root.dashboard ? root.dashboard.fontFamily : "monospace"
                font.pixelSize: root.dashboard ? root.dashboard.fontCaption : 10
                font.bold: true
                font.letterSpacing: 0.8
            }

            Rectangle {
                width: parent.width
                height: root.topModel !== null ? root.dashboard.rowHeight : 0
                radius: root.dashboard ? root.dashboard.cardRadius : 12
                color: topModelMouse.containsMouse && root.dashboard ? root.dashboard.alpha(root.dashboard.surfaceColor, 0.6) : root.dashboard ? root.dashboard.alpha(root.dashboard.surfaceColor, 0.32) : "transparent"
                visible: height > 0

                Text {
                    x: root.dashboard ? root.dashboard.cardPadding : 12
                    y: 10
                    width: parent.width - 140
                    text: root.dashboard ? root.dashboard.modelName(root.topModel ? root.topModel.model : "") : "Unknown model"
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
                    text: root.dashboard ? root.dashboard.cost(root.topModel ? root.topModel.cost : 0) : "$0.00"
                    color: root.dashboard ? root.dashboard.accentText : "white"
                    font.family: root.dashboard ? root.dashboard.fontFamily : "monospace"
                    font.pixelSize: root.dashboard ? root.dashboard.fontBody : 11
                    font.bold: true
                }

                Text {
                    x: root.dashboard ? root.dashboard.cardPadding : 12
                    y: 38
                    width: parent.width - 24
                    text: `${root.dashboard ? root.dashboard.compact(root.topModel ? root.topModel.tokens : 0) : "0"} tokens • ${root.topModel ? root.topModel.responses : 0} responses`
                    color: root.dashboard ? root.dashboard.mutedText : "white"
                    font.family: root.dashboard ? root.dashboard.fontFamily : "monospace"
                    font.pixelSize: root.dashboard ? root.dashboard.fontCaption : 10
                }

                MouseArea {
                    id: topModelMouse

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.dashboard.selectedModel = root.topModel.model;
                        root.dashboard.currentTab = "models";
                    }
                }

            }

            Text {
                width: parent.width
                height: root.topModel === null ? 34 : 0
                visible: height > 0
                text: "No model-attributed responses today"
                color: root.dashboard ? root.dashboard.quietText : "white"
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
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
                text: "DAILY COST · 7D"
                color: root.dashboard ? root.dashboard.mutedText : "white"
                verticalAlignment: Text.AlignBottom
                font.family: root.dashboard ? root.dashboard.fontFamily : "monospace"
                font.pixelSize: root.dashboard ? root.dashboard.fontCaption : 10
                font.bold: true
                font.letterSpacing: 0.8
            }

            Rectangle {
                width: parent.width
                height: root.dailyCost.length > 0 ? root.dailyCost.length * 22 + 16 : 58
                radius: root.dashboard ? root.dashboard.cardRadius : 12
                color: root.dashboard ? root.dashboard.alpha(root.dashboard.surfaceColor, 0.3) : "transparent"

                Column {
                    anchors.fill: parent
                    anchors.margins: 8

                    Repeater {
                        model: root.dailyCost

                        delegate: Item {
                            id: dailyBar

                            required property var modelData
                            readonly property real amount: Number(modelData.cost) || 0

                            width: parent.width
                            height: 22

                            Text {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                width: 28
                                text: root.dayLabel(dailyBar.modelData.day)
                                color: root.dashboard ? root.dashboard.mutedText : "white"
                                font.family: root.dashboard ? root.dashboard.fontFamily : "monospace"
                                font.pixelSize: root.dashboard ? root.dashboard.fontCaption : 10
                                font.bold: true
                            }

                            Rectangle {
                                anchors.left: parent.left
                                anchors.leftMargin: 34
                                anchors.right: costText.left
                                anchors.rightMargin: 12
                                anchors.verticalCenter: parent.verticalCenter
                                height: 4
                                radius: 2
                                color: root.dashboard ? root.dashboard.alpha(root.dashboard.quietText, 0.18) : "transparent"

                                Rectangle {
                                    width: dailyBar.amount > 0 ? Math.max(2, parent.width * dailyBar.amount / root.trendMaximum) : 0
                                    height: parent.height
                                    radius: parent.radius
                                    color: root.dashboard ? root.dashboard.alpha(root.dashboard.accentColor, 0.86) : "white"
                                }

                            }

                            Text {
                                id: costText

                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                width: 62
                                text: root.chartCost(dailyBar.amount)
                                color: root.dashboard ? root.dashboard.primaryText : "white"
                                horizontalAlignment: Text.AlignRight
                                font.family: root.dashboard ? root.dashboard.fontFamily : "monospace"
                                font.pixelSize: root.dashboard ? root.dashboard.fontCaption : 10
                                font.bold: true
                            }

                        }

                    }

                }

                Text {
                    anchors.centerIn: parent
                    visible: root.dailyCost.length === 0
                    text: "No retained cost data yet"
                    color: root.dashboard ? root.dashboard.quietText : "white"
                    font.family: root.dashboard ? root.dashboard.fontFamily : "monospace"
                    font.pixelSize: root.dashboard ? root.dashboard.fontCaption : 10
                }

            }

        }

        Column {
            width: parent.width
            spacing: 4
            visible: root.dashboard && root.dashboard.showRecent && root.recentSessions.length > 0
            height: visible ? implicitHeight : 0

            Text {
                width: parent.width
                height: 20
                text: "RECENT TODAY"
                color: root.dashboard ? root.dashboard.mutedText : "white"
                verticalAlignment: Text.AlignBottom
                font.family: root.dashboard ? root.dashboard.fontFamily : "monospace"
                font.pixelSize: root.dashboard ? root.dashboard.fontCaption : 10
                font.bold: true
                font.letterSpacing: 0.8
            }

            Repeater {
                model: root.dashboard && root.dashboard.showRecent ? root.recentSessions.slice(0, root.dashboard.recentLimit) : []

                delegate: Item {
                    id: recentRow

                    required property var modelData

                    width: parent.width
                    height: 28

                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 170
                        text: recentRow.modelData.project || "session"
                        color: root.dashboard ? root.dashboard.mutedText : "white"
                        elide: Text.ElideRight
                        font.family: root.dashboard ? root.dashboard.fontFamily : "monospace"
                        font.pixelSize: root.dashboard ? root.dashboard.fontCaption : 10
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: `${root.dashboard ? root.dashboard.compact(recentRow.modelData.tokens) : "0"} • ${root.dashboard ? root.dashboard.cost(recentRow.modelData.cost) : "$0.00"}`
                        color: root.dashboard ? root.dashboard.quietText : "white"
                        font.family: root.dashboard ? root.dashboard.fontFamily : "monospace"
                        font.pixelSize: root.dashboard ? root.dashboard.fontCaption : 10
                    }

                }

            }

        }

    }

}
