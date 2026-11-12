package backend.psychcne;

#if HSCRIPT_ALLOWED
import haxe.ds.ObjectMap;
#end

/**
 * Codename-style script lifecycle using hscript-improved alongside Psych's Iris runtime.
 * Supports typed/importing HScript state/substate scripts, ScriptPack, and global scripts.
 */
class CNEScriptRuntime
{
	#if HSCRIPT_ALLOWED
	static var statePacks:ObjectMap<backend.MusicBeatState, Array<CNEScript>> = new ObjectMap();
	static var subStatePacks:ObjectMap<backend.MusicBeatSubstate, Array<CNEScript>> = new ObjectMap();
	static var postCreatePending:ObjectMap<backend.MusicBeatState, Bool> = new ObjectMap();
	static var subPostCreatePending:ObjectMap<backend.MusicBeatSubstate, Bool> = new ObjectMap();
	static var globalScripts:Array<CNEScript> = [];
	static var eventScripts:Map<String, CNEScript> = [];
	static var noteTypeScripts:Map<String, CNEScript> = [];
	static var loadedGlobalMod:String = null;
	#end

	#if sys
	static function scriptFiles(folder:String, recursive:Bool = false):Array<String>
	{
		var result:Array<String> = [];
		if (!sys.FileSystem.exists(folder) || !sys.FileSystem.isDirectory(folder)) return result;
		var entries = sys.FileSystem.readDirectory(folder);
		entries.sort(Reflect.compare);
		for (entry in entries)
		{
			var path = folder + (StringTools.endsWith(folder, "/") ? "" : "/") + entry;
			if (sys.FileSystem.isDirectory(path))
			{
				if (recursive) result = result.concat(scriptFiles(path, true));
				continue;
			}
			var ext = haxe.io.Path.extension(entry).toLowerCase();
			if (["hx", "hscript", "hsc", "hxs"].contains(ext)) result.push(path);
		}
		return result;
	}
	#end

	#if HSCRIPT_ALLOWED
	static function configureScript(script:CNEScript, parent:Dynamic):Void
	{
		if (script == null) return;
		script.setParent(parent);
		script.set("state", parent);
		script.set("Script", funkin.backend.scripting.Script);
		script.set("ScriptPack", funkin.backend.scripting.ScriptPack);
		script.set("cameraFocus", cameraFocus);
		script.set("cameraFocusPosition", cameraFocusPosition);
		script.set("cameraResetFocus", cameraResetFocus);
	}

	public static function cameraFocus(target:String, offsetX:Float = 0, offsetY:Float = 0):Void
	{
		var state:Dynamic = flixel.FlxG.state;
		if (!Std.isOfType(state, states.PlayState)) return;
		var play:states.PlayState = cast state;
		switch (target == null ? "" : target.toLowerCase())
		{
			case "player" | "boyfriend" | "bf":
				play.moveCamera(false);
			case "gf" | "girlfriend":
				if (play.gf != null) play.moveCameraToGirlfriend();
			case "opponent" | "dad":
				play.moveCamera(true);
			default:
				var character:Dynamic = null;
				if (play.boyfriendMap.exists(target)) character = play.boyfriendMap.get(target);
				else if (play.dadMap.exists(target)) character = play.dadMap.get(target);
				if (character != null)
				{
					var midpoint = character.getMidpoint();
					play.camFollow.setPosition(midpoint.x, midpoint.y);
					play.camFollow.x += character.cameraPosition[0];
					play.camFollow.y += character.cameraPosition[1];
				}
		}
		play.camFollow.x += offsetX;
		play.camFollow.y += offsetY;
	}

	public static function cameraFocusPosition(x:Float, y:Float):Void
	{
		var state:Dynamic = flixel.FlxG.state;
		if (!Std.isOfType(state, states.PlayState)) return;
		var play:states.PlayState = cast state;
		play.camFollow.setPosition(x, y);
	}

	public static function cameraResetFocus():Void
	{
		cameraFocus("opponent");
	}
	#end

