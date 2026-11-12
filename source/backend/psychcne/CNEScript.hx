package backend.psychcne;

#if HSCRIPT_ALLOWED
import hscript.Expr;
import hscript.Interp;
import hscript.Parser;

class CNEScript
{
	public static var staticVariables:Map<String, Dynamic> = [];
	public var path:String;
	public var fileName:String;
	public var extension:String;
	public var remappedNames:Map<String, String> = [];
	public var active:Bool = true;
	public var didLoad:Bool = false;
	public var interp:Interp;
	public var parser:Parser;
	public var expr:Expr;
	public var parent:Dynamic;
	public var publicVariables:Map<String, Dynamic> = [];
	var importedPaths:Map<String, Bool> = [];

	public function new(path:String, ?parent:Dynamic, autoLoad:Bool = true)
	{
		this.path = resolvePath(path);
		this.fileName = haxe.io.Path.withoutDirectory(this.path);
		this.extension = haxe.io.Path.extension(this.path);
		this.parent = parent;
		parser = new Parser();
		parser.allowJSON = parser.allowMetadata = parser.allowTypes = true;
		parser.preprocessorValues = getPreprocessors();
		interp = new Interp();
		interp.importFailedCallback = importFailedCallback;
		interp.staticVariables = staticVariables;
		interp.allowStaticVariables = interp.allowPublicVariables = true;
		setParent(parent);
		setDefaultVariables();

		try
		{
			var code = readCode(this.path);
			if (code != null && code.length > 0)
			{
				expr = parser.parseString(code, this.path);
				if (autoLoad) load();
			}
		}
		catch (e:Dynamic)
		{
			trace('[PsychCNE] HScript error in ' + this.path + ': ' + Std.string(e));
		}
	}

	static function getPreprocessors():Map<String, Dynamic>
	{
		var values:Map<String, Dynamic> = [
			"CODENAME_ENGINE" => true,
			"CODENAME_VER" => "PsychCNE",
			"PSYCH_CNE" => true
		];
		#if MODS_ALLOWED
		values.set("MODS_ALLOWED", true);
		#end
		#if HSCRIPT_ALLOWED
		values.set("HSCRIPT_ALLOWED", true);
		#end
		#if android
		values.set("android", true);
		#end
		#if windows
		values.set("windows", true);
		#end
		#if linux
		values.set("linux", true);
		#end
		#if mac
		values.set("mac", true);
		#end
		return values;
	}

	function setDefaultVariables():Void
	{
		var defaults:Map<String, Dynamic> = [
			"Std" => Std, "Math" => Math, "Reflect" => Reflect, "StringTools" => StringTools,
			"Json" => haxe.Json, "Xml" => Xml, "Type" => Type, "Date" => Date, "Lambda" => Lambda,
			"FlxG" => flixel.FlxG, "FlxSprite" => flixel.FlxSprite, "FlxBasic" => flixel.FlxBasic,
			"FlxState" => flixel.FlxState, "FlxCamera" => flixel.FlxCamera, "FlxText" => flixel.text.FlxText,
			"FlxTween" => flixel.tweens.FlxTween, "FlxEase" => flixel.tweens.FlxEase,
			"FlxTimer" => flixel.util.FlxTimer, "FlxSound" => flixel.sound.FlxSound,
			"FlxGroup" => flixel.group.FlxGroup, "FlxSpriteGroup" => flixel.group.FlxSpriteGroup,
			"FlxTypedGroup" => flixel.group.FlxGroup.FlxTypedGroup, "FlxColor" => flixel.util.FlxColor,
			"Paths" => backend.Paths, "Conductor" => backend.Conductor, "CoolUtil" => backend.CoolUtil,
			"MusicBeatState" => backend.MusicBeatState, "MusicBeatSubstate" => backend.MusicBeatSubstate,
			"ModState" => funkin.backend.scripting.ModState,
			"ModSubState" => funkin.backend.scripting.ModSubState,
			"Script" => funkin.backend.scripting.Script, "ScriptPack" => funkin.backend.scripting.ScriptPack,
			"FunkinSprite" => funkin.backend.FunkinSprite, "FunkinText" => funkin.backend.FunkinText,
			"PlayState" => states.PlayState, "Character" => objects.Character,
			"engine" => {name: "Codename Engine", compatibility: "PsychCNE"}
		];
		#if sys
		defaults.set("Sys", Sys);
		#end
		for (key => value in defaults) set(key, value);
		set("state", parent);
		set("__script__", this);
		set("disableScript", function() active = false);
		set("trace", Reflect.makeVarArgs(function(args:Array<Dynamic>) {
			var message = args.length > 0 ? Std.string(args.shift()) : "";
			for (arg in args) message += ", " + Std.string(arg);
			haxe.Log.trace('[PsychCNE:' + this.path + '] ' + message);
		}));
	}

