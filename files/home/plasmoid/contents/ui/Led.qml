import QtQuick
import org.kde.kirigami as Kirigami

Item {
    id: led
    property color ledColor: "red"
    property bool lit: false
    property real offFactor: 0.2
    property int size: 12
    property string label: ""
    property bool showLabel: false

    implicitWidth: row.implicitWidth
    implicitHeight: size

    Row {
        id: row
        height: led.size
        spacing: Math.max(1, Math.round(led.size * 0.2))

        Rectangle {
            id: lamp
            anchors.verticalCenter: parent.verticalCenter
            width: led.size
            height: led.size
            radius: width / 2
            color: led.lit ? led.ledColor
                           : Qt.rgba(led.ledColor.r * led.offFactor,
                                     led.ledColor.g * led.offFactor,
                                     led.ledColor.b * led.offFactor, 1)
            border.width: 1
            border.color: Qt.darker(led.ledColor, 2.5)

            Rectangle {
                visible: led.lit
                width: parent.width * 0.35
                height: width
                radius: width / 2
                x: parent.width * 0.2
                y: parent.height * 0.18
                color: "white"
                opacity: 0.45
            }
        }

        Text {
            visible: led.showLabel
            height: led.size
            verticalAlignment: Text.AlignVCenter
            text: led.label
            color: Kirigami.Theme.textColor
            font.family: Kirigami.Theme.smallFont.family
            font.pixelSize: Math.max(Math.round(led.size * 0.8), 6)
        }
    }
}
