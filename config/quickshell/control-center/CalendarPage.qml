import QtQuick
import Quickshell

Item {
    id: root

    required property var host

    Item {
        id: header
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 44

        Rectangle {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: 44
            height: 44
            radius: 11
            color: backMouse.containsMouse ? Theme.alpha(Theme.surface, 0.45) : Theme.alpha(Theme.surface, 0.30)

            Text {
                anchors.centerIn: parent
                text: "<"
                color: Theme.accentText
                font.family: Ui.fontFamily
                font.pixelSize: Ui.heading
            }

            MouseArea {
                id: backMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.host.showCalendar = false
            }
        }

        Text {
            x: 58
            anchors.verticalCenter: parent.verticalCenter
            text: "CALENDAR"
            color: Theme.primaryText
            font.family: Ui.fontFamily
            font.pixelSize: Ui.title
            font.bold: true
            font.letterSpacing: 1
        }

        Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: root.host.calendarAuthenticated ? "Google connected" : "Local only"
            color: root.host.calendarAuthenticated ? Theme.success : Theme.mutedText
            font.family: Ui.fontFamily
            font.pixelSize: Ui.caption
        }
    }

    Row {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: header.bottom
        anchors.topMargin: Ui.gap
        anchors.bottom: parent.bottom
        spacing: Ui.gap

        Column {
            width: 232
            height: parent.height
            spacing: Ui.gap

            CalendarCard {
                width: parent.width
                events: root.host.calendarEvents
            }

            Rectangle {
                width: parent.width
                height: 88
                radius: 13
                color: Theme.alpha(Theme.surface, 0.30)

                Text {
                    x: 13
                    y: 11
                    width: parent.width - 26
                    text: root.host.calendarAuthenticated ? "Google Calendar synced" : "Connect Google Calendar"
                    color: Theme.primaryText
                    elide: Text.ElideRight
                    font.family: Ui.fontFamily
                    font.pixelSize: Ui.body
                    font.bold: true
                }

                Text {
                    x: 13
                    y: 45
                    width: parent.width - 26
                    text: root.host.calendarAuthenticated ? `${root.host.calendarEvents.length} upcoming events` : "OAuth setup required once"
                    color: Theme.mutedText
                    font.family: Ui.fontFamily
                    font.pixelSize: Ui.caption
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.host.calendarAuthenticated)
                            Ui.launch(["xdg-open", "https://calendar.google.com"]);
                        else
                            root.host.openCalendarSetup();
                    }
                }
            }
        }

        Rectangle {
            width: parent.width - 242
            height: parent.height
            radius: 15
            color: Theme.alpha(Theme.surface, 0.30)

            Text {
                id: agendaTitle
                x: 13
                y: 12
                text: "UPCOMING"
                color: Theme.mutedText
                font.family: Ui.fontFamily
                font.pixelSize: 12
                font.bold: true
                font.letterSpacing: 1
            }

            Flickable {
                x: 8
                y: 38
                width: parent.width - 16
                height: parent.height - 46
                contentHeight: agendaList.implicitHeight
                clip: true

                Column {
                    id: agendaList
                    width: parent.width
                    spacing: 5

                    Repeater {
                        model: root.host.calendarEvents.slice(0, 8)

                        Rectangle {
                            id: eventRow

                            required property var modelData
                            width: agendaList.width
                            height: 68
                            radius: 11
                            color: eventMouse.containsMouse ? Theme.alpha(Theme.surface, 0.45) : Theme.alpha(Theme.panel, 0.20)

                            Text {
                                x: 10
                                y: 8
                                width: parent.width - 20
                                text: eventRow.modelData.title
                                color: Theme.primaryText
                                elide: Text.ElideRight
                                font.family: Ui.fontFamily
                                font.pixelSize: Ui.body
                                font.bold: true
                            }

                            Text {
                                x: 10
                                y: 40
                                width: parent.width - 20
                                text: `${eventRow.modelData.startDate.substring(5)}  ${eventRow.modelData.time}`
                                color: Theme.mutedText
                                elide: Text.ElideRight
                                font.family: Ui.fontFamily
                                font.pixelSize: Ui.caption
                            }

                            MouseArea {
                                id: eventMouse
                                anchors.fill: parent
                                enabled: eventRow.modelData.url !== ""
                                hoverEnabled: true
                                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: Ui.launch(["xdg-open", eventRow.modelData.url])
                            }
                        }
                    }

                    Text {
                        width: parent.width
                        height: root.host.calendarEvents.length === 0 ? 90 : 0
                        visible: root.host.calendarEvents.length === 0
                        text: root.host.calendarAuthenticated ? "No upcoming events" : "Connect your Google account to show events"
                        color: Theme.mutedText
                        wrapMode: Text.WordWrap
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        font.family: Ui.fontFamily
                        font.pixelSize: Ui.caption
                    }
                }
            }
        }
    }
}
