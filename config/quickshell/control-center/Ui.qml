pragma Singleton

import QtQuick
import Quickshell

QtObject {
    readonly property real textScale: {
        const configured = Number(Quickshell.env("DOTFILES_TEXT_SCALE"))
        return Number.isFinite(configured) && configured >= 0.69 && configured <= 1.55 ? configured : 1
    }
    readonly property string fontFamily: Theme.fontFamily
    readonly property int caption: Math.round(11 * textScale)
    readonly property int body: Math.round(13 * textScale)
    readonly property int title: Math.round(15 * textScale)
    readonly property int heading: Math.round(17 * textScale)
    readonly property int display: Math.round(38 * textScale)
    readonly property int icon: Math.round(24 * textScale)
    readonly property int gap: 12
    readonly property string launchPath: Quickshell.env("HOME") + "/.config/hypr/scripts/launch-app"

    function launch(arguments) {
        Quickshell.execDetached([launchPath].concat(arguments))
    }
}
