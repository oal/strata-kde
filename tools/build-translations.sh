#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
#
# Compile po/*.po into the contents/locale tree that KPackage installs.
# Silently does nothing when msgfmt is unavailable, so installing never hard-
# fails just because gettext is missing.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOMAIN="plasma_applet_com.github.oal.strata"

if ! command -v msgfmt >/dev/null 2>&1; then
    echo "==> msgfmt not found, skipping translation build" >&2
    exit 0
fi

shopt -s nullglob
for po in "$ROOT"/po/*.po; do
    lang="$(basename "$po" .po)"
    dest="$ROOT/contents/locale/$lang/LC_MESSAGES"
    mkdir -p "$dest"
    msgfmt "$po" -o "$dest/$DOMAIN.mo"
    echo "==> built $lang catalog"
done
