/* SPDX-License-Identifier: MPL-2.0 */

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kcmutils as KCM
import org.kde.kirigami as Kirigami

KCM.SimpleKCM {
    id: page

    // Bound automatically to the KConfigXT keys of the same name.
    property alias cfg_metricsUrl: metricsUrlField.text
    property alias cfg_refreshIntervalSeconds: refreshInterval.value
    property string cfg_panelMetric

    readonly property var metricOptions: [
        { id: "tok_s", label: i18n("Tokens per second") },
        { id: "gpu_util", label: i18n("GPU utilisation") },
        { id: "gpu_mem", label: i18n("GPU memory used") },
        { id: "state", label: i18n("Engine state") },
    ]

    Component.onCompleted: {
        const i = metricOptions.findIndex(o => o.id === cfg_panelMetric);
        panelMetric.currentIndex = i >= 0 ? i : 0;
    }

    Kirigami.FormLayout {
        anchors.fill: parent

        Kirigami.Separator {
            Kirigami.FormData.label: i18n("Engine")
            Kirigami.FormData.isSection: true
        }

        QQC2.TextField {
            id: metricsUrlField
            Kirigami.FormData.label: i18n("Base URL:")
            placeholderText: "http://127.0.0.1:8080"
            selectByMouse: true
        }

        QQC2.Label {
            Layout.maximumWidth: Kirigami.Units.gridUnit * 18
            text: i18n("The widget polls <command>%1/metrics</command>.", metricsUrlField.text || "http://127.0.0.1:8080")
            textFormat: Text.StyledText
            font: Kirigami.Theme.smallFont
            wrapMode: Text.WordWrap
            opacity: 0.7
        }

        QQC2.SpinBox {
            id: refreshInterval
            Kirigami.FormData.label: i18n("Refresh every:")
            from: 1
            to: 60
            stepSize: 1
            textFromValue: (value) => i18np("%1 second", "%1 seconds", value)
            valueFromText: (text) => parseInt(text, 10)
        }

        Kirigami.Separator {
            Kirigami.FormData.label: i18n("Panel")
            Kirigami.FormData.isSection: true
        }

        QQC2.ComboBox {
            id: panelMetric
            Kirigami.FormData.label: i18n("Show in panel:")
            model: page.metricOptions
            textRole: "label"
            valueRole: "id"
            onActivated: cfg_panelMetric = currentValue
        }
    }
}
