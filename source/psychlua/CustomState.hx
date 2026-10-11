package psychlua;

import backend.MusicBeatState;
import backend.Paths;
import backend.Mods;
import backend.CoolUtil;
import states.MainMenuState;
import flixel.FlxG;
import mobile.backend.TouchUtil;

#if MODS_ALLOWED
import sys.FileSystem;
#end

#if LUA_ALLOWED
import psychlua.FunkinLua;
#end
#if HSCRIPT_ALLOWED
import psychlua.HScript;
#end

/**
 * Full FlxState điều khiển hoàn toàn bằng Lua/HScript, tương đương
 * "custom state" của Codename Engine. Khác với CustomSubstate.hx
 * (chỉ mở được đè lên PlayState), CustomState là màn hình độc lập,
 * dùng được cho menu phụ, minigame, cutscene ngoài gameplay, v.v.
 */
class CustomState extends MusicBeatState
{
	public static var instance:CustomState;
	public var stateName:String = 'unnamed';
	public var scriptFile:Null<String> = null;
	var loggedFirstUpdate:Bool = false;

	public function new(stateName:String, ?scriptFile:String)
	{
		this.stateName = stateName;
		this.scriptFile = scriptFile;
		super();
	}

	override function create()
	{
		instance = this;
		super.create(); // MusicBeatState.create() đã lo camera + fade-in
		trace('[CustomState] create state=' + stateName + ', script=' + scriptFile + ', mod=' + Mods.currentModDirectory);

		// CustomState.openState() is also used by ported mods to enter scripts
		// stored in the mod's states/ folder, not only shared customStates/.
		if (scriptFile == null)
			scriptFile = findModStateScript(stateName);

		#if (LUA_ALLOWED || HSCRIPT_ALLOWED)
		if (scriptFile != null)
		{
			var ext:String = haxe.io.Path.extension(scriptFile).toLowerCase();
			#if LUA_ALLOWED
			if (ext == 'lua')
				new FunkinLua(scriptFile);
			#end
			#if HSCRIPT_ALLOWED
			if (ext == 'hx' || ext == 'hscript')
			{
				var script:HScript = new HScript(null, scriptFile);
				hscriptArray.push(script);
			}
			#end
		}
		else for (folder in Mods.directoriesWithFile(Paths.getSharedPath(), 'customStates/$stateName/'))
		{
			#if linux
			for (file in CoolUtil.sortAlphabetically(Paths.readDirectory(folder)))
			#else
			for (file in Paths.readDirectory(folder))
			#end
			{
				#if LUA_ALLOWED
				if (file.toLowerCase().endsWith('.lua'))
					new FunkinLua(folder + file);
				#end

				#if HSCRIPT_ALLOWED
				if (file.toLowerCase().endsWith('.hx'))
					initHScript(folder + file);
				#end
			}
		}
		#end

		#if (LUA_ALLOWED || HSCRIPT_ALLOWED)
		var hasScripts:Bool = false;
		#if LUA_ALLOWED
		hasScripts = hasScripts || luaArray.length > 0;
		#end
		#if HSCRIPT_ALLOWED
		hasScripts = hasScripts || hscriptArray.length > 0;
		#end
		if (!hasScripts)
			trace('[CustomState] Không tìm thấy script nào cho state "$stateName" — kiểm tra lại thư mục customStates/$stateName/');
		#end

		callOnScripts('onCreate', [stateName]);
		callOnScripts('onCreatePost', [stateName]);
	}

	override function update(elapsed:Float)
	{
		if (!loggedFirstUpdate)
		{
			loggedFirstUpdate = true;
			var luaCount:Int = 0;
			var hscriptCount:Int = 0;
			#if LUA_ALLOWED
			luaCount = luaArray.length;
			#end
			#if HSCRIPT_ALLOWED
			hscriptCount = hscriptArray.length;
			#end
			trace('[CustomState] first update state=' + stateName + ', lua=' + luaCount + ', hscript=' + hscriptCount);
		}
		if (TouchUtil.justPressed || FlxG.mouse.justPressed)
			trace('[CustomState] input press state=' + stateName + ', touch=' + TouchUtil.justPressed + ', mouse=' + FlxG.mouse.justPressed);

		callOnScripts('onUpdate', [elapsed]);
		super.update(elapsed);
		callOnScripts('onUpdatePost', [elapsed]);
	}

	static function findModStateScript(name:String):Null<String>
	{
		#if MODS_ALLOWED
		if (name == null || name.length == 0 || name.indexOf('..') >= 0 || name.indexOf('/') >= 0 || name.indexOf(String.fromCharCode(92)) >= 0)
			return null;
		var mod:String = Mods.currentModDirectory;
		if (mod == null || mod.length == 0) return null;
		var candidates:Array<String> = [];
		for (root in Paths.modRootDirs)
		{
			var base:String = Paths.modsRootByName(root) + mod + '/';
			for (ext in ['hx', 'lua', 'hscript'])
			{
				candidates.push(base + 'states/' + name + '.' + ext);
				candidates.push(base + 'data/states/' + name + '.' + ext);
				candidates.push(base + 'customStates/' + name + '/main.' + ext);
				candidates.push(base + 'customStates/' + name + '/' + name + '.' + ext);
			}
		}
		for (path in candidates)
			if (FileSystem.exists(path) && !FileSystem.isDirectory(path))
			{
				trace('[CustomState] resolved ' + name + ' -> ' + path);
				return path;
			}
		#end
		return null;
	}

	override function beatHit()
	{
		super.beatHit();
		callOnScripts('onBeatHit');
	}

	override function stepHit()
	{
		super.stepHit();
		callOnScripts('onStepHit');
	}

	override function destroy()
	{
		callOnScripts('onDestroy', [stateName]);
		instance = null;
		super.destroy(); // luaArray/hscriptArray được MusicBeatState.destroy() dọn
	}

	public static function openState(stateName:String)
	{
		MusicBeatState.switchState(new CustomState(stateName));
	}

	public static function exitToMenu()
	{
		MusicBeatState.switchState(new MainMenuState());
	}
}
