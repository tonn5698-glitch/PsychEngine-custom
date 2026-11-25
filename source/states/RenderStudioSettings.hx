package states;

/** Render Studio preferences; never writes to ClientPrefs. */
class RenderStudioSettings
{
    // 0=720p, 1=1080p, 2=1440p, 3=mobile wide
    public static var resolutionPreset:Int = 0;
    public static var frameRate:Int = 60;
    public static var useGameplayFile:Bool = false;
    public static var showFPS:Bool = false;
    public static var selectedGameplayFile:String = '';
    public static var preferredSong:String = '';
    public static var preferredFolder:String = '';
    public static var preferredDifficulty:Int = 0;
    public static var hasPreferredSong:Bool = false;

    public static inline function getWidth():Int
    {
        return switch (resolutionPreset)
        {
            case 1: 1920;
            case 2: 2560;
            case 3: 1600;
            default: 1280;
        };
    }

    public static inline function getHeight():Int return resolutionPreset == 3 ? 720 : (resolutionPreset == 2 ? 1440 : (resolutionPreset == 1 ? 1080 : 720));
}
