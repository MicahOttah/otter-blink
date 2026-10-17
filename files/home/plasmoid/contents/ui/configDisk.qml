import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    property alias cfg_showDisk: showDisk.checked
    property alias cfg_writeMode: writeMode.currentIndex
    property alias cfg_deviceRegex: deviceRegex.text

    Kirigami.FormLayout {
        QQC2.CheckBox {
            id: showDisk
            Kirigami.FormData.label: i18n("Disk LEDs:")
            text: i18n("Show")
        }
        QQC2.ComboBox {
            id: writeMode
            enabled: showDisk.checked
            Kirigami.FormData.label: i18n("Write LED shows:")
            model: [
                i18n("Physical disk writes only"),
                i18n("Cache writes only (dirty memory growing)"),
                i18n("Both")
            ]
        }
        QQC2.TextField {
            id: deviceRegex
            enabled: showDisk.checked
            Kirigami.FormData.label: i18n("Devices (regex):")
            Layout.fillWidth: true
        }
        QQC2.Label {
            Layout.maximumWidth: Kirigami.Units.gridUnit * 20
            wrapMode: Text.WordWrap
            opacity: 0.7
            text: i18n("Matched against device names in /proc/diskstats. Examples: ^nvme0n1$ or ^sd[ab]$. Cache mode follows the kernel's Dirty counter, which refreshes about once per second.")
        }
    }
}
