import QtQuick
import org.kde.plasma.configuration

ConfigModel {
    ConfigCategory {
        name: i18n("General")
        icon: "configure"
        source: "configGeneral.qml"
    }
    ConfigCategory {
        name: i18n("Disk")
        icon: "drive-harddisk"
        source: "configDisk.qml"
    }
    ConfigCategory {
        name: i18n("Network")
        icon: "network-wired"
        source: "configNetwork.qml"
    }
}
