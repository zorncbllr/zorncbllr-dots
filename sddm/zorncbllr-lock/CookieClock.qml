// Port of quickshell's cookie clock (modules/ii/background/widgets/clock) with the settings
// used on the lock screen: 14 sides, full dial (hour + minute lines), time numbers in the
// middle, filled hour hand, medium minute hand, bubble date (day pentagon, month circle).
import QtQuick
import QtQuick.Effects

Item {
    id: root
    property real implicitSize: 230
    property date now: new Date()
    property string timeFormat: "h:mm ap"
    property string fontExpressive: "Space Grotesk"
    property int sides: 14

    // palette (see theme.conf)
    property color cPrimary: "#ffffff"
    property color cPrimaryContainer: "#d4d4d4"
    property color cSecondary: "#c6c6c6"
    property color cSecondaryContainer: "#474747"
    property color cOnSecondaryContainer: "#e2e2e2"
    property color cTertiary: "#e2e2e2"
    property color cTertiaryContainer: "#919191"
    property color cOnTertiaryContainer: "#000000"

    function mix(a, b, p) {
        return Qt.rgba(p * a.r + (1 - p) * b.r, p * a.g + (1 - p) * b.g, p * a.b + (1 - p) * b.b, p * a.a + (1 - p) * b.a)
    }
    readonly property color colBackground: cPrimaryContainer
    readonly property color colOnBackground: mix(cSecondary, cPrimaryContainer, 0.15)
    readonly property color colBackgroundInfo: mix(cPrimary, cPrimaryContainer, 0.55)

    // Shader effects (drop shadow) are unavailable with software rendering: draw without them.
    readonly property bool hasFx: GraphicsInfo.api !== GraphicsInfo.Software

    readonly property int clockHour: now.getHours() % 12
    readonly property int clockMinute: now.getMinutes()
    readonly property var clockNumbers: Qt.formatTime(now, timeFormat).split(/[: ]/)

    implicitWidth: implicitSize
    implicitHeight: implicitSize

    // Cookie face + drop shadow
    Item {
        anchors.fill: parent
        layer.enabled: root.hasFx
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: "#59000000"
            shadowBlur: 0.45
            shadowVerticalOffset: 3
            autoPaddingEnabled: true
        }
        MaterialCookie {
            anchors.fill: parent
            implicitSize: root.implicitSize
            sides: root.sides
            color: root.colBackground
        }
    }

    // Dial: 12 hour lines + 60 minute lines
    Item {
        anchors.fill: parent
        anchors.margins: 10
        Repeater {
            model: 12
            Item {
                required property int index
                anchors.fill: parent
                rotation: 360 / 12 * index
                Rectangle {
                    anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 12 }
                    width: 18; height: 4; radius: 2
                    color: root.colOnBackground
                }
            }
        }
        Repeater {
            model: 60
            Item {
                required property int index
                anchors.fill: parent
                rotation: 360 / 60 * index
                Rectangle {
                    anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 12 }
                    width: 7; height: 2; radius: 1
                    color: root.colOnBackground
                }
            }
        }
    }

    // Time numbers in the middle (04 / 10 / pm)
    Column {
        anchors.centerIn: parent
        spacing: -16
        Repeater {
            model: root.clockNumbers
            delegate: Text {
                required property string modelData
                readonly property bool isAmPm: !/\d{2}/.test(text)
                anchors.horizontalCenter: parent.horizontalCenter
                text: modelData.length < 2 ? ("0" + modelData) : modelData
                color: root.colBackgroundInfo
                font.family: root.fontExpressive
                font.weight: Font.Bold
                font.pixelSize: isAmPm ? 26 : 68
            }
        }
    }

    // Minute hand (medium)
    Item {
        anchors.fill: parent
        z: 1
        rotation: -90 + 6 * root.clockMinute
        Behavior on rotation { RotationAnimation { direction: RotationAnimation.Clockwise; duration: 300; easing.type: Easing.OutCubic } }
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            x: parent.width / 2 - 6
            width: 95; height: 12; radius: 6
            color: root.cTertiary
        }
    }

    // Hour hand (filled)
    Item {
        anchors.fill: parent
        z: 2
        rotation: -90 + 30 * (root.clockHour + root.clockMinute / 60)
        Behavior on rotation { RotationAnimation { direction: RotationAnimation.Clockwise; duration: 300; easing.type: Easing.OutCubic } }
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            x: (parent.width - 20) / 2
            width: 72; height: 20; radius: 10
            color: root.cPrimary
            border.color: root.cPrimary
            border.width: 4
        }
    }

    // Centre dot (medium minute hand)
    Rectangle {
        z: 4
        anchors.centerIn: parent
        width: 6; height: 6; radius: 3
        color: root.colBackground
    }

    // Date bubbles: day (pentagon) top-left, month (circle) bottom-right
    Item {
        anchors { left: parent.left; top: parent.top }
        width: 64; height: 64
        MaterialShape { anchors.centerIn: parent; shape: MaterialShape.Shape.Pentagon; implicitSize: 64; color: root.cTertiaryContainer; z: 5 }
        Text {
            anchors.centerIn: parent; z: 6
            text: Qt.formatDate(root.now, "d")
            color: root.cOnTertiaryContainer
            font.family: root.fontExpressive; font.weight: Font.Black; font.pixelSize: 30
        }
    }
    Item {
        anchors { right: parent.right; bottom: parent.bottom }
        width: 64; height: 64
        MaterialShape { anchors.centerIn: parent; shape: MaterialShape.Shape.Pill; implicitSize: 64; color: root.cSecondaryContainer; z: 5 }
        Text {
            anchors.centerIn: parent; z: 6
            text: Qt.formatDate(root.now, "MM")
            color: root.cOnSecondaryContainer
            font.family: root.fontExpressive; font.weight: Font.Black; font.pixelSize: 30
        }
    }
}
