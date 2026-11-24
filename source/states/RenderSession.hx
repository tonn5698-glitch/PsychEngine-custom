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
    public var frameIndex:Int = 0;
    public var totalFrames:Int = 0;
    public var timelinePositionUs:Int = 0;
    public var isRendering:Bool = false;
    public var audioEnabled:Bool = false;
    public var outputDirectory:String;

    public function new(song:String, mod:String = '')
    {
        songId = Paths.formatToSongPath(song);
        modDirectory = mod == null ? '' : mod;
        outputWidth = RenderStudioSettings.getWidth();
        outputHeight = RenderStudioSettings.getHeight();
        frameRate = RenderStudioSettings.frameRate;
        useGameplayFile = RenderStudioSettings.useGameplayFile;
        showFPS = RenderStudioSettings.showFPS;
        outputDirectory = 'renders/' + (modDirectory.length > 0 ? modDirectory + '/' : '') + songId + '/';
    }

    public function getFrameDurationUs():Int return Std.int(1000000 / frameRate);

    public function reset():Void
    {
        frameIndex = 0;
        timelinePositionUs = 0;
        isRendering = false;
        audioEnabled = false;
    }
}
