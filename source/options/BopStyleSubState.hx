package options;

import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.text.FlxTextBorderStyle;
import backend.FunkyMode;

/**
 * Tab thử nghiệm Bop Style:
 * - "<- Cube Out ->" hiển thị style hiện tại (Left/Right đổi)
 * - 1 HUD element random bop theo style để xem trước
 * - A = chọn style (save), B = thoát
 * Beat tự track từ menu music, independent với funkyMode.
 */
class BopStyleSubState extends MusicBeatSubstate
{
	static final STYLES:Array<String> = FunkyMode.BOP_STYLES;

	var styleText:FlxText;
	var testBox:FlxSprite;
	var hintText:FlxText;
	var curStyle:Int = 0;

	override function create():Void
	{
		super.create();

		var bg:FlxSprite = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, 0xCC000000);
		bg.scrollFactor.set();
		add(bg);

		styleText = new FlxText(0, 140, FlxG.width, '', 44);
		styleText.setFormat(Paths.font('vcr.ttf'), 44, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		styleText.scrollFactor.set();
		add(styleText);

		testBox = new FlxSprite().makeGraphic(150, 150, 0xFF00FF88);
		testBox.screenCenter();
		testBox.origin.set(testBox.width / 2, testBox.height / 2);
		testBox.scrollFactor.set();
		add(testBox);

		hintText = new FlxText(0, FlxG.height - 56, FlxG.width,
			'<  /  > : change style   A : choose   B : leave', 18);
		hintText.setFormat(Paths.font('vcr.ttf'), 18, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		hintText.scrollFactor.set();
		add(hintText);

		curStyle = STYLES.indexOf(ClientPrefs.data.bopStyle);
		if (curStyle < 0) curStyle = 0;
		updateStyleText();

		addTouchPad('LEFT_RIGHT', 'A_B');
	}

	override function update(elapsed:Float):Void
	{
		// Beat tự track từ menu music (không phụ thuộc funkyMode)
		if (FlxG.sound.music != null)
			Conductor.songPosition = FlxG.sound.music.time;
		if (ClientPrefs.data.bopBpm > 0)
			Conductor.bpm = ClientPrefs.data.bopBpm;

		if (controls.UI_LEFT_P) changeStyle(-1);
		if (controls.UI_RIGHT_P) changeStyle(1);

		if (controls.BACK)
		{
			closeBop(false);
			return;
		}
		if (controls.ACCEPT)
		{
			closeBop(true);
			return;
		}

		super.update(elapsed);
	}

	override function beatHit():Void
	{
		// Bop test element theo style preview (super.beatHit → FunkyMode.bopMembers sẽ double → bỏ qua)
		var dur:Float = Conductor.crochet / 1000;
		if (!(dur > 0) || Math.isNaN(dur)) dur = 0.15;
		final bump:Float = 1.3;
		var ease:Float->Float = FunkyMode.getEase(STYLES[curStyle]);

		FlxTween.cancelTweensOf(testBox.scale);
		testBox.scale.set(bump, bump);
		FlxTween.tween(testBox.scale, {x: 1, y: 1}, dur, {ease: ease});

		FlxTween.cancelTweensOf(styleText.scale);
		styleText.scale.set(bump, bump);
		FlxTween.tween(styleText.scale, {x: 1, y: 1}, dur, {ease: ease});
	}

	function changeStyle(dir:Int):Void
	{
		curStyle = FlxMath.wrap(curStyle + dir, 0, STYLES.length - 1);
		FlxG.sound.play(Paths.sound('scrollMenu'));
		updateStyleText();
	}

	function updateStyleText():Void
	{
		styleText.text = '<  ' + STYLES[curStyle] + '  >';
	}

	function closeBop(apply:Bool):Void
	{
		if (apply)
		{
			ClientPrefs.data.bopStyle = STYLES[curStyle];
			ClientPrefs.saveSettings();
			FlxG.sound.play(Paths.sound('confirmMenu'));
		}
		else
			FlxG.sound.play(Paths.sound('cancelMenu'));
		close();
	}
}