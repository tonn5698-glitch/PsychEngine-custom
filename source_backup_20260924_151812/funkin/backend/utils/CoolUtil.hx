package funkin.backend.utils;

/**
 * Shim: CNE CoolUtil API → Psych Engine equivalents.
 * Chỉ implement các method mà state CNE thật sự dùng.
 */
class CoolUtil
{
	// ===== MATH =====
	public static inline function bound(value:Float, min:Float, max:Float):Float
		return Math.max(min, Math.min(max, value));

	public static inline function positiveModulo(dividend:Float, divisor:Float):Float
		return ((dividend % divisor) + divisor) % divisor;

	public static inline function floorInt(value:Float):Int
		return Std.int(Math.floor(value));

	public static inline function maxInt(a:Int, b:Int):Int
		return a > b ? a : b;

	public static inline function minInt(a:Int, b:Int):Int
		return a < b ? a : b;

	public static inline function quantize(f:Float, snap:Float):Float
		return Math.floor(f / snap) * snap;

	public static inline function fpsLerp(v1:Float, v2:Float, ratio:Float):Float
		return FlxMath.lerp(v1, v2, ratio * (FlxG.elapsed / (1 / 60)));

	// ===== JSON =====
	public static function parseJson(jsonString:String):Dynamic
	{
		return haxe.Json.parse(jsonString);
	}

	public static function parseJsonFile(filePath:String):Dynamic
	{
		#if sys
		if (sys.FileSystem.exists(filePath))
			return haxe.Json.parse(sys.io.File.getContent(filePath));
		#end
		return null;
	}

	// ===== TEXT =====
	public static function coolTextFile(path:String):Array<String>
	{
		return backend.Paths.getTextFromFile(path).split('\n');
	}

	public static function timeToStr(time:Float):String
	{
		var minutes:Int = Std.int(time / 60000);
		var seconds:Int = Std.int((time % 60000) / 1000);
		var ms:Int = Std.int(time % 1000);
		return '$minutes:${Std.string(seconds).lpad('0', '2')}.${Std.string(ms).lpad('0', '3')}';
	}

	// ===== SOUND =====
	public static function playMusic(key:String, ?volume:Float, ?looped:Bool, ?startTime:Float, ?bpm:Float):Void
	{
		FlxG.sound.playMusic(backend.Paths.music(key), volume != null ? volume : 1, looped != null ? looped : true);
		if (bpm != null)
			backend.Conductor.bpm = bpm;
	}

	public static function playMenuSong():Void
	{
		playMusic('freakyMenu');
	}

	public static function playMenuSFX():Void
	{
		FlxG.sound.play(backend.Paths.sound('confirmMenu'));
	}

	// ===== COLOR =====
	public static function colorFromString(color:String):FlxColor
	{
		return FlxColor.fromString(color);
	}

	// ===== ARRAY =====
	public static function numberArray(max:Int, ?min:Int):Array<Int>
	{
		if (min == null) min = 0;
		var array:Array<Int> = [];
		for (i in min...max)
			array.push(i);
		return array;
	}

	// ===== SPRITE =====
	public static function setGraphicSizeFloat(sprite:flixel.FlxSprite, width:Float, height:Float):Void
	{
		sprite.setGraphicSize(Std.int(width), Std.int(height));
		sprite.updateHitbox();
	}

	public static function resetSprite(sprite:flixel.FlxSprite, ?x:Float, ?y:Float):Void
	{
		if (x != null) sprite.x = x;
		if (y != null) sprite.y = y;
		sprite.velocity.set(0, 0);
		sprite.acceleration.set(0, 0);
		sprite.angularVelocity = 0;
	}

	// ===== FILE =====
	public static function deleteFolder(path:String):Void
	{
		#if sys
		if (sys.FileSystem.exists(path))
		{
			if (sys.FileSystem.isDirectory(path))
			{
				for (file in sys.FileSystem.readDirectory(path))
					deleteFolder(path + '/' + file);
				sys.FileSystem.deleteDirectory(path);
			}
			else
				sys.FileSystem.deleteFile(path);
		}
		#end
	}

	// ===== MISC =====
	public static inline function isNotNull(v:Dynamic):Bool
		return v != null;

	public static inline function getDefault<T>(v:Null<T>, defaultValue:T):T
		return v != null ? v : defaultValue;

	public static inline function getDefaultFloat(v:Float, defaultValue:Float):Float
		return Math.isNaN(v) ? defaultValue : v;

	public static function openURL(url:String):Void
	{
		#if sys
		flixel.FlxG.openURL(url);
		#end
	}

	public static function getSavePath():String
		return backend.Paths.getSavePath();

	public static function getMacroAbstractClass(className:String):Dynamic
	{
		return Type.resolveClass(className);
	}

	public static function getCPUThreadsCount():Int
	{
		#if sys
		return Sys.cpuTime() != null ? 1 : 1;
		#else
		return 1;
		#end
	}

	public static function showPopUp(message:String, title:String):Void
	{
		#if (desktop || mobile)
		// On mobile, just trace
		trace('[$title] $message');
		#end
	}
}
