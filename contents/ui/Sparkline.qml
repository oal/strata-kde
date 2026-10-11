/* SPDX-License-Identifier: MPL-2.0 */

import QtQuick
import QtQuick.Shapes
import org.kde.kirigami as Kirigami

/*
 * A tiny sparkline for the history series the metrics endpoint keeps.
 * Values arrive pre-shaped from metrics.mjs (nulls become baseline gaps).
 */
Shape {
    id: spark

    required property var values
    property real maxValue: 0          // 0 -> auto-scale to the series
    property color lineColor: Kirigami.Theme.highlightColor
    antialiasing: true
    preferredWidth: 120
    preferredHeight: 28
    fillMode: Shape.PreserveAspectFit

    ShapePath {
        strokeWidth: 1.5
        strokeColor: spark.lineColor
        fillColor: "transparent"
        capStyle: ShapePath.RoundCap
        joinStyle: ShapePath.RoundJoin

        PathPolyline {
            path: {
                const pts = spark._points();
                return pts.map(p => Qt.point(p.x, p.y));
            }
        }
    }

    function _points() {
        const w = width, h = height;
        if (!Array.isArray(values) || values.length < 2 || w <= 0 || h <= 0)
            return [];
        let hi = maxValue;
        if (!hi) {
            hi = 1;
            for (const v of values)
                if (typeof v === "number" && v > hi)
                    hi = v;
        }
        const step = w / (values.length - 1);
        const out = [];
        for (let i = 0; i < values.length; ++i) {
            const v = values[i];
            out.push({
                x: i * step,
                y: (typeof v === "number")
                    ? h - (Math.min(Math.max(v, 0), hi) / hi) * (h - 2) - 1
                    : h - 1,
            });
        }
        return out;
    }
}
