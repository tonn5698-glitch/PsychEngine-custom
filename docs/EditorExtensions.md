# Editor Extensions

PsychEngine-Custom loads global HScript files from:

- Shared engine scripts: `assets/shared/customStates/global/*.hx`
- The active mod: `mods/<mod>/customStates/global/*.hx`
- Legacy active-mod entry points: `mods/<mod>/data/global.hx`

Global scripts can implement these callbacks:

- `onCreate()` — once when the global script system is initialized.
- `onStateSwitch(stateName:String)` — when a `MusicBeatState` is created; the argument is the fully qualified state class name.
- `onUpdate(elapsed:Float)` — every frame.
- `onEditorReady(state, data)` — after an Editor state has finished constructing its UI.
- `onEditorUpdate(state, elapsed)` — every frame while an Editor state is active.
- `onEditorSave(state, data)` — immediately before serialization in Character Editor and Stage Editor. The supplied data is the live character object, or a Stage payload containing `stage`, `sprites`, and `convertLua`.
- `onEditorEvent(state, event)` — custom editor event dispatched by `state.notifyEditorExtensionEvent(name, data)`; `event.event` is the event name and `event.data` is its payload.

## Shared Editor API

Every Editor derived from `backend.MusicBeatState` inherits these methods:

| Method | Purpose |
| --- | --- |
| `getEditorUIBox(boxField)` | Get a `PsychUIBox` by its field name, such as `UI_box`. |
| `addEditorExtensionTab(boxField, tabName)` | Add a new tab to an existing UI box. Returns `Bool`. |
| `addEditorExtensionControlTo(boxField, tabName, control)` | Add a Flixel/PsychUI control to an existing tab. Returns `Bool`. |
| `getEditorField(fieldName)` | Read an existing Editor field by name. |
| `setEditorField(fieldName, value, markDirty = true)` | Set an existing field; optionally mark the Editor as having unsaved changes. Returns `Bool`. |
| `markEditorDirty()` | Set the Editor's `unsavedProgress` flag when available. Returns `Bool`. |
| `notifyEditorExtensionEvent(name, data)` | Dispatch a custom `onEditorEvent` callback to global scripts. |
| `notifyEditorSave(data)` | Dispatch `onEditorSave` before serialization in supported Editors. |

`boxField` and `fieldName` are the actual Haxe field names. Check that a method returns `true` or a box/field is non-null before using it. Field access is intentionally generic for compatibility, so extensions should prefer stable editor-specific public fields and methods when available. Avoid replacing internal arrays or objects unless their expected structure is known.

## Example: add a custom tab to Character Editor

```haxe
function onEditorReady(state:Dynamic, data:Dynamic):Void
{
    var stateName = Type.getClassName(Type.getClass(state));
    if (stateName != "states.editors.CharacterEditorState") return;

    if (!state.addEditorExtensionTab("UI_box", "My Tools")) return;

    var label = new FlxText(10, 12, 180, "Added by a mod");
    var button = new PsychUIButton(10, 42, "Run", function()
    {
        state.notifyEditorExtensionEvent("myToolPressed", {source: "My Tools"});
    });
    state.addEditorExtensionControlTo("UI_box", "My Tools", label);
    state.addEditorExtensionControlTo("UI_box", "My Tools", button);
}

function onEditorEvent(state:Dynamic, event:Dynamic):Void
{
    if (event != null && event.event == "myToolPressed")
        trace("My editor tool was pressed");
}
```

## Existing Character Editor bridge

Character Editor keeps the original helper for compatibility:

```haxe
state.addEditorExtensionControl("Settings", control);
```

It also exposes `addStagePreviewLuaSprite(sprite, inFront)` and `editorMoveCameraEnabled` for its built-in camera extension. The camera extension remains in `assets/shared/customStates/global/CharacterEditorCamera.hx`.

## Locking or replacing an editor

A mod can register a state override from a global HScript using the existing `registerStateOverride(originalState, customState)` helper. The replacement script belongs in the mod's configured state folder (default: `states/`) or the supported legacy `data/states/` folder.

State overrides apply to future state transitions. They do not retroactively replace an Editor that is already open.

## Notes and limitations

- The shared UI and field APIs work with Editor states that expose their UI boxes as `PsychUIBox` fields.
- `onEditorReady` runs after the Editor's `create()` has built its UI, so extensions can safely add tabs and controls there.
- `onEditorUpdate` is observational; avoid expensive work every frame.
- `onEditorEvent` is a mod-dispatched event channel. `onEditorSave` is currently wired into Character Editor and Stage Editor; other Editors can add this hook as their save paths are standardized.
- These APIs extend the original Editor; they do not make every private implementation detail a stable public contract.
