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
    var recordingMode:Bool = false;

    // Resume prompt: shown when the output folder already holds frames for this song.
    var promptOpen:Bool = false;
    var promptCanContinue:Bool = false;
    var promptResume:Bool = true;
    var promptFrames:Int = 0;
    var promptNote:String = '';

    public function new(recording:Bool = false)
    {
        super();
        recordingMode = recording;
    }

    override function create():Void
    {
        var bg = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
        bg.color = 0xFF555D78;
        bg.setGraphicSize(FlxG.width, FlxG.height);
        bg.updateHitbox();
        add(bg);
        add(new FlxSprite().makeGraphic(FlxG.width, FlxG.height, 0xD9080B14));

        title = new FlxText(0, 70, FlxG.width, recordingMode ? 'SELECT SONG TO RECORD' : 'SELECT SONG TO RENDER');
        title.setFormat(Paths.font('vcr.ttf'), 30, FlxColor.WHITE, CENTER);
        add(title);

        details = new FlxText(100, 190, FlxG.width - 200, '', 23);
        details.setFormat(Paths.font('vcr.ttf'), 23, FlxColor.WHITE, CENTER);
        add(details);

        status = new FlxText(80, 330, FlxG.width - 160, '', 16);
        status.setFormat(Paths.font('vcr.ttf'), 16, 0xFF74E0BC, CENTER);
        add(status);

        help = new FlxText(0, FlxG.height - 54, FlxG.width, 'UP / DOWN SELECT     ENTER ' + (recordingMode ? 'START RECORDING' : 'START RENDER') + '     ESC BACK');
        help.setFormat(Paths.font('vcr.ttf'), 13, FlxColor.WHITE, CENTER);
        add(help);

        collectSongs();
        refresh();
        addTouchPad('LEFT_FULL', 'A_B');
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
        if (RenderStudioSettings.hasPreferredSong)
        {
            for (i in 0...songs.length)
            {
                if (songs[i].folder == RenderStudioSettings.preferredFolder
                    && Paths.formatToSongPath(songs[i].name) == Paths.formatToSongPath(RenderStudioSettings.preferredSong))
                {
                    selected = i;
                    break;
                }
            }
        }
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
        status.text = recordingMode ? 'ENTER starts a normal gameplay session and records lane input.' : 'ENTER loads the chart and creates an isolated RenderSession.\nOutput: .PsychEngine/output/' + Paths.formatToSongPath(entry.name) + '/';
    }

    /** Loads the chart for an entry and assigns it to PlayState. Returns the chart. */
    function loadChart(entry:RenderSongEntry, songLower:String):Dynamic
    {
        PlayState.storyWeek = entry.week;
        Difficulty.loadFromWeek();
        var renderDifficulty:Int = RenderStudioSettings.hasPreferredSong ? RenderStudioSettings.preferredDifficulty : 0;
        if (Difficulty.list.length > 0)
            renderDifficulty = Std.int(Math.max(0, Math.min(renderDifficulty, Difficulty.list.length - 1)));
        else renderDifficulty = 0;
        var chart = Song.loadFromJson(Highscore.formatSong(songLower, renderDifficulty), songLower);
        if (chart == null) throw 'Chart loader returned null';
        RenderStudioSettings.hasPreferredSong = false;
        PlayState.SONG = chart;
        PlayState.isStoryMode = false;
        return chart;
    }

    function createSession():Void
    {
        if (songs.length == 0) return;
        var entry = songs[selected];
        Mods.currentModDirectory = entry.folder;
        var songLower = Paths.formatToSongPath(entry.name);
        try
        {
            if (recordingMode)
            {
                loadChart(entry, songLower);
                RenderSession.active = null;
                GameplayRecording.clearReplay();
                GameplayRecording.requestRecording = true;
                details.text = 'Recording gameplay...\n' + entry.name;
                status.text = 'Input recording will start when the song begins.\nPress ESC in gameplay to leave.';
                LoadingState.loadAndSwitchState(new PlayState(), true);
                return;
            }

            RenderSession.active = new RenderSession(songLower, entry.folder);
            if (RenderSession.active.useGameplayFile)
                GameplayRecording.loadReplay(RenderStudioSettings.selectedGameplayFile, songLower, entry.folder);
            else GameplayRecording.clearReplay();

            var existingFrames = RenderFrameExporter.countResumableFrames(RenderSession.active.outputDirectory);
            if (existingFrames > 0)
            {
                openResumePrompt(existingFrames);
                return;
            }
            startRender();
        }
        catch (e:Dynamic)
        {
            RenderSession.active = null;
            GameplayRecording.clearReplay();
            status.text = 'Could not load chart: ' + Std.string(e);
        }
    }

    /** Opens the Continue / New render choice. Continue is only offered when the render can be reproduced. */
    function openResumePrompt(frames:Int):Void
    {
        var session = RenderSession.active;
        var mismatch = RenderFrameExporter.checkResumeConfig(session);
        promptFrames = frames;
        promptCanContinue = mismatch == null && session.useGameplayFile;
        promptResume = promptCanContinue;
        if (mismatch != null)
            promptNote = 'Không tiếp tục được, cấu hình đã đổi: ' + mismatch;
        else if (!session.useGameplayFile)
            promptNote = 'Bài này không dùng Gameplay file nên không thể tiếp tục.';
        else promptNote = '';
        promptOpen = true;
        showPrompt();
    }

    function showPrompt():Void
    {
        var resumeLabel = 'TIẾP TỤC từ frame ' + promptFrames;
        var newLabel = 'RENDER MỚI (thư mục khác)';
        var choice:String;
        if (!promptCanContinue) choice = '[ ' + newLabel + ' ]';
        else if (promptResume) choice = '[ ' + resumeLabel + ' ]   ' + newLabel;
        else choice = resumeLabel + '   [ ' + newLabel + ' ]';
        details.text = 'Đã có ' + promptFrames + ' frame cho bài này.\n\n' + choice;
        var keys = promptCanContinue ? 'LEFT / RIGHT đổi     ENTER xác nhận     ESC hủy' : 'ENTER xác nhận     ESC hủy';
        status.text = (promptNote.length > 0 ? promptNote + '\n' : '') + keys;
    }

    function confirmPrompt():Void
    {
        var session = RenderSession.active;
        if (session == null)
        {
            promptOpen = false;
            return;
        }
        if (promptCanContinue && promptResume)
            session.startFrame = promptFrames;
        else
            session.useFreshFolder();
        startRender();
    }

    function cancelPrompt():Void
    {
        promptOpen = false;
        RenderSession.active = null;
        GameplayRecording.clearReplay();
        refresh();
    }

    /** Loads the chart for the selected song and switches to PlayState in render mode. */
    function startRender():Void
    {
        var entry = songs[selected];
        var songLower = Paths.formatToSongPath(entry.name);
        try
        {
            var chart:Dynamic = loadChart(entry, songLower);
            var session = RenderSession.active;
            var bpmText = Std.string(chart.bpm);
            status.text = 'SESSION CREATED  |  ' + songLower + '  |  BPM ' + bpmText
                + '  |  ' + session.outputWidth + 'x' + session.outputHeight
                + ' @ ' + session.frameRate + ' FPS'
                + (session.startFrame > 0 ? '  |  CONTINUE from frame ' + session.startFrame : '');
            details.text = 'Opening render gameplay...\n' + entry.name
                + '\n\nChart sections: ' + chart.notes.length
                + '\nOutput folder: ' + session.outputDirectory
                + '\nAudio playback: DISABLED';
            promptOpen = false;
            LoadingState.loadAndSwitchState(new PlayState(), true);
        }
        catch (e:Dynamic)
        {
            promptOpen = false;
            RenderSession.active = null;
            GameplayRecording.clearReplay();
            status.text = 'Could not start render: ' + Std.string(e);
        }
    }

    override function update(elapsed:Float):Void
    {
        super.update(elapsed);
        if (promptOpen)
        {
            if (promptCanContinue && (controls.UI_LEFT_P || controls.UI_RIGHT_P))
            {
                promptResume = !promptResume;
                showPrompt();
            }
            if (controls.ACCEPT) confirmPrompt();
            else if (controls.BACK) cancelPrompt();
            return;
        }
        if (controls.UI_UP_P && songs.length > 0) { selected = (selected + songs.length - 1) % songs.length; refresh(); }
        if (controls.UI_DOWN_P && songs.length > 0) { selected = (selected + 1) % songs.length; refresh(); }
        if (controls.ACCEPT) createSession();
        if (controls.BACK) { RenderSession.active = null; if (recordingMode) GameplayRecording.requestRecording = false; if (recordingMode) MusicBeatState.switchState(new GameplayRecorderState()); else MusicBeatState.switchState(new RenderWorkspaceState(false)); }
    }
}
