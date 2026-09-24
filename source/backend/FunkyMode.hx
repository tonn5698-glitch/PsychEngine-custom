package backend;

import flixel.group.FlxSpriteGroup;
import flixel.group.FlxTypedGroup;

/**
 * Funky Mode (Experiment): HUD/menu elements "bop" scale theo beat.
 * - Beat tự track từ FlxG.sound.music (ngoài PlayState).
 * - Không áp dụng khi đang vào bài (PlayState) — pause menu chưa hỗ trợ (cần track pause music riêng).
 */
class FunkyMode
{
	// Base scale cache — key là FlxPoint.scale reference của object
	static var scaleCache:haxe.ds.ObjectMap<FlxPoint, FlxPoint> = new haxe.ds.ObjectMap();

	/**
	 * Auto track Conductor.songPosition từ menu music.
	 * Gọi mỗi frame ở MusicBeatState/MusicBeatSubstate KHI funkyMode ON
	 * và KHÔNG phải PlayState (PlayState tự track).
	 */
	public static function autoTrackMusic():Void
	{
		if (!ClientPrefs.data.funkyMode) return;
		if (FlxG.sound.music == null || !FlxG.sound.music.playing) return;
		// PlayState tự quản lý Conductor — không đụng
		if (Std.isOfType(FlxG.state, PlayState)) return;
		Conductor.songPosition = FlxG.sound.music.time;
	}

	/** Có nên bop ở beat này không? */
	public static function shouldBop():Bool
	{
		if (!ClientPrefs.data.funkyMode) return false;
		// Không bop khi đang vào bài
		if (Std.isOfType(FlxG.state, PlayState)) return false;
		if (FlxG.sound.music == null || !FlxG.sound.music.playing) return false;
		return true;
	}

	/** Bop toàn bộ members của state/substate (bỏ qua controls/bg lớn). */
	public static function bopMembers(members:Array<FlxBasic>):Void
	{
		if (members == null) return;
		var dur:Float = Conductor.crochet / 1000;
		if (!(dur > 0) || Math.isNaN(dur)) dur = 0.15;
		final bump:Float = 1.12;

		for (obj in members)
		{
			if (obj == null || !obj.exists || !obj.visible) continue;

			// Skip touch controls
			if (Std.isOfType(obj, TouchPad) || Std.isOfType(obj, Hitbox)
				|| Std.isOfType(obj, MobileControls) || Std.isOfType(obj, IMobileControls))
				continue;

			// FlxSpriteGroup (Alphabet, menu groups…) — KHÔNG extends FlxSprite,
			// scale group trực tiếp, không recurse children (tránh double-scale).
			if (Std.isOfType(obj, FlxSpriteGroup))
			{
				var group:FlxSpriteGroup = cast obj;
				bopScaleableObject(group, group.scale, group.width, group.height, bump, dur);
				continue;
			}

			// Group thường (FlxTypedGroup…) — recurse
			if (Std.isOfType(obj, FlxTypedGroup))
			{
				var g:FlxTypedGroup<Dynamic> = cast obj;
				bopMembers(cast g.members);
				continue;
			}

			if (Std.isOfType(obj, FlxSprite))
			{
				var spr:FlxSprite = cast obj;
				bopScaleableObject(spr, spr.scale, spr.width, spr.height, bump, dur);
			}
		}
	}

	/**
	 * Bop scale 1 object có scale/width/height (FlxSprite hoặc FlxSpriteGroup).
	 * Lưu base scale bằng key object (ObjectMap theo reference).
	 */
	static function bopScaleableObject(owner:Dynamic, scale:FlxPoint, width:Float, height:Float, bump:Float, dur:Float):Void
	{
		if (owner == null || scale == null) return;
		if (Std.isOfType(owner, TouchButton)) return;
		// Skip background lớn (bg menu, overlay full-screen)
		if (width >= FlxG.width * 0.9 && height >= FlxG.height * 0.65) return;

		// ObjectMap cần key là FlxSprite — dùng Reflect để set/get theo owner
		// Fallback: lưu base theo scale.x/y lockstep qua Weak không có — dùng companion map theo scale reference
		var base:FlxPoint = scaleCache.get(scale);
		if (base == null)
		{
			base = FlxPoint.get(scale.x, scale.y);
			scaleCache.set(scale, base);
		}

		FlxTween.cancelTweensOf(scale);
		scale.set(base.x * bump, base.y * bump);
		FlxTween.tween(scale, {x: base.x, y: base.y}, dur, {ease: FlxEase.cubeOut});
	}

	/** Clear cache base scale (gọi khi switch state để tránh leak reference). */
	public static function clearCache():Void
	{
		for (key in scaleCache.keys())
			scaleCache.remove(key);
	}
}
