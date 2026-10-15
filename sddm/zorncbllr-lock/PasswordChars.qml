// Port of quickshell's PasswordChars: every typed character is drawn as a Material shape
// (cycling Clover4Leaf, Arrow, Pill, SoftBurst, Diamond, ClamShell, Pentagon) that pops in.
import QtQuick

Flickable {
    id: root

    required property int length
    property int cursorPosition: length
    property color color: "#ffffff"          // pop-in colour, fades to settledColor
    property color settledColor: "#c6c6c6"
    property int charSize: 20

    // A real model: changing an integer Repeater model would destroy and recreate *every*
    // delegate on each keystroke (all shapes re-animating = flicker). Here only the last one
    // is added or removed.
    ListModel { id: charModel }
    function syncModel() {
        while (charModel.count < root.length) charModel.append({})
        while (charModel.count > root.length) charModel.remove(charModel.count - 1)
    }
    property int created: 0          // delegates created so far (diagnostic: must equal keystrokes)
    onLengthChanged: syncModel()
    Component.onCompleted: syncModel()

    clip: true
    interactive: false
    contentWidth: dotsRow.implicitWidth
    contentX: Math.max(contentWidth - width, 0)
    Behavior on contentX { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

    Rectangle {
        id: cursor
        anchors { verticalCenter: parent.verticalCenter }
        x: root.charSize * root.cursorPosition + 4 - 5
        color: root.color
        width: 2
        height: root.charSize
        Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
    }

    Row {
        id: dotsRow
        anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 4 - 5 }
        spacing: 0

        Repeater {
            model: charModel
            delegate: Item {
                id: charItem
                required property int index
                implicitWidth: root.charSize
                implicitHeight: root.charSize
                Component.onCompleted: root.created++

                MaterialShape {
                    id: materialShape
                    anchors.centerIn: parent
                    readonly property var charShapes: [
                        MaterialShape.Shape.Clover4Leaf, MaterialShape.Shape.Arrow, MaterialShape.Shape.Pill,
                        MaterialShape.Shape.SoftBurst, MaterialShape.Shape.Diamond, MaterialShape.Shape.ClamShell,
                        MaterialShape.Shape.Pentagon
                    ]
                    shape: charShapes[charItem.index % charShapes.length]
                    color: root.color
                    implicitSize: 0
                    opacity: 0
                    scale: 0.5
                    Component.onCompleted: appearAnim.start()
                    ParallelAnimation {
                        id: appearAnim
                        NumberAnimation { target: materialShape; property: "opacity"; to: 1; duration: 50 }
                        NumberAnimation {
                            target: materialShape; property: "scale"; to: 1; duration: 200
                            easing.type: Easing.BezierSpline; easing.bezierCurve: [0.42, 1.67, 0.21, 0.90, 1, 1]
                        }
                        NumberAnimation {
                            target: materialShape; property: "implicitSize"; to: 18; duration: 250
                            easing.type: Easing.BezierSpline; easing.bezierCurve: [0.42, 1.67, 0.21, 0.90, 1, 1]
                        }
                        ColorAnimation { target: materialShape; property: "color"; to: root.settledColor; duration: 1000; easing.type: Easing.OutCubic }
                    }
                }
            }
        }
    }
}