	public static function attachSubState(state:backend.MusicBeatSubstate):Void
	{
		#if (HSCRIPT_ALLOWED && sys)
		if (state == null || !CNEModManager.isActive()) return;
		if (Std.isOfType(state, funkin.backend.scripting.ModSubState)) return;
		if (subStatePacks.exists(state)) return;
		var mod = CNEModManager.getActiveMod();
		var className = Type.getClassName(Type.getClass(state));
		if (className == null) return;
		var shortName = className.substr(className.lastIndexOf(".") + 1);
		var folder = CNEModManager.modPath(mod) + "data/states";
		var pack:Array<CNEScript> = [];
		for (ext in ["hx", "hscript", "hsc", "hxs"])
		{
			var file = folder + "/" + shortName + "." + ext;
			if (!sys.FileSystem.exists(file)) continue;
			try
			{
				var script = new CNEScript(file, state);
				configureScript(script, state);
				pack.push(script);
				callScript(script, "onCreate");
			}
			catch (e:Dynamic) trace('[PsychCNE] Substate script failed: ' + file + ' :: ' + Std.string(e));
		}
		if (pack.length > 0) subStatePacks.set(state, pack);
		#end
	}

	public static function subStateCreate(state:backend.MusicBeatSubstate):Void
	{
		attachSubState(state);
		#if HSCRIPT_ALLOWED
		if (subStatePacks.exists(state)) subPostCreatePending.set(state, true);
		callPack(subStatePacks.get(state), "create");
		#end
	}

	public static function subStatePostCreate(state:backend.MusicBeatSubstate):Void
	{
		#if HSCRIPT_ALLOWED
		callPack(subStatePacks.get(state), "postCreate");
		#end
	}

	public static function subStateUpdate(state:backend.MusicBeatSubstate, elapsed:Float):Void
	{
		#if HSCRIPT_ALLOWED
		if (subPostCreatePending.exists(state))
		{
			subPostCreatePending.remove(state);
			subStatePostCreate(state);
		}
		callPack(subStatePacks.get(state), "preUpdate", [elapsed]);
		callPack(subStatePacks.get(state), "update", [elapsed]);
		#end
	}

	public static function subStatePostUpdate(state:backend.MusicBeatSubstate, elapsed:Float):Void
	{
		#if HSCRIPT_ALLOWED
		callPack(subStatePacks.get(state), "postUpdate", [elapsed]);
		#end
	}

	public static function subStateBeatHit(state:backend.MusicBeatSubstate, beat:Int):Void
	{
		#if HSCRIPT_ALLOWED
		callPack(subStatePacks.get(state), "beatHit", [beat]);
		#end
	}

	public static function subStateStepHit(state:backend.MusicBeatSubstate, step:Int):Void
	{
		#if HSCRIPT_ALLOWED
		callPack(subStatePacks.get(state), "stepHit", [step]);
		#end
	}

	public static function destroySubState(state:backend.MusicBeatSubstate):Void
	{
		#if HSCRIPT_ALLOWED
		var pack = subStatePacks.get(state);
		callPack(pack, "destroy");
		if (pack != null)
		{
			for (script in pack) if (script != null) script.destroy();
			subStatePacks.remove(state);
			subPostCreatePending.remove(state);
		}
		#end
	}

	public static function attachState(state:backend.MusicBeatState):Void
	{
		#if (HSCRIPT_ALLOWED && sys)
		if (state == null || !CNEModManager.isActive()) return;
		if (Std.isOfType(state, funkin.backend.scripting.ModState)) return;
		if (statePacks.exists(state)) return;

		var mod = CNEModManager.getActiveMod();
		var className = Type.getClassName(Type.getClass(state));
		if (className == null) return;
		var shortName = className.substr(className.lastIndexOf(".") + 1);
		var folder = CNEModManager.modPath(mod) + "data/states";
		var files:Array<String> = [];
		for (ext in ["hx", "hscript", "hsc", "hxs"])
		{
			var file = folder + "/" + shortName + "." + ext;
			if (sys.FileSystem.exists(file)) files.push(file);
		}
		if (files.length == 0) return;

		var pack:Array<CNEScript> = [];
		statePacks.set(state, pack);
		for (file in files)
		{
			try
			{
				var script = new CNEScript(file, state);
				configureScript(script, state);
				pack.push(script);
				callScript(script, "onCreate");
			}
			catch (e:Dynamic) trace('[PsychCNE] State script failed: ' + file + ' :: ' + Std.string(e));
		}
		#end
	}

	#if HSCRIPT_ALLOWED
	static function callScript(script:CNEScript, func:String, ?args:Array<Dynamic>):Dynamic
	{
		if (script == null || !script.exists(func)) return null;
		return script.call(func, args == null ? [] : args);
	}

