package states;

import flixel.FlxObject;
import flixel.effects.FlxFlicker;
import lime.app.Application;
import states.editors.MasterEditorMenu;
import options.OptionsState;

#if MODS_ALLOWED
import sys.FileSystem;
import haxe.io.Path;
#end

enum MainMenuColumn {
	LEFT;
	CENTER;
	RIGHT;
}

class MainMenuState extends MusicBeatState
{
	public static var psychEngineVersion:String = '1.0.4';
	public static var curSelected:Int = 0;
	public static var curColumn:MainMenuColumn = CENTER;
	var allowMouse:Bool = true;

	var menuItems:FlxTypedGroup<FlxSprite>;
	var leftItem:FlxSprite;
	var rightItem:FlxSprite;

	var optionShit:Array<String> = [
		'story_mode',
		'freeplay',
		#if MODS_ALLOWED 'mods', #end
		'credits'
	];

	var leftOption:String = #if ACHIEVEMENTS_ALLOWED 'achievements' #else null #end;
	var rightOption:String = 'options';

	var magenta:FlxSprite;
	var camFollow:FlxObject;

	static var showOutdatedWarning:Bool = true;

	// ===== AUTO-SCAN MOD STATES =====
	// Quét data/states/ trong tất cả mod → trả về danh sách state
	public static function scanModStates():Array<{name:String, mod:String}>
	{
		var result:Array<{name:String, mod:String}> = [];
		#if MODS_ALLOWED
		var mods:Array<String> = Mods.getModDirectories();
		for (mod in mods)
		{
			var dir:String = Paths.mods(mod + '/data/states/');
			if (FileSystem.exists(dir))
			{
				var files:Array<String> = FileSystem.readDirectory(dir);
				for (file in files)
				{
					var ext:String = Path.extension(file).toLowerCase();
					if (ext == 'hx' || ext == 'hscript' || ext == 'lua')
					{
						var name:String = Path.withoutExtension(file);
						result.push({name: name, mod: mod});
					}
				}
			}
		}
		#end
		return result;
	}

	override function create()
	{
		super.create();

		#if MODS_ALLOWED
		Mods.pushGlobalMods();
		#end
		Mods.loadTopMod();

		#if DISCORD_ALLOWED
		DiscordClient.changePresence("In the Menus", null);
		#end

		persistentUpdate = persistentDraw = true;

		var yScroll:Float = 0.25;
		var bg:FlxSprite = new FlxSprite(-80).loadGraphic(Paths.image('menuBG'));
		bg.antialiasing = ClientPrefs.data.antialiasing;
		bg.scrollFactor.set(0, yScroll);
		bg.setGraphicSize(Std.int(bg.width * 1.175));
		bg.updateHitbox();
		bg.screenCenter();
		add(bg);

		camFollow = new FlxObject(0, 0, 1, 1);
		add(camFollow);

		magenta = new FlxSprite(-80).loadGraphic(Paths.image('menuDesat'));
		magenta.antialiasing = ClientPrefs.data.antialiasing;
		magenta.scrollFactor.set(0, yScroll);
		magenta.setGraphicSize(Std.int(magenta.width * 1.175));
		magenta.updateHitbox();
		magenta.screenCenter();
		magenta.visible = false;
		magenta.color = 0xFFfd719b;
		add(magenta);

		menuItems = new FlxTypedGroup<FlxSprite>();
		add(menuItems);

		for (num => option in optionShit)
		{
			var item:FlxSprite = createMenuItem(option, 0, (num * 140) + 90);
			item.y += (4 - optionShit.length) * 70;
			item.screenCenter(X);
		}

		if (leftOption != null)
			leftItem = createMenuItem(leftOption, 60, 490);
		if (rightOption != null)
		{
			rightItem = createMenuItem(rightOption, FlxG.width - 60, 490);
			rightItem.x -= rightItem.width;
		}

		var psychVer:FlxText = new FlxText(12, FlxG.height - 44, 0, "Psych Engine v" + psychEngineVersion, 12);
		psychVer.scrollFactor.set();
		psychVer.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(psychVer);
		var fnfVer:FlxText = new FlxText(12, FlxG.height - 24, 0, "Friday Night Funkin' v" + Application.current.meta.get('version'), 12);
		fnfVer.scrollFactor.set();
		fnfVer.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(fnfVer);
		changeItem();

		#if ACHIEVEMENTS_ALLOWED
		var leDate = Date.now();
		if (leDate.getDay() == 5 && leDate.getHours() >= 18)
			Achievements.unlock('friday_night_play');
		#if MODS_ALLOWED
		Achievements.reloadList();
		#end
		#end

		#if CHECK_FOR_UPDATES
		if (showOutdatedWarning && ClientPrefs.data.checkForUpdates && substates.OutdatedSubState.updateVersion != psychEngineVersion) {
			persistentUpdate = false;
			showOutdatedWarning = false;
			openSubState(new substates.OutdatedSubState());
		}
		#end

		FlxG.camera.follow(camFollow, null, 0.15);
		addTouchPad('NONE', 'E');
	}

