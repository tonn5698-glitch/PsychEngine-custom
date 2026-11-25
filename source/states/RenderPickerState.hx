package states;

import backend.MusicBeatState;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;

/** Full-screen list picker for Render Studio options. ENTER confirms, ESC cancels. */
class RenderPickerState extends MusicBeatState
{
    var heading:String;
    var labels:Array<String>;
    var current:Int;
    var onPick:Int->Void;
    var cursor:Int;
    var lines:Array<FlxText> = [];

    public function new(heading:String, labels:Array<String>, current:Int, onPick:Int->Void)
    {
        super();
        this.heading = heading;
        this.labels = labels;
        this.current = current;
        this.onPick = onPick;
        cursor = current;
    }

    override function create():Void
    {
        add(new FlxSprite().makeGraphic(FlxG.width, FlxG.height, 0xF00A0D18));

        var title = new FlxText(0, 40, FlxG.width, heading, 30);
        title.setFormat(Paths.font('vcr.ttf'), 30, 0xFFFFFFFF, CENTER);
        add(title);

        for (i in 0...labels.length)
        {
            var line = new FlxText(0, 120 + i * 44, FlxG.width, '', 22);
            line.setFormat(Paths.font('vcr.ttf'), 22, 0xFFFFFFFF, CENTER);
            add(line);
            lines.push(line);
        }

        var help = new FlxText(0, FlxG.height - 48, FlxG.width, 'UP / DOWN CHOOSE     ENTER CONFIRM     ESC CANCEL', 12);
        help.setFormat(Paths.font('vcr.ttf'), 12, 0xFFE1E7F5, CENTER);
        add(help);

        refresh();
        addTouchPad('UP_DOWN', 'A_B');
        super.create();
    }

    function refresh():Void
    {
        for (i in 0...lines.length)
        {
            lines[i].text = labels[i] + (i == current ? '   (current)' : '');
            lines[i].color = i == cursor ? 0xFFFFE066 : 0xFFFFFFFF;
        }
    }

    function close():Void
    {
        MusicBeatState.switchState(new RenderSettingsState());
    }

    override function update(elapsed:Float):Void
    {
        super.update(elapsed);
        if (labels.length == 0)
        {
            if (controls.BACK) close();
            return;
        }
        if (controls.UI_UP_P) { cursor = (cursor + labels.length - 1) % labels.length; refresh(); }
        if (controls.UI_DOWN_P) { cursor = (cursor + 1) % labels.length; refresh(); }
        if (controls.ACCEPT)
        {
            onPick(cursor);
            close();
            return;
        }
        if (controls.BACK) close();
    }
}
