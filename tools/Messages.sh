#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
#
# Extract translatable strings. Follows the KDE convention of a Messages.sh per
# module, but is runnable by hand from the repo root:
#
#     ./tools/Messages.sh
#     msgmerge --update po/nb.po po/plasma_applet_com.github.oal.strata.pot
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOMAIN="plasma_applet_com.github.oal.strata"
POT="$ROOT/po/$DOMAIN.pot"

cd "$ROOT"
mkdir -p po

# ki18n's keyword set: i18n, i18nc (1st arg is context), i18np (plural),
# i18ncp (context + plural).
xgettext \
    --from-code=UTF-8 \
    --language=JavaScript \
    --keyword=i18n:1 \
    --keyword=i18nc:1c,2 \
    --keyword=i18np:1,2 \
    --keyword=i18ncp:1c,2,3 \
    --package-name="Strata stats" \
    --copyright-holder="oal" \
    --msgid-bugs-address="https://github.com/oal/strata-kde/issues" \
    -o "$POT" \
    $(find contents -name '*.qml' -o -name '*.mjs' | sort)

echo "==> $POT"
