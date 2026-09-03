package psychlua;

import backend.MusicBeatState;
import backend.Paths;
import backend.Mods;
import backend.CoolUtil;
import states.MainMenuState;

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

	public function new(stateName:String)
	{
		this.stateName = stateName;
		super();
	}

	override function create()
	{
		instance = this;
		super.create(); // MusicBeatState.create() đã lo camera + fade-in

		#if (LUA_ALLOWED || HSCRIPT_ALLOWED)
		for (folder in Mods.directoriesWithFile(Paths.getSharedPath(), 'customStates/$stateName/'))
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
		if (luaArray.length == 0 && hscriptArray.length == 0)
			trace('[CustomState] Không tìm thấy script nào cho state "$stateName" — kiểm tra lại thư mục customStates/$stateName/');
		#end

		callOnScripts('onCreate', [stateName]);
		callOnScripts('onCreatePost', [stateName]);
	}

	override function update(elapsed:Float)
	{
		callOnScripts('onUpdate', [elapsed]);
		super.update(elapsed);
		callOnScripts('onUpdatePost', [elapsed]);
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

	public static function switchTo(stateName:String)
	{
		MusicBeatState.switchState(new CustomState(stateName));
	}

	public static function exitToMenu()
	{
		MusicBeatState.switchState(new MainMenuState());
	}
}
