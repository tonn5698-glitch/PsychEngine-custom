package backend.psychcne;

import backend.Mods;

#if sys
import sys.FileSystem;
import sys.io.File;
#end

/**
 * Owns the isolated Codename mod list.
 * It never reads from or writes to the Psych Engine modsList.txt.
 */
class CNEModManager
{
	public static inline var ROOT_NAME:String = "modsCNE";
	static var activeMod:String = null;
	static var invalidEnabledCount:Int = 0;

	public static function rootPath():String
	{
		return #if android StorageUtil.getExternalStorageDirectory() #else Sys.getCwd() #end + ROOT_NAME + "/";
	}

	public static function listPath():String
	{
		return rootPath() + "modsList.txt";
	}

	static function ensureRoot():Void
	{
		#if sys
		var root = rootPath();
		if (!FileSystem.exists(root)) FileSystem.createDirectory(root);
		var path = listPath();
		if (!FileSystem.exists(path)) File.saveContent(path, "");
		#end
	}

	public static function getAvailableMods():Array<String>
	{
		var result:Array<String> = [];
		#if sys
		ensureRoot();
		for (entry in FileSystem.readDirectory(rootPath()))
		{
			var path = rootPath() + entry;
			if (FileSystem.isDirectory(path) && entry != "." && entry != "..")
				result.push(entry);
		}
		#end
		result.sort(Reflect.compare);
		return result;
	}

	static function readEntries():Array<Array<String>>
	{
		var result:Array<Array<String>> = [];
		#if sys
		ensureRoot();
		for (line in File.getContent(listPath()).split("\n"))
		{
			var clean = StringTools.trim(StringTools.replace(line, "\r", ""));
			if (clean.length == 0) continue;
			var parts = clean.split("|");
			if (parts[0].length == 0) continue;
			result.push([parts[0], parts.length > 1 && StringTools.trim(parts[1]) == "1" ? "1" : "0"]);
		}
		#end
		return result;
	}

	static function writeEntries(entries:Array<Array<String>>):Void
	{
		#if sys
		ensureRoot();
		var lines:Array<String> = [];
		for (entry in entries) lines.push(entry[0] + "|" + entry[1]);
		File.saveContent(listPath(), lines.join("\n"));
		#end
	}

	/**
	 * Adds newly discovered folders as disabled. Existing enable states and
	 * ordering are retained. This is intentionally different from Psych's
	 * auto-enable-on-first-scan behavior.
	 */
	public static function refreshList():Void
	{
		#if sys
		var entries = readEntries();
		var known:Array<String> = [for (entry in entries) entry[0]];
		for (folder in getAvailableMods())
		{
			if (!known.contains(folder))
			{
				entries.push([folder, "0"]);
				known.push(folder);
			}
		}
		var available = getAvailableMods();
		entries = entries.filter(function(entry) return available.contains(entry[0]));
		// Repair legacy/manual lists with multiple enabled entries deterministically.
		var keptEnabled = false;
		for (entry in entries)
		{
			if (entry[1] == "1")
			{
				if (keptEnabled) entry[1] = "0";
				else keptEnabled = true;
			}
		}
		writeEntries(entries);
		#end
		refreshMode();
	}

	public static function getEnabledMods():Array<String>
	{
		var enabled:Array<String> = [];
		for (entry in readEntries())
			if (entry[1] == "1") enabled.push(entry[0]);
		return enabled;
	}

	public static function getActiveMod():String
	{
		refreshMode();
		return activeMod;
	}

	public static function hasInvalidSelection():Bool
	{
		refreshMode();
		return invalidEnabledCount > 1;
	}

	public static function isActive():Bool
	{
		refreshMode();
		return activeMod != null;
	}

	/** Exactly one CNE mod may be enabled. */
	public static function setEnabled(folder:String, enabled:Bool):Bool
	{
		if (folder == null || !getAvailableMods().contains(folder)) return false;
		var entries = readEntries();
		var found = false;
		for (entry in entries)
		{
			if (entry[0] == folder)
			{
				entry[1] = enabled ? "1" : "0";
				found = true;
			}
			else entry[1] = "0";
		}
		if (!found) entries.push([folder, enabled ? "1" : "0"]);
		writeEntries(entries);
		refreshMode();
		// Keep the Psych modsList.txt untouched; only switch the in-memory layer.
		if (activeMod != null)
		{
			Mods.currentModDirectory = "";
			Mods.pushGlobalMods();
		}
		else
		{
			Mods.loadTopMod();
			Mods.pushGlobalMods();
		}
		resetPsychGlobalScripts();
		return true;
	}

	/** Destroy the currently loaded Psych global scripts so a state restart
	 * can recreate only the scripts belonging to the newly active engine layer. */
	static function resetPsychGlobalScripts():Void
	{
		#if (LUA_ALLOWED || HSCRIPT_ALLOWED)
		var globals = psychlua.PsychGlobalScript.instance;
		if (globals != null)
		{
			#if LUA_ALLOWED
			if (globals.luaArray != null)
				for (lua in globals.luaArray) if (lua != null) lua.stop();
			globals.luaArray = [];
			#end
			#if HSCRIPT_ALLOWED
			if (globals.hscriptArray != null)
				for (script in globals.hscriptArray) if (script != null) script.destroy();
			globals.hscriptArray = [];
			#end
		}
		psychlua.PsychGlobalScript.instance = null;
		#end
	}

	public static function refreshMode():Void
	{
		var enabled = getEnabledMods();
		invalidEnabledCount = enabled.length > 1 ? enabled.length : 0;
		activeMod = enabled.length == 1 ? enabled[0] : null;
	}
}
