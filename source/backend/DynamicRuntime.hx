package backend;

#if (HSCRIPT_ALLOWED && sys)
import haxe.Json;
import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;
import flixel.FlxG;
import psychlua.HScript;
import mobile.backend.StorageUtil;

private typedef DynamicScriptEntry =
{
	var path:String;
	var script:HScript;
	var modified:Float;
	var failed:Bool;
}

/**
 * External HScript runtime for Android/Desktop.
 * Scripts are loaded from the writable .PsychEngine/dynamic directory.
 * Only files listed in runtime.json are loaded.
 */
class DynamicRuntime
{
	public static var root(default, null):String = "";
	public static var enabled(default, null):Bool = false;
	public static var autoReload(default, null):Bool = true;

	static var initialized:Bool = false;
	static var entries:Array<DynamicScriptEntry> = [];
	static var selectedFiles:Array<String> = [];
	static var configPath:String = "";
	static var configModified:Float = -1;
	static var lastPoll:Float = 0;
	static var pollInterval:Float = 0.5;
	static var activeState:Dynamic;

	public static function init():Void
	{
		if (initialized) return;
		initialized = true;

		root = StorageUtil.getExternalStorageDirectory() + "dynamic/";
		configPath = root + "runtime.json";

		try
		{
			if (!FileSystem.exists(root)) FileSystem.createDirectory(root);
			if (!FileSystem.exists(root + "scripts")) FileSystem.createDirectory(root + "scripts");
			if (!FileSystem.exists(configPath))
			{
				File.saveContent(configPath, Json.stringify({
					enabled: true,
					autoReload: true,
					pollInterval: 0.5,
					files: ["scripts/main.hx"]
				}, null, "\t"));
			}
			var samplePath = root + "scripts/main.hx";
			if (!FileSystem.exists(samplePath))
			{
				File.saveContent(samplePath,
					'// External HScript entry point. Edit this file while the game is running.\n' +
					'function onCreate() { trace("[DynamicRuntime] external script loaded"); }\n' +
					'function onUpdate(elapsed:Float) {}\n' +
					'function onStateEnter(state) {}\n' +
					'function onStateExit(state) {}\n' +
					'function onDestroy() {}\n');
			}
			loadConfig();
			trace('[DynamicRuntime] root: ' + root);
		}
		catch (e:Dynamic)
		{
			trace('[DynamicRuntime] initialization failed: ' + Std.string(e));
		}
	}

	static function loadConfig():Void
	{
		try
		{
			var data:Dynamic = Json.parse(File.getContent(configPath));
			var wasEnabled = enabled;
			enabled = Reflect.field(data, "enabled") != false;
			autoReload = Reflect.field(data, "autoReload") != false;
			var interval:Dynamic = Reflect.field(data, "pollInterval");
			if (interval != null && Std.parseFloat(Std.string(interval)) > 0)
				pollInterval = Math.max(0.2, Std.parseFloat(Std.string(interval)));

			selectedFiles = [];
			var rawFiles:Dynamic = Reflect.field(data, "files");
			if (Std.isOfType(rawFiles, Array))
			{
				for (value in (cast rawFiles:Array<Dynamic>))
				{
					var rel = normalizeRelativePath(Std.string(value));
					if (rel != null && !selectedFiles.contains(rel)) selectedFiles.push(rel);
				}
			}

			if (!enabled)
			{
				unloadAll();
			}
			else
			{
				for (entry in entries.copy())
					if (!selectedFiles.contains(relativePath(entry.path))) unload(entry);
				for (rel in selectedFiles)
					if (findEntry(rel) == null) load(rel);
			}
			configModified = modifiedTime(configPath);
			if (wasEnabled != enabled) trace('[DynamicRuntime] enabled=' + enabled);
		}
		catch (e:Dynamic)
		{
			trace('[DynamicRuntime] config error: ' + Std.string(e));
		}
	}

	static function normalizeRelativePath(value:String):String
	{
		if (value == null) return null;
		var rel = StringTools.replace(StringTools.trim(value), "\\", "/");
		if (rel.length == 0 || StringTools.startsWith(rel, "/") || Path.extension(rel).toLowerCase() != "hx")
			return null;
		for (part in rel.split("/"))
			if (part == ".." || part == "." || part.length == 0) return null;
		return rel;
	}

	static function relativePath(path:String):String
		return path.indexOf(root) == 0 ? path.substr(root.length) : path;

