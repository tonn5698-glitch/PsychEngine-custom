package funkin.backend.scripting;

import flixel.FlxState;
import backend.MusicBeatState;
import backend.psychcne.CNEModManager;
#if HSCRIPT_ALLOWED
import backend.psychcne.CNEScript;
#end

/**
 * ModState — custom state chạy theo script HScript của Codename Engine.
 * Lifecycle hỗ trợ new/create/postCreate/update/destroy/beatHit/stepHit và alias onXxx của Psych.
 *
 * Script được tìm trong thư mục mod CNE đang hoạt động: data/states/<scriptName>.*
 */
class ModState extends backend.MusicBeatState
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
		this.scriptName = _stateName;
		if (_data != null) lastData = _data;
		data = lastData;
	}

	override function create()
	{
		super.create();

		#if HSCRIPT_ALLOWED
		var file:String = findScript();
		trace('[ModState] create state=' + scriptName + ' scriptFile=' + file);
		if (file != null)
		{
			trace('[ModState] load script: ' + file);
			initCNEScript(file);
		}
		else
		{
			trace('[ModState] WARNING: không tìm thấy data/states/$scriptName.hx trong mods/');
		}
		#end

		callLifecycle('onCreate', [scriptName]);
		callLifecycle('create');
		callLifecycle('postCreate', []);
		callLifecycle('createPost', []);
		callLifecycle('onCreatePost', [scriptName]);
	}

	override function update(elapsed:Float)
	{
		callLifecycle('update', [elapsed]);
		callLifecycle('onUpdate', [elapsed]);
		super.update(elapsed);
		callLifecycle('postUpdate', [elapsed]);
		callLifecycle('onUpdatePost', [elapsed]);
	}

	override function beatHit()
	{
		super.beatHit();
		callLifecycle('beatHit', [curBeat]);
		callLifecycle('onBeatHit');
	}

	override function stepHit()
	{
		super.stepHit();
		callLifecycle('stepHit', [curStep]);
		callLifecycle('onStepHit');
	}

	override function destroy()
	{
		callLifecycle('destroy');
		callLifecycle('onDestroy', [scriptName]);
		#if HSCRIPT_ALLOWED
		for (script in cneScripts) if (script != null) script.destroy();
		cneScripts = [];
		#end
		super.destroy();
	}

	#if HSCRIPT_ALLOWED
	function initCNEScript(file:String):Void
	{
		try
		{
			var script = new CNEScript(file, this);
			cneScripts.push(script);
		}
		catch (e:Dynamic) trace('[ModState] Script load failed: ' + Std.string(e));
	}
	#end

	function callLifecycle(func:String, ?args:Array<Dynamic>):Void
	{
		#if HSCRIPT_ALLOWED
		for (script in cneScripts) if (script != null) script.call(func, args == null ? [] : args);
		#end
	}

	function findScript():String
	{
		var path:String = 'data/states/$scriptName.hx';

		// CNE mode is isolated: never fall through to Psych mods or their globals.
		if (CNEModManager.isActive())
		{
			var active:String = CNEModManager.getActiveMod();
			var base:String = CNEModManager.modPath(active) + 'data/states/' + scriptName;
			#if sys
			for (ext in ['hx', 'hscript', 'hsc', 'hxs'])
			{
				var cnePath:String = base + '.' + ext;
				if (sys.FileSystem.exists(cnePath)) return cnePath;
			}
			#end
			return null;
		}

		#if MODS_ALLOWED
		// 1) Quét mọi thư mục mod có trong mods/ (kể cả không phải current)
		for (mod in backend.Mods.getModDirectories())
		{
			var p:String = backend.Paths.mods(mod + '/' + path);
			if (sys.FileSystem.exists(p)) return p;
		}
		// 2) Fallback: global mods
		for (mod in backend.Mods.getGlobalMods())
		{
			var p:String = backend.Paths.mods(mod + '/' + path);
			if (sys.FileSystem.exists(p)) return p;
		}
		#end

		// 3) Game gốc (shared asset — hiếm khi có trên Android)
		var shared:String = backend.Paths.getSharedPath(path);
		#if MODS_ALLOWED
		if (sys.FileSystem.exists(shared)) return shared;
		#else
		if (openfl.utils.Assets.exists(shared)) return shared;
		#end
		return null;
	}

	public static function open(_stateName:String, ?_data:Dynamic)
		backend.MusicBeatState.switchState(new ModState(_stateName, _data));
}