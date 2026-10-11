/* SPDX-License-Identifier: MPL-2.0 */

/*
 * Parsing and shaping of the Strata /metrics payload.
 *
 * Pure ES module: no Qt, no XMLHttpRequest — everything here runs under node
 * and is covered by tests/metrics.test.mjs against a captured fixture. The
 * QML layer only binds to the shaped objects this module returns.
 */

/** Panel metric ids, mirrored in contents/config/main.xml. */
export const PANEL_METRICS = ["tok_s", "gpu_util", "gpu_mem", "state"];

/**
 * Validate and normalise the raw JSON payload.
 *
 * @param {unknown} raw parsed JSON from GET /metrics
 * @returns {{ok: true, metrics: object} | {ok: false, error: string}}
 */
export function parseMetrics(raw) {
    if (raw === null || typeof raw !== "object" || Array.isArray(raw))
        return { ok: false, error: "not a JSON object" };

    const required = ["engine", "live", "hardware", "totals"];
    for (const key of required) {
        if (raw[key] === null || typeof raw[key] !== "object")
            return { ok: false, error: `missing section: ${key}` };
    }
    if (typeof raw.engine.model !== "string" || raw.engine.model === "")
        return { ok: false, error: "missing engine.model" };
    if (typeof raw.live.state !== "string")
        return { ok: false, error: "missing live.state" };
    if (typeof raw.hardware.gpu_util !== "number")
        return { ok: false, error: "missing hardware.gpu_util" };

    return { ok: true, metrics: raw };
}

/** True when the engine is actively generating or reading a prompt. */
export function isBusy(live) {
    return live.state === "reading" || live.state === "generating";
}

/**
 * The value shown in the panel for the chosen metric.
 *
 * @returns {{text: string, busy: boolean}}
 */
export function panelValue(metrics, panelMetric) {
    const hw = metrics.hardware;
    const live = metrics.live;
    switch (panelMetric) {
        case "gpu_util":
            return { text: `${Math.round(hw.gpu_util)}%`, busy: isBusy(live) };
        case "gpu_mem":
            return {
                text: `${Math.round((hw.gpu_mem_used / (hw.gpu_mem_total || 1)) * 100)}%`,
                busy: isBusy(live),
            };
        case "state":
            return { text: stateLabel(live.state), busy: isBusy(live) };
        case "tok_s":
        default: {
            const t = live.tok_s ?? hw.tok_s;
            if (isBusy(live) && t != null && t > 0)
                return { text: `${Math.round(t)} t/s`, busy: true };
            return { text: "–", busy: false };
        }
    }
}

/** Short, panel-friendly label for an engine state. */
export function stateLabel(state) {
    switch (state) {
        case "reading": return "read";
        case "generating": return "gen";
        case "idle": return "idle";
        default: return state || "–";
    }
}

/**
 * Shape the payload for the popup. Every number is pre-formatted so the QML
 * delegates stay dumb; missing values become null and the UI shows an em dash.
 */
export function shapeSummary(metrics) {
    const eng = metrics.engine;
    const live = metrics.live;
    const hw = metrics.hardware;
    const statics = metrics.hardware_static || {};
    const cache = metrics.conversation_cache || {};
    const totals = metrics.totals || {};

    return {
        model: eng.model,
        version: eng.version || "",
        context: eng.max_context || 0,
        kv: eng.kv || "",

        state: live.state,
        stateLabel: stateLabel(live.state),
        phase: live.phase || "",
        busy: isBusy(live),
        queued: live.queued || 0,
        promptTokens: live.prompt_tokens || 0,
        promptRead: live.prompt_read ?? null,
        promptTotal: live.prompt_total ?? null,
        generated: live.generated || 0,
        elapsedS: live.elapsed_s ?? null,
        tokS: live.tok_s ?? hw.tok_s ?? null,
        prefillTokS: live.prefill_tok_s_mean ?? hw.prefill_tok_s_mean ?? null,

        gpuName: statics.gpu_name || "GPU",
        gpuUtil: hw.gpu_util,
        gpuMemUsedMiB: mib(hw.gpu_mem_used),
        gpuMemTotalMiB: mib(hw.gpu_mem_total),
        gpuTemp: hw.gpu_temp ?? null,
        gpuPower: hw.gpu_power ?? null,
        gpuPowerLimit: hw.gpu_power_limit ?? null,

        cpuName: statics.cpu_name || "CPU",
        cpuPct: hw.cpu ?? null,
        ramUsedGiB: gib(hw.ram_used),
        ramTotalGiB: gib(hw.ram_total),

        cacheEnabled: !!cache.enabled,
        cacheParked: cache.parked ?? 0,
        cacheSlots: cache.slots ?? 0,
        cacheBudgetMiB: cache.budget_mib ?? 0,
        cacheHitRate: cache.prompt_tokens
            ? cache.reused_tokens / cache.prompt_tokens
            : null,

        // Reuse of the most recent finished request, for the live row.
        lastReused: (metrics.requests && metrics.requests[0])
            ? (metrics.requests[0].reused ?? 0)
            : 0,

        totalRequests: totals.requests ?? 0,
        totalOutputTokens: totals.output_tokens ?? 0,
        totalHitRate: totals.prompt_tokens
            ? totals.reused / totals.prompt_tokens
            : null,

        requests: (metrics.requests || []).slice(0, 10).map(shapeRequest),
        history: shapeHistory(metrics.history || {}),
    };
}

/** One row of the recent-requests list. Newest first, as the API returns it. */
export function shapeRequest(req) {
    const drafts = req.drafts_offered || 0;
    return {
        time: req.time ?? 0,
        finish: req.finish || "?",
        promptTokens: req.prompt_tokens ?? 0,
        promptRead: req.prompt_read ?? 0,
        reused: req.reused ?? 0,
        outputTokens: req.output_tokens ?? 0,
        durationS: req.duration_s ?? 0,
        decodeTokS: req.decode_tok_s ?? null,
        hitRate: req.hit_rate ?? null,
        acceptRate: drafts ? (req.drafts_accepted ?? 0) / drafts : null,
    };
}

/** Keep only the series the popup draws, trimmed to a common length. */
export function shapeHistory(history) {
    const out = {};
    for (const key of ["gpu_util", "gpu_power", "tok_s", "cpu"]) {
        const v = history[key];
        out[key] = Array.isArray(v) ? v.map(x => (typeof x === "number" ? x : null)) : [];
    }
    return out;
}

/** Sparkline geometry: normalised points for a canvas of w x h. */
export function sparkPoints(values, w, h, max) {
    if (!Array.isArray(values) || values.length < 2 || w <= 0 || h <= 0)
        return [];
    const hi = max ?? Math.max(...values.map(v => (v == null ? 0 : v)), 1);
    const step = w / (values.length - 1);
    return values.map((v, i) => ({
        x: i * step,
        y: v == null ? h : h - (Math.min(Math.max(v, 0), hi) / hi) * h,
    }));
}

function mib(bytes) {
    return bytes == null ? null : Math.round(bytes / (1024 * 1024));
}

function gib(bytes) {
    return bytes == null ? null : Math.round(bytes / (1024 * 1024 * 1024));
}
