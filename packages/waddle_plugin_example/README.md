# waddle_demo reference plugin

Drop this folder under `WADDLE_DISPLAY_PLUGINS_DIR` (or `/opt/waddle-view/plugins/waddle_demo/`) and restart the display.

## Run sidecar locally

```bash
cd packages/waddle_plugin_example
export WADDLE_DISPLAY_BASE_URL=http://127.0.0.1:8787
export WADDLE_DISPLAY_API_KEY=<adopted-api-key>
dart run bin/sidecar.dart
```

Enable integration `plugin_waddle_demo` in the controller and set `collect_url` to `http://127.0.0.1:9876/collect`.
