package states.editors;

import backend.WeekData;
import backend.Mods;
import backend.Song;
import backend.Highscore;
import backend.Difficulty;

class CameraEditorSongSelectState extends MusicBeatState
{
    var songs:Array<CameraSongInfo> = [];
    var items:FlxTypedGroup<Alphabet>;
    var title:FlxText;
    var info:FlxText;
    var diffText:FlxText;
    var cur:Int = 0;
    var diff:Int = 0;
    var selectingDifficulty:Bool = false;

    override function create()
    {
        if(Difficulty.list.length < 1) Difficulty.resetList();
        collectSongs();
        FlxG.camera.bgColor=FlxColor.BLACK;
        var bg=new FlxSprite().loadGraphic(Paths.image('menuDesat')); bg.color=0xFF303030; bg.scrollFactor.set(); add(bg);
        title=new FlxText(0,24,FlxG.width,'CAMERA EDITOR',28); title.setFormat(Paths.font('vcr.ttf'),28,FlxColor.WHITE,CENTER); add(title);
        info=new FlxText(0,62,FlxG.width,'Select a song',18); info.setFormat(Paths.font('vcr.ttf'),18,FlxColor.WHITE,CENTER); add(info);
        items=new FlxTypedGroup<Alphabet>(); add(items);
        diffText=new FlxText(0,FlxG.height-62,FlxG.width,'',18); diffText.setFormat(Paths.font('vcr.ttf'),18,FlxColor.WHITE,CENTER); add(diffText);
        rebuild(); updateTexts(); addTouchPad('UP_DOWN','A_B'); super.create();
    }

    function collectSongs()
    {
        songs=[];
        for(w in WeekData.weeksList)
        {
            var week=WeekData.weeksLoaded.get(w); if(week==null) continue;
            WeekData.setDirectoryFromWeek(week);
            for(song in week.songs)
            {
                if(song==null||song.length<1) continue;
                var name=Std.string(song[0]); var duplicate=false;
                for(existing in songs) if(existing.songName.toLowerCase()==name.toLowerCase() && existing.folder==Mods.currentModDirectory){duplicate=true;break;}
                if(!duplicate)
                {
                    var colors:Array<Int>=song.length>2?cast song[2]:null;
                    var color=colors!=null&&colors.length>=3?FlxColor.fromRGB(colors[0],colors[1],colors[2]):0xFF9271FD;
                    songs.push(new CameraSongInfo(name,w,song.length>1?Std.string(song[1]):'bf',color));
                }
            }
        }
        songs.sort(function(a,b)return a.songName.toLowerCase()<b.songName.toLowerCase()?-1:1);
    }

    function rebuild()
    {
        items.clear(); var start=Math.max(0,cur-5); var end=Math.min(songs.length,cur+6);
        for(i in start...end)
        {
            var t=new Alphabet(0,150+(i-start)*58,songs[i].songName,true);
            t.targetY=i-cur; t.isMenuItem=true; t.screenCenter(X); t.snapToPosition(); t.alpha=i==cur?1:0.45; items.add(t);
        }
    }

    function updateTexts()
    {
        if(songs.length==0){info.text='No songs were found in loaded weeks.';diffText.text='Press BACK';return;}
        if(selectingDifficulty){info.text=songs[cur].songName+'  —  Select Difficulty';diffText.text='Difficulty: '+Difficulty.getString(diff,false)+'    A/ENTER Select    B/BACK';}
        else{info.text='Select a song';diffText.text='A/ENTER Select    B/BACK';}
        rebuild();
    }

    override function update(elapsed:Float)
    {
        if(controls.BACK){if(selectingDifficulty){selectingDifficulty=false;updateTexts();}else MusicBeatState.switchState(new MasterEditorMenu());return;}
        if(!selectingDifficulty){if(controls.UI_UP_P)change(-1);if(controls.UI_DOWN_P)change(1);}
        else{if(controls.UI_UP_P)changeDiff(-1);if(controls.UI_DOWN_P)changeDiff(1);}
        if(controls.ACCEPT){if(!selectingDifficulty){if(songs.length>0){selectingDifficulty=true;diff=Math.max(0,Difficulty.defaultList.indexOf(Difficulty.getDefault()));updateTexts();}}else openEditor();}
        super.update(elapsed);
    }

    function change(delta:Int){if(songs.length==0)return;cur=FlxMath.wrap(cur+delta,0,songs.length-1);updateTexts();}
    function changeDiff(delta:Int){if(Difficulty.defaultList.length==0)return;diff=FlxMath.wrap(diff+delta,0,Difficulty.defaultList.length-1);diffText.text='Difficulty: '+Difficulty.getString(diff,false)+'    A/ENTER Select    B/BACK';}

    function openEditor()
    {
        if(songs.length==0)return;
        var md=songs[cur]; Mods.currentModDirectory=md.folder;
        var chartKey=Highscore.formatSong(md.songName.toLowerCase(),diff);
        try
        {
            Song.loadFromJson(chartKey,Paths.formatToSongPath(md.songName));
            if(PlayState.SONG==null)throw 'Chart returned null';
            CameraEditorState.lastDifficulty=Difficulty.getString(diff,false);
            LoadingState.loadAndSwitchState(new CameraEditorState(PlayState.SONG),false);
        }
        catch(e:Dynamic){diffText.text='Chart not found for '+Difficulty.getString(diff,false)+' — B to return';}
    }
}

class CameraSongInfo
{
    public var songName:String=''; public var week:Int=0; public var songCharacter:String=''; public var color:Int=0xFF9271FD; public var folder:String='';
    public function new(song:String,week:Int,char:String,color:Int){songName=song;this.week=week;songCharacter=char;this.color=color;folder=Mods.currentModDirectory;if(folder==null)folder='';}
}
