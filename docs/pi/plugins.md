# Display plugins

Operators install plugins as folders under `WADDLE_DISPLAY_PLUGINS_DIR` (default `/opt/waddle-view/plugins/<id>/`), each containing `manifest.json` and an optional sidecar.

Authors use [`packages/waddle_plugin_sdk`](../packages/waddle_plugin_sdk) and copy [`packages/waddle_plugin_example`](../packages/waddle_plugin_example).

## Capabilities

| Capability | Mechanism |
|------------|-----------|
| Integration | `plugin_http` collector calls sidecar `POST /collect` |
| Runtime signal | `PUT /v1/runtime/signals/<id>` |
| Ticker | `ticker_type: plugin` or KV `ticker.marquee.<plugin_id>` |
| Screen | `screen_type: plugin_template` |
| Overlay | `plugin_template` / `plugin_web` celebration overlays; alerts via `POST /v1/alerts` |

Restart the display after adding or removing plugin folders (v1).
