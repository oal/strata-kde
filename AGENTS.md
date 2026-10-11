# AGENTS.md — build & test commands

## Prerequisites

- **Plasma 6** with `kpackagetool6` and `plasmawindowed` (both ship with Plasma).
  These need the live desktop session; they cannot run in a container. If your
  shell is inside a distrobox/dev container, prefix them with
  `distrobox-host-exec`.
- **Node 18+** to run the test suite.
- Optionally `qmllint` (Qt 6 declarative dev tools) and `gettext` for
  translations.

## Repo layout

- `metadata.json` — KPackage manifest (`Plasma/Applet`, id `com.github.oal.strata`).
- `contents/code/` — pure ES modules; all logic, no Qt. Testable under node.
  - `metrics.mjs` — payload validation (`parseMetrics`), panel value selection
    (`panelValue`), popup shaping (`shapeSummary`, `shapeRequest`,
    `shapeHistory`), sparkline geometry (`sparkPoints`).
- `contents/ui/` — the widget.
  - `main.qml` — state, poll timer, error/offline handling.
  - `CompactRepresentation.qml` — panel glyph + chosen metric.
  - `FullRepresentation.qml` — the popup (live row, hardware sparklines,
    cache, recent requests).
  - `Sparkline.qml` — Shape-based mini chart fed from `summary.history`.
  - `HttpTransport.qml` — the HTTP socket (see the gotcha below).
  - `configGeneral.qml` — base URL, poll interval, panel metric.
- `contents/config/` — `main.xml` (KConfigXT) and `config.qml` (page list).
- `po/` — `nb.po` plus the `.pot`; compiled into `contents/locale/` at install.
- `tests/fixtures/metrics-live.json` — a real capture from a running engine.

## Gotcha: XHR callbacks in ES modules

QML delivers XMLHttpRequest callbacks only to handlers assigned from a QML
context; a handler assigned inside an `.mjs` module is silently never invoked.
That is why the socket lives in `HttpTransport.qml` and only parsing/shaping
live in `metrics.mjs`. Do not move XHR handling into the module.

## Install / run

```bash
./tools/check-environment.sh    # report host prerequisites, changes nothing
./tools/install.sh              # install or upgrade into ~/.local/share
./tools/install.sh --restart    # also restart plasmashell (metadata.json changes)
./tools/install.sh --remove
./tools/package.sh              # dist/com.github.oal.strata.plasmoid
```

`plasmashell` caches `metadata.json`, so a first install (or any manifest edit)
needs the shell restarted before the widget appears in "Add Widgets".

## Test

```bash
# Everything: pure logic + the live contract test (~22 assertions).
node --test tests/*.test.mjs

# Just the offline suite.
node --test tests/metrics.test.mjs
```

`tests/live-metrics.test.mjs` fetches `http://127.0.0.1:8080/metrics` (override
with `STRATA_METRICS_URL`) to catch schema drift no fixture can. It probes
reachability at module load and skips itself when the engine is down.

The fixture is a real capture; regenerate it with
`curl -s http://127.0.0.1:8080/metrics -o tests/fixtures/metrics-live.json`
when the engine's schema changes — and update `parseMetrics`/`shapeSummary`
in the same commit.

## Smoke-test the widget

```bash
plasmawindowed com.github.oal.strata    # QML errors print to stderr; clean = silent
```

Wayland windows are invisible to X11 screenshot tools, and the widget's
short-lived polls rarely show in `ss`. To prove it polls, count TIME_WAIT
sockets to port 8080 twice a few seconds apart:

```bash
pid=$(pgrep -x plasmawindowed)
awk '$3 ~ /:1F90$/ && $4=="06"' /proc/$pid/net/tcp | wc -l   # grows at 1/pollMs
```

## Lint the QML

```bash
qmllint contents/ui/*.qml
```

## Translations

```bash
./tools/Messages.sh                     # regenerate po/*.pot
msgmerge --update po/nb.po po/plasma_applet_com.github.oal.strata.pot
./tools/build-translations.sh           # msgfmt into contents/locale/ (skips if gettext is absent)
```
