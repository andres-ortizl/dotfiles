import QtQuick
import Quickshell

Item {
    id: root

    required property var host

    Column {
        width: parent.width
        spacing: Ui.gap

        Text {
            width: parent.width
            height: 28
            text: "QUICK CONFIG"
            color: "#a7abbe"
            verticalAlignment: Text.AlignVCenter
            font.family: Ui.fontFamily
            font.pixelSize: 12
            font.bold: true
            font.letterSpacing: 1
        }

        Row {
            width: parent.width
            height: 116
            spacing: Ui.gap

            ActionCard {
                width: (parent.width - parent.spacing) / 2
                icon: "󰸉"
                title: "Next wallpaper"
                subtitle: "Rotate with awww / swww"
                onClicked: Quickshell.execDetached([Quickshell.env("HOME") + "/.config/hypr/scripts/setwall"])
            }

            ActionCard {
                width: (parent.width - parent.spacing) / 2
                icon: "󰑐"
                title: "Reload Waybar"
                subtitle: "Restart the user service"
                onClicked: Quickshell.execDetached(["systemctl", "--user", "restart", "waybar.service"])
            }
        }

        Row {
            width: parent.width
            height: 116
            spacing: Ui.gap

            ActionCard {
                width: (parent.width - parent.spacing) / 2
                icon: "󰕾"
                title: "Audio settings"
                subtitle: "Outputs, inputs and levels"
                onClicked: {
                    root.host.open = false;
                    Quickshell.execDetached(["pavucontrol"]);
                }
            }

            ActionCard {
                width: (parent.width - parent.spacing) / 2
                icon: "󰈐"
                title: "Cooling curves"
                subtitle: "Fans, pump and profiles"
                onClicked: {
                    root.host.open = false;
                    Quickshell.execDetached(["coolercontrol"]);
                }
            }
        }

        Row {
            width: parent.width
            height: 116
            spacing: Ui.gap

            ActionCard {
                width: (parent.width - parent.spacing) / 2
                icon: "󰆍"
                title: "Open dotfiles"
                subtitle: "Edit this dashboard and desktop"
                onClicked: {
                    root.host.open = false;
                    Quickshell.execDetached(["zed", Quickshell.env("DOTFILES") || Quickshell.env("HOME") + "/code/dotfiles"]);
                }
            }

            ActionCard {
                width: (parent.width - parent.spacing) / 2
                icon: "󰌾"
                title: "Lock session"
                subtitle: "Lock with Hyprlock"
                onClicked: {
                    root.host.open = false;
                    Quickshell.execDetached(["hyprlock", "--immediate-render", "--no-fade-in"]);
                }
            }
        }
    }
}
