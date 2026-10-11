#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
#
# Build a distributable .plasmoid (a zip with metadata.json at its root).
set -euo pipefail

ID="com.github.oal.strata"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$ROOT/dist/$ID.plasmoid"

"$ROOT/tools/build-translations.sh" || echo "==> translations skipped"

mkdir -p "$ROOT/dist"
rm -f "$OUT"

cd "$ROOT"
zip -r -q "$OUT" metadata.json contents \
    -x "*.po" "*.pot" "*/.*"

echo "==> $OUT"
unzip -l "$OUT" | tail -n 1
