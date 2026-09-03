package funkin.savedata;

/**
 * Shim cho funkin.savedata.FunkinSave (Codename Engine).
 * Bản port dùng backend.Highscore nên đây là stub giữ cho import resolve.
 */
class FunkinSave
{
	public static var save:Dynamic = null;

	public static function getSongHighscore(song:String, ?diff:String):Dynamic
		return null;
}
