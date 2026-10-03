package funkin.backend.assets;

import flixel.graphics.FlxGraphic;

/**
 * Shim: CNE Paths API → Psych Engine Paths.
 * CNE Paths trả String, Psych Paths trả FlxGraphic/Sound.
 * Shim này bridge 2 hệ thống.
 */
class Paths
{
	// ===== IMAGE =====
	public static function image(key:String, ?library:String, ?checkForAtlas:Bool = true, ?ext:String = 'png'):String
	{
		// CNE trả String path, Psych trả FlxGraphic
		// Dùng getPath để lấy path string
		return backend.Paths.getPath('images/$key.$ext', openfl.utils.AssetType.IMAGE, library);
	}

	// ===== SOUND / MUSIC =====
	public static function sound(key:String, ?library:String, ?ext:String = 'ogg'):String
	{
		return backend.Paths.getPath('sounds/$key.$ext', openfl.utils.AssetType.SOUND, library);
	}

	public static function music(key:String, ?library:String, ?ext:String = 'ogg'):String
	{
		return backend.Paths.getPath('music/$key.$ext', openfl.utils.AssetType.SOUND, library);
	}

	public static function voices(song:String, ?difficulty:String, ?suffix:String, ?ext:String = 'ogg'):String
	{
		var formatted:String = backend.Paths.formatToSongPath(song);
		return backend.Paths.getPath('songs/$formatted/Voices.$ext', openfl.utils.AssetType.SOUND);
	}

	public static function inst(song:String, ?difficulty:String, ?ext:String = 'ogg'):String
	{
		var formatted:String = backend.Paths.formatToSongPath(song);
		return backend.Paths.getPath('songs/$formatted/Inst.$ext', openfl.utils.AssetType.SOUND);
	}

	// ===== DATA =====
	public static function txt(key:String, ?library:String):String
		return backend.Paths.txt(key, library);

	public static function json(key:String, ?library:String):String
		return backend.Paths.json(key, library);

	public static function xml(key:String, ?library:String):String
		return backend.Paths.xml(key, library);

	// ===== CHART =====
	public static function chart(song:String, ?difficulty:String, ?variant:String):String
	{
		var formatted:String = backend.Paths.formatToSongPath(song);
		var diff:String = difficulty != null ? difficulty : 'hard';
		return backend.Paths.getPath('data/$formatted/$formatted.json', openfl.utils.AssetType.TEXT);
	}

	// ===== CHARACTER =====
	public static function character(character:String):String
	{
		return 'characters/$character';
	}

	// ===== SCRIPT =====
	public static function script(key:String, ?library:String, ?isAssetsPath:Bool = false):String
	{
		if (isAssetsPath) return key;
		return backend.Paths.getPath('$key.lua', openfl.utils.AssetType.TEXT, library);
	}

	// ===== FONT =====
	public static function font(key:String, ?library:String):String
		return backend.Paths.font(key);

	// ===== VIDEO =====
	public static function video(key:String, ?ext:String = 'mp4'):String
		return backend.Paths.video(key);

	// ===== SHADER =====
	public static function fragShader(key:String, ?library:String):String
		return backend.Paths.shaderFragment(key, library);

	public static function vertShader(key:String, ?library:String):String
		return backend.Paths.shaderVertex(key, library);

	// ===== UTILITY =====
	public static function formatToSongPath(path:String):String
		return backend.Paths.formatToSongPath(path);

	public static function getSparrowAtlas(key:String, ?library:String):flixel.graphics.frames.FlxAtlasFrames
		return backend.Paths.getSparrowAtlas(key, library);

	public static function getTextFromFile(key:String, ?ignoreMods:Bool = false):String
		return backend.Paths.getTextFromFile(key, ignoreMods);

	public static function readDirectory(directory:String):Array<String>
		return backend.Paths.readDirectory(directory);
}
