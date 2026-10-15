// Login screen styled after the quickshell lock screen (modules/ii/lock/LockSurface.qml):
// blurred wallpaper, big clock, and three pill "islands" along the bottom.
import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts

Item {
    id: root
    width: 1920
    height: 1080

    // ---- palette / fonts (theme.conf) -------------------------------------------------
    readonly property color cIsland: config.surfaceContainer || "#1f1f1f"
    readonly property color cIslandHigh: config.surfaceContainerHigh || "#2a2a2a"
    readonly property color cText: config.onSurface || "#e2e2e2"
    readonly property color cSubtext: config.onSurfaceVariant || "#c6c6c6"
    readonly property color cPrimary: config.primary || "#ffffff"
    readonly property color cOnPrimary: config.onPrimary || "#1b1b1b"
    readonly property color cError: config.error || "#ffb4ab"
    readonly property string uiFont: config.font || "Rubik"
    readonly property string iconFont: config.iconFont || "Material Symbols Rounded"

    // ---- state ------------------------------------------------------------------------
    property bool failed: false
    property bool busy: false
    property date now: new Date()

    Timer {
        interval: 1000; running: true; repeat: true
        onTriggered: root.now = new Date()
    }

    // ---- background -------------------------------------------------------------------
    Rectangle { anchors.fill: parent; color: "#131313" }

    Image {
        id: wallpaper
        anchors.fill: parent
        source: config.background || "background.png"
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        visible: false
    }
    MultiEffect {
        anchors.fill: parent
        source: wallpaper
        visible: wallpaper.status === Image.Ready
        autoPaddingEnabled: false
        blurEnabled: true
        blurMax: 64
        blur: parseFloat(config.blur || "1.0")
    }
    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: parseFloat(config.dim || "0.30")
    }

    // ---- clock ------------------------------------------------------------------------
    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -root.height * 0.10
        spacing: 4

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatTime(root.now, config.timeFormat || "h:mm ap")
            color: root.cText
            font.family: root.uiFont
            font.pixelSize: Math.round(root.height * 0.14)
            font.weight: Font.Medium
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDate(root.now, config.dateFormat || "dddd, d MMMM")
            color: root.cSubtext
            font.family: root.uiFont
            font.pixelSize: Math.round(root.height * 0.032)
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
    component Icon: Text {
        property real size: 22
        color: root.cSubtext
        font.family: root.iconFont
        font.pixelSize: size
        font.variableAxes: ({ "FILL": 1 })
        verticalAlignment: Text.AlignVCenter
    }

    component Island: Rectangle {
        default property alias content: row.data
        property alias spacing: row.spacing
        color: root.cIsland
        radius: height / 2
        implicitHeight: 56
        implicitWidth: row.implicitWidth + 16
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.05)
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
            color: ib.toggled ? root.cOnPrimary : root.cSubtext
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
        NumberAnimation on opacity { id: fadeOut; running: false; to: 1; duration: 300 }
    }

    // ---- islands ----------------------------------------------------------------------
    Item {
        id: dock
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 20
        width: leftIsland.width + 10 + mainIsland.width + 10 + rightIsland.width
        height: 56
        // shrink to fit narrow screens; 0.9 -> 1 is the appear animation
        property real appear: 0.9
        scale: appear * Math.min(1, (root.width - 24) / width)
        transformOrigin: Item.Bottom
        opacity: 0
        Component.onCompleted: { appear = 1; opacity = 1; password.forceActiveFocus() }
        Behavior on appear { NumberAnimation { duration: 350; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 250 } }

        // left: user, keyboard layout, session
        Island {
            id: leftIsland
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 14
            Item { Layout.preferredWidth: 4 }
            RowLayout {
                spacing: 6
                Icon { text: "account_circle"; size: 24 }
                Text {
                    text: root.curUser ? root.curUser.shownName : ""
                    color: root.cSubtext
                    font.family: root.uiFont
                    font.pixelSize: 15
                }
                TapHandler {
                    enabled: userRepeater.count > 1
                    onTapped: root.userIndex = (root.userIndex + 1) % userRepeater.count
                }
            }
            RowLayout {
                spacing: 6
                Icon { text: "keyboard_alt"; size: 24 }
                Text {
                    text: keyboard.layouts.length > 0 ? keyboard.layouts[keyboard.currentLayout].shortName : ""
                    color: root.cSubtext
                    font.family: root.uiFont
                    font.pixelSize: 15
                }
                TapHandler {
                    enabled: keyboard.layouts.length > 1
                    onTapped: keyboard.currentLayout = (keyboard.currentLayout + 1) % keyboard.layouts.length
                }
            }
            RowLayout {
                spacing: 6
                Icon { text: "desktop_windows"; size: 24 }
                Text {
                    text: root.curSession ? root.curSession.sName : ""
                    color: root.cSubtext
                    font.family: root.uiFont
                    font.pixelSize: 15
                }
                TapHandler {
                    enabled: sessionRepeater.count > 1
                    onTapped: root.sessionIndex = (root.sessionIndex + 1) % sessionRepeater.count
                }
            }
            Item { Layout.preferredWidth: 4 }
        }

        // middle: password pill + confirm
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
                passwordCharacter: "•"
                inputMethodHints: Qt.ImhSensitiveData
                enabled: !root.busy
                color: root.cText
                selectedTextColor: root.cText
                selectionColor: root.cIslandHigh
                font.family: root.uiFont
                font.pixelSize: 15
                leftPadding: 18
                rightPadding: 18
                verticalAlignment: TextInput.AlignVCenter
                background: Rectangle {
                    color: root.cIslandHigh
                    radius: height / 2
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        x: 18
                        visible: password.text.length === 0
                        text: root.failed ? "Incorrect password" : "Enter password"
                        color: root.failed ? root.cError : root.cSubtext
                        font.family: root.uiFont
                        font.pixelSize: 15
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
            IconButton { icon: "dark_mode"; visible: sddm.canSuspend || root.showPower; onClicked: sddm.suspend() }
            IconButton { icon: "restart_alt"; visible: sddm.canReboot || root.showPower; onClicked: sddm.reboot() }
            IconButton { icon: "power_settings_new"; visible: sddm.canPowerOff || root.showPower; onClicked: sddm.powerOff() }
        }
    }

    // Preview helper: with previewShot=/path.png in theme.conf the theme saves a screenshot
    // of itself and quits (used to render the theme headlessly; ignored otherwise).
    Timer {
        interval: 2500
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
