// Port of quickshell's MaterialShape (modules/common/widgets/MaterialShape.qml), trimmed to
// the shapes this theme uses. Needs the rounded-polygon library in ./shapes (copied by
// install-theme.sh from the stow package).
import QtQuick
import "shapes"
import "shapes/material-shapes.js" as MaterialShapes

ShapeCanvas {
    id: root
    enum Shape { Circle, Pill, Pentagon, Clover4Leaf, Arrow, SoftBurst, Diamond, ClamShell }

    required property var shape
    property double implicitSize
    implicitHeight: implicitSize
    implicitWidth: implicitSize
    polygonIsNormalized: true
    roundedPolygon: {
        switch (root.shape) {
            case MaterialShape.Shape.Circle: return MaterialShapes.getCircle();
            case MaterialShape.Shape.Pill: return MaterialShapes.getPill();
            case MaterialShape.Shape.Pentagon: return MaterialShapes.getPentagon();
            case MaterialShape.Shape.Clover4Leaf: return MaterialShapes.getClover4Leaf();
            case MaterialShape.Shape.Arrow: return MaterialShapes.getArrow();
            case MaterialShape.Shape.SoftBurst: return MaterialShapes.getSoftBurst();
            case MaterialShape.Shape.Diamond: return MaterialShapes.getDiamond();
            case MaterialShape.Shape.ClamShell: return MaterialShapes.getClamShell();
            default: return MaterialShapes.getCircle();
        }
    }
}
