package backend;

import flixel.FlxG;

/**
 * Logical game size theo từng state.
 * - baseW/baseH: size đã expand lúc boot (fullScreenMode / wideScreen), dùng cho mọi state.
 * - PlayState của mod KHÔNG có CustomBuild: tạm resize về 1280x720, rời PlayState thì restore.
 */
class GameSize
{
	public static var baseW:Int = 1280;
	public static var baseH:Int = 720;
	public static var legacyActive:Bool = false;

	public static function set(w:Int, h:Int):Void
	{
		if (FlxG.width == w && FlxG.height == h) return;

		@:privateAccess
		{
			FlxG.width = w;
			FlxG.height = h;
		}

		// tính lại scale/offset của game theo size logic mới
		if (FlxG.stage != null && FlxG.scaleMode != null)
			FlxG.scaleMode.onMeasure(FlxG.stage.stageWidth, FlxG.stage.stageHeight);
	}

	/** Gọi ở đầu PlayState.create(), TRƯỚC khi tạo camera. */
	public static function enterPlayState():Void
	{
		#if mobile
		var custom:Bool = Mods.hasCustomBuild(Mods.currentModDirectory);
		Mods.customBuild = custom;
		trace('[CustomBuild] PlayState mod="${Mods.currentModDirectory}" flag=$custom');

		if (!custom && (baseW != 1280 || baseH != 720))
		{
			set(1280, 720);
			legacyActive = true;
		}
		#end
	}

	/** Gọi đầu PlayState.destroy(), TRƯỚC khi state kế tiếp create(). */
	public static function leavePlayState():Void
	{
		if (!legacyActive) return;
		legacyActive = false;
		set(baseW, baseH);
	}
}
