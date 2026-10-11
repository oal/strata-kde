#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
#
# Install (or upgrade) the plasmoid into the user's home. No sudo, no host
# packages — kpackagetool6 ships with Plasma.
set -euo pipefail

ID="com.github.oal.strata"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALLED="$HOME/.local/share/plasma/plasmoids/$ID"

usage() {
    cat <<USAGE
Usage: tools/install.sh [--upgrade|--remove|--restart]

  (no args)   Install if absent, upgrade if already installed.
  --upgrade   Force the upgrade path.
  --remove    Uninstall the widget.
  --restart   Also restart plasmashell (needed after metadata.json changes).
USAGE
}

restart_shell() {
    echo "==> restarting plasmashell"
    # Prefer the systemd unit; fall back to kquitapp/kstart for other setups.
    if systemctl --user --quiet is-active plasma-plasmashell.service 2>/dev/null; then
        systemctl --user restart plasma-plasmashell.service
    else
        kquitapp6 plasmashell 2>/dev/null || true
        sleep 2
        (setsid plasmashell >/dev/null 2>&1 &)
    fi
}

RESTART=0
ACTION="auto"
for arg in "$@"; do
    case "$arg" in
        --upgrade) ACTION="upgrade" ;;
        --remove)  ACTION="remove" ;;
        --restart) RESTART=1 ;;
        -h|--help) usage; exit 0 ;;
        *) echo "unknown option: $arg" >&2; usage; exit 1 ;;
    esac
done

"$ROOT/tools/build-translations.sh" || echo "==> translations skipped"

case "$ACTION" in
    remove)
        kpackagetool6 --type Plasma/Applet --remove "$ID"
        echo "==> removed $ID"
        exit 0
        ;;
    upgrade)
        kpackagetool6 --type Plasma/Applet --upgrade "$ROOT"
        ;;
    auto)
        if [[ -d "$INSTALLED" ]]; then
            kpackagetool6 --type Plasma/Applet --upgrade "$ROOT"
        else
            kpackagetool6 --type Plasma/Applet --install "$ROOT"
        fi
        ;;
esac

echo "==> installed to $INSTALLED"

if [[ "$RESTART" -eq 1 ]]; then
    restart_shell
else
    echo "==> add it from: right-click the panel -> Add Widgets -> \"Strata stats\""
    echo "    (after changing metadata.json, rerun with --restart)"
fi
