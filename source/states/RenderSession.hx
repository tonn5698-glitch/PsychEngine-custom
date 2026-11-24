package states;

/** Mutable render state is isolated per selected song. */
class RenderSession
{
    public static var active:RenderSession = null;
    public var songId:String;
    public var modDirectory:String;
    public var outputWidth:Int;
    public var outputHeight:Int;
    public var frameRate:Int;
    public var useGameplayFile:Bool;
    public var showFPS:Bool;
    /** Number of frames already advanced. */
    public var frameIndex:Int = 0;
    /** Total output frames; zero means duration has not been configured. */
    public var totalFrames:Int = 0;
    /** Original chart/instrumental duration in milliseconds. */
    public var durationMs:Float = 0;
    /** Timestamp of the most recently advanced frame, in microseconds. */
    public var timelinePositionUs:Int = 0;
    public var isRendering:Bool = false;
    public var completed:Bool = false;
    public var failed:Bool = false;
    public var errorMessage:String = '';
    public var audioEnabled:Bool = false;
    public var outputDirectory:String;

    public function new(song:String, mod:String = '')
    {
        songId = Paths.formatToSongPath(song);
        modDirectory = mod == null ? '' : mod;
        outputWidth = RenderStudioSettings.getWidth();
        outputHeight = RenderStudioSettings.getHeight();
        frameRate = RenderStudioSettings.frameRate;
        if (frameRate < 1) frameRate = 60;
        useGameplayFile = RenderStudioSettings.useGameplayFile;
        showFPS = RenderStudioSettings.showFPS;
        var outputRoot:String = #if android mobile.backend.StorageUtil.getExternalStorageDirectory() + 'output/' #elseif sys Sys.getCwd() + '.PsychEngine/output/' #else 'output/' #end;
        outputDirectory = outputRoot + songId + '/';
    }

    /** Calculates the exact timestamp for a frame without accumulating rounding drift. */
    public function getFrameTimestampUs(index:Int):Int
    {
        if (index <= 0) return 0;
        return Std.int(index * 1000000.0 / frameRate);
    }

    /** Frame duration is derived from adjacent timestamps to avoid fractional-FPS drift. */
    public function getFrameDurationUs(?index:Int = -1):Int
    {
        var current:Int = index < 0 ? frameIndex : index;
        return getFrameTimestampUs(current + 1) - getFrameTimestampUs(current);
    }

    public function configureDurationMs(durationMs:Float):Void
    {
        var safeDuration:Float = Math.max(0, durationMs);
        this.durationMs = safeDuration;
        totalFrames = Std.int(Math.ceil(safeDuration * frameRate / 1000.0));
        reset();
    }

    /** Moves the cursor to the next frame after the current frame has been exported. */
    public function advanceFrame():Bool
    {
        if (totalFrames <= 0 || frameIndex >= totalFrames) return false;
        frameIndex++;
        if (frameIndex >= totalFrames)
        {
            completed = true;
            isRendering = false;
            return false;
        }
        timelinePositionUs = getFrameTimestampUs(frameIndex);
        return true;
    }

    public function getProgress():Float
    {
        if (totalFrames <= 0) return 0;
        return Math.min(1, frameIndex / totalFrames);
    }

    public function reset():Void
    {
        frameIndex = 0;
        timelinePositionUs = 0;
        isRendering = false;
        completed = false;
        failed = false;
        errorMessage = '';
        audioEnabled = false;
    }
}
