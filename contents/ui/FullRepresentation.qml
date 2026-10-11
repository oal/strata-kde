/* SPDX-License-Identifier: MPL-2.0 */

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.plasmoid
import org.kde.kirigami as Kirigami

/*
 * The popup: live engine state, hardware gauges with sparklines, the
 * conversation cache, and the ten most recent requests. `root` is the
 * PlasmoidItem from main.qml; everything shown comes from root.summary
 * (shapeSummary() in code/metrics.mjs).
 */
PlasmaExtras.Representation {
    id: full

    Layout.minimumWidth: Kirigami.Units.gridUnit * 20
    Layout.minimumHeight: Kirigami.Units.gridUnit * 16
    Layout.preferredWidth: Kirigami.Units.gridUnit * 26
    Layout.preferredHeight: Kirigami.Units.gridUnit * 24

    collapseMarginsHint: true

    header: PlasmaExtras.PlasmoidHeading {
        contentItem: RowLayout {
            spacing: Kirigami.Units.smallSpacing

            Kirigami.Heading {
                Layout.fillWidth: true
                level: 4
                text: root.summary ? root.summary.model : i18n("Strata stats")
                elide: Text.ElideRight
            }

            PlasmaComponents.ToolButton {
                id: refreshButton
                icon.name: "view-refresh"
                display: QQC2.AbstractButton.IconOnly
                text: i18n("Refresh now")
                enabled: !root.polling
                onClicked: root.refresh()

                PlasmaComponents.ToolTip { text: refreshButton.text }
            }

            PlasmaComponents.ToolButton {
                id: configureButton
                icon.name: "configure"
                display: QQC2.AbstractButton.IconOnly
                text: i18n("Configure…")
                onClicked: Plasmoid.internalAction("configure").trigger()

                PlasmaComponents.ToolTip { text: configureButton.text }
            }
        }
    }

    footer: PlasmaExtras.PlasmoidHeading {
        contentItem: PlasmaComponents.Label {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            font: Kirigami.Theme.smallFont
            color: root.offline
                ? Kirigami.Theme.negativeTextColor
                : Kirigami.Theme.disabledTextColor
            text: {
                if (root.offline)
                    return root.lastError;
                const age = root.ageSeconds();
                if (age < 0)
                    return i18n("No data yet");
                return i18n("updated %1 s ago", Math.round(age));
            }
        }
    }

    QQC2.ScrollView {
        anchors.fill: parent

        ColumnLayout {
            width: Math.max(full.width - Kirigami.Units.largeSpacing * 2, 1)
            spacing: Kirigami.Units.smallSpacing

            visible: root.summary !== null

            /* ---------------- live state ---------------- */

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: Kirigami.Units.smallSpacing

                // State pill: filled with the theme's highlight when the engine
                // is working, outlined when idle. (Kirigami.Badge has no
                // `positive` property on Plasma 6.6 — colour it explicitly.)
                Rectangle {
                    visible: root.summary !== null
                    Layout.alignment: Qt.AlignVCenter
                    width: stateLabel.implicitWidth + Kirigami.Units.smallSpacing * 2
                    height: stateLabel.implicitHeight + Kirigami.Units.smallSpacing
                    radius: height / 2
                    color: root.summary && root.summary.busy
                        ? Kirigami.Theme.highlightColor
                        : "transparent"
                    border.width: 1
                    border.color: Kirigami.Theme.highlightColor

                    PlasmaComponents.Label {
                        id: stateLabel
                        anchors.centerIn: parent
                        font: Kirigami.Theme.smallFont
                        text: root.summary ? root.summary.stateLabel : ""
                        color: root.summary && root.summary.busy
                            ? Kirigami.Theme.highlightedTextColor
                            : Kirigami.Theme.highlightColor
                    }
                }

                PlasmaComponents.Label {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    visible: root.summary !== null
                    text: root.summary
                        ? (root.summary.busy
                           ? root.summary.phase
                           : i18n("idle, %1 queued", root.summary.queued))
                        : ""
                }

                PlasmaComponents.Label {
                    visible: root.summary !== null
                    font.weight: Font.Bold
                    text: root.summary && root.summary.tokS != null
                        ? i18n("%1 t/s", Math.round(root.summary.tokS))
                        : ""
                }
            }

            // Prompt progress bar while reading a prompt.
            QQC2.ProgressBar {
                Layout.fillWidth: true
                visible: root.summary && root.summary.busy
                         && root.summary.promptTotal > 0
                from: 0
                to: root.summary ? root.summary.promptTotal : 1
                value: root.summary ? Math.min(root.summary.promptRead ?? 0, root.summary.promptTotal) : 0
            }

            GridLayout {
                Layout.fillWidth: true
                visible: root.summary !== null
                columns: 4
                columnSpacing: Kirigami.Units.largeSpacing

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    PlasmaComponents.Label { text: root.summary ? fmtK(root.summary.promptTokens) : ""; font.weight: Font.Bold }
                    PlasmaComponents.Label { text: i18n("prompt"); font: Kirigami.Theme.smallFont; color: Kirigami.Theme.disabledTextColor }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    PlasmaComponents.Label { text: root.summary ? fmtK(root.summary.lastReused) : ""; font.weight: Font.Bold }
                    PlasmaComponents.Label { text: i18n("reused"); font: Kirigami.Theme.smallFont; color: Kirigami.Theme.disabledTextColor }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    PlasmaComponents.Label { text: root.summary ? fmtK(root.summary.generated) : ""; font.weight: Font.Bold }
                    PlasmaComponents.Label { text: i18n("generated"); font: Kirigami.Theme.smallFont; color: Kirigami.Theme.disabledTextColor }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    PlasmaComponents.Label {
                        text: root.summary && root.summary.elapsedS != null
                            ? root.summary.elapsedS.toFixed(1) + " s" : ""
                        font.weight: Font.Bold
                    }
                    PlasmaComponents.Label { text: i18n("elapsed"); font: Kirigami.Theme.smallFont; color: Kirigami.Theme.disabledTextColor }
                }
            }

            Kirigami.Separator { Layout.fillWidth: true; Layout.topMargin: Kirigami.Units.smallSpacing }

            /* ---------------- hardware ---------------- */

            GridLayout {
                Layout.fillWidth: true
                visible: root.summary !== null
                columns: 2
                columnSpacing: Kirigami.Units.largeSpacing
                rowSpacing: Kirigami.Units.smallSpacing

                // GPU row
                PlasmaComponents.Label {
                    text: root.summary ? root.summary.gpuName : ""
                    elide: Text.ElideRight
                    font.weight: Font.Bold
                    font.pointSize: Kirigami.Theme.defaultFont.pointSize - 1
                    Layout.fillWidth: true
                }
                PlasmaComponents.Label {
                    text: root.summary
                        ? i18n("%1% · %2 GiB / %3 GiB",
                               Math.round(root.summary.gpuUtil),
                               (root.summary.gpuMemUsedMiB / 1024).toFixed(1),
                               (root.summary.gpuMemTotalMiB / 1024).toFixed(1))
                        : ""
                    horizontalAlignment: Text.AlignRight
                    font: Kirigami.Theme.smallFont
                }
                Sparkline {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Kirigami.Units.gridUnit * 1.5
                    values: root.summary ? root.summary.history.gpu_util : []
                    maxValue: 100
                }
                PlasmaComponents.Label {
                    text: root.summary
                        ? i18n("%1 °C · %2 W",
                               root.summary.gpuTemp ?? "–",
                               root.summary.gpuPower != null ? Math.round(root.summary.gpuPower) : "–")
                        : ""
                    horizontalAlignment: Text.AlignRight
                    font: Kirigami.Theme.smallFont
                    color: Kirigami.Theme.disabledTextColor
                }

                // CPU row
                PlasmaComponents.Label {
                    text: root.summary ? root.summary.cpuName : ""
                    elide: Text.ElideRight
                    font.weight: Font.Bold
                    font.pointSize: Kirigami.Theme.defaultFont.pointSize - 1
                    Layout.fillWidth: true
                }
                PlasmaComponents.Label {
                    text: root.summary
                        ? i18n("%1% · %2 / %3 GiB RAM",
                               Math.round(root.summary.cpuPct ?? 0),
                               root.summary.ramUsedGiB,
                               root.summary.ramTotalGiB)
                        : ""
                    horizontalAlignment: Text.AlignRight
                    font: Kirigami.Theme.smallFont
                }
                Sparkline {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Kirigami.Units.gridUnit * 1.5
                    values: root.summary ? root.summary.history.cpu : []
                    maxValue: 100
                    lineColor: Kirigami.Theme.neutralTextColor
                }
                Item { Layout.fillWidth: true } // spacer to keep the grid even
            }

            Kirigami.Separator { Layout.fillWidth: true; Layout.topMargin: Kirigami.Units.smallSpacing }

            /* ---------------- conversation cache ---------------- */

            PlasmaComponents.Label {
                visible: root.summary && root.summary.cacheEnabled
                text: root.summary
                    ? i18n("Conversation cache: %1/%2 parked · hit rate %3%",
                           root.summary.cacheParked, root.summary.cacheSlots,
                           root.summary.cacheHitRate != null
                               ? Math.round(root.summary.cacheHitRate * 100) : "–")
                    : ""
                font: Kirigami.Theme.smallFont
            }

            Kirigami.Separator { Layout.fillWidth: true; Layout.topMargin: Kirigami.Units.smallSpacing }

            /* ---------------- recent requests ---------------- */

            Kirigami.Heading {
                Layout.fillWidth: true
                level: 5
                visible: root.summary && root.summary.requests.length > 0
                text: i18n("Recent requests")
            }

            Repeater {
                model: root.summary ? root.summary.requests : []
                delegate: RowLayout {
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true

                    PlasmaComponents.Label {
                        text: String(index + 1)
                        font: Kirigami.Theme.smallFont
                        color: Kirigami.Theme.disabledTextColor
                    }
                    PlasmaComponents.Label {
                        text: fmtK(modelData.promptTokens) + "→" + fmtK(modelData.outputTokens)
                        font: Kirigami.Theme.smallFont
                    }
                    PlasmaComponents.Label {
                        Layout.fillWidth: true
                        text: modelData.hitRate != null
                            ? i18n("hit %1%", Math.round(modelData.hitRate * 100))
                            : ""
                        font: Kirigami.Theme.smallFont
                        color: Kirigami.Theme.disabledTextColor
                    }
                    PlasmaComponents.Label {
                        text: modelData.decodeTokS != null
                            ? Math.round(modelData.decodeTokS) + " t/s"
                            : ""
                        font: Kirigami.Theme.smallFont
                    }
                    PlasmaComponents.Label {
                        text: modelData.durationS.toFixed(1) + " s"
                        font: Kirigami.Theme.smallFont
                        color: Kirigami.Theme.disabledTextColor
                    }
                }
            }
        }
    }

    function fmtK(n) {
        if (n == null)
            return "–";
        if (n >= 1000000)
            return (n / 1000000).toFixed(1) + "M";
        if (n >= 1000)
            return (n / 1000).toFixed(1) + "k";
        return String(n);
    }
}
