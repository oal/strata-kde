/* SPDX-License-Identifier: MPL-2.0 */

import QtQuick
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore

import "../code/metrics.mjs" as Metrics

/*
 * Applet root. Polls the Strata engine's /metrics endpoint, keeps the parsed
 * payload in `metrics`, and exposes the shaped summary the popup binds to.
 * The panel text is recomputed from `metrics` whenever a fetch lands.
 */
PlasmoidItem {
    id: root

    /* ---------------- state ---------------- */

    /** Last successfully parsed payload, or null when never fetched. */
    property var metrics: null

    /** shapeSummary() of the last good payload — what FullRepresentation binds to. */
    property var summary: null

    property bool offline: false
    property string lastError: ""
    property double lastFetchMs: 0
    property bool polling: false

    readonly property int pollMs: Math.max(1, plasmoid.configuration.refreshIntervalSeconds) * 1000
    readonly property string metricsUrl: {
        const base = (plasmoid.configuration.metricsUrl || "").trim();
        return base.endsWith("/metrics") ? base : base.replace(/\/+$/, "") + "/metrics";
    }

    /* ---------------- service wiring ---------------- */

    /*
     * The socket lives in HttpTransport because QML only delivers XHR
     * callbacks to handlers assigned from a QML context; one assigned inside
     * an ES module never fires. Parsing stays in metrics.mjs.
     */
    property HttpTransport transport: HttpTransport {}

    /** In-flight request, so a new poll supersedes the previous one. */
    property var pending: null

    /* ---------------- representations ---------------- */

    preferredRepresentation: compactRepresentation

    compactRepresentation: CompactRepresentation {}
    fullRepresentation: FullRepresentation {}

    toolTipMainText: i18n("Strata stats")
    toolTipSubText: {
        if (offline || !summary)
            return lastError || i18n("No data yet");
        return i18nc("%1 model, %2 tok/s, %3 GPU utilisation",
                     "%1 · %2 t/s · GPU %3%",
                     summary.model,
                     summary.tokS != null ? Math.round(summary.tokS) : "–",
                     Math.round(summary.gpuUtil));
    }

    Plasmoid.status: PlasmaCore.Types.ActiveStatus

    /* ---------------- timers ---------------- */

    // Bound to the setting rather than read once, so changing the interval
    // retimes the poll immediately.
    Timer {
        id: pollTimer
        interval: root.pollMs
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.poll()
    }

    /* ---------------- polling ---------------- */

    function poll() {
        if (pending) {
            pending.abort();
            pending = null;
        }
        polling = true;

        const request = transport.get(metricsUrl);
        pending = request;
        request.promise.then(function (resp) {
            if (pending === request)
                pending = null;
            polling = false;
            if (resp.status !== 200) {
                root.offline = true;
                root.lastError = i18n("HTTP %1", resp.status);
                return;
            }
            let parsed;
            try {
                parsed = JSON.parse(resp.text);
            } catch (e) {
                root.offline = true;
                root.lastError = i18n("bad JSON from %1", metricsUrl);
                return;
            }
            const validated = Metrics.parseMetrics(parsed);
            if (!validated.ok) {
                root.offline = true;
                root.lastError = validated.error;
                return;
            }
            root.metrics = validated.metrics;
            root.summary = Metrics.shapeSummary(validated.metrics);
            root.offline = false;
            root.lastError = "";
            root.lastFetchMs = Date.now();
        }).catch(function (e) {
            if (pending === request)
                pending = null;
            polling = false;
            if (e && e.kind === "abort")
                return;                     // superseded by a newer poll
            root.offline = true;
            root.lastError = i18n("cannot reach %1", metricsUrl);
        });
    }

    function refresh() {
        poll();
    }

    /** Seconds since the last successful fetch, for the freshness footer. */
    function ageSeconds(): real {
        if (!lastFetchMs)
            return -1;
        return (Date.now() - lastFetchMs) / 1000.0;
    }
}
