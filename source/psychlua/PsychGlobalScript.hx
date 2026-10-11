package psychlua;

import backend.MusicBeatState;
import backend.Mods;
import backend.Paths;

#if (LUA_ALLOWED || HSCRIPT_ALLOWED)
class PsychGlobalScript
{
	public static var instance:PsychGlobalScript;

	#if LUA_ALLOWED public var luaArray:Array<FunkinLua> = []; #end
	#if HSCRIPT_ALLOWED public var hscriptArray:Array<HScript> = []; #end

	/** Chỉ chạy 1 lần duy nhất — do MusicBeatState.create() gọi có guard sẵn. */
	public static function init()
	{
		if (instance != null) return;
		instance = new PsychGlobalScript();
		instance.loadScripts();
	}

	public function new() {}

	function loadScripts()
	{
		var owner:MusicBeatState = MusicBeatState.getState();
		var loadedPaths:Array<String> = [];

		// 1) Scan shared (game built-in)
		for (folder in Mods.directoriesWithFile(Paths.getSharedPath(), 'customStates/global/'))
		{
			if (!loadedPaths.contains(folder))
			{
				loadFolder(folder);
				loadedPaths.push(folder);
			}
		}

		// 2) Scan ONLY the currently active mod.
		// Do not scan every enabled/installed mod: a global script must belong
		// to the mod that is actually running.
		#if MODS_ALLOWED
		var activeMod:String = Mods.currentModDirectory;
		if (activeMod != null && activeMod.length > 0)
		{
			var modPath:String = Paths.mods(activeMod + '/customStates/global/');
			if (sys.FileSystem.exists(modPath) && !loadedPaths.contains(modPath))
			{
				loadFolder(modPath);
				loadedPaths.push(modPath);
			}

			for (root in Paths.modRootDirs)
			{
				var base:String = Paths.modsRootByName(root) + activeMod + '/data/';
				for (name in ['global.hx', 'global.lua'])
				{
					var file:String = base + name;
					if (sys.FileSystem.exists(file) && !loadedPaths.contains(file))
					{
						loadGlobalFile(file, activeMod);
						loadedPaths.push(file);
					}
				}
			}
		}
		#end

		callOnScripts('onCreate', []);
	}

	#if (LUA_ALLOWED || HSCRIPT_ALLOWED)
	function loadGlobalFile(file:String, modName:String):Void
	{
		var owner:MusicBeatState = MusicBeatState.getState();
		var ext:String = haxe.io.Path.extension(file).toLowerCase();
		#if LUA_ALLOWED
		if (ext == 'lua')
		{
			var lua:FunkinLua = new FunkinLua(file);
			if (owner != null) owner.luaArray.remove(lua);
			luaArray.push(lua);
		}
		#end
		#if HSCRIPT_ALLOWED
		if (ext == 'hx')
		{
			var script:HScript = new HScript(null, file);
			hscriptArray.push(script);
		}
		#end
	}

	function loadFolder(folder:String)
	{
		var owner:MusicBeatState = MusicBeatState.getState();
		for (file in Paths.readDirectory(folder))
		{
			#if LUA_ALLOWED
			if (file.toLowerCase().endsWith('.lua'))
			{
				var lua = new FunkinLua(folder + file);
				if (owner != null) owner.luaArray.remove(lua);
				luaArray.push(lua);
			}
			#end

			#if HSCRIPT_ALLOWED
			if (file.toLowerCase().endsWith('.hx'))
			{
				var script = new HScript(null, folder + file);
				hscriptArray.push(script);
			}
			#end
		}
	}
	#end

	public function callOnScripts(funcToCall:String, args:Array<Dynamic> = null):Void
	{
		if(args == null) args = [];

		#if LUA_ALLOWED
		for (script in luaArray)
			if(script != null && !script.closed)
				script.call(funcToCall, args);
		#end

		#if HSCRIPT_ALLOWED
		for (script in hscriptArray)
			if(script != null && script.exists(funcToCall))
				script.call(funcToCall, args);
		#end
	}

	public static function notifyStateSwitch(stateName:String)
	{
		if (instance != null) instance.callOnScripts('onStateSwitch', [stateName]);
	}
}
#end
