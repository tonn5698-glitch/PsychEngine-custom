package funkin.backend.assets;

/**
 * Shim cho namespace Codename Engine: delegate sang backend.Paths (Psych fork).
 * Chỉ expose các hàm mà các state CNE cần. Bổ sung dần khi cần.
 */
class Paths
{
	inline public static function image(key:String, ?parentFolder:String = null, ?allowGPU:Bool = true):flixel.graphics.FlxGraphic
		return backend.Paths.image(key, parentFolder, allowGPU);

	inline public static function getSparrowAtlas(key:String):flixel.graphics.frames.FlxAtlasFrames
		return backend.Paths.getSparrowAtlas(key);

	inline public static function music(key:String, ?modsAllowed:Bool = true):openfl.media.Sound
		return backend.Paths.music(key, modsAllowed);

	inline public static function inst(song:String, ?modsAllowed:Bool = true):openfl.media.Sound
		return backend.Paths.inst(song, modsAllowed);

	inline public static function sound(key:String, ?modsAllowed:Bool = true):openfl.media.Sound
		return backend.Paths.sound(key, modsAllowed);

	inline public static function formatToSongPath(song:String):String
		return backend.Paths.formatToSongPath(song);
}
