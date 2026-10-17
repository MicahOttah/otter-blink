import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    component Pulse: Item {
        id: p
        property int hold: 80
        property bool lit: false
        function fire() { lit = true; t.restart() }
        Timer { id: t; interval: Math.max(p.hold, 1); onTriggered: p.lit = false }
    }

    component SectionHeader: ColumnLayout {
        id: sh
        property string title
        property string detail
        Layout.fillWidth: true
        Layout.topMargin: Kirigami.Units.smallSpacing
        spacing: 0
        Kirigami.Heading { level: 4; text: sh.title; Layout.fillWidth: true }
        PlasmaComponents.Label {
            text: sh.detail
            opacity: 0.6
            font: Kirigami.Theme.smallFont
            elide: Text.ElideRight
            Layout.fillWidth: true
        }
    }

    component RateRow: RowLayout {
        id: rr
        property string name
        property color ledColor
        property bool lit
        property string value
        property real off: 0.2
        Layout.fillWidth: true
        spacing: Kirigami.Units.largeSpacing
        Led {
            ledColor: rr.ledColor
            lit: rr.lit
            offFactor: rr.off
            size: Kirigami.Units.iconSizes.small - 4
        }
        PlasmaComponents.Label { text: rr.name; Layout.fillWidth: true }
        PlasmaComponents.Label {
            text: rr.value
            font.family: Kirigami.Theme.fixedWidthFont.family
            horizontalAlignment: Text.AlignRight
            Layout.minimumWidth: Kirigami.Units.gridUnit * 6
        }
    }

    readonly property var cfg: Plasmoid.configuration
    readonly property string cmd: "cat /proc/diskstats; echo @@NET; cat /proc/net/dev; echo @@MEM; grep '^Dirty:' /proc/meminfo"

    readonly property var diskRe: makeRegex(cfg.deviceRegex)
    readonly property var lanRe: makeRegex(cfg.lanRegex)
    readonly property var wlanRe: makeRegex(cfg.wlanRegex)

    property var last: null
    property var avgBase: null
    property var rates: ({ read: 0, write: 0, cache: 0, lanRx: 0, lanTx: 0, wlanRx: 0, wlanTx: 0 })
    property var names: ({ disk: "", lan: "", wlan: "" })

    Pulse { id: diskR;  hold: root.cfg.holdTime }
    Pulse { id: diskW;  hold: root.cfg.holdTime }
    Pulse { id: lanRx;  hold: root.cfg.holdTime }
    Pulse { id: lanTx;  hold: root.cfg.holdTime }
    Pulse { id: wlanRx; hold: root.cfg.holdTime }
    Pulse { id: wlanTx; hold: root.cfg.holdTime }

    preferredRepresentation: compactRepresentation
    compactRepresentation: ledsView
    fullRepresentation: ratesView

    toolTipMainText: i18n("Disk & Network Activity")
    toolTipSubText: {
        const L = []
        if (cfg.showDisk) {
            L.push(i18n("Disk read: %1", fmtRate(rates.read)))
            L.push(i18n("Disk write: %1", fmtRate(rates.write)))
        }
        if (cfg.showLan)
            L.push(i18n("Ethernet: ↓ %1  ↑ %2", fmtRate(rates.lanRx), fmtRate(rates.lanTx)))
        if (cfg.showWlan)
            L.push(i18n("Wi-Fi: ↓ %1  ↑ %2", fmtRate(rates.wlanRx), fmtRate(rates.wlanTx)))
        return L.join("\n")
    }

    function makeRegex(s) {
        try { return new RegExp(s) } catch (e) { return /.*/ }
    }

    function fmt(b) {
        const u = ["B", "KiB", "MiB", "GiB"]
        let i = 0
        while (b >= 1024 && i < u.length - 1) { b /= 1024; i++ }
        return b.toFixed(i === 0 ? 0 : 1) + " " + u[i]
    }

    function fmtRate(b) { return fmt(b) + "/s" }

    function delta(a, b) {
        const dt = Math.max(a.time - b.time, 1) / 1000
        const d = k => Math.max(a[k] - b[k], 0)
        return {
            read:   d("read") * 512 / dt,
            write:  d("write") * 512 / dt,
            cache:  d("dirty") / dt,
            lanRx:  d("lanRx") / dt,
            lanTx:  d("lanTx") / dt,
            wlanRx: d("wlanRx") / dt,
            wlanTx: d("wlanTx") / dt
        }
    }

    function parse(text) {
        const s = { read: 0, write: 0, dirty: 0, lanRx: 0, lanTx: 0, wlanRx: 0, wlanTx: 0, time: Date.now() }
        const seen = { disk: [], lan: [], wlan: [] }
        let section = "disk"

        for (const raw of text.split("\n")) {
            const line = raw.trim()
            if (!line) continue
            if (line === "@@NET") { section = "net"; continue }
            if (line === "@@MEM") { section = "mem"; continue }

            if (section === "disk") {
                const f = line.split(/\s+/)
                if (f.length >= 10 && diskRe.test(f[2])) {
                    s.read += Number(f[5])    // sectors read
                    s.write += Number(f[9])   // sectors written
                    seen.disk.push(f[2])
                }
            } else if (section === "net") {
                const i = line.indexOf(":")
                if (i < 0) continue
                const name = line.slice(0, i).trim()
                const f = line.slice(i + 1).trim().split(/\s+/)
                if (f.length < 9) continue
                if (lanRe.test(name)) {
                    s.lanRx += Number(f[0]); s.lanTx += Number(f[8]); seen.lan.push(name)
                } else if (wlanRe.test(name)) {
                    s.wlanRx += Number(f[0]); s.wlanTx += Number(f[8]); seen.wlan.push(name)
                }
            } else {
                const f = line.split(/\s+/)
                if (f[0] === "Dirty:") s.dirty = Number(f[1]) * 1024
            }
        }

        const none = i18n("No matching devices")
        const n = {
            disk: seen.disk.join(", ") || none,
            lan:  seen.lan.join(", ")  || none,
            wlan: seen.wlan.join(", ") || none
        }
        if (n.disk !== names.disk || n.lan !== names.lan || n.wlan !== names.wlan)
            names = n

        // Instant deltas drive the LEDs
        if (last) {
            const r = delta(s, last)
            if (r.read > 0) diskR.fire()
            const physical = cfg.writeMode !== 1 && r.write > 0
            const cached   = cfg.writeMode !== 0 && r.cache > 0
            if (physical || cached) diskW.fire()

            const thr = cfg.netThreshold * 1024
            if (r.lanRx > 0 && r.lanRx >= thr) lanRx.fire()
            if (r.lanTx > 0 && r.lanTx >= thr) lanTx.fire()
            if (r.wlanRx > 0 && r.wlanRx >= thr) wlanRx.fire()
            if (r.wlanTx > 0 && r.wlanTx >= thr) wlanTx.fire()
        }
        last = s

        // One-second averages drive the popup and tooltip
        if (!avgBase) {
            avgBase = s
        } else if (s.time - avgBase.time >= 1000) {
            rates = delta(s, avgBase)
            avgBase = s
        }
    }

    P5Support.DataSource {
        id: executable
        engine: "executable"
        connectedSources: []
        onNewData: (sourceName, data) => {
            disconnectSource(sourceName)
            if (data["exit code"] === 0)
                root.parse(data["stdout"])
        }
    }

    Timer {
        interval: Math.max(root.cfg.interval, 20)
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (executable.connectedSources.length === 0)
                executable.connectSource(root.cmd)
        }
    }

    Component {
        id: ratesView

        ColumnLayout {
            id: pop
            readonly property real off: root.cfg.offBrightness / 100

            Layout.minimumWidth: Kirigami.Units.gridUnit * 16
            Layout.preferredWidth: Kirigami.Units.gridUnit * 16
            Layout.minimumHeight: implicitHeight
            Layout.preferredHeight: implicitHeight
            spacing: Kirigami.Units.smallSpacing

            SectionHeader { visible: root.cfg.showDisk; title: i18n("Disk"); detail: root.names.disk }
            RateRow {
                visible: root.cfg.showDisk
                name: i18n("Read"); ledColor: root.cfg.readColor; lit: diskR.lit; off: pop.off
                value: root.fmtRate(root.rates.read)
            }
            RateRow {
                visible: root.cfg.showDisk
                name: i18n("Write"); ledColor: root.cfg.writeColor; lit: diskW.lit; off: pop.off
                value: root.fmtRate(root.rates.write)
            }
            RateRow {
                visible: root.cfg.showDisk && root.cfg.writeMode !== 0
                name: i18n("Cache growth"); ledColor: root.cfg.writeColor; lit: diskW.lit; off: pop.off
                value: root.fmtRate(root.rates.cache)
            }

            SectionHeader { visible: root.cfg.showLan; title: i18n("Ethernet"); detail: root.names.lan }
            RateRow {
                visible: root.cfg.showLan
                name: i18n("Download"); ledColor: root.cfg.rxColor; lit: lanRx.lit; off: pop.off
                value: root.fmtRate(root.rates.lanRx)
            }
            RateRow {
                visible: root.cfg.showLan
                name: i18n("Upload"); ledColor: root.cfg.txColor; lit: lanTx.lit; off: pop.off
                value: root.fmtRate(root.rates.lanTx)
            }

            SectionHeader { visible: root.cfg.showWlan; title: i18n("Wi-Fi"); detail: root.names.wlan }
            RateRow {
                visible: root.cfg.showWlan
                name: i18n("Download"); ledColor: root.cfg.rxColor; lit: wlanRx.lit; off: pop.off
                value: root.fmtRate(root.rates.wlanRx)
            }
            RateRow {
                visible: root.cfg.showWlan
                name: i18n("Upload"); ledColor: root.cfg.txColor; lit: wlanTx.lit; off: pop.off
                value: root.fmtRate(root.rates.wlanTx)
            }
        }
    }

    Component {
        id: ledsView

        Item {
            id: view

            readonly property bool hPanel: Plasmoid.formFactor === PlasmaCore.Types.Horizontal
            readonly property bool vPanel: Plasmoid.formFactor === PlasmaCore.Types.Vertical
            readonly property int mode: root.cfg.layoutMode
            readonly property int sp: root.cfg.spacing
            readonly property int groupSp: sp * 2 + 2
            readonly property int groups: Math.max(
                (root.cfg.showDisk ? 1 : 0) + (root.cfg.showLan ? 1 : 0) + (root.cfg.showWlan ? 1 : 0), 1)

            // How many LEDs (and how much spacing) sit across the panel's thickness
            readonly property var cross: {
                if (hPanel) {
                    if (mode === 0) return { n: 1, gaps: 0 }
                    if (mode === 1) return { n: 2, gaps: sp }
                    return { n: groups, gaps: (groups - 1) * groupSp }
                }
                if (vPanel) {
                    if (mode === 0) return { n: groups * 2, gaps: groups * sp + (groups - 1) * groupSp }
                    if (mode === 1) return { n: groups, gaps: (groups - 1) * groupSp }
                    return { n: 2, gaps: sp }
                }
                return { n: 0, gaps: 0 }
            }
            readonly property real thickness: hPanel ? height : (vPanel ? width : 0)

            readonly property int ledSize: {
                if (root.cfg.ledSize > 0) return root.cfg.ledSize
                if (cross.n === 0 || thickness <= 0) return Kirigami.Units.iconSizes.small - 4
                return Math.max(4, Math.floor((thickness - 2 - cross.gaps) / cross.n))
            }
            readonly property real off: root.cfg.offBrightness / 100
            readonly property int pairCols: mode === 1 ? 1 : 2
            readonly property bool labels: root.cfg.showLabels

            Layout.minimumWidth: vPanel ? -1 : grid.implicitWidth
            Layout.preferredWidth: vPanel ? -1 : grid.implicitWidth
            Layout.minimumHeight: hPanel ? -1 : grid.implicitHeight
            Layout.preferredHeight: hPanel ? -1 : grid.implicitHeight

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton
                onClicked: root.expanded = !root.expanded
            }

            Grid {
                id: grid
                anchors.centerIn: parent
                columns: view.mode === 2 ? 1 : 3
                spacing: view.groupSp

                Grid {
                    visible: root.cfg.showDisk
                    columns: view.pairCols
                    spacing: view.sp
                    Led { ledColor: root.cfg.readColor;  lit: diskR.lit; offFactor: view.off; size: view.ledSize; label: "R"; showLabel: view.labels }
                    Led { ledColor: root.cfg.writeColor; lit: diskW.lit; offFactor: view.off; size: view.ledSize; label: "W"; showLabel: view.labels }
                }
                Grid {
                    visible: root.cfg.showLan
                    columns: view.pairCols
                    spacing: view.sp
                    Led { ledColor: root.cfg.rxColor; lit: lanRx.lit; offFactor: view.off; size: view.ledSize; label: "E↓"; showLabel: view.labels }
                    Led { ledColor: root.cfg.txColor; lit: lanTx.lit; offFactor: view.off; size: view.ledSize; label: "E↑"; showLabel: view.labels }
                }
                Grid {
                    visible: root.cfg.showWlan
                    columns: view.pairCols
                    spacing: view.sp
                    Led { ledColor: root.cfg.rxColor; lit: wlanRx.lit; offFactor: view.off; size: view.ledSize; label: "Wi↓"; showLabel: view.labels }
                    Led { ledColor: root.cfg.txColor; lit: wlanTx.lit; offFactor: view.off; size: view.ledSize; label: "Wi↑"; showLabel: view.labels }
                }
            }
        }
    }
}
