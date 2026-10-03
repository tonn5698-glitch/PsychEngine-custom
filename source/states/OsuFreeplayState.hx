package states;

import objects.OsuUI;
import objects.OsuButton;
import objects.OsuSongCard;
import psychlua.CustomFreeplayFunctions;
import backend.MusicBeatState;

class OsuFreeplayState extends MusicBeatState
{
	var songs:Array<Dynamic> = [];
	var cards:Array<OsuSongCard> = [];
	var diffBtns:Array<OsuButton> = [];
	var diffs:Array<String> = [];
	var curSelected:Int = 0;
	var curDiff:Int = 0;
	var loadedIndex:Int = -1;
	var leaving:Bool = false;
	var bg:FlxSprite;
	var leftPanel:FlxSprite;
	var accent:FlxSprite;
	var titleTxt:FlxText;
	var hintTxt:FlxText;
	var scoreTxt:FlxText;
	var infoTxt:FlxText;

	override function create()
	{
		#if MODS_ALLOWED
		Mods.pushGlobalMods();
		Mods.loadTopMod();
		#end

		FlxG.mouse.visible = true;
		songs = CustomFreeplayFunctions.getFreeplaySongList();
		if (songs.length == 0)
			songs.push({songName: 'debug', week: 0, character: 'bf', color: 0xFF808080, folder: ''});

		bg = OsuUI.rect(FlxG.width, FlxG.height, 0xFF101014);
		add(bg);

		leftPanel = OsuUI.rect(470, FlxG.height, 0xFF1A1A24);
		add(leftPanel);

		accent = OsuUI.rect(6, FlxG.height, 0xFFFFFFFF);
		accent.x = 464;
		add(accent);

		titleTxt = OsuUI.text(40, 30, 400, 'FREEPLAY', 46, 0xFFFF66AA);
		add(titleTxt);

		hintTxt = OsuUI.text(40, 96, 420, 'UP/DOWN: song\nLEFT/RIGHT: difficulty\nENTER: play   ESC: menu', 16, 0xFFCCCCCC);
		add(hintTxt);

		scoreTxt = OsuUI.text(40, FlxG.height - 100, 420, '', 26, 0xFFFFFFFF);
		add(scoreTxt);

		infoTxt = OsuUI.text(40, FlxG.height - 64, 420, '', 16, 0xFFAAAAAA);
		add(infoTxt);

		for (i in 0...songs.length)
		{
			var s:Dynamic = songs[i];
			var card = new OsuSongCard(s.songName, s.folder == null ? '' : s.folder, s.color);
			card.x = FlxG.width - 620;
			card.y = FlxG.height / 2 - 44 + i * 112;
			add(card);
			cards.push(card);
		}

		selectSong(0);
		super.create();
	}

	function selectSong(index:Int):Void
	{
		if (index < 0 || index >= songs.length || index == loadedIndex) return;
		loadedIndex = index;
		curSelected = index;
		curDiff = 0;

		var s:Dynamic = songs[curSelected];
		diffs = CustomFreeplayFunctions.selectFreeplaySong(s.week, s.folder);
		if (diffs == null) diffs = [];

		rebuildDiffButtons();
		accent.color = s.color;
		updateInfo();
	}

	function rebuildDiffButtons():Void
	{
		for (b in diffBtns)
		{
			remove(b);
			b.destroy();
		}
		diffBtns = [];

		for (i in 0...diffs.length)
		{
			var b = new OsuButton(40, 160 + i * 88, 350, 76, diffs[i], 0xFFFF66AA, 26);
			b.selected = (i == curDiff);
			add(b);
			diffBtns.push(b);
		}
	}

	function changeSel(dir:Int):Void
	{
		if (songs.length == 0) return;
		var n:Int = curSelected + dir;
		if (n < 0) n = songs.length - 1;
		if (n >= songs.length) n = 0;
		if (n == loadedIndex) return;
		FlxG.sound.play(Paths.sound('scrollMenu'));
		selectSong(n);
	}

	function changeDiff(dir:Int):Void
	{
		if (diffs.length == 0) return;
		var n:Int = curDiff + dir;
		if (n < 0) n = diffs.length - 1;
		if (n >= diffs.length) n = 0;
		if (n == curDiff) return;
		curDiff = n;
		for (i in 0...diffBtns.length) diffBtns[i].selected = (i == curDiff);
		FlxG.sound.play(Paths.sound('scrollMenu'));
		updateInfo();
	}

	function pickDiff(index:Int):Void
	{
		if (index == curDiff || index < 0 || index >= diffs.length) return;
		curDiff = index;
		for (i in 0...diffBtns.length) diffBtns[i].selected = (i == curDiff);
		FlxG.sound.play(Paths.sound('scrollMenu'));
		updateInfo();
	}

	function updateInfo():Void
	{
		if (songs.length == 0) return;
		var s:Dynamic = songs[curSelected];
		var folderName:String = (s.folder == null || s.folder == '') ? 'base game' : s.folder;
		infoTxt.text = folderName + '  -  week ' + s.week + '  -  ' + diffs.join(' / ');
		scoreTxt.text = 'Best: ' + CustomFreeplayFunctions.getFreeplayScore(s.songName, curDiff) + ' pts';
	}

	function playSelected():Void
	{
		if (leaving || songs.length == 0) return;
		var s:Dynamic = songs[curSelected];
		var ok:Bool = CustomFreeplayFunctions.playFreeplaySong(s.songName, curDiff);
		if (ok)
		{
			leaving = true;
			FlxG.sound.play(Paths.sound('confirmMenu'));
		}
		else
			infoTxt.text = 'Chart loi / thieu file: ' + s.songName;
	}

	override function update(elapsed:Float):Void
	{
		if (leaving) return;

		if (controls.BACK)
		{
			leaving = true;
			FlxG.sound.play(Paths.sound('cancelMenu'));
			MusicBeatState.switchState(new MainMenuState());
			return;
		}

		if (songs.length > 0)
		{
			if (controls.UI_UP_P) changeSel(-1);
			if (controls.UI_DOWN_P) changeSel(1);
			if (controls.UI_LEFT_P) changeDiff(-1);
			if (controls.UI_RIGHT_P) changeDiff(1);
			if (controls.ACCEPT) playSelected();

			if (FlxG.mouse.justPressed)
			{
				for (i in 0...cards.length)
				{
					if (FlxG.mouse.overlaps(cards[i]))
					{
						if (i == curSelected) playSelected();
						else
						{
							FlxG.sound.play(Paths.sound('scrollMenu'));
							selectSong(i);
						}
					}
				}
				for (i in 0...diffBtns.length)
					if (FlxG.mouse.overlaps(diffBtns[i])) pickDiff(i);
			}
		}

		var k:Float = elapsed * 14;
		if (k > 1) k = 1;
		for (i in 0...cards.length)
		{
			var c:OsuSongCard = cards[i];
			var targetY:Float = FlxG.height / 2 - 44 + (i - curSelected) * 112;
			c.targetY = Std.int(targetY);
			c.y = c.y + (c.targetY - c.y) * k;
			var sel:Bool = (i == curSelected);
			c.setSelected(sel);
			c.alpha = sel ? 1 : 0.55;
		}

		super.update(elapsed);
	}
}
