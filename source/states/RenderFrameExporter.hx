package states;

import flixel.FlxG;
import lime.app.Application;
import lime.graphics.Image;
import lime.math.Rectangle;
import sys.FileSystem;
import sys.io.File;

/**
 * Captures the final rendered game framebuffer and writes a PNG sequence.
 * Called after Flixel has rendered its cameras; writes synchronously so frames
 * cannot be dropped while storage is slower than the render loop.
 */
class RenderFrameExporter
{
    public static function writeCurrentStageFrame(session:RenderSession, frameIndex:Int):String
    {
        if (session == null) throw 'RenderFrameExporter requires an active session';
        if (frameIndex < 0) throw 'Frame index cannot be negative';

        var app = Application.current;
        if (app == null || app.window == null) throw 'Application window is not available';

        var gameSize = FlxG.scaleMode.gameSize;
        var offset = FlxG.scaleMode.offset;
        if (gameSize == null || gameSize.x <= 0 || gameSize.y <= 0)
            throw 'Game viewport dimensions are invalid';

        // readPixels returns the final composited framebuffer (all active cameras,
        // HUD and post-processing), matching the capture path used by JS Engine.
        var frame:Image = app.window.readPixels(new Rectangle(offset.x, offset.y, gameSize.x, gameSize.y));
        if (frame == null || frame.width <= 0 || frame.height <= 0)
            throw 'Framebuffer capture returned an empty image';

        ensureDirectory(session.outputDirectory);
        if (frame.width != session.outputWidth || frame.height != session.outputHeight)
            frame.resize(session.outputWidth, session.outputHeight);

        var bytes = frame.encode();
        if (bytes == null || bytes.length == 0) throw 'PNG encoding returned no data';

        var filename = 'frame_' + StringTools.lpad(Std.string(frameIndex), '0', 6) + '.png';
        var path = session.outputDirectory + filename;
        File.saveBytes(path, bytes);
        return path;
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
