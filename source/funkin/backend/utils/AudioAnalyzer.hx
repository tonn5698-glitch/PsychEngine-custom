package funkin.backend.utils;

/**
 * Shim cho funkin.backend.utils.AudioAnalyzer (Codename Engine).
 * Bản port dùng FlxTimer BPM nên đây là stub để import resolve.
 */
class AudioAnalyzer
{
	public function new(?source:Dynamic)
	{
	}

	public var time:Float = 0;

	public function getLevels(time:Float = 0, size:Int = 32, sampleCount:Int = 32, ?levels:Array<Float>, ?lower:Int = 0, ?upper:Int = 1, ?a:Bool = false, ?b:Int = 0, ?c:Int = 0, ?d:Int = 0):Array<Float>
	{
		if (levels == null) levels = [];
		return levels;
	}
}
