package funkin.backend;

import flixel.text.FlxText;

/**
 * Shim cho funkin.backend.FunkinText (Codename Engine) — delegate sang FlxText.
 * Có thêm alignment etc... mọi thứ đã có sẵn trong FlxText (flixel 5).
 */
class FunkinText extends FlxText
{
	public function new(x:Float = 0, y:Float = 0, fieldWidth:Float = 0, text:String = '', size:Int = 8)
	{
		super(x, y, fieldWidth, text, size);
	}
}
