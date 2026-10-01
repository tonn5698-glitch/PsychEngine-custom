package objects;

/** Card bài hát trong carousel Freeplay (kiểu song select của osu!). */
class OsuSongCard extends FlxSpriteGroup
{
	public var targetY:Int = 0;
	public var cardW:Int = 560;
	public var cardH:Int = 88;
	public var songColor:FlxColor;

	var bg:FlxSprite;
	var nameTxt:FlxText;
	var subTxt:FlxText;

	public function new(name:String, folder:String, color:FlxColor)
	{
		super();
		songColor = color;

		bg = OsuUI.slant(cardW, cardH, FlxColor.WHITE, 26);
		add(bg);

		nameTxt = OsuUI.text(110, 14, cardW - 160, name, 28);
		nameTxt.wordWrap = false;
		add(nameTxt);

		subTxt = OsuUI.text(110, 52, cardW - 160, folder.length > 0 ? folder : 'base game', 18, 0xFFDDDDDD);
		subTxt.wordWrap = false;
		add(subTxt);

		scrollFactor.set();
		setSelected(false);
	}

	public function setSelected(sel:Bool):Void
	{
		bg.color = sel ? FlxColor.interpolate(songColor, FlxColor.WHITE, 0.35) : FlxColor.interpolate(songColor, FlxColor.BLACK, 0.55);
	}
}
