#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
# Report host-side prerequisites without changing the user's installation.
set -u

missing=0
for command in kpackagetool6; do
    if command -v "$command" >/dev/null 2>&1; then
        printf 'ok      %s -> %s\n' "$command" "$(command -v "$command")"
    else
        printf 'missing %s\n' "$command"
        missing=1
    fi
done

for command in plasmawindowed qmllint node; do
    if command -v "$command" >/dev/null 2>&1; then
        printf 'ok      %s -> %s\n' "$command" "$(command -v "$command")"
    else
        printf 'optional %s (only needed for testing and linting)\n' "$command"
    fi
done

# The Strata engine itself: the widget is useless without something serving
# /metrics, but it may legitimately be started later, so this is a warning.
url="${STRATA_METRICS_URL:-http://127.0.0.1:8080/metrics}"
if command -v curl >/dev/null 2>&1; then
    if curl -sf -m 3 -o /dev/null "$url"; then
        printf 'ok      engine -> %s\n' "$url"
    else
        printf 'warning engine not reachable at %s (the widget will show offline until it is)\n' "$url"
    fi
fi

if [[ "$missing" -ne 0 ]]; then
    printf '%s\n' 'The widget can be installed only after the missing host tools are available.' >&2
    exit 1
fi
