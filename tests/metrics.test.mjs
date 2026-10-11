// SPDX-License-Identifier: MPL-2.0
//
// Pure-logic tests for code/metrics.mjs, run under node:
//
//     node --test tests/*.test.mjs
//
// The live fixture (tests/fixtures/metrics-live.json) is a real capture from
// a running Strata engine; tests/live-metrics.test.mjs re-fetches it to catch
// schema drift and skips itself when the engine is unreachable.

import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import path from "node:path";

import {
    parseMetrics,
    panelValue,
    stateLabel,
    shapeSummary,
    shapeRequest,
    shapeHistory,
    sparkPoints,
    isBusy,
    PANEL_METRICS,
} from "../contents/code/metrics.mjs";

const HERE = path.dirname(fileURLToPath(import.meta.url));
const live = JSON.parse(readFileSync(path.join(HERE, "fixtures/metrics-live.json"), "utf8"));

/* ---------- parseMetrics ---------- */

test("parseMetrics accepts the live fixture", () => {
    const r = parseMetrics(live);
    assert.equal(r.ok, true);
    assert.equal(r.metrics, live);
});

test("parseMetrics rejects junk", () => {
    for (const bad of [null, undefined, 42, "x", [], {}]) {
        const r = parseMetrics(bad);
        assert.equal(r.ok, false, `should reject ${JSON.stringify(bad)}`);
        assert.equal(typeof r.error, "string");
    }
});

test("parseMetrics rejects missing sections", () => {
    const missing = structuredClone(live);
    delete missing.hardware;
    assert.match(parseMetrics(missing).error, /hardware/);

    const noModel = structuredClone(live);
    delete noModel.engine.model;
    assert.match(parseMetrics(noModel).error, /model/);
});

/* ---------- panelValue ---------- */

test("panelValue: tok_s shows an em dash while idle", () => {
    const v = panelValue(live, "tok_s");
    assert.equal(v.busy, false); // fixture live.state === "idle"
    assert.equal(v.text, "–");
});

test("panelValue: tok_s falls back to hardware rate when generating", () => {
    const m = structuredClone(live);
    m.live.state = "generating";
    m.live.tok_s = 127.4;
    const v = panelValue(m, "tok_s");
    assert.equal(v.text, "127 t/s");
    assert.equal(v.busy, true);
});

test("panelValue: gpu_util rounds", () => {
    const v = panelValue(live, "gpu_util");
    assert.equal(v.text, `${Math.round(live.hardware.gpu_util)}%`);
    assert.equal(v.busy, false); // idle fixture
});

test("panelValue: gpu_mem is a percentage of total", () => {
    const v = panelValue(live, "gpu_mem");
    const pct = Math.round((live.hardware.gpu_mem_used / live.hardware.gpu_mem_total) * 100);
    assert.equal(v.text, `${pct}%`);
});

test("panelValue: state maps to a short label", () => {
    const m = structuredClone(live);
    m.live.state = "idle";
    assert.equal(panelValue(m, "state").text, "idle");
    assert.equal(panelValue(m, "state").busy, false);
});

test("panelValue: unknown metric falls back to tok_s behaviour", () => {
    const v = panelValue(live, "nonsense");
    assert.equal(v.text, "–");
});

test("PANEL_METRICS matches the config schema ids", () => {
    const xml = readFileSync(path.join(HERE, "../contents/config/main.xml"), "utf8");
    for (const id of PANEL_METRICS)
        assert.ok(xml.includes(id), `main.xml should mention ${id}`);
});

/* ---------- state / busy ---------- */

test("isBusy only for reading and generating", () => {
    assert.equal(isBusy({ state: "reading" }), true);
    assert.equal(isBusy({ state: "generating" }), true);
    assert.equal(isBusy({ state: "idle" }), false);
    assert.equal(isBusy({ state: "loading" }), false);
});

