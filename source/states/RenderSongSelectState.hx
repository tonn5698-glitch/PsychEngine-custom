package states;

import backend.MusicBeatState;
import backend.WeekData;
import backend.Mods;
import backend.Song;
import backend.Highscore;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;

private typedef RenderSongEntry =
{
    var name:String;
    var folder:String;
    var week:Int;
}

class RenderSongSelectState extends MusicBeatState
{
    var songs:Array<RenderSongEntry> = [];
    var selected:Int = 0;
    var title:FlxText;
    var details:FlxText;
    var help:FlxText;
    var status:FlxText;

    override function create():Void
    {
        var bg = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
        bg.color = 0xFF555D78;
        bg.setGraphicSize(FlxG.width, FlxG.height);
        bg.updateHitbox();
        add(bg);
        add(new FlxSprite().makeGraphic(FlxG.width, FlxG.height, 0xD9080B14));

        title = new FlxText(0, 70, FlxG.width, 'SELECT SONG TO RENDER');
        title.setFormat(Paths.font('vcr.ttf'), 30, FlxColor.WHITE, CENTER);
        add(title);

        details = new FlxText(100, 190, FlxG.width - 200, '', 23);
        details.setFormat(Paths.font('vcr.ttf'), 23, FlxColor.WHITE, CENTER);
        add(details);

        status = new FlxText(80, 330, FlxG.width - 160, '', 16);
        status.setFormat(Paths.font('vcr.ttf'), 16, 0xFF74E0BC, CENTER);
        add(status);

        help = new FlxText(0, FlxG.height - 54, FlxG.width, 'UP / DOWN SELECT     ENTER CREATE SESSION     ESC BACK');
        help.setFormat(Paths.font('vcr.ttf'), 13, FlxColor.WHITE, CENTER);
        add(help);

        collectSongs();
        refresh();
        super.create();
    }

    function collectSongs():Void
    {
        songs = [];
        WeekData.reloadWeekFiles(false);
        for (i in 0...WeekData.weeksList.length)
        {
            var weekName = WeekData.weeksList[i];
            var week:WeekData = WeekData.weeksLoaded.get(weekName);
            if (week == null || week.songs == null) continue;
            if (!week.startUnlocked && week.weekBefore.length > 0 && (!StoryMenuState.weekCompleted.exists(week.weekBefore) || !StoryMenuState.weekCompleted.get(week.weekBefore))) continue;
            WeekData.setDirectoryFromWeek(week);
            for (song in week.songs)
            {
                if (song == null || song.length < 2 || song[0] == null) continue;
                var folder = Mods.currentModDirectory == null ? '' : Mods.currentModDirectory;
                var exists = false;
                for (entry in songs)
                    if (entry.folder == folder && Paths.formatToSongPath(entry.name) == Paths.formatToSongPath(song[0])) { exists = true; break; }
                if (!exists)
                    songs.push({name: song[0], folder: folder, week: i});
            }
        }
        WeekData.setDirectoryFromWeek();
        songs.sort(function(a, b) return Reflect.compare(a.name.toLowerCase(), b.name.toLowerCase()));
    }

    function refresh():Void
    {
        if (songs.length == 0)
        {
            details.text = 'No songs were found in the loaded weeks.';
            status.text = 'Check that at least one week and song chart are installed.';
            return;
        }
        selected = (selected + songs.length) % songs.length;
        var entry = songs[selected];
        details.text = '< ' + entry.name + ' >\n\n' + (selected + 1) + ' / ' + songs.length;
        status.text = 'ENTER loads the chart and creates an isolated RenderSession.\nOutput: renders/' + Paths.formatToSongPath(entry.name) + '/';
    }

    function createSession():Void
    {
        if (songs.length == 0) return;
        var entry = songs[selected];
        Mods.currentModDirectory = entry.folder;
        var songLower = Paths.formatToSongPath(entry.name);
        try
        {
            var chart = Song.loadFromJson(Highscore.formatSong(songLower, 0), songLower);
            if (chart == null) throw 'Chart loader returned null';
            PlayState.SONG = chart;
            PlayState.isStoryMode = false;
            RenderSession.active = new RenderSession(songLower, entry.folder);
            var bpmText = Std.string(chart.bpm);
            status.text = 'SESSION CREATED  |  ' + songLower + '  |  BPM ' + bpmText
                + '  |  ' + RenderSession.active.outputWidth + 'x' + RenderSession.active.outputHeight
                + ' @ ' + RenderSession.active.frameRate + ' FPS';
            details.text = 'Opening render gameplay...\n' + entry.name
                + '\n\nChart sections: ' + chart.notes.length
                + '\nOutput folder: ' + RenderSession.active.outputDirectory
                + '\nAudio playback: DISABLED';
            LoadingState.loadAndSwitchState(new PlayState(), true);
        }
        catch (e:Dynamic)
        {
            status.text = 'Could not load chart: ' + Std.string(e);
        }
    }

    override function update(elapsed:Float):Void
    {
        super.update(elapsed);
        if (controls.UI_UP_P && songs.length > 0) { selected = (selected + songs.length - 1) % songs.length; refresh(); }
        if (controls.UI_DOWN_P && songs.length > 0) { selected = (selected + 1) % songs.length; refresh(); }
        if (controls.ACCEPT) createSession();
        if (controls.BACK) { RenderSession.active = null; MusicBeatState.switchState(new RenderWorkspaceState(false)); }
    }
}
