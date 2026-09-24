package backend;

import flixel.FlxBasic;
import flixel.group.FlxSpriteGroup;
import flixel.group.FlxGroup.FlxTypedGroup;

/**
 * Funky Mode (Experiment): HUD/menu elements "bop" scale theo beat.
 * - Beat tự track từ FlxG.sound.music (ngoài PlayState).
 * - Không áp dụng khi đang vào bài (PlayState) — pause menu chưa hỗ trợ (cần track pause music riêng).
 */
class FunkyMode
{
	// Danh sách Bop Style có thể chọn (Experiment) hoặc đặt trong Engine.json "bop-style"
	public static final BOP_STYLES:Array<String> = [
		'Linear',
		'Sine In', 'Sine Out', 'Sine InOut',
		'Quad In', 'Quad Out', 'Quad InOut',
		'Cube In', 'Cube Out', 'Cube InOut',
		'Quart In', 'Quart Out', 'Quart InOut',
		'Quint In', 'Quint Out', 'Quint InOut',
		'Expo In', 'Expo Out', 'Expo InOut',
		'Circ In', 'Circ Out', 'Circ InOut',
		'Back In', 'Back Out', 'Back InOut',
		'Bounce In', 'Bounce Out', 'Bounce InOut',
		'Elastic In', 'Elastic Out', 'Elastic InOut'
	];

	// Base scale cache — key là FlxPoint.scale reference của object
	static var scaleCache:haxe.ds.ObjectMap<FlxPoint, FlxPoint> = new haxe.ds.ObjectMap();

	/**
	 * Auto track Conductor.songPosition từ menu music.
	 * Gọi mỗi frame ở MusicBeatState/MusicBeatSubstate KHI funkyMode ON
	 * và KHÔNG phải PlayState (PlayState tự track).
	 * Đồng thời set Conductor.bpm = bopBpm (Engine.json "bop-bpm") để nhịp bop đúng config.
	 */
	public static function autoTrackMusic():Void
	{
		if (!ClientPrefs.data.funkyMode) return;
		if (FlxG.sound.music == null || !FlxG.sound.music.playing) return;
		// PlayState tự quản lý Conductor — không đụng
		if (Std.isOfType(FlxG.state, PlayState)) return;
		Conductor.songPosition = FlxG.sound.music.time;
		if (ClientPrefs.data.bopBpm > 0)
			Conductor.bpm = ClientPrefs.data.bopBpm;
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
		FlxTween.tween(scale, {x: base.x, y: base.y}, dur, {ease: getEase(ClientPrefs.data.bopStyle)});
	}

	/** Map tên style (VD: "Cube Out", "cubeout", "backout") → function FlxEase. */
	public static function getEase(style:String):Float->Float
	{
		var key:String = labelToField(style);
		var fn:Dynamic = Reflect.field(FlxEase, key);
		if (fn != null)
			return cast fn;
		return FlxEase.linear;
	}

	/** Chuẩn hóa bất kỳ format ("cubeout"/"Cube Out"/"cube_out") → nhãn chuẩn trong BOP_STYLES. */
	public static function normalizeStyle(raw:String):String
	{
		if (raw == null) return 'Cube Out';
		var s:String = raw.toLowerCase().split(' ').join('').split('_').join('').split('-').join('');
		for (style in BOP_STYLES)
		{
			var cmp:String = style.toLowerCase().split(' ').join('');
			if (cmp == s) return style;
		}
		return 'Cube Out';
	}

	/** "Cube Out" → "cubeOut", "Sine InOut" → "sineInOut", "Linear" → "linear". */
	static function labelToField(label:String):String
	{
		if (label == null) return 'linear';
		var parts:Array<String> = label.split(' ');
		var field:String = parts[0].toLowerCase();
		for (i in 1...parts.length)
			field += parts[i].charAt(0).toUpperCase() + parts[i].substring(1);
		return field;
	}

	/** Clear cache base scale (gọi khi switch state để tránh leak reference). */
	public static function clearCache():Void
	{
		for (key in scaleCache.keys())
			scaleCache.remove(key);
	}
}
