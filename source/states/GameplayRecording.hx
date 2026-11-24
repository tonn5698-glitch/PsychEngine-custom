package states;

import haxe.Json;
import sys.FileSystem;
import sys.io.File;

/** Stores logical lane input as a timestamped, versioned replay stream. */
class GameplayRecording
{
    public static var requestRecording:Bool = false;
    public static var recording:Bool = false;
    public static var replaying:Bool = false;
    public static var lastSavedPath:String = '';

    static var recordingSong:String = '';
    static var recordingMod:String = '';
    static var recordEvents:Array<Dynamic> = [];
    static var recordHeld:Map<Int, Bool> = new Map<Int, Bool>();
    static var sequence:Int = 0;

    static var replayEvents:Array<Dynamic> = [];
    static var replayCursor:Int = 0;
    static var replayHeld:Map<Int, Bool> = new Map<Int, Bool>();
    static var replaySong:String = '';

    public static function recordingsDirectory():String
    {
        #if android
        return mobile.backend.StorageUtil.getExternalStorageDirectory() + 'recordings/';
        #elseif sys
        return Sys.getCwd() + '.PsychEngine/recordings/';
        #else
        return 'recordings/';
        #end
    }

    public static function listRecordings():Array<String>
    {
        var result:Array<String> = [];
        var dir = recordingsDirectory();
        if (!FileSystem.exists(dir)) return result;
        for (name in FileSystem.readDirectory(dir))
            if (name.toLowerCase().endsWith('.json') && !FileSystem.isDirectory(dir + name))
                result.push(dir + name);
        result.sort(Reflect.compare);
        return result;
    }

    public static function startRequested(song:String, mod:String):Void
    {
        if (!requestRecording) return;
        requestRecording = false;
        stopRecording();
        recordingSong = Paths.formatToSongPath(song);
        recordingMod = mod == null ? '' : mod;
        recordEvents = [];
        recordHeld = new Map<Int, Bool>();
        sequence = 0;
        recording = true;
    }

    public static function recordLane(timeMs:Float, lane:Int, down:Bool):Void
    {
        if (!recording || replaying || lane < 0) return;
        var wasDown = recordHeld.exists(lane) && recordHeld.get(lane);
        if (wasDown == down) return;
        recordHeld.set(lane, down);
        recordEvents.push({t: Math.max(0, timeMs), lane: lane, down: down, seq: sequence++});
    }

    public static function stopRecording():String
    {
        if (!recording) return lastSavedPath;
        recording = false;
        recordEvents.sort(function(a:Dynamic, b:Dynamic):Int {
            var timeCompare = Reflect.compare(a.t, b.t);
            return timeCompare != 0 ? timeCompare : Reflect.compare(a.seq, b.seq);
        });
        var dir = recordingsDirectory();
        ensureDirectory(dir);
        var filename = recordingSong + '_' + Std.string(Date.now().getTime()) + '.json';
        lastSavedPath = dir + filename;
        var payload = {
            schemaVersion: 1,
            song: recordingSong,
            modDirectory: recordingMod,
            createdAt: Date.now().toString(),
            eventCount: recordEvents.length,
            events: recordEvents
        };
        File.saveContent(lastSavedPath, Json.stringify(payload, '\t'));
        recordEvents = [];
        recordHeld = new Map<Int, Bool>();
        return lastSavedPath;
    }

    public static function loadReplay(path:String, expectedSong:String, expectedMod:String = ''):Void
    {
        clearReplay();
        if (path == null || path.length == 0) throw 'No gameplay recording selected';
        if (!FileSystem.exists(path) || FileSystem.isDirectory(path)) throw 'Gameplay recording file was not found: ' + path;
        var data:Dynamic = Json.parse(File.getContent(path));
        if (data == null || Reflect.field(data, 'schemaVersion') != 1)
            throw 'Unsupported gameplay recording format';
        var song = Std.string(Reflect.field(data, 'song'));
        if (Paths.formatToSongPath(song) != Paths.formatToSongPath(expectedSong))
            throw 'Selected recording belongs to a different song (' + song + ')';
        var recordedMod:String = Reflect.field(data, 'modDirectory') == null ? '' : Std.string(Reflect.field(data, 'modDirectory'));
        if (recordedMod != (expectedMod == null ? '' : expectedMod))
            throw 'Selected recording belongs to a different mod directory';
        var source:Dynamic = Reflect.field(data, 'events');
        if (!Std.isOfType(source, Array)) throw 'Recording has no input event list';
        replayEvents = cast source;
        replayEvents.sort(function(a:Dynamic, b:Dynamic):Int {
            var timeCompare = Reflect.compare(a.t, b.t);
            return timeCompare != 0 ? timeCompare : Reflect.compare(a.seq, b.seq);
        });
        replayCursor = 0;
        replayHeld = new Map<Int, Bool>();
        replaySong = song;
        replaying = true;
    }

    public static function pollReplay(timeMs:Float, press:Int->Void, release:Int->Void):Void
    {
        if (!replaying) return;
        while (replayCursor < replayEvents.length)
        {
            var event:Dynamic = replayEvents[replayCursor];
            if (event == null || event.t > timeMs) break;
            replayCursor++;
            var lane:Int = Std.int(event.lane);
            var down:Bool = event.down == true;
            var wasDown = replayHeld.exists(lane) && replayHeld.get(lane);
            if (lane < 0 || wasDown == down) continue;
            replayHeld.set(lane, down);
            if (down) press(lane); else release(lane);
        }
    }

    public static function isLaneHeld(lane:Int):Bool
        return replaying && replayHeld.exists(lane) && replayHeld.get(lane);

    public static function clearReplay():Void
    {
        replaying = false;
        replayEvents = [];
        replayCursor = 0;
        replayHeld = new Map<Int, Bool>();
        replaySong = '';
    }

    static function ensureDirectory(path:String):Void
    {
        var current = path.startsWith('/') ? '/' : '';
        for (part in path.split('/'))
        {
            if (part.length == 0) continue;
            current = current == '/' ? current + part : (current.length == 0 ? part : current + '/' + part);
            if (!FileSystem.exists(current)) FileSystem.createDirectory(current);
            else if (!FileSystem.isDirectory(current)) throw 'Recording path is not a directory: ' + current;
        }
    }
}
