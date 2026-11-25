package states;

/** Render Studio preferences; never writes to ClientPrefs. */
class RenderStudioSettings
{
    public static var resolutionPreset:Int = 0;
    public static var frameRate:Int = 60;
    /** Number of background threads that resize and encode PNG frames. */
    public static var exportWorkers:Int = 3;
    public static var useGameplayFile:Bool = false;
    public static var showFPS:Bool = false;
    public static var selectedGameplayFile:String = '';
    public static var preferredSong:String = '';
    public static var preferredFolder:String = '';
    public static var preferredDifficulty:Int = 0;
    public static var hasPreferredSong:Bool = false;

    public static inline var FPS_MIN:Int = 24;
    public static inline var FPS_MAX:Int = 120;
    public static inline var WORKERS_MIN:Int = 1;
    public static inline var WORKERS_MAX:Int = 4;

    public static var RESOLUTIONS:Array<{label:String, width:Int, height:Int}> = [
        {label: '720p', width: 1280, height: 720},
        {label: '900p', width: 1600, height: 900},
        {label: '1080p', width: 1920, height: 1080},
        {label: '1440p', width: 2560, height: 1440},
        {label: '4K (2160p)', width: 3840, height: 2160},
        {label: 'Mobile', width: 1600, height: 720}
    ];

    public static inline var MOBILE_INDEX:Int = 5;

    /** Engine logical size is expanded when Wide Screen / mobile scale is active (height stays 720). */
    static function engineExpanded():Bool
    {
        return backend.GameSize.baseW != 1280 || backend.GameSize.baseH != 720;
    }

    /** Keeps the Mobile preset equal to the engine's expanded size so it is never squeezed. */
    public static function syncEngineSize():Void
    {
        var bw = backend.GameSize.baseW;
        var bh = backend.GameSize.baseH;
        if (bh == 720 && bw > 1280)
        {
            RESOLUTIONS[MOBILE_INDEX].width = bw;
            RESOLUTIONS[MOBILE_INDEX].height = bh;
        }
    }

    /** 1280x720 is locked while the engine runs expanded, since its frame would be squeezed into it. */
    public static function isLocked(index:Int):Bool
    {
        var r = RESOLUTIONS[clampPreset(index)];
        return engineExpanded() && r.width == 1280 && r.height == 720;
    }

    /** Returns the preset itself if allowed, otherwise the engine-size preset, otherwise the first allowed one. */
    public static function compatiblePreset(index:Int):Int
    {
        var i = clampPreset(index);
        if (!isLocked(i)) return i;
        for (j in 0...RESOLUTIONS.length)
            if (!isLocked(j) && RESOLUTIONS[j].width == backend.GameSize.baseW && RESOLUTIONS[j].height == backend.GameSize.baseH) return j;
        for (j in 0...RESOLUTIONS.length)
            if (!isLocked(j)) return j;
        return i;
    }

    public static function clampPreset(index:Int):Int
    {
        if (index < 0) return 0;
        if (index >= RESOLUTIONS.length) return RESOLUTIONS.length - 1;
        return index;
    }

    public static function getWidth():Int return RESOLUTIONS[clampPreset(resolutionPreset)].width;

    public static function getHeight():Int return RESOLUTIONS[clampPreset(resolutionPreset)].height;
}
