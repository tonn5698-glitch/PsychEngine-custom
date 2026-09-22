package states;

import backend.Mods;
import backend.Paths;

/**
 * Popup chuyển mod trong Freeplay.
 * Hiển thị danh sách mod enabled, dùng LEFT/RIGHT để chọn, A để xác nhận, B để hủy.
 */
class FreeplayModSwitchSubState extends MusicBeatSubstate
{
	var titleText:FlxText;
	var modText:FlxText;
	var arrowLeft:FlxText;
	var arrowRight:FlxText;
	var bg:FlxSprite;

	var enabledMods:Array<String> = [];
	var currentIdx:Int = 0;
	var onConfirm:String->Void;

	public function new(currentMod:String, onConfirm:String->Void)
	{
		super();
		this.onConfirm = onConfirm;

		// Lấy danh sách mod enabled từ TẤT CẢ root dirs
		enabledMods = getEnabledMods();
		if (enabledMods.length == 0)
		{
			close();
			return;
		}

		// Tìm index mod hiện tại
		currentIdx = 0;
		for (i in 0...enabledMods.length)
		{
			if (enabledMods[i] == currentMod)
			{
				currentIdx = i;
				break;
			}
		}

		// Nền popup
		bg = new FlxSprite().makeGraphic(400, 200, 0xCC000000);
		bg.screenCenter();
		bg.scrollFactor.set();
		add(bg);

		// Tiêu đề
		titleText = new FlxText(0, bg.y + 20, 400, 'Chuyển đổi Mod\'s Freeplay', 20);
		titleText.setFormat(Paths.font("vcr.ttf"), 20, 0xFFFF4444, 1); // CENTER
		titleText.x = bg.x;
		titleText.scrollFactor.set();
		add(titleText);

		// Tên mod
		modText = new FlxText(0, bg.y + 70, 400, '', 28);
		modText.setFormat(Paths.font("vcr.ttf"), 28, FlxColor.WHITE, 1); // CENTER
		modText.x = bg.x;
		modText.scrollFactor.set();
		add(modText);

		// Mũi tên trái
		arrowLeft = new FlxText(bg.x + 20, bg.y + 75, 60, '<-', 32);
		arrowLeft.setFormat(Paths.font("vcr.ttf"), 32, 0xFFAAAAAA, 1);
		arrowLeft.scrollFactor.set();
		add(arrowLeft);

		// Mũi tên phải
		arrowRight = new FlxText(bg.x + 320, bg.y + 75, 60, '->', 32);
		arrowRight.setFormat(Paths.font("vcr.ttf"), 32, 0xFFAAAAAA, 1);
		arrowRight.scrollFactor.set();
		add(arrowRight);

		// Hướng dẫn
		var hintText:FlxText = new FlxText(0, bg.y + 140, 400, 'LEFT/RIGHT: chọn  |  A: xác nhận  |  B: hủy', 12);
		hintText.setFormat(Paths.font("vcr.ttf"), 12, 0xFF888888, 1);
		hintText.x = bg.x;
		hintText.scrollFactor.set();
		add(hintText);

		updateDisplay();
	}

	function getEnabledMods():Array<String>
	{
		var mods:Array<String> = [];
		var list = Mods.parseList();
		if (list != null && list.enabled != null)
		{
			for (mod in list.enabled)
			{
				if (mod != null && mod.length > 0 && !mods.contains(mod))
					mods.push(mod);
			}
		}
		return mods;
	}

	function updateDisplay()
	{
		if (enabledMods.length == 0) return;
		modText.text = '< ' + enabledMods[currentIdx] + ' >';
		// Highlight
		arrowLeft.alpha = 0.8;
		arrowRight.alpha = 0.8;
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (controls.UI_LEFT_P)
		{
			currentIdx--;
			if (currentIdx < 0) currentIdx = enabledMods.length - 1;
			updateDisplay();
			FlxG.sound.play(Paths.sound('scrollMenu'), 0.5);
		}
		if (controls.UI_RIGHT_P)
		{
			currentIdx++;
			if (currentIdx >= enabledMods.length) currentIdx = 0;
			updateDisplay();
			FlxG.sound.play(Paths.sound('scrollMenu'), 0.5);
		}
		if (controls.ACCEPT)
		{
			FlxG.sound.play(Paths.sound('confirmMenu'), 0.6);
			onConfirm(enabledMods[currentIdx]);
			close();
		}
		if (controls.BACK)
		{
			FlxG.sound.play(Paths.sound('cancelMenu'));
			close();
		}
	}
}
