import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    property alias cfg_showLan: showLan.checked
    property alias cfg_lanRegex: lanRegex.text
    property alias cfg_showWlan: showWlan.checked
    property alias cfg_wlanRegex: wlanRegex.text
    property alias cfg_combineNetwork: combineNetwork.checked
    property alias cfg_netThreshold: netThreshold.value

    Kirigami.FormLayout {
        QQC2.CheckBox {
            id: showLan
            Kirigami.FormData.label: i18n("Ethernet:")
            text: i18n("Show")
        }
        QQC2.TextField {
            id: lanRegex
            enabled: showLan.checked
            Kirigami.FormData.label: i18n("Ethernet interfaces (regex):")
            Layout.fillWidth: true
        }

        Item { Kirigami.FormData.isSection: true }

        QQC2.CheckBox {
            id: showWlan
            Kirigami.FormData.label: i18n("Wi-Fi:")
            text: i18n("Show")
        }
        QQC2.TextField {
            id: wlanRegex
            enabled: showWlan.checked
            Kirigami.FormData.label: i18n("Wi-Fi interfaces (regex):")
            Layout.fillWidth: true
        }

        Item { Kirigami.FormData.isSection: true }

        QQC2.CheckBox {
            id: combineNetwork
            enabled: showLan.checked || showWlan.checked
            Kirigami.FormData.label: i18n("Space saving:")
            text: i18n("Combine Ethernet and Wi-Fi into one pair")
        }
        QQC2.SpinBox {
            id: netThreshold
            Kirigami.FormData.label: i18n("Ignore traffic below (KiB/s):")
            from: 0; to: 100000; stepSize: 1
        }
        QQC2.Label {
            Layout.maximumWidth: Kirigami.Units.gridUnit * 20
            wrapMode: Text.WordWrap
            opacity: 0.7
            text: i18n("Matched against interface names in /proc/net/dev. Run \"ip -br link\" to list yours. Fedora usually names Ethernet enp... and Wi-Fi wlp...")
        }
    }
}
