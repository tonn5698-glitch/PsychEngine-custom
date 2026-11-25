package states;

import backend.MusicBeatState;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;

class RenderSettingsState extends MusicBeatState
{
    /** Keeps the cursor row when returning from the resolution picker. */
    public static var lastSelected:Int = 0;

    static inline var ROW_RESOLUTION:Int = 0;
    static inline var ROW_FPS:Int = 1;
    static inline var ROW_WORKERS:Int = 2;
    static inline var ROW_GAMEPLAY:Int = 3;
    static inline var ROW_SHOW_FPS:Int = 4;

    /** Hold-to-repeat timing for LEFT/RIGHT on numeric rows. */
    static inline var REPEAT_DELAY:Float = 0.4;
    static inline var REPEAT_INTERVAL:Float = 0.05;

    var selected:Int = 0;
    var rows:Array<FlxText> = [];
    var values:Array<FlxText> = [];
    var description:FlxText;
    var holdDir:Int = 0;
    var holdTime:Float = 0;
    var repeatTime:Float = 0;

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
        addRow('Export threads (PNG)', 246);

        addText(80, 300, 'GAMEPLAY', 18, 0xFF9B8CFF, true, 500);
        addRow('Use Gameplay file', 338);
        addRow('Show FPS overlay', 386);

        description = addText(80, 450, '', 15, 0xFFADB8D0, false, FlxG.width - 160);
        addText(0, FlxG.height - 48, 'UP / DOWN SELECT     LEFT / RIGHT CHANGE     ENTER OPEN / TOGGLE     ESC BACK', 12, 0xFFE1E7F5, true, FlxG.width, CENTER);

        RenderStudioSettings.syncEngineSize();
        RenderStudioSettings.resolutionPreset = RenderStudioSettings.compatiblePreset(RenderStudioSettings.resolutionPreset);
        selected = lastSelected;
        updateValues();
        addTouchPad('LEFT_FULL', 'A_B');
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

    function clampInt(value:Int, min:Int, max:Int):Int
    {
        if (value < min) return min;
        if (value > max) return max;
        return value;
    }

    function updateValues():Void
    {
        lastSelected = selected;
        var preset = RenderStudioSettings.RESOLUTIONS[RenderStudioSettings.clampPreset(RenderStudioSettings.resolutionPreset)];
        values[ROW_RESOLUTION].text = preset.label + '   ' + preset.width + ' x ' + preset.height + (RenderStudioSettings.isLocked(RenderStudioSettings.resolutionPreset) ? '   (locked)' : '');
        values[ROW_FPS].text = Std.string(RenderStudioSettings.frameRate) + ' FPS';
        values[ROW_WORKERS].text = Std.string(RenderStudioSettings.exportWorkers) + (RenderStudioSettings.exportWorkers == 1 ? ' thread' : ' threads');
        values[ROW_GAMEPLAY].text = RenderStudioSettings.useGameplayFile ? '[✓] ENABLED' : '[ ] DISABLED';
        values[ROW_SHOW_FPS].text = RenderStudioSettings.showFPS ? '[✓] ENABLED' : '[ ] DISABLED';

        for (i in 0...rows.length)
        {
            rows[i].alpha = i == selected ? 1 : 0.62;
            values[i].alpha = i == selected ? 1 : 0.62;
            rows[i].color = i == selected ? 0xFFFFFFFF : 0xFFADB8D0;
        }

        description.text = switch (selected)
        {
            case 0: 'ENTER opens the full list (720p to 4K). LEFT / RIGHT steps through it.';
            case 1: 'Output frame rate, 24 to 120. Hold LEFT / RIGHT to scroll faster.';
            case 2: 'Background threads that resize and encode PNG frames. More threads use more RAM.';
            case 3: 'Use a saved Gameplay Recorder input stream. Selected: ' + (RenderStudioSettings.selectedGameplayFile.length > 0 ? RenderStudioSettings.selectedGameplayFile.substr(RenderStudioSettings.selectedGameplayFile.lastIndexOf('/') + 1) : '(none selected)');
            default: 'Draw an FPS and OS-version overlay into the rendered output.';
        };
    }

