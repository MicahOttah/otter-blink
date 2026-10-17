import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import org.kde.kquickcontrols as KQControls

KCM.SimpleKCM {
    property alias cfg_readColor: readColor.color
    property alias cfg_writeColor: writeColor.color
    property alias cfg_rxColor: rxColor.color
    property alias cfg_txColor: txColor.color
    property alias cfg_offBrightness: offBrightness.value
    property alias cfg_ledSize: ledSize.value
    property alias cfg_spacing: spacing.value
    property alias cfg_layoutMode: layoutMode.currentIndex
    property alias cfg_showLabels: showLabels.checked
    property alias cfg_interval: interval.value
    property alias cfg_holdTime: holdTime.value

    Kirigami.FormLayout {
        KQControls.ColorButton {
            id: readColor
            Kirigami.FormData.label: i18n("Disk read color:")
            showAlphaChannel: false
        }
        KQControls.ColorButton {
            id: writeColor
            Kirigami.FormData.label: i18n("Disk write color:")
            showAlphaChannel: false
        }
        KQControls.ColorButton {
            id: rxColor
            Kirigami.FormData.label: i18n("Network receive color:")
            showAlphaChannel: false
        }
        KQControls.ColorButton {
            id: txColor
            Kirigami.FormData.label: i18n("Network transmit color:")
            showAlphaChannel: false
        }
        QQC2.SpinBox {
            id: offBrightness
            Kirigami.FormData.label: i18n("Off brightness (%):")
            from: 0; to: 100; stepSize: 5
        }

        Item { Kirigami.FormData.isSection: true }

        QQC2.SpinBox {
            id: ledSize
            Kirigami.FormData.label: i18n("LED size in px (0 = auto):")
            from: 0; to: 64
        }
        QQC2.SpinBox {
            id: spacing
            Kirigami.FormData.label: i18n("Spacing (px):")
            from: 0; to: 32
        }
        QQC2.ComboBox {
            id: layoutMode
            Kirigami.FormData.label: i18n("Layout:")
            model: [
                i18n("Single row"),
                i18n("Pairs stacked, groups side by side"),
                i18n("Pairs side by side, groups stacked")
            ]
        }
        QQC2.CheckBox {
            id: showLabels
            text: i18n("Show labels")
        }

        Item { Kirigami.FormData.isSection: true }

        QQC2.SpinBox {
            id: interval
            Kirigami.FormData.label: i18n("Poll interval (ms):")
            from: 20; to: 2000; stepSize: 10
        }
        QQC2.SpinBox {
            id: holdTime
            Kirigami.FormData.label: i18n("Blink duration (ms):")
            from: 0; to: 1000; stepSize: 10
        }
    }
}
