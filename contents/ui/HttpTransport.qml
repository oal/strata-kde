/* SPDX-License-Identifier: MPL-2.0 */

import QtQuick

/*
 * Raw HTTP transport for the Strata metrics client.
 *
 * Same shape as the other KDE widgets in this family: QML delivers
 * XMLHttpRequest callbacks only to handlers assigned from a QML context, so
 * the socket lives here and all parsing/shaping lives in code/metrics.mjs
 * where node can test it.
 *
 * get(url) returns {promise, abort()}:
 *   - resolves {status, text} for any completed response, 4xx/5xx included;
 *     deciding what counts as an error is the caller's job.
 *   - rejects with an Error carrying .kind === 'abort' when superseded, or
 *     .kind === 'network' when the connection failed or timed out.
 */
QtObject {
    id: transport

    /** QML's XMLHttpRequest has no timeout property, so we guard it ourselves. */
    property int timeoutMs: 5000

    property Component _timerComponent: Component {
        Timer { repeat: false }
    }

    function _fail(kind, message) {
        const e = new Error(message);
        e.kind = kind;
        return e;
    }

    function get(url) {
        const xhr = new XMLHttpRequest();
        let abortReason = null;        // null | 'superseded' | 'timeout'
        let settled = false;
        let timer = null;

        const promise = new Promise((resolve, reject) => {
            function stopTimer() {
                if (timer) {
                    timer.stop();
                    timer.destroy();
                    timer = null;
                }
            }
            function fail(e) {
                if (settled)
                    return;
                settled = true;
                stopTimer();
                reject(e);
            }
            function done(value) {
                if (settled)
                    return;
                settled = true;
                stopTimer();
                resolve(value);
            }

            xhr.onreadystatechange = function () {
                if (xhr.readyState !== 4 /* DONE */)
                    return;
                // abort() fires this synchronously, so check the reason first.
                if (abortReason === "timeout") {
                    fail(transport._fail("network", "request timed out"));
                    return;
                }
                if (abortReason === "superseded") {
                    fail(transport._fail("abort", "request superseded"));
                    return;
                }
                if (xhr.status === 0) {
                    fail(transport._fail("network", "network unreachable"));
                    return;
                }
                done({ status: xhr.status, text: xhr.responseText });
            };

            timer = _timerComponent.createObject(transport, { interval: transport.timeoutMs });
            timer.triggered.connect(function () {
                if (settled)
                    return;
                abortReason = "timeout";
                try {
                    xhr.abort();
                } catch (e) {
                    // already gone
                }
                fail(transport._fail("network", "request timed out"));
            });
            timer.start();

            try {
                xhr.open("GET", url);
                xhr.send();
            } catch (e) {
                fail(transport._fail("network", "could not send request: " + e));
            }
        });

        return {
            promise: promise,
            abort: function () {
                if (settled)
                    return;
                abortReason = "superseded";
                try {
                    xhr.abort();
                } catch (e) {
                    // already gone
                }
            },
        };
    }
}