	static function callPack(pack:Array<CNEScript>, func:String, ?args:Array<Dynamic>):Void
	{
		if (pack == null) return;
		for (script in pack) callScript(script, func, args);
	}

	static function ensureGlobals():Void
	{
		if (!CNEModManager.isActive()) return;
		var mod = CNEModManager.getActiveMod();
		if (loadedGlobalMod == mod) return;
		destroyGlobals();
		loadedGlobalMod = mod;
		#if sys
		var root = CNEModManager.modPath(mod);
		var files:Array<String> = [];
		var single = root + "data/global.hx";
		if (sys.FileSystem.exists(single)) files.push(single);
		files = files.concat(scriptFiles(root + "data/globals", true));
		for (file in files)
		{
			try
			{
				var script = new CNEScript(file, flixel.FlxG.state);
				configureScript(script, flixel.FlxG.state);
				globalScripts.push(script);
				callScript(script, "onCreate");
			}
			catch (e:Dynamic) trace('[PsychCNE] Global script failed: ' + file + ' :: ' + Std.string(e));
		}
		#end
	}

	static function getEventScript(name:String):CNEScript
	{
		if (!CNEModManager.isActive() || name == null) return null;
		if (eventScripts.exists(name)) return eventScripts.get(name);
		#if sys
		var folder = CNEModManager.modPath(CNEModManager.getActiveMod()) + "data/events/";
		for (ext in ["hx", "hscript", "hsc", "hxs"])
		{
			var file = folder + name + "." + ext;
			if (!sys.FileSystem.exists(file)) continue;
			try
			{
				var script = new CNEScript(file, flixel.FlxG.state);
				configureScript(script, flixel.FlxG.state);
				eventScripts.set(name, script);
				callScript(script, "onCreate");
				return script;
			}
			catch (e:Dynamic) trace('[PsychCNE] Event script failed: ' + file + ' :: ' + Std.string(e));
		}
		#end
		return null;
	}

	static function getNoteTypeScript(name:String):CNEScript
	{
		if (!CNEModManager.isActive() || name == null || name.length == 0) return null;
		if (noteTypeScripts.exists(name)) return noteTypeScripts.get(name);
		#if sys
		var folder = CNEModManager.modPath(CNEModManager.getActiveMod()) + "data/notetypes/";
		for (ext in ["hx", "hscript", "hsc", "hxs"])
		{
			var file = folder + name + "." + ext;
			if (!sys.FileSystem.exists(file)) continue;
			try
			{
				var script = new CNEScript(file, flixel.FlxG.state);
				configureScript(script, flixel.FlxG.state);
				noteTypeScripts.set(name, script);
				callScript(script, "onCreate");
				return script;
			}
			catch (e:Dynamic) trace('[PsychCNE] Note type script failed: ' + file + ' :: ' + Std.string(e));
		}
		#end
		return null;
	}

	public static function noteHit(note:Dynamic):Bool
	{
		#if HSCRIPT_ALLOWED
		if (note == null) return false;
		var script = getNoteTypeScript(Reflect.field(note, "noteType"));
		if (script == null) return false;
		var event:Dynamic = {note: note, cancelled: false, __continueCalls: false};
		callScript(script, "onNoteHit", [event]);
		return event.cancelled == true;
		#else
		return false;
		#end
	}

	public static function noteMiss(note:Dynamic):Bool
	{
		#if HSCRIPT_ALLOWED
		if (note == null) return false;
		var script = getNoteTypeScript(Reflect.field(note, "noteType"));
		if (script == null) return false;
		var event:Dynamic = {note: note, cancelled: false, __continueCalls: false};
		callScript(script, "onNoteMiss", [event]);
		return event.cancelled == true;
		#else
		return false;
		#end
	}

	public static function eventPushed(name:String, value1:String, value2:String, strumTime:Float):Void
	{
		#if HSCRIPT_ALLOWED
		var script = getEventScript(name);
		if (script != null)
		{
			var eventNote = {event: name, value1: value1, value2: value2, strumTime: strumTime};
			callScript(script, "onEventPushed", [eventNote]);
		}
		#end
	}

	public static function callEvent(name:String, value1:String, value2:String, strumTime:Float):Bool
	{
		#if HSCRIPT_ALLOWED
		var script = getEventScript(name);
		if (script == null) return false;
		var chartEvent = {name: name, params: [value1, value2], strumTime: strumTime};
		var wrapper:Dynamic = {event: chartEvent, cancelled: false, __continueCalls: false};
		callScript(script, "onEvent", [wrapper]);
		return wrapper.cancelled == true;
		#else
		return false;
		#end
	}

