package psychlua;

#if (LUA_ALLOWED || HSCRIPT_ALLOWED)
class GlobalScript
{
	public static var instance:GlobalScript;

	#if LUA_ALLOWED public var luaArray:Array<FunkinLua> = []; #end
	#if HSCRIPT_ALLOWED public var hscriptArray:Array<HScript> = []; #end

	/** Chỉ chạy 1 lần duy nhất — do MusicBeatState.create() gọi có guard sẵn. */
	public static function init()
	{
		if (instance != null) return;
		instance = new GlobalScript();
		instance.loadScripts();
	}

	function loadScripts()
	{
		#if (LUA_ALLOWED || HSCRIPT_ALLOWED)
		var owner:MusicBeatState = MusicBeatState.getState(); // state đang tạo (thường là state đầu game)

		for (folder in Mods.directoriesWithFile(Paths.getSharedPath(), 'customStates/global/'))
		{
			for (file in Paths.readDirectory(folder))
			{
				#if LUA_ALLOWED
				if (file.toLowerCase().endsWith('.lua'))
				{
					var lua = new FunkinLua(folder + file);
					// new FunkinLua() tự push vào owner.luaArray (patch Bước 3, tài liệu 1) —
					// rút ra để owner.destroy() không lỡ tay hủy mất script global.
					if (owner != null) owner.luaArray.remove(lua);
					luaArray.push(lua);
				}
				#end

				#if HSCRIPT_ALLOWED
				if (file.toLowerCase().endsWith('.hx'))
				{
					var script = new HScript(null, folder + file);
					if (script.exists('onCreate')) script.call('onCreate');
					hscriptArray.push(script);
				}
				#end
			}
		}
		#end

		callOnScripts('onCreate', []);
	}

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
