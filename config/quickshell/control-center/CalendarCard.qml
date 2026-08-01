import QtQuick

Rectangle {
    id: root

    required property var events
    property int year: new Date().getFullYear()
    property int month: new Date().getMonth()

    signal openRequested()

    readonly property var monthNames: [
        "January", "February", "March", "April", "May", "June",
        "July", "August", "September", "October", "November", "December"
    ]
    readonly property var weekDays: ["M", "T", "W", "T", "F", "S", "S"]
    readonly property int firstWeekDay: (new Date(year, month, 1).getDay() + 6) % 7
    readonly property int daysInMonth: new Date(year, month + 1, 0).getDate()

    function previousMonth() {
        if (month === 0) {
            month = 11;
            year--;
        } else {
            month--;
        }
    }

    function nextMonth() {
        if (month === 11) {
            month = 0;
            year++;
        } else {
            month++;
        }
    }

    function dateKey(day) {
        return `${year}-${String(month + 1).padStart(2, "0")}-${String(day).padStart(2, "0")}`;
    }

    function hasEvents(day) {
        const key = dateKey(day);
        return events.some(event => event.startDate === key);
    }

    height: 200
    radius: 16
    color: "#4d414558"
    border.width: 1
    border.color: "#33414558"

    Item {
        id: header
        x: 10
        y: 8
        width: parent.width - 20
        height: 28

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: "<"
            color: previousMouse.containsMouse ? "#d4ccff" : "#626784"
            font.family: Ui.fontFamily
            font.pixelSize: Ui.title

            MouseArea {
                id: previousMouse
                anchors.fill: parent
                anchors.margins: -6
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.previousMonth()
            }
        }

        Text {
            anchors.centerIn: parent
            text: `${root.monthNames[root.month].substring(0, 3).toUpperCase()}  ${root.year}`
            color: titleMouse.containsMouse ? "#d4ccff" : "#f8f8f2"
            font.family: Ui.fontFamily
            font.pixelSize: 12
            font.bold: true

            MouseArea {
                id: titleMouse
                anchors.fill: parent
                anchors.margins: -6
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.openRequested()
            }
        }

        Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: ">"
            color: nextMouse.containsMouse ? "#d4ccff" : "#626784"
            font.family: Ui.fontFamily
            font.pixelSize: Ui.title

            MouseArea {
                id: nextMouse
                anchors.fill: parent
                anchors.margins: -6
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.nextMonth()
            }
        }
    }

    Row {
        id: weekHeader
        x: 8
        y: 42
        width: parent.width - 16
        height: 18

        Repeater {
            model: root.weekDays

            Text {
                required property string modelData
                width: weekHeader.width / 7
                text: modelData
                color: "#626784"
                horizontalAlignment: Text.AlignHCenter
                font.family: Ui.fontFamily
                font.pixelSize: Ui.caption
                font.bold: true
            }
        }
    }

    Grid {
        id: dayGrid
        x: 8
        y: 62
        width: parent.width - 16
        height: parent.height - 62
        columns: 7
        rows: 6

        Repeater {
            model: 42

            Item {
                id: dayCell

                required property int index
                readonly property int day: index - root.firstWeekDay + 1
                readonly property bool valid: day >= 1 && day <= root.daysInMonth
                readonly property var now: new Date()
                readonly property bool today: valid && day === now.getDate() && root.month === now.getMonth() && root.year === now.getFullYear()

                width: dayGrid.width / 7
                height: dayGrid.height / 6

                Rectangle {
                    anchors.centerIn: parent
                    width: 22
                    height: 22
                    radius: 11
                    color: dayCell.today ? "#4d9580ff" : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: dayCell.valid ? dayCell.day : ""
                        color: dayCell.today ? "#f8f8f2" : "#a7abbe"
                        font.family: Ui.fontFamily
                        font.pixelSize: Ui.caption
                        font.bold: dayCell.today
                    }

                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: -1
                        width: 3
                        height: 3
                        radius: 2
                        visible: dayCell.valid && root.hasEvents(dayCell.day)
                        color: "#ff80bf"
                    }
                }
            }
        }
    }
}