test("stateLabel covers the known states", () => {
    assert.equal(stateLabel("reading"), "read");
    assert.equal(stateLabel("generating"), "gen");
    assert.equal(stateLabel("idle"), "idle");
    assert.equal(stateLabel(""), "–");
});

/* ---------- shapeSummary ---------- */

test("shapeSummary on the live fixture", () => {
    const s = shapeSummary(live);
    assert.equal(s.model, live.engine.model);
    assert.equal(s.state, live.live.state);
    assert.equal(s.gpuName, live.hardware_static.gpu_name);
    assert.equal(s.gpuMemUsedMiB, Math.round(live.hardware.gpu_mem_used / 1048576));
    assert.equal(s.ramTotalGiB, Math.round(live.hardware.ram_total / 1073741824));
    assert.equal(s.requests.length, 10); // capped
    assert.equal(s.cacheParked, live.conversation_cache.parked);
    assert.ok(s.cacheHitRate > 0.9 && s.cacheHitRate < 1);
    assert.equal(s.totalRequests, live.totals.requests);
    assert.equal(s.lastReused, live.requests[0].reused);
});

test("shapeSummary tolerates missing optional sections", () => {
    const minimal = {
        engine: { model: "m", max_context: 1 },
        live: { state: "idle" },
        hardware: { gpu_util: 0, gpu_mem_used: 0, gpu_mem_total: 1, cpu: 0 },
        totals: {},
    };
    const s = shapeSummary(minimal);
    assert.equal(s.gpuName, "GPU");
    assert.equal(s.cacheHitRate, null);
    assert.deepEqual(s.requests, []);
    assert.deepEqual(s.history.gpu_util, []);
});

/* ---------- shapeRequest ---------- */

test("shapeRequest computes draft accept rate", () => {
    const r = shapeRequest({
        time: 1, finish: "stop", prompt_tokens: 100, reused: 90,
        output_tokens: 10, duration_s: 2, decode_tok_s: 5,
        hit_rate: 0.9, drafts_offered: 20, drafts_accepted: 15,
    });
    assert.equal(r.acceptRate, 0.75);
    assert.equal(r.hitRate, 0.9);
});

test("shapeRequest tolerates missing drafts", () => {
    const r = shapeRequest({ time: 1, finish: "length" });
    assert.equal(r.acceptRate, null);
    assert.equal(r.promptTokens, 0);
});

/* ---------- history / sparklines ---------- */

test("shapeHistory keeps only drawn series and normalises nulls", () => {
    const h = shapeHistory({
        gpu_util: [1, null, 3],
        gpu_power: [10, 20],
        tok_s: [],
        cpu: [5, 6],
        ram_used: [1, 2, 3], // not drawn
    });
    assert.deepEqual(h.gpu_util, [1, null, 3]);
    assert.deepEqual(h.cpu, [5, 6]);
    assert.equal(h.ram_used, undefined);
});

test("sparkPoints scales to the box", () => {
    const pts = sparkPoints([0, 50, 100], 100, 10, 100);
    assert.equal(pts.length, 3);
    assert.equal(pts[0].x, 0);
    assert.equal(pts[2].x, 100);
    assert.equal(pts[0].y, 10);   // 0 -> bottom
    assert.equal(pts[2].y, 0);    // max -> top
});

test("sparkPoints auto-scales when max is omitted", () => {
    const pts = sparkPoints([0, 200], 10, 5);
    assert.equal(pts[1].y, 0);
});

test("sparkPoints handles degenerate input", () => {
    assert.deepEqual(sparkPoints([], 10, 10), []);
    assert.deepEqual(sparkPoints([1], 10, 10), []);
    assert.deepEqual(sparkPoints([1, 2], 0, 10), []);
});

test("sparkPoints on the live fixture history", () => {
    const pts = sparkPoints(live.history.gpu_util, 120, 28, 100);
    assert.equal(pts.length, live.history.gpu_util.length);
    for (const p of pts) {
        assert.ok(p.x >= 0 && p.x <= 120);
        assert.ok(p.y >= 0 && p.y <= 28);
    }
});