	static function findEntry(rel:String):DynamicScriptEntry
	{
		for (entry in entries) if (relativePath(entry.path) == rel) return entry;
		return null;
	}

	static function modifiedTime(path:String):Float
	{
		try
		{
			return FileSystem.stat(path).mtime.getTime();
		}
		catch (e:Dynamic)
		{
			return -1;
		}
	}

	static function load(rel:String):Bool
	{
		var path = root + rel;
		if (!FileSystem.exists(path) || FileSystem.isDirectory(path))
		{
			trace('[DynamicRuntime] missing script: ' + rel);
			return false;
		}
		var next:HScript = null;
		try
		{
			next = new HScript(null, path);
			next.set("DynamicRuntime", DynamicRuntime);
			next.set("runtimeRoot", root);
			next.set("reloadDynamicScript", function(file:String) return reload(file));
			next.set("reloadAllDynamicScripts", reloadAll);
			next.set("getDynamicScripts", getLoadedFiles);

			var previous = findEntry(rel);
			if (previous != null)
			{
				if (previous.script != null)
				{
					safeCall(previous, "onDestroy", []);
					previous.script.destroy();
				}
				entries.remove(previous);
			}
			var entry:DynamicScriptEntry = {path: path, script: next, modified: modifiedTime(path), failed: false};
			entries.push(entry);
			safeCall(entry, "onCreate", []);
			if (activeState != null) safeCall(entry, "onStateEnter", [activeState]);
			trace('[DynamicRuntime] loaded: ' + rel);
			return true;
		}
		catch (e:Dynamic)
		{
			if (next != null) next.destroy();
			trace('[DynamicRuntime] load failed (' + rel + '): ' + Std.string(e));
			return false;
		}
	}

	static function unload(entry:DynamicScriptEntry):Void
	{
		if (entry == null) return;
		if (entry.script != null)
		{
			try
			{
				safeCall(entry, "onDestroy", []);
				entry.script.destroy();
			}
			catch (e:Dynamic) trace('[DynamicRuntime] unload error: ' + Std.string(e));
		}
		entries.remove(entry);
	}

	static function safeCall(entry:DynamicScriptEntry, callback:String, args:Array<Dynamic>):Void
	{
		if (entry == null || entry.script == null || entry.failed) return;
		try
		{
			if (entry.script.exists(callback)) entry.script.call(callback, args);
		}
		catch (e:Dynamic)
		{
			entry.failed = true;
			trace('[DynamicRuntime] disabled ' + relativePath(entry.path) + ' after ' + callback + ' error: ' + Std.string(e));
		}
	}

	static function unloadAll():Void
	{
		for (entry in entries.copy()) unload(entry);
	}

	public static function reload(file:String):Bool
	{
		var rel = normalizeRelativePath(file);
		if (rel == null || !selectedFiles.contains(rel)) return false;
		return load(rel);
	}

	public static function reloadAll():Void
	{
		for (rel in selectedFiles) load(rel);
	}

	public static function getLoadedFiles():Array<String>
	{
		var result:Array<String> = [];
		for (entry in entries) result.push(relativePath(entry.path));
		return result;
	}

	/** Called once per frame from FlxG's postUpdate signal. */
	public static function update(elapsed:Float):Void
	{
		if (!initialized) return;

		var now = Sys.time();
		if (now - lastPoll >= pollInterval)
		{
			lastPoll = now;
			var configTime = modifiedTime(configPath);
			if (configTime >= 0 && configTime != configModified) loadConfig();

			if (enabled && autoReload)
			{
				for (entry in entries.copy())
				{
					var currentTime = modifiedTime(entry.path);
					if (currentTime >= 0 && currentTime != entry.modified)
						reload(relativePath(entry.path));
				}
			}
		}

		if (!enabled) return;
		var current = FlxG.state;
		if (current != activeState)
		{
			for (entry in entries) safeCall(entry, "onStateExit", [activeState]);
			activeState = current;
			for (entry in entries)
				if (entry.script != null)
				{
					entry.script.set("game", current);
					entry.script.set("state", current);
					safeCall(entry, "onStateEnter", [current]);
				}
		}
		for (entry in entries)
			if (entry.script != null)
			{
				entry.script.set("game", current);
				entry.script.set("state", current);
				if (!entry.failed) safeCall(entry, "onUpdate", [elapsed]);
			}
	}
}
#else
class DynamicRuntime
{
	public static function init():Void {}
	public static function update(elapsed:Float):Void {}
}
#end
