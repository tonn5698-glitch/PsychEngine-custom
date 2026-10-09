package psychlua;

import flixel.FlxState;
import backend.Mods;
import backend.Paths;
import haxe.io.Path;

#if MODS_ALLOWED
import sys.FileSystem;
import sys.io.File;
#end

/**
 * Resolves mod state overrides before the requested FlxState is switched in.
 * Config: mods/<mod>/data/engine.json
 * {
 *   "stateScripts": {
 *     "folder": "states",
 *     "overrides": { "MainMenuState": "TonMenu" }
 *   }
 * }
 */
class StateScriptManager
{
	public static var stateFolder:String = "states";
	static var overrides:Map<String, String> = new Map();
	static var overrideMods:Map<String, String> = new Map();
	static var configLoaded:Bool = false;
	static var registeredOverrides:Map<String, String> = new Map();
	static var registeredOverrideMods:Map<String, String> = new Map();

	public static function registerStateOverride(originalState:String, customState:String, ?modName:String):Bool
	{
		if (originalState == null || customState == null) return false;
		originalState = normalizeStateName(originalState);
		customState = StringTools.trim(customState);
		if (originalState.length == 0 || customState.length == 0) return false;
		registeredOverrides.set(originalState, customState);
		overrides.set(originalState, customState);
		if (modName == null || modName.length == 0) modName = Mods.currentModDirectory;
		if (modName != null && modName.length > 0)
		{
			overrideMods.set(originalState, modName);
			registeredOverrideMods.set(originalState, modName);
		}
		trace('[StateScriptManager] Registered state override: ' + originalState + ' -> ' + customState);
		return true;
	}

	public static function resolveState(nextState:FlxState):FlxState
	{
		if (nextState == null || Std.isOfType(nextState, CustomState)) return nextState;
		loadConfig();
		var className:String = Type.getClassName(Type.getClass(nextState));
		if (className == null) return nextState;
		var shortName:String = normalizeStateName(className);
		var lookupName:String = shortName;
		var customName:String = overrides.get(lookupName);
		if (customName == null && StringTools.endsWith(shortName, 'State'))
		{
			lookupName = shortName.substr(0, shortName.length - 5);
			customName = overrides.get(lookupName);
		}
		if (customName == null && !StringTools.endsWith(shortName, 'State'))
		{
			lookupName = shortName + 'State';
			customName = overrides.get(lookupName);
		}
		if (customName == null) { lookupName = className; customName = overrides.get(className); }
		if (customName == null) return nextState;

		var modName:String = overrideMods.get(lookupName);
		var scriptPath:String = findStateFile(customName, modName);
		if (scriptPath == null)
		{
			trace('[StateScriptManager] Missing custom state "' + customName + '" for ' + shortName + '; using original state.');
			return nextState;
		}
		trace('[StateScriptManager] Redirecting ' + shortName + ' -> ' + scriptPath);
		return new CustomState(customName, scriptPath);
	}

	public static function getStateFolder():String
	{
		loadConfig();
		return stateFolder;
	}

	static function loadConfig():Void
	{
		if (configLoaded) return;
		configLoaded = true;
		#if MODS_ALLOWED
		var candidates:Array<String> = [];
		for (mod in Mods.parseList().enabled) if (!candidates.contains(mod)) candidates.push(mod);
		for (mod in Mods.getModDirectories()) if (!candidates.contains(mod)) candidates.push(mod);
		for (mod in candidates)
		{
			var base:String = findModDir(mod);
			if (base == null) continue;
			var configPath:String = null;
			for (candidate in [base + "/data/engine.json", base + "/data/Engine.json"])
				if (FileSystem.exists(candidate)) { configPath = candidate; break; }
			if (configPath == null) continue;
			try
			{
				var json:Dynamic = haxe.Json.parse(File.getContent(configPath));
				var cfg:Dynamic = Reflect.field(json, "stateScripts");
				if (cfg == null) cfg = Reflect.field(json, "states");
				if (cfg == null) continue;
				var folder:Dynamic = Reflect.field(cfg, "folder");
				if (folder != null && StringTools.trim(Std.string(folder)).length > 0)
					stateFolder = sanitizeFolder(Std.string(folder));
				var mapping:Dynamic = Reflect.field(cfg, "overrides");
				if (mapping != null)
				{
					for (key in Reflect.fields(mapping))
					{
						var value:Dynamic = Reflect.field(mapping, key);
						if (value == null) continue;
						var normalized:String = normalizeStateName(key);
						overrides.set(normalized, Std.string(value));
						overrideMods.set(normalized, mod);
					}
				}
				trace('[StateScriptManager] Loaded state config: ' + configPath);
				// Merge one config only, matching EngineJSON's first-mod-wins behavior.
				break;
			}
			catch (e:Dynamic)
			{
				trace('[StateScriptManager] Invalid config ' + configPath + ': ' + e);
			}
		}
		#end
		for (key in registeredOverrides.keys())
		{
			overrides.set(key, registeredOverrides.get(key));
			var mod:String = registeredOverrideMods.get(key);
			if (mod != null) overrideMods.set(key, mod);
		}
	}

	static function findStateFile(name:String, preferredMod:String):Null<String>
	{
		#if MODS_ALLOWED
		var clean:String = StringTools.replace(name, "\\", "/");
		if (clean.indexOf("..") >= 0 || clean.startsWith("/")) return null;
		var fileName:String = clean;
		if (!['hx', 'lua', 'hscript'].contains(Path.extension(fileName).toLowerCase()))
			fileName += ".hx";

		var mods:Array<String> = [];
		if (preferredMod != null && preferredMod.length > 0) mods.push(preferredMod);
		for (mod in Mods.parseList().enabled) if (!mods.contains(mod)) mods.push(mod);
		for (mod in Mods.getModDirectories()) if (!mods.contains(mod)) mods.push(mod);
		for (mod in mods)
		{
			var base:String = findModDir(mod);
			if (base == null) continue;
			var path:String = base + "/" + stateFolder + "/" + fileName;
			if (FileSystem.exists(path) && !FileSystem.isDirectory(path)) return path;
			// Support the older data/states convention used by this engine.
			path = base + "/data/states/" + fileName;
			if (FileSystem.exists(path) && !FileSystem.isDirectory(path)) return path;
		}
		#end
		return null;
	}

	#if MODS_ALLOWED
	static function findModDir(name:String):Null<String>
	{
		for (root in Paths.modRootDirs)
		{
			var dir:String = Path.join([Paths.modsRootByName(root), name]);
			if (FileSystem.exists(dir) && FileSystem.isDirectory(dir)) return dir;
		}
		return null;
	}
	#end

	static function normalizeStateName(name:String):String
	{
		if (name == null) return "";
		var result:String = name;
		var dot:Int = result.lastIndexOf(".");
		if (dot >= 0) result = result.substr(dot + 1);
		return result;
	}

	static function sanitizeFolder(folder:String):String
	{
		folder = StringTools.replace(StringTools.trim(folder), "\\", "/");
		while (StringTools.startsWith(folder, "/")) folder = folder.substr(1);
		if (folder.indexOf("..") >= 0) return "states";
		while (StringTools.endsWith(folder, "/")) folder = folder.substr(0, folder.length - 1);
		return folder.length == 0 ? "states" : folder;
	}
}
