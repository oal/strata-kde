# Strata stats — KDE Plasma widget

A Plasma 6 panel widget that shows live stats from your [Strata] local LLM
engine, straight from its `/metrics` endpoint: tokens per second, GPU
utilisation, memory, temperature, prompt-cache hits, and the most recent
requests.

## What it does

- **Panel readout** of one live metric — tok/s, GPU utilisation, GPU memory,
  or engine state — refreshed every 2 s by default. Bold while the engine is
  actually generating.
- **Click to expand** a popup with:
  - live engine state, phase, prompt progress bar, prompt/reused/generated
    token counts and elapsed time;
  - GPU and CPU rows with sparklines from the engine's own history series,
    plus temperature, power, VRAM and RAM;
  - conversation-cache parked slots and hit rate;
  - the ten most recent requests with hit rate, decode speed and duration.
- **Configurable** base URL (default `http://127.0.0.1:8080`) and poll
  interval, and which metric sits in the panel.
- Dims to 50 % when the engine is unreachable instead of leaving a hole in
  the panel; the popup footer shows the last error or the fetch age.
- Follows your desktop language: **English** and **Norwegian Bokmål**.

## Requirements

- **Plasma 6** (developed against 6.6, Wayland), Qt 6.
- `kpackagetool6`, which ships with Plasma. Nothing else — no build step, no
  compiler, no root.
- A Strata engine serving `/metrics` (the JSON endpoint, not Prometheus text).

## Install

```bash
./tools/install.sh
```

Then right-click your panel → **Add Widgets…** → **Strata stats**, and drag it
where you want it.

To upgrade after pulling changes, run the same script again. If you changed
`metadata.json`, rerun with `--restart` to bounce `plasmashell`.

## Development

See [`AGENTS.md`](AGENTS.md) for build, test, and lint commands.

## License

MPL-2.0.

[Strata]: https://github.com/Niko1221/Strata