	function createMenuItem(name:String, x:Float, y:Float):FlxSprite
	{
		var menuItem:FlxSprite = new FlxSprite(x, y);
		menuItem.frames = Paths.getSparrowAtlas('mainmenu/menu_$name');
		menuItem.animation.addByPrefix('idle', '$name idle', 24, true);
		menuItem.animation.addByPrefix('selected', '$name selected', 24, true);
		menuItem.animation.play('idle');
		menuItem.updateHitbox();
		menuItem.antialiasing = ClientPrefs.data.antialiasing;
		menuItem.scrollFactor.set();
		menuItems.add(menuItem);
		return menuItem;
	}

	var selectedSomethin:Bool = false;
	var timeNotMoving:Float = 0;

	override function update(elapsed:Float)
	{
		if (FlxG.sound.music.volume < 0.8)
			FlxG.sound.music.volume = Math.min(FlxG.sound.music.volume + 0.5 * elapsed, 0.8);

		if (!selectedSomethin)
		{
			if (controls.UI_UP_P) changeItem(-1);
			if (controls.UI_DOWN_P) changeItem(1);

			var allowMouse:Bool = allowMouse;
			if (allowMouse && ((FlxG.mouse.deltaScreenX != 0 && FlxG.mouse.deltaScreenY != 0) || FlxG.mouse.justPressed))
			{
				allowMouse = false;
				FlxG.mouse.visible = true;
				timeNotMoving = 0;

				var selectedItem:FlxSprite;
				switch(curColumn)
				{
					case CENTER: selectedItem = menuItems.members[curSelected];
					case LEFT: selectedItem = leftItem;
					case RIGHT: selectedItem = rightItem;
				}

				if(leftItem != null && FlxG.mouse.overlaps(leftItem))
				{
					allowMouse = true;
					if(selectedItem != leftItem) { curColumn = LEFT; changeItem(); }
				}
				else if(rightItem != null && FlxG.mouse.overlaps(rightItem))
				{
					allowMouse = true;
					if(selectedItem != rightItem) { curColumn = RIGHT; changeItem(); }
				}
				else
				{
					var dist:Float = -1;
					var distItem:Int = -1;
					for (i in 0...optionShit.length)
					{
						var memb:FlxSprite = menuItems.members[i];
						if(FlxG.mouse.overlaps(memb))
						{
							var distance:Float = Math.sqrt(Math.pow(memb.getGraphicMidpoint().x - FlxG.mouse.screenX, 2) + Math.pow(memb.getGraphicMidpoint().y - FlxG.mouse.screenY, 2));
							if (dist < 0 || distance < dist) { dist = distance; distItem = i; allowMouse = true; }
						}
					}
					if(distItem != -1 && selectedItem != menuItems.members[distItem])
					{
						curColumn = CENTER;
						curSelected = distItem;
						changeItem();
					}
				}
			}
			else { timeNotMoving += elapsed; if(timeNotMoving > 2) FlxG.mouse.visible = false; }

			switch(curColumn)
			{
				case CENTER:
					if(controls.UI_LEFT_P && leftOption != null) { curColumn = LEFT; changeItem(); }
					else if(controls.UI_RIGHT_P && rightOption != null) { curColumn = RIGHT; changeItem(); }
				case LEFT:
					if(controls.UI_RIGHT_P) { curColumn = CENTER; changeItem(); }
				case RIGHT:
					if(controls.UI_LEFT_P) { curColumn = CENTER; changeItem(); }
			}

			if (controls.BACK)
			{
				selectedSomethin = true;
				FlxG.mouse.visible = false;
				FlxG.sound.play(Paths.sound('cancelMenu'));
				MusicBeatState.switchState(new TitleState());
			}

			if (controls.ACCEPT || (FlxG.mouse.overlaps(menuItems, FlxG.camera) && FlxG.mouse.justPressed && allowMouse))
			{
				FlxG.sound.play(Paths.sound('confirmMenu'));
				selectedSomethin = true;
				FlxG.mouse.visible = false;

				if (ClientPrefs.data.flashing)
					FlxFlicker.flicker(magenta, 1.1, 0.15, false);

				var item:FlxSprite;
				var option:String;
				switch(curColumn)
				{
					case CENTER: option = optionShit[curSelected]; item = menuItems.members[curSelected];
					case LEFT: option = leftOption; item = leftItem;
					case RIGHT: option = rightOption; item = rightItem;
				}

				FlxFlicker.flicker(item, 1, 0.06, false, false, function(flick:FlxFlicker)
				{
					switch (option)
					{
						case 'story_mode':
							MusicBeatState.switchState(new StoryMenuState());
						case 'freeplay':
							// ===== AUTO-SCAN MOD STATES =====
							var states:Array<{name:String, mod:String}> = scanModStates();
							if (states.length == 0)
							{
								// Không có mod nào có state → dùng Freeplay mặc định
								MusicBeatState.switchState(new FreeplayState());
							}
							else if (states.length == 1)
							{
								// Chỉ có 1 mod có state → dùng luôn
								trace('[MainMenu] Dùng state "' + states[0].name + '" từ mod "' + states[0].mod + '"');
								MusicBeatState.switchState(new funkin.backend.scripting.ModState(states[0].name));
							}
							else
							{
								// Nhiều mod có state → hiện chọn
								trace('[MainMenu] Phát hiện ' + states.length + ' states, mở chọn');
								MusicBeatState.switchState(new FreeplaySelectState(states));
							}

						#if MODS_ALLOWED
						case 'mods':
							MusicBeatState.switchState(new ModsMenuState());
						#end

						#if ACHIEVEMENTS_ALLOWED
						case 'achievements':
							MusicBeatState.switchState(new AchievementsMenuState());
						#end

						case 'credits':
							MusicBeatState.switchState(new CreditsState());
						case 'options':
							MusicBeatState.switchState(new OptionsState());
							OptionsState.onPlayState = false;
							if (PlayState.SONG != null)
							{
								PlayState.SONG.arrowSkin = null;
								PlayState.SONG.splashSkin = null;
								PlayState.stageUI = 'normal';
							}
						case 'donate':
							CoolUtil.browserLoad('https://ninja-muffin24.itch.io/funkin');
							selectedSomethin = false;
							item.visible = true;
						default:
							trace('Menu Item ${option} doesn\'t do anything');
							selectedSomethin = false;
							item.visible = true;
					}
				});

				for (memb in menuItems)
				{
					if(memb == item) continue;
					FlxTween.tween(memb, {alpha: 0}, 0.4, {ease: FlxEase.quadOut});
				}
			}
			else if (controls.justPressed('debug_1') || touchPad.buttonE.justPressed)
			{
				selectedSomethin = true;
				FlxG.mouse.visible = false;
				MusicBeatState.switchState(new MasterEditorMenu());
			}
		}

		super.update(elapsed);
	}

