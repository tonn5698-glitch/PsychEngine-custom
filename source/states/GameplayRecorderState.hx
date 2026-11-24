package states;

import backend.MusicBeatState;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;

/** Browse saved input recordings or launch a fresh gameplay recording. */
class GameplayRecorderState extends MusicBeatState
{
    var files:Array<String> = [];
    var selected:Int = 0;
    var title:FlxText;
    var detail:FlxText;
    var status:FlxText;

    override function create():Void
    {
        var bg = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
        bg.color = 0xFF398A80;
        bg.setGraphicSize(FlxG.width, FlxG.height);
        bg.updateHitbox();
        add(bg);
        add(new FlxSprite().makeGraphic(FlxG.width, FlxG.height, 0xD9080B14));

        title = new FlxText(0, 76, FlxG.width, 'GAMEPLAY RECORDER');
        title.setFormat(Paths.font('vcr.ttf'), 32, FlxColor.WHITE, CENTER);
        add(title);

        detail = new FlxText(80, 180, FlxG.width - 160, '', 19);
        detail.setFormat(Paths.font('vcr.ttf'), 19, FlxColor.WHITE, CENTER);
        add(detail);

        status = new FlxText(60, FlxG.height - 112, FlxG.width - 120, '', 14);
        status.setFormat(Paths.font('vcr.ttf'), 14, 0xFFB9DCCF, CENTER);
        add(status);

        refresh();
        super.create();
    }

    function refresh():Void
    {
        files = GameplayRecording.listRecordings();
        var count = files.length + 1;
        selected = (selected + count) % count;
        if (selected == 0)
            detail.text = '< RECORD NEW GAMEPLAY >\n\nChoose a song, play normally, and the lane inputs will be saved as a JSON replay.';
        else
        {
            var path = files[selected - 1];
            var name = path.substr(path.lastIndexOf('/') + 1);
            detail.text = '< ' + name + ' >\n\n' + selected + ' / ' + files.length
                + '\n\nENTER: Use this recording in Rendering Mode';
        }
        status.text = 'UP / DOWN SELECT   ENTER CONFIRM   ESC BACK';
    }

    override function update(elapsed:Float):Void
    {
        super.update(elapsed);
        if (controls.UI_UP_P) { selected = (selected + files.length) % (files.length + 1); refresh(); }
        if (controls.UI_DOWN_P) { selected = (selected + 1) % (files.length + 1); refresh(); }
        if (controls.ACCEPT)
        {
            if (selected == 0)
            {
                GameplayRecording.requestRecording = true;
                MusicBeatState.switchState(new RenderSongSelectState(true));
            }
            else
            {
                RenderStudioSettings.selectedGameplayFile = files[selected - 1];
                RenderStudioSettings.useGameplayFile = true;
                MusicBeatState.switchState(new RenderWorkspaceState(false));
            }
            return;
        }
        if (controls.BACK)
        {
            MusicBeatState.switchState(new RenderWorkspaceState(true));
            return;
        }
    }
}
