# Editor Extensions

PsychEngine-Custom loads global HScript files from:

- Shared engine scripts: `assets/shared/customStates/global/*.hx`
- The active mod: `mods/<mod>/customStates/global/*.hx`
- Legacy active-mod entry points: `mods/<mod>/data/global.hx`

Global scripts can implement these callbacks:

- `onCreate()` — once when the global script system is initialized.
- `onStateSwitch(stateName:String)` — when a `MusicBeatState` is created; the argument is the fully qualified state class name.
- `onUpdate(elapsed:Float)` — every frame.

## Extending an editor

Use `onStateSwitch` to detect an editor, then add UI to its existing PsychUI tab. Use reflection for editor-specific fields so the extension does not need compile-time access to private UI members.

Example pattern:

```haxe
function onStateSwitch(stateName:String):Void
{
    if (stateName != "states.editors.CharacterEditorState") return;

    var state:Dynamic = FlxG.state;
    var toggle = new PsychUICheckBox(10, 122, "Example toggle", 180);
    state.addEditorExtensionControl("Settings", toggle);
}
```

Keep extensions isolated: check that the target state and UI tab exist, and avoid changing editor data unless the user activates the control.

## Locking or replacing an editor

A mod can register a state override from a global HScript using the existing `registerStateOverride(originalState, customState)` helper. For example, it can redirect `CharacterEditorState` to a mod-owned custom state that displays a locked message or provides a restricted editor. The replacement script belongs in the mod's configured state folder (default: `states/`) or the supported legacy `data/states/` folder.

State overrides apply to future state transitions. They do not retroactively replace an editor that is already open.

## Example extension included with the engine

`assets/shared/customStates/global/CharacterEditorCamera.hx` adds a Settings toggle to Character Editor. It writes to the small public bridge field `editorMoveCameraEnabled`; the editor handles D-pad movement and updates the character's `camera_position` values. The JSON is written only when the user saves the character.

The global loader and state-switch callback already exist in the engine, so extensions do not need a separate loader or per-feature engine rebuild. A new bridge field or hook is only needed when a feature requires behavior that the existing runtime API cannot expose.