	function changeItem(change:Int = 0)
	{
		if(change != 0) curColumn = CENTER;
		curSelected = FlxMath.wrap(curSelected + change, 0, optionShit.length - 1);
		FlxG.sound.play(Paths.sound('scrollMenu'));
		for (item in menuItems) { item.animation.play('idle'); item.centerOffsets(); }
		var selectedItem:FlxSprite;
		switch(curColumn)
		{
			case CENTER: selectedItem = menuItems.members[curSelected];
			case LEFT: selectedItem = leftItem;
			case RIGHT: selectedItem = rightItem;
		}
		selectedItem.animation.play('selected');
		selectedItem.centerOffsets();
		camFollow.y = selectedItem.getGraphicMidpoint().y;
	}
}

// ===== FREEPLAY SELECT STATE =====
// Hiện khi 2+ mod có state → chọn 1
class FreeplaySelectState extends MusicBeatState
{
	var states:Array<{name:String, mod:String}>;
	var curSelected:Int = 0;
	var items:Array<FlxText> = [];
	var title:FlxText;

	public function new(states:Array<{name:String, mod:String}>)
	{
		super();
		this.states = states;
	}

	override function create()
	{
		super.create();
		FlxG.camera.bgColor = 0xFF000000;

		var bg:FlxSprite = new FlxSprite(-80).loadGraphic(Paths.image('menuDesat'));
		bg.antialiasing = ClientPrefs.data.antialiasing;
		bg.scrollFactor.set(0, 0.25);
		bg.setGraphicSize(Std.int(bg.width * 1.175));
		bg.updateHitbox();
		bg.screenCenter();
		bg.alpha = 0.5;
		add(bg);

		title = new FlxText(0, 30, FlxG.width, 'PHÁT HIỆN ' + states.length + ' MOD STATE', 32);
		title.setFormat(Paths.font("vcr.ttf"), 32, 0xFFFF0000, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		title.scrollFactor.set();
		add(title);

		for (i in 0...states.length)
		{
			var txt:FlxText = new FlxText(0, 100 + i * 50, FlxG.width,
				states[i].mod + ' → ' + states[i].name, 24);
			txt.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			txt.scrollFactor.set();
			add(txt);
			items.push(txt);
		}

		var hint:FlxText = new FlxText(0, FlxG.height - 60, FlxG.width,
			'UP/DOWN để chọn • ACCEPT để vào • BACK để quay lại', 16);
		hint.setFormat(Paths.font("vcr.ttf"), 16, 0xFFAAAAAA, CENTER);
		hint.scrollFactor.set();
		add(hint);

		highlight();
	}

	function highlight()
	{
		for (i in 0...items.length)
		{
			if (i == curSelected)
				items[i].color = 0xFFFFFF00;
			else
				items[i].color = FlxColor.WHITE;
		}
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (controls.UI_UP_P) { curSelected--; if (curSelected < 0) curSelected = items.length - 1; highlight(); FlxG.sound.play(Paths.sound('scrollMenu')); }
		if (controls.UI_DOWN_P) { curSelected++; if (curSelected >= items.length) curSelected = 0; highlight(); FlxG.sound.play(Paths.sound('scrollMenu')); }

		if (controls.ACCEPT)
		{
			FlxG.sound.play(Paths.sound('confirmMenu'));
			trace('[MainMenu] Chọn state "' + states[curSelected].name + '" từ mod "' + states[curSelected].mod + '"');
			MusicBeatState.switchState(new funkin.backend.scripting.ModState(states[curSelected].name));
		}

		if (controls.BACK)
		{
			FlxG.sound.play(Paths.sound('cancelMenu'));
			MusicBeatState.switchState(new MainMenuState());
		}
	}
}
