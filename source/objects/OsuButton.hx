package objects;

/** Nút hình bình hành kiểu osu!: tối khi idle, sáng + trượt sang phải khi selected. */
class OsuButton extends FlxSpriteGroup
{
	public var bg:FlxSprite;
	public var txt:FlxText;
	public var baseColor:FlxColor;
	public var baseX:Float = 0;
	public var shiftX:Float = 0;
	public var btnW:Int;
	public var btnH:Int;
	var _selected:Bool = false;
	public var selected(get, set):Bool;

	public function new(x:Float, y:Float, w:Int, h:Int, label:String, color:FlxColor, size:Int = 30)
	{
		super(x, y);
		baseX = x;
		btnW = w;
		btnH = h;
		baseColor = color;

		var skew:Int = Std.int(h * 0.3);
		bg = OsuUI.slant(w, h, FlxColor.WHITE, skew);
		add(bg);

		txt = OsuUI.text(skew + 24, 0, w - skew - 48, label, size);
		txt.wordWrap = false;
		txt.y = (h - txt.height) / 2; // toạ độ tương đối, group cộng offset khi add
		add(txt);

		scrollFactor.set();
		set_selected(false);
	}

	function get_selected():Bool
	{
		return _selected;
	}

	function set_selected(v:Bool):Bool
	{
		_selected = v;
		bg.color = v ? baseColor : FlxColor.interpolate(baseColor, FlxColor.BLACK, 0.55);
		return v;
	}

	public inline function hovered():Bool
		return FlxG.mouse.overlaps(bg);

	override function update(elapsed:Float)
	{
		shiftX = FlxMath.lerp(selected ? 34 : 0, shiftX, Math.exp(-elapsed * 14));
		x = baseX + shiftX;
		super.update(elapsed);
	}
}
