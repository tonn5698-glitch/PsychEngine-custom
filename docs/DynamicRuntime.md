# Dynamic Runtime (Android / Desktop)

The Dynamic Runtime loads selected HScript modules from writable external storage. It uses the existing `hscript-iris` interpreter; it does not invoke the Haxe compiler, hxcpp, Gradle, or rebuild the APK while the game is running.

## Runtime files

On Android, the runtime directory is:

```text
/sdcard/.PsychEngine/dynamic/
├── runtime.json
└── scripts/
    └── main.hx
```

The first launch creates the directory, a sample script, and this default configuration:

```json
{
  "enabled": true,
  "autoReload": true,
  "pollInterval": 0.5,
  "files": ["scripts/main.hx"]
}
```

Only relative `.hx` paths listed in `files` are loaded. Absolute paths, `.`, and `..` path segments are rejected. Edit `runtime.json` to select modules or disable the runtime. Configuration and script files are checked about twice per second by default.

## Script callbacks

A module may define any of these optional callbacks:

- `onCreate()` — after the module is loaded.
- `onUpdate(elapsed)` — each frame.
- `onStateEnter(state)` and `onStateExit(state)` — when the active Flixel state changes.
- `onDestroy()` — before the module is unloaded or replaced.

The current state is exposed as `game` and `state`. The runtime also exposes `DynamicRuntime`, `runtimeRoot`, `reloadDynamicScript(path)`, `reloadAllDynamicScripts()`, and `getDynamicScripts()`.

## Reload behavior and limits

With `autoReload: true`, changing a loaded file replaces that module at the next poll. A syntax/load failure leaves the previous loaded module active; a runtime callback error disables that module until it is reloaded. The file can also be reloaded from another HScript module using `reloadDynamicScript("scripts/main.hx")`.

This is an interpreted extension layer, not native Haxe hot-swapping. It can run compatible HScript code and call exposed engine APIs, but it cannot replace compiled native class definitions, change C++ code, or make every Haxe language feature available to the interpreter. Existing native objects are not transparently reconstructed when a script changes.