	static function readCode(file:String):String
	{
		#if sys
		if (sys.FileSystem.exists(file) && !sys.FileSystem.isDirectory(file)) return sys.io.File.getContent(file);
		#end
		if (openfl.Assets.exists(file)) return openfl.Assets.getText(file);
		return null;
	}

	public static function resolvePath(path:String):String
	{
		if (path == null) return "";
		#if sys
		if (sys.FileSystem.exists(path)) return path;
		if (CNEModManager.isActive())
		{
			var root = CNEModManager.modPath(CNEModManager.getActiveMod());
			var relative = path;
			var modPrefix = "assets/" + CNEModManager.getActiveMod() + "/";
			if (StringTools.startsWith(relative, modPrefix)) relative = relative.substr(modPrefix.length);
			else if (StringTools.startsWith(relative, "assets/")) relative = relative.substr(7);
			var candidates = [root + relative, root + "source/" + relative];
			for (candidate in candidates)
			{
				if (sys.FileSystem.exists(candidate)) return candidate;
				for (ext in ["hx", "hscript", "hsc", "hxs"])
					if (sys.FileSystem.exists(candidate + "." + ext)) return candidate + "." + ext;
			}
		}
		#end
		return path;
	}

	function importFailedCallback(classes:Array<String>, ?asName:String):Bool
	{
		#if sys
		var relative = classes.join("/");
		var root = CNEModManager.isActive() ? CNEModManager.modPath(CNEModManager.getActiveMod()) : "";
		var prefixes = [root + "source/", root, root + "data/", "assets/source/", "assets/"];
		for (prefix in prefixes)
		{
			for (ext in ["hx", "hscript", "hsc", "hxs"])
			{
				var file = prefix + relative + "." + ext;
				if (importedPaths.exists(file)) return true;
				if (!sys.FileSystem.exists(file)) continue;
				try
				{
					var source = sys.io.File.getContent(file);
					parser.line = 1;
					var imported = parser.parseString(source, file);
					@:privateAccess interp.exprReturn(imported);
					importedPaths.set(file, true);
					return true;
				}
				catch (e:Dynamic)
				{
					trace('[PsychCNE] Import failed: ' + file + ': ' + Std.string(e));
					return false;
				}
			}
		}
		#end
		return false;
	}

	public function exists(name:String):Bool
		return interp != null && Reflect.isFunction(interp.variables.get(name));

	public function callOne(name:String, arg:Dynamic):Dynamic
		return call(name, [arg]);

	public function call(name:String, ?args:Array<Dynamic>):Dynamic
	{
		if (!active || interp == null) return null;
		var fn = interp.variables.get(name);
		if (fn == null || !Reflect.isFunction(fn)) return null;
		return Reflect.callMethod(null, fn, args == null ? [] : args);
	}

	public function get(name:String):Dynamic
	{
		if (interp == null) return null;
		var value = interp.variables.get(name);
		return value != null ? value : publicVariables.get(name);
	}

	public function set(name:String, value:Dynamic):Void
	{
		if (interp == null) return;
		interp.variables.set(name, value);
		interp.invalidateCache();
	}

	public function setParent(value:Dynamic):Void
	{
		parent = value;
		if (interp != null) interp.scriptObject = value;
		set("state", value);
	}

	public function setPublicMap(map:Map<String, Dynamic>):Void
	{
		publicVariables = map;
		if (interp != null) interp.publicVariables = map;
	}

	public function reload():Void
	{
		if (interp == null) return;
		var oldParent = parent;
		var oldPublic = publicVariables;
		if (parser != null) parser.line = 1;
		try
		{
			var code = readCode(path);
			if (code != null)
			{
				expr = parser.parseString(code, path);
				setParent(oldParent);
				setPublicMap(oldPublic);
				didLoad = false;
				load();
			}
		}
		catch (e:Dynamic) trace('[PsychCNE] Reload error in ' + path + ': ' + Std.string(e));
	}

	public function load():Void
	{
		if (didLoad || interp == null) return;
		didLoad = true;
		try
		{
			if (expr != null) interp.execute(expr);
			call("new");
		}
		catch (e:Dynamic) trace('[PsychCNE] Load error in ' + path + ': ' + Std.string(e));
	}

	public function trace(value:Dynamic):Void
		haxe.Log.trace('[PsychCNE:' + path + '] ' + Std.string(value));

	public function error(value:String, ?additional:Dynamic):Void
		haxe.Log.trace('[PsychCNE ERROR:' + path + '] ' + value + (additional == null ? '' : ': ' + Std.string(additional)));

	public function destroy():Void
	{
		active = false;
		interp = null;
		parser = null;
		expr = null;
	}
}
#end