    function setFps(value:Int):Void
    {
        RenderStudioSettings.frameRate = clampInt(value, RenderStudioSettings.FPS_MIN, RenderStudioSettings.FPS_MAX);
    }

    function setWorkers(value:Int):Void
    {
        RenderStudioSettings.exportWorkers = clampInt(value, RenderStudioSettings.WORKERS_MIN, RenderStudioSettings.WORKERS_MAX);
    }

    function openResolutionPicker():Void
    {
        var labels:Array<String> = [];
        for (i in 0...RenderStudioSettings.RESOLUTIONS.length)
        {
            var r = RenderStudioSettings.RESOLUTIONS[i];
            labels.push(r.label + '   ' + r.width + ' x ' + r.height + (RenderStudioSettings.isLocked(i) ? '   (locked)' : ''));
        }
        var current = RenderStudioSettings.clampPreset(RenderStudioSettings.resolutionPreset);
        MusicBeatState.switchState(new RenderPickerState('OUTPUT RESOLUTION', labels, current, function(idx:Int)
        {
            if (!RenderStudioSettings.isLocked(idx)) RenderStudioSettings.resolutionPreset = RenderStudioSettings.clampPreset(idx);
        }));
    }

    function changeValue(dir:Int):Void
    {
        switch (selected)
        {
            case 0:
                var len = RenderStudioSettings.RESOLUTIONS.length;
                var idx = RenderStudioSettings.clampPreset(RenderStudioSettings.resolutionPreset);
                for (_ in 0...len)
                {
                    idx = (idx + dir + len) % len;
                    if (!RenderStudioSettings.isLocked(idx)) break;
                }
                RenderStudioSettings.resolutionPreset = idx;
            case 1: setFps(RenderStudioSettings.frameRate + dir);
            case 2: setWorkers(RenderStudioSettings.exportWorkers + dir);
            case 3: RenderStudioSettings.useGameplayFile = !RenderStudioSettings.useGameplayFile;
            case 4: RenderStudioSettings.showFPS = !RenderStudioSettings.showFPS;
        }
        updateValues();
    }

    function isHoldRow():Bool
    {
        return selected == ROW_FPS || selected == ROW_WORKERS;
    }

    /** LEFT / RIGHT: one step on press, then repeats after a short delay while held. */
    function updateHold(elapsed:Float):Void
    {
        if (!isHoldRow())
        {
            holdDir = 0;
            return;
        }

        if (controls.UI_LEFT_P || controls.UI_RIGHT_P)
        {
            var dir = controls.UI_LEFT_P ? -1 : 1;
            holdDir = dir;
            holdTime = 0;
            repeatTime = 0;
            changeValue(dir);
            return;
        }

        var held = controls.UI_LEFT ? -1 : (controls.UI_RIGHT ? 1 : 0);
        if (held == 0 || held != holdDir)
        {
            holdDir = held;
            holdTime = 0;
            repeatTime = 0;
            return;
        }

        holdTime += elapsed;
        if (holdTime < REPEAT_DELAY) return;

        repeatTime += elapsed;
        while (repeatTime >= REPEAT_INTERVAL)
        {
            repeatTime -= REPEAT_INTERVAL;
            changeValue(held);
        }
    }

    override function update(elapsed:Float):Void
    {
        super.update(elapsed);
        if (controls.UI_UP_P) { selected = (selected + rows.length - 1) % rows.length; updateValues(); }
        if (controls.UI_DOWN_P) { selected = (selected + 1) % rows.length; updateValues(); }

        if (controls.ACCEPT)
        {
            if (selected == ROW_RESOLUTION) openResolutionPicker();
            else changeValue(1);
            return;
        }

        if (isHoldRow())
            updateHold(elapsed);
        else
        {
            if (controls.UI_LEFT_P) changeValue(-1);
            if (controls.UI_RIGHT_P) changeValue(1);
        }

        if (controls.BACK) MusicBeatState.switchState(new RenderWorkspaceState(false));
    }
}
