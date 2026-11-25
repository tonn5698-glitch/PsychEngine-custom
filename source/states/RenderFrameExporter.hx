package states;

import flixel.FlxG;
import lime.app.Application;
import lime.graphics.Image;
import lime.math.Rectangle;
import sys.FileSystem;
import sys.io.File;
import sys.io.FileSeek;
import sys.thread.Deque;
import sys.thread.Mutex;
import sys.thread.Thread;

private typedef FrameJob =
{
    var img:Image;
    var path:String;
    var width:Int;
    var height:Int;
}

/**
 * Captures the final framebuffer on the main thread, then resizes, encodes and writes
 * PNG frames on a worker pool. Every frame has its own file name, so write order does
 * not matter. The main thread only blocks when too many frames are waiting.
 */
class RenderFrameExporter
{
    static var queue:Deque<FrameJob> = null;
    static var workers:Array<Thread> = [];
    static var lock:Mutex = new Mutex();
    static var pending:Int = 0;
    static var maxPending:Int = 6;
    static var workerError:String = null;
    static var directoryReady:String = null;

    public static function writeCurrentStageFrame(session:RenderSession, frameIndex:Int):String
    {
        if (session == null) throw 'RenderFrameExporter requires an active session';
        if (frameIndex < 0) throw 'Frame index cannot be negative';
        if (workerError != null) throw 'PNG writer failed: ' + workerError;

        var app = Application.current;
        if (app == null || app.window == null) throw 'Application window is not available';

        var gameSize = FlxG.scaleMode.gameSize;
        var offset = FlxG.scaleMode.offset;
        if (gameSize == null || gameSize.x <= 0 || gameSize.y <= 0)
            throw 'Game viewport dimensions are invalid';

        // Main thread: GPU readback of the composited framebuffer, the only step that needs GL.
        var frame:Image = app.window.readPixels(new Rectangle(offset.x, offset.y, gameSize.x, gameSize.y));
        if (frame == null || frame.width <= 0 || frame.height <= 0)
            throw 'Framebuffer capture returned an empty image';

        if (directoryReady != session.outputDirectory)
        {
            ensureDirectory(session.outputDirectory);
            directoryReady = session.outputDirectory;
        }

        startWorkers(session.exportWorkers);
        waitForSlot();

        var path = session.outputDirectory + 'frame_' + StringTools.lpad(Std.string(frameIndex), '0', 6) + '.png';
        lock.acquire();
        pending++;
        lock.release();
        queue.add({img: frame, path: path, width: session.outputWidth, height: session.outputHeight});
        return path;
    }

    /** Blocks until every queued PNG is on disk. Throws if any write failed. */
    public static function flush():Void
    {
        while (true)
        {
            lock.acquire();
            var busy = pending;
            lock.release();
            if (busy == 0) break;
            Sys.sleep(0.005);
        }
        if (workerError != null) throw 'PNG writer failed: ' + workerError;
    }

    static function startWorkers(count:Int):Void
    {
        if (queue == null) queue = new Deque<FrameJob>();
        var target = count < 1 ? 1 : count;
        while (workers.length < target)
            workers.push(Thread.create(workerLoop));
        maxPending = target * 2;
    }

    static function workerLoop():Void
    {
        while (true)
        {
            var job:FrameJob = queue.pop(true);
            try
            {
                if (job.img.width != job.width || job.img.height != job.height)
                    job.img.resize(job.width, job.height);
                var bytes = job.img.encode();
                if (bytes == null || bytes.length == 0) throw 'PNG encoding returned no data';
                File.saveBytes(job.path, bytes);
            }
            catch (e:Dynamic)
            {
                workerError = job.path + ': ' + Std.string(e);
            }

            lock.acquire();
            pending--;
            lock.release();
        }
    }

    static function waitForSlot():Void
    {
        // Each waiting frame is a full uncompressed image, so the queue is capped.
        while (true)
        {
            lock.acquire();
            var busy = pending;
            lock.release();
            if (busy < maxPending) return;
            Sys.sleep(0.001);
        }
    }

