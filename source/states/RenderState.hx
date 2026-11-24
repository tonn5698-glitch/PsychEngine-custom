package states;

import backend.MusicBeatState;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;

/** Render Studio entry screen. Each workspace opens its own dedicated state. */
class RenderState extends MusicBeatState
{
    var selected:Int = 0;
    var entries:Array<FlxText> = [];

    override function create():Void
    {
        var bg = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
        bg.color = 0xFF58627D;
        bg.setGraphicSize(FlxG.width, FlxG.height);
        bg.updateHitbox();
        add(bg);
        add(new FlxSprite().makeGraphic(FlxG.width, FlxG.height, 0xD9080B14));

        var title = new FlxText(0, 85, FlxG.width, 'RENDER STUDIO');
        title.setFormat(Paths.font('vcr.ttf'), 36, FlxColor.WHITE, CENTER);
        add(title);
        var subtitle = new FlxText(0, 135, FlxG.width, 'Choose a workspace');
        subtitle.setFormat(Paths.font('vcr.ttf'), 17, 0xFFB8C4DD, CENTER);
        add(subtitle);

        var render = new FlxText(0, 260, FlxG.width, 'Rendering Mode');
        render.setFormat(Paths.font('vcr.ttf'), 28, FlxColor.WHITE, CENTER);
        add(render); entries.push(render);

        var recorder = new FlxText(0, 350, FlxG.width, 'Gameplay Recorder');
        recorder.setFormat(Paths.font('vcr.ttf'), 28, FlxColor.WHITE, CENTER);
        add(recorder); entries.push(recorder);

        var hint = new FlxText(0, FlxG.height - 58, FlxG.width, 'UP / DOWN SELECT     ENTER OPEN     ESC BACK');
        hint.setFormat(Paths.font('vcr.ttf'), 14, 0xFFDCE4F5, CENTER);
        add(hint);
        refresh();
        super.create();
    }

    function refresh():Void
    {
        for (i in 0...entries.length)
        {
            entries[i].alpha = i == selected ? 1 : 0.55;
            entries[i].scale.set(i == selected ? 1.08 : 1, i == selected ? 1.08 : 1);
            entries[i].updateHitbox();
        }
    }

    override function update(elapsed:Float):Void
    {
        super.update(elapsed);
        if (controls.UI_UP_P) { selected = (selected + 1) % 2; refresh(); }
        if (controls.UI_DOWN_P) { selected = (selected + 1) % 2; refresh(); }
        if (controls.ACCEPT) MusicBeatState.switchState(new RenderWorkspaceState(selected == 1));
        if (controls.BACK) MusicBeatState.switchState(new MainMenuState());
    }
}
