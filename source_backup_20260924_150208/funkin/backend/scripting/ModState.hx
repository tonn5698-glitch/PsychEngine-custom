package funkin.backend.scripting;

import flixel.FlxState;
import backend.MusicBeatState;

/**
 * ModState — state chạy theo file HScript kiểu Codename Engine.
 * Khác CustomState (gọi tên hàm Psych onXxx), ModState cũng gọi tên hàm CNE
 * (new/create/update/destroy/beatHit/stepHit) — gọi CNE trước, rồi fallback Psych.
 *
 * Vị trí script: mods/<Mod>/data/states/<scriptName>.hx (hoặc assets/shared/data/states/...)
 */
class ModState extends backend.MusicBeatState
{
	public static var lastName:String = null;
	public static var lastData:Dynamic = null;
	public var data:Dynamic = null;
	public var scriptName:String;

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
			initHScript(file);
		}
		else
		{
			trace('[ModState] WARNING: không tìm thấy data/states/$scriptName.hx trong mods/');
		}
		#end

		callLifecycle('new');
		callLifecycle('create');
		callLifecycle('onCreate', [scriptName]);
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
		super.destroy();
	}

	function callLifecycle(func:String, ?args:Array<Dynamic>)
		callOnScripts(func, args);

	function findScript():String
	{
		var path:String = 'data/states/$scriptName.hx';

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