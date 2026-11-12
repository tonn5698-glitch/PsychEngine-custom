package states;

import backend.psychcne.CNEModManager;

class CNEModsMenuState extends MusicBeatState
{
	var modFolders:Array<String> = [];
	var modRows:Array<FlxText> = [];
	var backText:FlxText;
	var selected:Int = 0;

	override function create()
	{
		super.create();
		CNEModManager.refreshList();

		var bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, 0xFF171923);
		add(bg);

		var title = new FlxText(0, 24, FlxG.width, "CODENAME ENGINE MODS", 32);
		title.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, CENTER);
		add(title);

		var info = new FlxText(40, 70, FlxG.width - 80,
			"Only one CNE mod can be enabled. New folders are added as disabled.", 16);
		info.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.GRAY, CENTER);
		add(info);

		modFolders = CNEModManager.getAvailableMods();
		var enabled = CNEModManager.getEnabledMods();
		if (modFolders.length == 0)
		{
			var empty = new FlxText(40, 150, FlxG.width - 80,
				"No CNE mods found. Put each Codename mod folder inside modsCNE/.", 22);
			empty.setFormat(Paths.font("vcr.ttf"), 22, FlxColor.WHITE, CENTER);
			add(empty);
		}
		else
		{
			for (i in 0...modFolders.length)
			{
				var folder = modFolders[i];
				var isEnabled = enabled.contains(folder);
				var row = new FlxText(90, 130 + i * 48, FlxG.width - 180, "", 22);
				row.text = (isEnabled ? "[ON]  " : "[OFF] ") + folder;
				row.setFormat(Paths.font("vcr.ttf"), 22, isEnabled ? FlxColor.GREEN : FlxColor.WHITE, LEFT);
				row.ID = i;
				modRows.push(row);
				add(row);
			}
			if (CNEModManager.hasInvalidSelection())
			{
				var warning = new FlxText(40, FlxG.height - 100, FlxG.width - 80,
					"Invalid modsList: more than one CNE mod is enabled.", 16);
				warning.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.RED, CENTER);
				add(warning);
			}
		}
		backText = new FlxText(40, FlxG.height - 52, FlxG.width - 80, "BACK", 20);
		backText.setFormat(Paths.font("vcr.ttf"), 20, FlxColor.YELLOW, CENTER);
		add(backText);
		updateSelection();
	}

	function updateSelection():Void
	{
		for (i in 0...modRows.length)
		{
			var isEnabled = CNEModManager.getEnabledMods().contains(modFolders[i]);
			modRows[i].color = i == selected ? FlxColor.YELLOW : (isEnabled ? FlxColor.GREEN : FlxColor.WHITE);
		}
	}

	function toggleMod(index:Int):Void
	{
		if (index < 0 || index >= modFolders.length) return;
		var folder = modFolders[index];
		var currentlyEnabled = CNEModManager.getEnabledMods().contains(folder);
		CNEModManager.setEnabled(folder, !currentlyEnabled);
		if (CNEModManager.isActive()) MusicBeatState.switchState(new CNEModsMenuState());
		else MusicBeatState.switchState(new ModsMenuState());
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);
		if (FlxG.keys.justPressed.ESCAPE || FlxG.keys.justPressed.BACKSPACE)
		{
			MusicBeatState.switchState(new ModsMenuState());
			return;
		}
		if (FlxG.keys.justPressed.UP && modRows.length > 0)
		{
			selected = (selected - 1 + modRows.length) % modRows.length;
			updateSelection();
		}
		if (FlxG.keys.justPressed.DOWN && modRows.length > 0)
		{
			selected = (selected + 1) % modRows.length;
			updateSelection();
		}
		if (controls.mobileC && TouchUtil.justReleased)
		{
			if (TouchUtil.overlaps(backText))
			{
				MusicBeatState.switchState(new ModsMenuState());
				return;
			}
			for (i in 0...modRows.length)
			{
				if (TouchUtil.overlaps(modRows[i]))
				{
					toggleMod(i);
					return;
				}
			}
		}
		if (FlxG.mouse.justPressed)
		{
			if (FlxG.mouse.overlaps(backText))
			{
				MusicBeatState.switchState(new ModsMenuState());
				return;
			}
			for (i in 0...modRows.length)
			{
				if (FlxG.mouse.overlaps(modRows[i]))
				{
					toggleMod(i);
					return;
				}
			}
		}
		if (FlxG.keys.justPressed.ENTER && modRows.length > 0) toggleMod(selected);
	}
}