	static function destroyGlobals():Void
	{
		for (script in globalScripts)
		{
			callScript(script, "onDestroy");
			if (script != null) script.destroy();
		}
		globalScripts = [];
		for (name => script in eventScripts)
		{
			callScript(script, "onDestroy");
			if (script != null) script.destroy();
		}
		eventScripts = [];
		for (name => script in noteTypeScripts)
		{
			callScript(script, "onDestroy");
			if (script != null) script.destroy();
		}
		noteTypeScripts = [];
		loadedGlobalMod = null;
	}

	public static function globalStateCreate():Void
	{
		ensureGlobals();
		callPack(globalScripts, "onStateSwitch", [flixel.FlxG.state]);
	}

	public static function stateCreate(state:backend.MusicBeatState):Void
	{
		attachState(state);
		if (statePacks.exists(state)) postCreatePending.set(state, true);
		callPack(statePacks.get(state), "create");
	}

	public static function statePostCreate(state:backend.MusicBeatState):Void
		callPack(statePacks.get(state), "postCreate");

	public static function stateUpdate(state:backend.MusicBeatState, elapsed:Float):Void
	{
		ensureGlobals();
		if (postCreatePending.exists(state))
		{
			postCreatePending.remove(state);
			statePostCreate(state);
		}
		callPack(globalScripts, "preUpdate", [elapsed]);
		callPack(globalScripts, "update", [elapsed]);
		callPack(statePacks.get(state), "preUpdate", [elapsed]);
		callPack(statePacks.get(state), "update", [elapsed]);
	}

	public static function statePostUpdate(state:backend.MusicBeatState, elapsed:Float):Void
	{
		callPack(statePacks.get(state), "postUpdate", [elapsed]);
		callPack(globalScripts, "postUpdate", [elapsed]);
	}

	public static function beatHit(state:backend.MusicBeatState, beat:Int):Void
	{
		callPack(globalScripts, "beatHit", [beat]);
		callPack(statePacks.get(state), "beatHit", [beat]);
	}

	public static function stepHit(state:backend.MusicBeatState, step:Int):Void
	{
		callPack(globalScripts, "stepHit", [step]);
		callPack(statePacks.get(state), "stepHit", [step]);
	}

	public static function destroyState(state:backend.MusicBeatState):Void
	{
		var pack = statePacks.get(state);
		callPack(pack, "destroy");
		if (pack != null)
		{
			for (script in pack) if (script != null) script.destroy();
			statePacks.remove(state);
			postCreatePending.remove(state);
		}
	}

	public static function shutdown():Void
	{
		destroyGlobals();
		var states:Array<backend.MusicBeatState> = [];
		for (state in statePacks.keys()) states.push(state);
		for (state in states) destroyState(state);
		var substates:Array<backend.MusicBeatSubstate> = [];
		for (state in subStatePacks.keys()) substates.push(state);
		for (state in substates) destroySubState(state);
		statePacks = new ObjectMap();
		subStatePacks = new ObjectMap();
		for (key in CNEScript.staticVariables.keys()) CNEScript.staticVariables.remove(key);
		postCreatePending = new ObjectMap();
		subPostCreatePending = new ObjectMap();
	}
	#else
	public static function globalStateCreate():Void {}
	public static function stateCreate(state:backend.MusicBeatState):Void {}
	public static function statePostCreate(state:backend.MusicBeatState):Void {}
	public static function stateUpdate(state:backend.MusicBeatState, elapsed:Float):Void {}
	public static function statePostUpdate(state:backend.MusicBeatState, elapsed:Float):Void {}
	public static function beatHit(state:backend.MusicBeatState, beat:Int):Void {}
	public static function stepHit(state:backend.MusicBeatState, step:Int):Void {}
	public static function destroyState(state:backend.MusicBeatState):Void {}
	public static function eventPushed(name:String, value1:String, value2:String, strumTime:Float):Void {}
	public static function callEvent(name:String, value1:String, value2:String, strumTime:Float):Bool return false;
	public static function noteHit(note:Dynamic):Bool return false;
	public static function noteMiss(note:Dynamic):Bool return false;
	public static function shutdown():Void {}
	#end
}
