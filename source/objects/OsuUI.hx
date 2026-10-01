package objects;

import flixel.util.FlxSpriteUtil;

/**
 * Helper vẽ shape kiểu osu! (không cần asset ngoài).
 * Tất cả đều dùng makeGraphic/FlxSpriteUtil nên chạy được trên mọi mod.
 */
class OsuUI
{
	public static inline var PINK:Int = 0xFFFF66AA;
	public static inline var BLUE:Int = 0xFF66CCFF;
	public static inline var PURPLE:Int = 0xFF9966EE;
	public static inline var YELLOW:Int = 0xFFFFCC22;
	public static inline var GREEN:Int = 0xFF88DA20;
	public static inline var ORANGE:Int = 0xFFFF9933;
	public static inline var RED:Int = 0xFFED1121;

	public static function circle(radius:Int, color:FlxColor):FlxSprite
	{
		var s:FlxSprite = new FlxSprite().makeGraphic(radius * 2, radius * 2, FlxColor.TRANSPARENT, true);
		FlxSpriteUtil.drawCircle(s, radius, radius, radius, color);
		s.antialiasing = ClientPrefs.data.antialiasing;
		s.scrollFactor.set();
		return s;
	}

	/** Hình bình hành (nghiêng trái) — kiểu nút/card của osu!. Vẽ màu trắng rồi tint bằng .color */
	public static function slant(w:Int, h:Int, color:FlxColor = FlxColor.WHITE, skew:Int = 24):FlxSprite
	{
		var s:FlxSprite = new FlxSprite().makeGraphic(w, h, FlxColor.TRANSPARENT, true);
		var pts:Array<FlxPoint> = [FlxPoint.get(skew, 0), FlxPoint.get(w, 0), FlxPoint.get(w - skew, h), FlxPoint.get(0, h)];
		FlxSpriteUtil.drawPolygon(s, pts, color);
		for (p in pts) p.put();
		s.antialiasing = ClientPrefs.data.antialiasing;
		s.scrollFactor.set();
		return s;
	}

	public static function round(w:Int, h:Int, color:FlxColor = FlxColor.BLACK, r:Int = 18):FlxSprite
	{
		var s:FlxSprite = new FlxSprite().makeGraphic(w, h, FlxColor.TRANSPARENT, true);
		FlxSpriteUtil.drawRoundRect(s, 0, 0, w, h, r, r, color);
		s.antialiasing = ClientPrefs.data.antialiasing;
		s.scrollFactor.set();
		return s;
	}

	public static function rect(w:Int, h:Int, color:FlxColor = FlxColor.BLACK, alpha:Float = 1):FlxSprite
	{
		var s:FlxSprite = new FlxSprite().makeGraphic(1, 1, color);
		s.scale.set(w, h);
		s.updateHitbox();
		s.alpha = alpha;
		s.scrollFactor.set();
		return s;
	}

	public static function text(x:Float, y:Float, w:Float, str:String, size:Int, color:FlxColor = FlxColor.WHITE, align:FlxTextAlign = LEFT):FlxText
	{
		var t:FlxText = new FlxText(x, y, w, str, size);
		t.setFormat(Paths.font("vcr.ttf"), size, color, align, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		t.borderSize = 1.5;
		t.scrollFactor.set();
		return t;
	}
}