    public static function writeOutputInfo(session:RenderSession, status:String):Void
    {
        if (session == null) throw 'Output metadata requires an active session';
        ensureDirectory(session.outputDirectory);
        var duration:String = Std.string(Math.round(session.durationMs * 1000) / 1000);
        var content = [
            'Song: ' + session.songId,
            'Mod directory: ' + (session.modDirectory == null || session.modDirectory.length == 0 ? '(base game)' : session.modDirectory),
            'Resolution: ' + session.outputWidth + 'x' + session.outputHeight,
            'Frame rate: ' + session.frameRate + ' FPS',
            'Export threads: ' + session.exportWorkers,
            'Frame count: ' + session.totalFrames,
            'Frames exported: ' + session.frameIndex,
            'Duration: ' + duration + ' ms',
            'Gameplay file input: ' + (session.useGameplayFile ? 'enabled' : 'disabled'),
            'Gameplay recording: ' + (session.useGameplayFile ? RenderStudioSettings.selectedGameplayFile : '(none)'),
            'FPS and OS overlay: ' + (session.showFPS ? 'enabled' : 'disabled'),
            'Output format: PNG image sequence',
            'Frame pattern: frame_000000.png',
            'Status: ' + status
        ].join('\n') + '\n';
        File.saveContent(session.outputDirectory + 'output-info.txt', content);
    }

    static var PNG_SIGNATURE:Array<Int> = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
    static var PNG_IEND_TAIL:Array<Int> = [0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82];

    /** A PNG is usable only if it has the signature and ends with the IEND chunk (not cut off by a kill). */
    static function isCompletePng(path:String):Bool
    {
        if (!FileSystem.exists(path) || FileSystem.isDirectory(path)) return false;
        var size = FileSystem.stat(path).size;
        if (size < 32) return false;
        var input = File.read(path, true);
        var valid = false;
        try
        {
            var head = input.read(8);
            var headOk = true;
            for (i in 0...8)
                if (head.get(i) != PNG_SIGNATURE[i]) headOk = false;
            input.seek(size - 8, FileSeek.SeekBegin);
            var tail = input.read(8);
            var tailOk = true;
            for (i in 0...8)
                if (tail.get(i) != PNG_IEND_TAIL[i]) tailOk = false;
            valid = headOk && tailOk;
        }
        catch (e:Dynamic)
        {
            valid = false;
        }
        input.close();
        return valid;
    }

    /** Counts consecutive complete frames from frame_000000 upward. */
    public static function countResumableFrames(dir:String):Int
    {
        var count = 0;
        while (isCompletePng(dir + 'frame_' + StringTools.lpad(Std.string(count), '0', 6) + '.png'))
            count++;
        return count;
    }

    /** Reads key: value lines from output-info.txt. */
    public static function readOutputInfo(dir:String):Map<String, String>
    {
        var map = new Map<String, String>();
        var path = dir + 'output-info.txt';
        if (!FileSystem.exists(path)) return map;
        for (line in File.getContent(path).split('\n'))
        {
            var idx = line.indexOf(': ');
            if (idx > 0) map.set(line.substr(0, idx), line.substr(idx + 2));
        }
        return map;
    }

    /** Returns null when the stored render settings match this session, otherwise the first mismatch. */
    public static function checkResumeConfig(session:RenderSession):String
    {
        var info = readOutputInfo(session.outputDirectory);
        if (!info.exists('Duration')) return 'không tìm thấy output-info.txt của lần render trước';
        var checks:Array<Array<String>> = [
            ['Song', session.songId],
            ['Mod directory', session.modDirectory == null || session.modDirectory.length == 0 ? '(base game)' : session.modDirectory],
            ['Resolution', session.outputWidth + 'x' + session.outputHeight],
            ['Frame rate', session.frameRate + ' FPS'],
            ['Gameplay recording', session.useGameplayFile ? RenderStudioSettings.selectedGameplayFile : '(none)'],
            ['FPS and OS overlay', session.showFPS ? 'enabled' : 'disabled']
        ];
        for (c in checks)
        {
            var stored = info.exists(c[0]) ? info.get(c[0]) : '(không có)';
            if (stored != c[1]) return c[0] + ': ' + stored + ' → ' + c[1];
        }
        return null;
    }

    /** Duration is only known once the song has loaded, so it is checked when rendering starts. */
    public static function checkResumeDuration(session:RenderSession):String
    {
        var info = readOutputInfo(session.outputDirectory);
        if (!info.exists('Duration')) return 'không tìm thấy output-info.txt của lần render trước';
        var expected = Std.string(Math.round(session.durationMs * 1000) / 1000) + ' ms';
        var stored = info.get('Duration');
        return stored == expected ? null : 'Duration: ' + stored + ' → ' + expected;
    }

    static function ensureDirectory(path:String):Void
    {
        if (path == null || path.length == 0) throw 'Output directory is empty';
        var current = path.startsWith('/') ? '/' : '';
        for (part in path.split('/'))
        {
            if (part.length == 0) continue;
            current = current == '/' ? current + part : (current.length == 0 ? part : current + '/' + part);
            if (!FileSystem.exists(current))
                FileSystem.createDirectory(current);
            else if (!FileSystem.isDirectory(current))
                throw 'Output path component is not a directory: ' + current;
        }
    }
}
