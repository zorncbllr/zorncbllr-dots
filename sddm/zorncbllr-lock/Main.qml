// Login screen styled after the quickshell lock screen (modules/ii/lock/LockSurface.qml and
// the desktop background shown while locked): blurred + zoomed wallpaper, the centred cookie
// clock with a "Locked" pill, and three pill "islands" along the bottom. Typed characters
// are drawn as Material shapes, like the lock screen's materialShapeChars.
import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts

Item {
    id: root
    width: 1920
    height: 1080

    // ---- palette / fonts (theme.conf) -------------------------------------------------
    readonly property color cSurface: config.surface || "#131313"
    readonly property color cIsland: config.surfaceContainer || "#1f1f1f"
    readonly property color cIslandHigh: config.surfaceContainerHigh || "#2a2a2a"
    readonly property color cText: config.onSurface || "#e2e2e2"
    readonly property color cOnLayer: config.onSurfaceVariant || "#c6c6c6"
    readonly property color cSubtext: config.outline || "#919191"
    readonly property color cPrimary: config.primary || "#ffffff"
    readonly property color cOnPrimary: config.onPrimary || "#1b1b1b"
    readonly property color cError: config.error || "#ffb4ab"
    readonly property color cPrimaryContainer: config.primaryContainer || "#d4d4d4"
    readonly property color cSecondary: config.secondary || "#c6c6c6"
    readonly property color cSecondaryContainer: config.secondaryContainer || "#474747"
    readonly property color cOnSecondaryContainer: config.onSecondaryContainer || "#e2e2e2"
    readonly property color cTertiary: config.tertiary || "#e2e2e2"
    readonly property color cTertiaryContainer: config.tertiaryContainer || "#919191"
    readonly property color cOnTertiaryContainer: config.onTertiaryContainer || "#000000"
    readonly property string iconFont: config.iconFont || "Material Symbols Rounded"
    readonly property string expressiveFont: config.fontExpressive || "Space Grotesk"
    // Google Sans Flex ships in the user's font dir, which the sddm user cannot read:
    // install-theme.sh copies it into ./fonts. Falls back to Rubik.
    readonly property string uiFont: gsf.status === FontLoader.Ready ? gsf.name : (config.font || "Rubik")
    readonly property string statusText: config.statusText === undefined ? "Locked" : config.statusText

    FontLoader { id: gsf; source: Qt.resolvedUrl("fonts/GoogleSansFlex.ttf") }

    // Blur/shadows are shader effects: unavailable with software rendering, then the
    // wallpaper is shown as-is (dimmed) and the shadows are skipped.
    readonly property bool fx: GraphicsInfo.api !== GraphicsInfo.Software

    // ---- battery (read from sysfs; needs QML_XHR_ALLOW_FILE_READ=1, set by install-theme.sh) --
    property int batteryPercent: -1
    property bool batteryCharging: false
    function readFile(path) {
        try {
            var x = new XMLHttpRequest()
            x.open("GET", "file://" + path, false)
            x.send()
            return (x.status === 200 || x.status === 0) ? String(x.responseText).trim() : ""
        } catch (e) { return "" }
    }
    function refreshBattery() {
        var names = ["BAT0", "BAT1", "BATT", "CMB0"]
        for (var i = 0; i < names.length; i++) {
            var base = "/sys/class/power_supply/" + names[i]
            var cap = readFile(base + "/capacity")
            if (cap.length > 0 && !isNaN(parseInt(cap))) {
                batteryPercent = parseInt(cap)
                batteryCharging = readFile(base + "/status") === "Charging"
                return
            }
        }
        batteryPercent = -1
    }
    Timer { interval: 30000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.refreshBattery() }

    // ---- state ------------------------------------------------------------------------
    property bool failed: false
    property bool busy: false
    property date now: new Date()

    Timer {
        interval: 1000; running: true; repeat: true
        onTriggered: root.now = new Date()
    }

    // ---- background: wallpaper, Gaussian-style blur, 1.1x zoom, 30% surface overlay ----
    Rectangle { anchors.fill: parent; color: root.cSurface }

    Image {
        id: wallpaper
        anchors.fill: parent
        source: config.background || "background.png"
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        visible: !root.fx
    }
    MultiEffect {
        anchors.fill: parent
        source: wallpaper
        visible: root.fx && wallpaper.status === Image.Ready
        scale: parseFloat(config.zoom || "1.1")
        autoPaddingEnabled: false
        blurEnabled: true
        blurMax: 64
        blur: parseFloat(config.blur || "1.0")
    }
    Rectangle {
        anchors.fill: parent
        color: root.cSurface
        opacity: parseFloat(config.dim || "0.30")
    }

    // ---- centred cookie clock + "Locked" pill -----------------------------------------
    Column {
        id: centerBlock
        anchors.centerIn: parent
        spacing: 10
        scale: Math.min(1, root.height / 640)

        CookieClock {
            anchors.horizontalCenter: parent.horizontalCenter
            now: root.now
            timeFormat: config.timeFormat || "h:mm ap"
            fontExpressive: root.expressiveFont
            sides: parseInt(config.cookieSides || "14")
            cPrimary: root.cPrimary
            cPrimaryContainer: root.cPrimaryContainer
            cSecondary: root.cSecondary
            cSecondaryContainer: root.cSecondaryContainer
            cOnSecondaryContainer: root.cOnSecondaryContainer
            cTertiary: root.cTertiary
            cTertiaryContainer: root.cTertiaryContainer
            cOnTertiaryContainer: root.cOnTertiaryContainer
        }

        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.statusText.length > 0
            width: pill.width
            height: pill.height
            RectangularShadow {
                anchors.fill: pill
                radius: pill.radius
                blur: 14
                offset: Qt.vector2d(0, 1)
                spread: 1
                color: "#4d000000"
                z: -1
            }
            Rectangle {
                id: pill
                color: root.cSecondaryContainer
                radius: 10
                width: pillRow.implicitWidth + 20
                height: pillRow.implicitHeight + 10
                Row {
                    id: pillRow
                    anchors.centerIn: parent
                    spacing: 4
                    Icon { text: "lock"; size: 22; color: root.cOnSecondaryContainer }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.statusText
                        color: root.cOnSecondaryContainer
                        font.family: root.uiFont
                        font.pixelSize: 17
                    }
                }
            }
        }
    }

    // ---- current user / session (Repeaters: delegates exist even when invisible) -------
    property int userIndex: userModel.lastIndex >= 0 ? userModel.lastIndex : 0
    property int sessionIndex: sessionModel.lastIndex >= 0 ? sessionModel.lastIndex : 0
    readonly property var curUser: userRepeater.count > userIndex ? userRepeater.itemAt(userIndex) : null
    readonly property var curSession: sessionRepeater.count > sessionIndex ? sessionRepeater.itemAt(sessionIndex) : null
    readonly property bool showPower: config.showPowerAlways === "true"

    Item {
        visible: false
        Repeater {
            id: userRepeater
            model: userModel
            delegate: Item {
                property string loginName: model.name
                property string shownName: (model.realName && model.realName.length) ? model.realName : model.name
            }
        }
        Repeater {
            id: sessionRepeater
            model: sessionModel
            delegate: Item { property string sName: model.name }
        }
    }

    // ---- reusable pieces --------------------------------------------------------------
    // Same as quickshell's MaterialSymbol: optical size = icon size, heavier weight when filled.
    component Icon: Text {
        property real size: 22
        property real fill: 0
        color: root.cOnLayer
        renderType: Text.NativeRendering
        font.family: root.iconFont
        font.pixelSize: size
        font.hintingPreference: Font.PreferNoHinting
        font.weight: fill > 0.5 ? Font.DemiBold : Font.Normal
        font.variableAxes: ({ "FILL": fill, "opsz": size })
        verticalAlignment: Text.AlignVCenter
    }

    component Island: Rectangle {
        default property alias content: row.data
        property alias spacing: row.spacing
        color: root.cIsland
        radius: height / 2
        implicitHeight: 56
        implicitWidth: row.implicitWidth + 16
        RectangularShadow {
            anchors.fill: parent
            radius: parent.radius
            blur: 14
            offset: Qt.vector2d(0, 1)
            spread: 1
            color: "#4d000000"
            z: -1
        }
        RowLayout {
            id: row
            anchors.fill: parent
            anchors.margins: 8
            spacing: 4
        }
    }

    component IconButton: Rectangle {
        id: ib
        property string icon
        property bool toggled: false
        signal clicked()
        implicitWidth: 40
        implicitHeight: 40
        radius: height / 2
        color: toggled ? root.cPrimary : (hover.hovered ? root.cIslandHigh : "transparent")
        Behavior on color { ColorAnimation { duration: 120 } }
        Icon {
            anchors.centerIn: parent
            text: ib.icon
            size: ib.toggled ? 24 : 22
            color: ib.toggled ? root.cOnPrimary : root.cOnLayer
        }
        HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: ib.clicked() }
    }

    // ---- login ------------------------------------------------------------------------
    function tryLogin() {
        if (root.busy || password.text.length === 0 || !root.curUser || !root.curSession)
            return
        root.busy = true
        root.failed = false
        sddm.login(root.curUser.loginName, password.text, root.sessionIndex)
    }

    Connections {
        target: sddm
        function onLoginFailed() {
            root.busy = false
            root.failed = true
            password.text = ""
            shake.restart()
            password.forceActiveFocus()
        }
        function onLoginSucceeded() { fadeOut.start() }
    }

    Rectangle {
        id: curtain
        anchors.fill: parent
        color: "black"
        opacity: 0
        z: 100
        NumberAnimation on opacity { id: fadeOut; running: false; to: 1; duration: 300 }
    }

    // ---- islands ----------------------------------------------------------------------
    Item {
        id: dock
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 20
        width: leftIsland.width + 10 + mainIsland.width + (rightIsland.visible ? 10 + rightIsland.width : 0)
        height: 56
        // shrink to fit narrow screens; 0.9 -> 1 is the appear animation
        property real appear: 0.9
        scale: appear * Math.min(1, (root.width - 24) / width)
        transformOrigin: Item.Bottom
        opacity: 0
        Component.onCompleted: {
            appear = 1; opacity = 1; password.forceActiveFocus()
            if (config.previewText) password.text = config.previewText   // preview/testing only
        }
        Behavior on appear { NumberAnimation { duration: 350; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 250 } }

        // left: user, keyboard layout, session
        Island {
            id: leftIsland
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0
            RowLayout {
                Layout.leftMargin: 8
                Layout.rightMargin: 10
                spacing: 4
                Icon { text: "account_circle"; size: 22; fill: 1 }
                Text {
                    text: root.curUser ? root.curUser.shownName : ""
                    color: root.cOnLayer
                    font.family: root.uiFont
                    font.pixelSize: 15
                }
                TapHandler {
                    enabled: userRepeater.count > 1
                    onTapped: root.userIndex = (root.userIndex + 1) % userRepeater.count
                }
            }
            RowLayout {
                Layout.leftMargin: 10
                Layout.rightMargin: 10
                spacing: 4
                Icon { text: "keyboard_alt"; size: 22; fill: 1 }
                Text {
                    text: keyboard.layouts.length > 0 ? keyboard.layouts[keyboard.currentLayout].shortName : ""
                    color: root.cOnLayer
                    font.family: root.uiFont
                    font.pixelSize: 15
                }
                TapHandler {
                    enabled: keyboard.layouts.length > 1
                    onTapped: keyboard.currentLayout = (keyboard.currentLayout + 1) % keyboard.layouts.length
                }
            }
            RowLayout {
                Layout.leftMargin: 10
                Layout.rightMargin: 8
                spacing: 4
                Icon { text: "desktop_windows"; size: 22; fill: 1 }
                Text {
                    text: root.curSession ? root.curSession.sName : ""
                    color: root.cOnLayer
                    font.family: root.uiFont
                    font.pixelSize: 15
                }
                TapHandler {
                    enabled: sessionRepeater.count > 1
                    onTapped: root.sessionIndex = (root.sessionIndex + 1) % sessionRepeater.count
                }
            }
        }

        // middle: password pill (shape characters) + confirm
        Island {
            id: mainIsland
            anchors.left: leftIsland.right
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            TextField {
                id: password
                Layout.preferredWidth: 240
                Layout.fillHeight: true
                echoMode: TextInput.Password
                inputMethodHints: Qt.ImhSensitiveData
                enabled: !root.busy
                // The characters are drawn by PasswordChars; the real text stays invisible.
                color: "transparent"
                selectedTextColor: "transparent"
                selectionColor: "transparent"
                cursorDelegate: Item {}
                font.family: root.uiFont
                font.pixelSize: 15
                leftPadding: 18
                rightPadding: 18
                verticalAlignment: TextInput.AlignVCenter
                background: Rectangle {
                    color: root.cIslandHigh
                    radius: height / 2
                    clip: true
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        x: 18
                        visible: password.text.length === 0
                        text: root.failed ? "Incorrect password" : "Enter password"
                        color: root.failed ? root.cError : root.cSubtext
                        font.family: root.uiFont
                        font.pixelSize: 15
                    }
                    PasswordChars {
                        anchors { fill: parent; leftMargin: 18; rightMargin: 18 }
                        length: password.text.length
                        cursorPosition: password.cursorPosition
                        color: root.cPrimary
                        settledColor: root.cOnLayer
                    }
                }
                onAccepted: root.tryLogin()
                onTextEdited: root.failed = false
                Keys.onEscapePressed: text = ""

                SequentialAnimation {
                    id: shake
                    NumberAnimation { target: password; property: "x"; to: password.x - 10; duration: 40 }
                    NumberAnimation { target: password; property: "x"; to: password.x + 10; duration: 70 }
                    NumberAnimation { target: password; property: "x"; to: password.x - 6; duration: 60 }
                    NumberAnimation { target: password; property: "x"; to: password.x; duration: 40 }
                }
            }

            IconButton {
                icon: "arrow_right_alt"
                toggled: true
                enabled: !root.busy
                onClicked: root.tryLogin()
            }
        }

        // right: sleep / reboot / power
        Island {
            id: rightIsland
            anchors.left: mainIsland.right
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            visible: root.batteryPercent >= 0 || root.showPower || sddm.canSuspend || sddm.canReboot || sddm.canPowerOff

            RowLayout {
                visible: root.batteryPercent >= 0
                Layout.leftMargin: 10
                Layout.rightMargin: 10
                spacing: 4
                readonly property color tint: (root.batteryPercent <= 20 && !root.batteryCharging) ? root.cError : root.cOnLayer
                Icon { text: root.batteryCharging ? "bolt" : "battery_android_full"; size: 22; fill: 1; color: parent.tint }
                Text {
                    text: root.batteryPercent
                    color: parent.tint
                    font.family: root.uiFont
                    font.pixelSize: 15
                }
            }
            IconButton { icon: "dark_mode"; visible: sddm.canSuspend || root.showPower; onClicked: sddm.suspend() }
            IconButton { icon: "restart_alt"; visible: sddm.canReboot || root.showPower; onClicked: sddm.reboot() }
            IconButton { icon: "power_settings_new"; visible: sddm.canPowerOff || root.showPower; onClicked: sddm.powerOff() }
        }
    }

    // Preview helpers (theme.conf): previewText=abc types characters, previewShot=/x.png saves
    // a screenshot of the theme and quits. Ignored unless set.
    // Preview helper: with previewShot=/path.png in theme.conf the theme saves a screenshot
    // of itself and quits (used to render the theme headlessly; ignored otherwise).
    Timer {
        interval: 3500
        running: (config.previewShot || "") !== ""
        onTriggered: root.grabToImage(function (r) { r.saveToFile(config.previewShot); Qt.quit() })
    }

    // Click anywhere to focus the password field again
    MouseArea {
        anchors.fill: parent
        z: -1
        onPressed: password.forceActiveFocus()
    }
}
