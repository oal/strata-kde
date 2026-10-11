/* SPDX-License-Identifier: MPL-2.0 */

import QtQuick
import QtQuick.Layouts
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.plasmoid
import org.kde.kirigami as Kirigami

import "../code/metrics.mjs" as Metrics

/*
 * What sits in the panel: the Strata glyph plus the chosen live metric
 * (tok/s, GPU %, GPU memory %, or engine state). `root` is the PlasmoidItem
 * from main.qml.
 */
MouseArea {
    id: compact

    readonly property bool horizontal: Plasmoid.formFactor === PlasmaCore.Types.Horizontal

    // The number is the whole point of the widget, so let it set the width
    // rather than squeezing it into a square icon slot.
    Layout.minimumWidth: horizontal ? content.implicitWidth + Kirigami.Units.smallSpacing * 2 : 0
    Layout.preferredWidth: Layout.minimumWidth
    Layout.minimumHeight: horizontal ? 0 : content.implicitHeight + Kirigami.Units.smallSpacing * 2
    Layout.preferredHeight: Layout.minimumHeight

    hoverEnabled: true
    acceptedButtons: Qt.LeftButton | Qt.MiddleButton
    activeFocusOnTab: true

    Accessible.role: Accessible.Button
    Accessible.name: root.toolTipMainText
    Accessible.description: root.toolTipSubText

    onClicked: (mouse) => {
        if (mouse.button === Qt.MiddleButton)
            root.refresh();
        else
            root.expanded = !root.expanded;
    }

    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.expanded = !root.expanded;
            event.accepted = true;
        }
    }

    /** Recomputed whenever a fetch lands or the setting changes. */
    readonly property var value: {
        if (!root.metrics)
            return { text: "–", busy: false };
        return Metrics.panelValue(root.metrics, plasmoid.configuration.panelMetric);
    }

    RowLayout {
        id: content
        anchors.centerIn: parent
        spacing: Kirigami.Units.smallSpacing

        // Reverse the row in a vertical panel so icon and text stack.
        LayoutMirroring.enabled: !compact.horizontal
        LayoutMirroring.childrenInherit: true

        // Dimmed when the engine is unreachable: a panel widget that
        // disappears leaves a hole, so show the last-known shape instead.
        opacity: root.offline || !root.metrics ? 0.5 : 1.0
        Behavior on opacity { NumberAnimation { duration: Kirigami.Units.shortDuration } }

        Kirigami.Icon {
            id: icon
            source: Qt.resolvedUrl("../icons/strata-layer.svg")
            isMask: true
            color: Kirigami.Theme.textColor
            Layout.alignment: Qt.AlignCenter
            implicitWidth: Kirigami.Units.iconSizes.small
            implicitHeight: Kirigami.Units.iconSizes.small
        }

        PlasmaComponents.Label {
            id: label
            text: compact.value.text
            Layout.alignment: Qt.AlignCenter
            font.pixelSize: Math.max(Kirigami.Theme.smallFont.pixelSize,
                                     Kirigami.Units.gridUnit * 0.7)
            // Bold while the engine is actually working.
            font.weight: compact.value.busy ? Font.Bold : Font.Normal
            color: root.offline || !root.metrics
                ? Kirigami.Theme.disabledTextColor
                : Kirigami.Theme.textColor
        }
    }
}
