package states;

import backend.MusicBeatState;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;

class GameplayRecorderState extends MusicBeatState
{
    override function create():Void
    {
        var bg = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
        bg.setGraphicSize(FlxG.width, FlxG.height);
        bg.updateHitbox();
        add(bg);
        add(new FlxSprite().makeGraphic(FlxG.width, FlxG.height, 0xD9080B14));
        var title = new FlxText(0, 120, FlxG.width, 'GAMEPLAY RECORDER');
        title.setFormat(Paths.font('vcr.ttf'), 32, FlxColor.WHITE, CENTER);
        add(title);
        var info = new FlxText(100, 230, FlxG.width - 200, 'Recorder workspace placeholder\n\nThis state will record gameplay input and export a JSON timeline.');
        info.setFormat(Paths.font('vcr.ttf'), 20, FlxColor.WHITE, CENTER);
        add(info);
        super.create();
    }

    override function update(elapsed:Float):Void
    {
        super.update(elapsed);
        if (controls.BACK) MusicBeatState.switchState(new RenderWorkspaceState(true));
    }
}
