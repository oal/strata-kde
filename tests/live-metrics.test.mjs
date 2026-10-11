// SPDX-License-Identifier: MPL-2.0
//
// Contract test against a live Strata engine. Catches schema drift that no
// fixture can: when the engine renames or drops a field the widget breaks,
// and this is the test that says so. Probes reachability at module load and
// skips itself when the engine is down, so the suite passes offline.

import { test } from "node:test";
import assert from "node:assert/strict";

import { parseMetrics, shapeSummary } from "../contents/code/metrics.mjs";

const URL = process.env.STRATA_METRICS_URL || "http://127.0.0.1:8080/metrics";

let payload = null;
try {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), 3000);
    const res = await fetch(URL, { signal: controller.signal });
    clearTimeout(timer);
    if (res.ok)
        payload = await res.json();
} catch {
    // engine down — the suite skips below
}

test("live /metrics parses and shapes", { skip: payload === null }, () => {
    const r = parseMetrics(payload);
    assert.equal(r.ok, true, r.error);
    const s = shapeSummary(r.metrics);
    assert.ok(s.model.length > 0);
    assert.equal(typeof s.gpuUtil, "number");
    assert.ok(Array.isArray(s.requests));
});
