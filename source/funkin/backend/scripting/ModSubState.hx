package funkin.backend.scripting;

import backend.MusicBeatSubstate;
import backend.psychcne.CNEModManager;
#if HSCRIPT_ALLOWED
import backend.psychcne.CNEScript;
#end

/** CNE-compatible custom substate backed by the hscript-improved adapter. */
class ModSubState extends MusicBeatSubstate
{
	public static var lastName:String = null;
	public static var lastData:Dynamic = null;
	public var data:Dynamic = null;
	public var scriptName:String;
	#if HSCRIPT_ALLOWED
	var cneScripts:Array<CNEScript> = [];
	#end

	public function new(_stateName:String, ?_data:Dynamic)
	{
		super();
		if (_stateName != null && _stateName != lastName)
		{
			lastName = _stateName;
			lastData = null;
		}
		scriptName = lastName;
		if (_data != null) lastData = _data;
		data = lastData;
	}

	override function create()
	{
		super.create();
		#if (HSCRIPT_ALLOWED && sys)
		var file = findScript();
		if (file != null)
		{
			try
			{
				var script = new CNEScript(file, this);
				cneScripts.push(script);
			}
			catch (e:Dynamic) trace('[ModSubState] Script load failed: ' + Std.string(e));
		}
		#end
		callScripts("onCreate", [scriptName]);
		callScripts("create");
		callScripts("postCreate");
	}

	override function update(elapsed:Float)
	{
		callScripts("preUpdate", [elapsed]);
		callScripts("update", [elapsed]);
		super.update(elapsed);
		callScripts("postUpdate", [elapsed]);
	}

	override function stepHit():Void
	{
		super.stepHit();
		callScripts("stepHit", [curStep]);
	}

	override function beatHit():Void
	{
		super.beatHit();
		callScripts("beatHit", [curBeat]);
	}

	override function destroy()
	{
		callScripts("destroy");
		callScripts("onDestroy", [scriptName]);
		#if HSCRIPT_ALLOWED
		for (script in cneScripts) if (script != null) script.destroy();
		cneScripts = [];
		#end
		super.destroy();
	}

	function callScripts(name:String, ?args:Array<Dynamic>):Void
	{
		#if HSCRIPT_ALLOWED
		for (script in cneScripts)
		{
			if (script == null) continue;
			script.call(name, args == null ? [] : args);
		}
		#end
	}

	function findScript():String
	{
		if (!CNEModManager.isActive()) return null;
		var root = CNEModManager.modPath(CNEModManager.getActiveMod()) + "data/states/";
		#if sys
		for (ext in ["hx", "hscript", "hsc", "hxs"])
		{
			var path = root + scriptName + "." + ext;
			if (sys.FileSystem.exists(path)) return path;
		}
		#end
		return null;
	}
}
