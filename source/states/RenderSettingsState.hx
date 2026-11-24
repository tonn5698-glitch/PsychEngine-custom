package states;

import backend.MusicBeatState;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;

class RenderSettingsState extends MusicBeatState
{
    static var resolutions:Array<String> = ["1280 x 720", "1920 x 1080", "2560 x 1440", "1600 x 720 (Mobile)"];
    static var frameRates:Array<Int> = [24, 30, 60, 120];

    var selected:Int = 0;
    var rows:Array<FlxText> = [];
    var values:Array<FlxText> = [];
    var description:FlxText;

    override function create():Void
    {
        var bg = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
        bg.color = 0xFF59627A;
        bg.setGraphicSize(FlxG.width, FlxG.height);
        bg.updateHitbox();
        add(bg);
        add(new FlxSprite().makeGraphic(FlxG.width, FlxG.height, 0xD90A0D18));

        addText(64, 28, 'RENDER SETTINGS', 32, 0xFFFFFFFF, true, FlxG.width - 128);
        addText(66, 70, 'Render Studio preferences — independent from ClientPrefs.', 14, 0xFFADB8D0, false, FlxG.width - 132);

        addText(80, 112, 'QUALITY OUTPUT', 18, 0xFF9B8CFF, true, 500);
        addRow('Resolution', 150);
        addRow('Frame Rate (FPS)', 198);

        addText(80, 270, 'GAMEPLAY', 18, 0xFF9B8CFF, true, 500);
        addRow('Use Gameplay file', 308);
        addRow('Show FPS overlay', 356);

        description = addText(80, 430, '', 15, 0xFFADB8D0, false, FlxG.width - 160);
        addText(0, FlxG.height - 48, 'UP / DOWN SELECT     LEFT / RIGHT CHANGE     ENTER TOGGLE     ESC BACK', 12, 0xFFE1E7F5, true, FlxG.width, CENTER);
        updateValues();
        super.create();
    }

    function addRow(label:String, y:Float):Void
    {
        rows.push(addText(80, y, label, 20, 0xFFFFFFFF, false, 500));
        values.push(addText(650, y, '', 20, 0xFF74E0BC, true, FlxG.width - 700));
    }

    function addText(x:Float, y:Float, text:String, size:Int, color:Int, bold:Bool, width:Float, align:Dynamic = LEFT):FlxText
    {
        var t = new FlxText(x, y, width, text, size);
        t.setFormat(Paths.font('vcr.ttf'), size, color, align);
        t.antialiasing = ClientPrefs.data.antialiasing;
        add(t);
        return t;
    }

    function updateValues():Void
    {
        values[0].text = resolutions[RenderStudioSettings.resolutionPreset];
        values[1].text = Std.string(RenderStudioSettings.frameRate) + ' FPS';
        values[2].text = RenderStudioSettings.useGameplayFile ? '[✓] ENABLED' : '[ ] DISABLED';
        values[3].text = RenderStudioSettings.showFPS ? '[✓] ENABLED' : '[ ] DISABLED';
        for (i in 0...rows.length)
        {
            rows[i].alpha = i == selected ? 1 : 0.62;
            values[i].alpha = i == selected ? 1 : 0.62;
            rows[i].color = i == selected ? 0xFFFFFFFF : 0xFFADB8D0;
        }
        description.text = switch (selected)
        {
            case 0: 'Choose output dimensions: 720p, Full HD, QHD or the 1600×720 mobile canvas.';
            case 1: 'Output frame rate. Every frame is scheduled from the song timeline; frames must not be skipped.';
            case 2: 'Use a saved Gameplay Recorder input stream. Selected: ' + (RenderStudioSettings.selectedGameplayFile.length > 0 ? RenderStudioSettings.selectedGameplayFile.substr(RenderStudioSettings.selectedGameplayFile.lastIndexOf('/') + 1) : '(none selected)');
            default: 'Draw an FPS and OS-version overlay into the rendered output.';
        };
    }

    function changeValue(dir:Int):Void
    {
        switch (selected)
        {
            case 0:
                RenderStudioSettings.resolutionPreset = (RenderStudioSettings.resolutionPreset + (dir >= 0 ? 1 : resolutions.length - 1)) % resolutions.length;
            case 1:
                var idx = frameRates.indexOf(RenderStudioSettings.frameRate);
                if (idx < 0) idx = 2;
                idx = (idx + (dir >= 0 ? 1 : frameRates.length - 1)) % frameRates.length;
                RenderStudioSettings.frameRate = frameRates[idx];
            case 2: RenderStudioSettings.useGameplayFile = !RenderStudioSettings.useGameplayFile;
            case 3: RenderStudioSettings.showFPS = !RenderStudioSettings.showFPS;
        }
        updateValues();
    }

    override function update(elapsed:Float):Void
    {
        super.update(elapsed);
        if (controls.UI_UP_P) { selected = (selected + rows.length - 1) % rows.length; updateValues(); }
        if (controls.UI_DOWN_P) { selected = (selected + 1) % rows.length; updateValues(); }
        if (controls.UI_LEFT_P) changeValue(-1);
        if (controls.UI_RIGHT_P || controls.ACCEPT) changeValue(1);
        if (controls.BACK) MusicBeatState.switchState(new RenderWorkspaceState(false));
    }
}
