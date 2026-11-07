import backend.ui.PsychUICheckBox;

function onStateSwitch(stateName:String):Void
{
    if (stateName != "states.editors.CharacterEditorState")
        return;

    var state:Dynamic = FlxG.state;
    var moveCameraToggle:PsychUICheckBox = new PsychUICheckBox(10, 122, "Move Camera with D-Pad", 180);
    moveCameraToggle.checked = Reflect.field(state, "editorMoveCameraEnabled") == true;
    moveCameraToggle.onClick = function()
    {
        Reflect.setField(state, "editorMoveCameraEnabled", moveCameraToggle.checked);
        trace("[EditorExtensions] D-Pad camera movement: " + moveCameraToggle.checked);
    };

    if (!state.addEditorExtensionControl("Settings", moveCameraToggle))
        trace("[EditorExtensions] Failed to add Character Editor camera toggle.");
}
