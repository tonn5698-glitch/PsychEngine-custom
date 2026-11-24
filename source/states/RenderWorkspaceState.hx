package states;

import backend.MusicBeatState;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;
import options.OptionsState;

class RenderWorkspaceState extends MusicBeatState
{
    public var recorder:Bool = false;
    var selected:Int = 0;
    var items:Array<FlxText> = [];
    var heading:FlxText;

    public function new(isRecorder:Bool = false)
    {
        super();
        recorder = isRecorder;
    }

    override function create():Void
    {
        var bg = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
        bg.color = recorder ? 0xFF398A80 : 0xFF6558A8;
        bg.setGraphicSize(FlxG.width, FlxG.height);
        bg.updateHitbox();
        add(bg);
        add(new FlxSprite().makeGraphic(FlxG.width, FlxG.height, 0xD9080B14));

        heading = new FlxText(0, 100, FlxG.width, recorder ? 'GAMEPLAY RECORDER' : 'RENDER STUDIO');
        heading.setFormat(Paths.font('vcr.ttf'), 34, FlxColor.WHITE, CENTER);
        add(heading);

        var first = new FlxText(0, 260, FlxG.width, 'Open settings');
        first.setFormat(Paths.font('vcr.ttf'), 27, FlxColor.WHITE, CENTER);
        add(first); items.push(first);

        var second = new FlxText(0, 340, FlxG.width, recorder ? 'Enter gameplay' : 'Enter render');
        second.setFormat(Paths.font('vcr.ttf'), 27, FlxColor.WHITE, CENTER);
        add(second); items.push(second);

        var hint = new FlxText(0, FlxG.height - 60, FlxG.width, 'UP / DOWN SELECT     ENTER OPEN     ESC BACK');
        hint.setFormat(Paths.font('vcr.ttf'), 14, 0xFFDCE4F5, CENTER);
        add(hint);
        refresh();
        super.create();
    }

    function refresh():Void
    {
        for (i in 0...items.length)
        {
            items[i].alpha = i == selected ? 1 : 0.55;
            items[i].scale.set(i == selected ? 1.08 : 1, i == selected ? 1.08 : 1);
            items[i].updateHitbox();
        }
    }

    override function update(elapsed:Float):Void
    {
        super.update(elapsed);
        if (controls.UI_UP_P) { selected = (selected + 1) % 2; refresh(); }
        if (controls.UI_DOWN_P) { selected = (selected + 1) % 2; refresh(); }
        if (controls.ACCEPT)
        {
            if (selected == 0)
            {
                if (recorder) MusicBeatState.switchState(new OptionsState());
                else MusicBeatState.switchState(new RenderSettingsState());
            }
            else
            {
                if (recorder) MusicBeatState.switchState(new GameplayRecorderState());
                else MusicBeatState.switchState(new RenderSongSelectState());
            }
        }
        if (controls.BACK) MusicBeatState.switchState(new RenderState());
    }
}
