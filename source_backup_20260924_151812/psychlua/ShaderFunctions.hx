package psychlua;

#if (!flash && sys)
import flixel.addons.display.FlxRuntimeShader;
import openfl.filters.ShaderFilter;
#end

class ShaderFunctions
{
	public static function implement(funk:FunkinLua)
	{
		var lua = funk.lua;
		// shader shit
		funk.addLocalCallback("initLuaShader", function(name:String) {
			if(!ClientPrefs.data.shaders) return false;

			#if (!flash && MODS_ALLOWED && sys)
			return funk.initLuaShader(name);
			#else
			FunkinLua.luaTrace("initLuaShader: Platform unsupported for Runtime Shaders!", false, false, FlxColor.RED);
			#end
			return false;
		});

		funk.addLocalCallback("setSpriteShader", function(obj:String, shader:String) {
			if(!ClientPrefs.data.shaders) return false;

			#if (!flash && sys)
			if(!funk.runtimeShaders.exists(shader) && !funk.initLuaShader(shader))
			{
				FunkinLua.luaTrace('setSpriteShader: Shader $shader is missing!', false, false, FlxColor.RED);
				return false;
			}

			var split:Array<String> = obj.split('.');
			var leObj:FlxSprite = LuaUtils.getObjectDirectly(split[0]);
			if(split.length > 1) {
				leObj = LuaUtils.getVarInArray(LuaUtils.getPropertyLoop(split), split[split.length-1]);
			}

			if(leObj != null) {
				var arr:Array<String> = funk.runtimeShaders.get(shader);
				leObj.shader = new shaders.ErrorHandledShader.ErrorHandledRuntimeShader(shader, arr[0], arr[1]);
				return true;
			}
			#else
			FunkinLua.luaTrace("setSpriteShader: Platform unsupported for Runtime Shaders!", false, false, FlxColor.RED);
			#end
			return false;
		});
		Lua_helper.add_callback(lua, "removeSpriteShader", function(obj:String) {
			var split:Array<String> = obj.split('.');
			var leObj:FlxSprite = LuaUtils.getObjectDirectly(split[0]);
			if(split.length > 1) {
				leObj = LuaUtils.getVarInArray(LuaUtils.getPropertyLoop(split), split[split.length-1]);
			}

			if(leObj != null) {
				leObj.shader = null;
				return true;
			}
			return false;
		});

		// Camera shader API
		Lua_helper.add_callback(lua, "setCameraShader", function(camera:String, shader:String) {
			if(!ClientPrefs.data.shaders) return false;

			#if (!flash && sys)
			if(!funk.runtimeShaders.exists(shader) && !funk.initLuaShader(shader))
			{
				FunkinLua.luaTrace('setCameraShader: Shader $shader is missing!', false, false, FlxColor.RED);
				return false;
			}

			var cam:FlxCamera = LuaUtils.getObjectDirectly(camera);
			if(cam == null)
			{
				// Try common camera names
				switch(camera.toLowerCase())
				{
					case 'game' | 'camgame': cam = FlxG.camera;
					case 'hud' | 'camhud' | 'camother': cam = FlxG.camera != null ? FlxG.cameras.list[FlxG.cameras.list.length - 1] : null;
					case 'camfullscreen': cam = FlxG.cameras.list.length > 1 ? FlxG.cameras.list[1] : null;
				}
			}

			if(cam == null)
			{
				FunkinLua.luaTrace('setCameraShader: Camera "$camera" not found!', false, false, FlxColor.RED);
				return false;
			}

			var arr:Array<String> = funk.runtimeShaders.get(shader);
			var shaderObj = new shaders.ErrorHandledShader.ErrorHandledRuntimeShader(shader, arr[0], arr[1]);
			var filter = new ShaderFilter(shaderObj);

			// Store shader name on camera for later reference
			if(cam.filters == null) cam.filters = [];
			cam.filters.push(filter);

			return true;
			#else
			FunkinLua.luaTrace("setCameraShader: Platform unsupported for Runtime Shaders!", false, false, FlxColor.RED);
			#end
			return false;
		});

		Lua_helper.add_callback(lua, "removeCameraShader", function(camera:String) {
			#if (!flash && sys)
			var cam:FlxCamera = LuaUtils.getObjectDirectly(camera);
			if(cam == null)
			{
				switch(camera.toLowerCase())
				{
					case 'game' | 'camgame': cam = FlxG.camera;
					case 'hud' | 'camhud' | 'camother': cam = FlxG.camera != null ? FlxG.cameras.list[FlxG.cameras.list.length - 1] : null;
					case 'camfullscreen': cam = FlxG.cameras.list.length > 1 ? FlxG.cameras.list[1] : null;
				}
			}

			if(cam == null)
			{
				FunkinLua.luaTrace('removeCameraShader: Camera "$camera" not found!', false, false, FlxColor.RED);
				return false;
			}

			if(cam.filters != null)
				cam.filters = [];

			return true;
			#else
			FunkinLua.luaTrace("removeCameraShader: Platform unsupported for Runtime Shaders!", false, false, FlxColor.RED);
			#end
			return false;
		});

		Lua_helper.add_callback(lua, "getCameraShaderCount", function(camera:String) {
			#if (!flash && sys)
			var cam:FlxCamera = LuaUtils.getObjectDirectly(camera);
			if(cam == null)
			{
				switch(camera.toLowerCase())
				{
					case 'game' | 'camgame': cam = FlxG.camera;
					case 'hud' | 'camhud' | 'camother': cam = FlxG.camera != null ? FlxG.cameras.list[FlxG.cameras.list.length - 1] : null;
					case 'camfullscreen': cam = FlxG.cameras.list.length > 1 ? FlxG.cameras.list[1] : null;
				}
			}
			if(cam == null || cam.filters == null) return 0;
			return cam.filters.length;
			#else
			return 0;
			#end
		});

		Lua_helper.add_callback(lua, "addCameraFilter", function(camera:String, shader:String) {
			if(!ClientPrefs.data.shaders) return false;

			#if (!flash && sys)
			var cam:FlxCamera = LuaUtils.getObjectDirectly(camera);
			if(cam == null)
			{
				switch(camera.toLowerCase())
				{
					case 'game' | 'camgame': cam = FlxG.camera;
					case 'hud' | 'camhud' | 'camother': cam = FlxG.camera != null ? FlxG.cameras.list[FlxG.cameras.list.length - 1] : null;
					case 'camfullscreen': cam = FlxG.cameras.list.length > 1 ? FlxG.cameras.list[1] : null;
				}
			}
			if(cam == null)
			{
				FunkinLua.luaTrace('addCameraFilter: Camera "$camera" not found!', false, false, FlxColor.RED);
				return false;
			}
			if(!funk.runtimeShaders.exists(shader) && !funk.initLuaShader(shader))
			{
				FunkinLua.luaTrace('addCameraFilter: Shader "$shader" is missing!', false, false, FlxColor.RED);
				return false;
			}
			var arr:Array<String> = funk.runtimeShaders.get(shader);
			var shaderObj = new shaders.ErrorHandledShader.ErrorHandledRuntimeShader(shader, arr[0], arr[1]);
			var filterObj = new ShaderFilter(shaderObj);
			if(cam.filters == null) cam.filters = [];
			cam.filters.push(filterObj);
			return true;
			#else
			FunkinLua.luaTrace("addCameraFilter: Platform unsupported for Runtime Shaders!", false, false, FlxColor.RED);
			return false;
			#end
		});

		Lua_helper.add_callback(lua, "clearCameraFilters", function(camera:String) {
			#if (!flash && sys)
			var cam:FlxCamera = LuaUtils.getObjectDirectly(camera);
			if(cam == null)
			{
				switch(camera.toLowerCase())
				{
					case 'game' | 'camgame': cam = FlxG.camera;
					case 'hud' | 'camhud' | 'camother': cam = FlxG.camera != null ? FlxG.cameras.list[FlxG.cameras.list.length - 1] : null;
					case 'camfullscreen': cam = FlxG.cameras.list.length > 1 ? FlxG.cameras.list[1] : null;
				}
			}
			if(cam != null) cam.filters = [];
			return true;
			#else
			FunkinLua.luaTrace("clearCameraFilters: Platform unsupported for Runtime Shaders!", false, false, FlxColor.RED);
			return false;
			#end
		});


		Lua_helper.add_callback(lua, "getShaderBool", function(obj:String, prop:String) {
			#if (!flash && MODS_ALLOWED && sys)
			var shader:FlxRuntimeShader = getShader(obj);
			if (shader == null)
			{
				FunkinLua.luaTrace("getShaderBool: Shader is not FlxRuntimeShader!", false, false, FlxColor.RED);
				return null;
			}
			return shader.getBool(prop);
			#else
			FunkinLua.luaTrace("getShaderBool: Platform unsupported for Runtime Shaders!", false, false, FlxColor.RED);
			return null;
			#end
		});
		Lua_helper.add_callback(lua, "getShaderBoolArray", function(obj:String, prop:String) {
			#if (!flash && MODS_ALLOWED && sys)
			var shader:FlxRuntimeShader = getShader(obj);
			if (shader == null)
			{
				FunkinLua.luaTrace("getShaderBoolArray: Shader is not FlxRuntimeShader!", false, false, FlxColor.RED);
				return null;
			}
			return shader.getBoolArray(prop);
			#else
			FunkinLua.luaTrace("getShaderBoolArray: Platform unsupported for Runtime Shaders!", false, false, FlxColor.RED);
			return null;
			#end
		});
		Lua_helper.add_callback(lua, "getShaderInt", function(obj:String, prop:String) {
			#if (!flash && MODS_ALLOWED && sys)
			var shader:FlxRuntimeShader = getShader(obj);
			if (shader == null)
			{
				FunkinLua.luaTrace("getShaderInt: Shader is not FlxRuntimeShader!", false, false, FlxColor.RED);
				return null;
			}
			return shader.getInt(prop);
			#else
			FunkinLua.luaTrace("getShaderInt: Platform unsupported for Runtime Shaders!", false, false, FlxColor.RED);
			return null;
			#end
		});
		Lua_helper.add_callback(lua, "getShaderIntArray", function(obj:String, prop:String) {
			#if (!flash && MODS_ALLOWED && sys)
			var shader:FlxRuntimeShader = getShader(obj);
			if (shader == null)
			{
				FunkinLua.luaTrace("getShaderIntArray: Shader is not FlxRuntimeShader!", false, false, FlxColor.RED);
				return null;
			}
			return shader.getIntArray(prop);
			#else
			FunkinLua.luaTrace("getShaderIntArray: Platform unsupported for Runtime Shaders!", false, false, FlxColor.RED);
			return null;
			#end
		});
		Lua_helper.add_callback(lua, "getShaderFloat", function(obj:String, prop:String) {
			#if (!flash && MODS_ALLOWED && sys)
			var shader:FlxRuntimeShader = getShader(obj);
			if (shader == null)
			{
				FunkinLua.luaTrace("getShaderFloat: Shader is not FlxRuntimeShader!", false, false, FlxColor.RED);
				return null;
			}
			return shader.getFloat(prop);
			#else
			FunkinLua.luaTrace("getShaderFloat: Platform unsupported for Runtime Shaders!", false, false, FlxColor.RED);
			return null;
			#end
		});
		Lua_helper.add_callback(lua, "getShaderFloatArray", function(obj:String, prop:String) {
			#if (!flash && MODS_ALLOWED && sys)
			var shader:FlxRuntimeShader = getShader(obj);
			if (shader == null)
			{
				FunkinLua.luaTrace("getShaderFloatArray: Shader is not FlxRuntimeShader!", false, false, FlxColor.RED);
				return null;
			}
			return shader.getFloatArray(prop);
			#else
			FunkinLua.luaTrace("getShaderFloatArray: Platform unsupported for Runtime Shaders!", false, false, FlxColor.RED);
			return null;
			#end
		});


		Lua_helper.add_callback(lua, "setShaderBool", function(obj:String, prop:String, value:Bool) {
			#if (!flash && MODS_ALLOWED && sys)
			var shader:FlxRuntimeShader = getShader(obj);
			if(shader == null)
			{
				FunkinLua.luaTrace("setShaderBool: Shader is not FlxRuntimeShader!", false, false, FlxColor.RED);
				return false;
			}
			shader.setBool(prop, value);
			return true;
			#else
			FunkinLua.luaTrace("setShaderBool: Platform unsupported for Runtime Shaders!", false, false, FlxColor.RED);
			return false;
			#end
		});
		Lua_helper.add_callback(lua, "setShaderBoolArray", function(obj:String, prop:String, values:Dynamic) {
			#if (!flash && MODS_ALLOWED && sys)
			var shader:FlxRuntimeShader = getShader(obj);
			if(shader == null)
			{
				FunkinLua.luaTrace("setShaderBoolArray: Shader is not FlxRuntimeShader!", false, false, FlxColor.RED);
				return false;
			}
			shader.setBoolArray(prop, values);
			return true;
			#else
			FunkinLua.luaTrace("setShaderBoolArray: Platform unsupported for Runtime Shaders!", false, false, FlxColor.RED);
			return false;
			#end
		});
		Lua_helper.add_callback(lua, "setShaderInt", function(obj:String, prop:String, value:Int) {
			#if (!flash && MODS_ALLOWED && sys)
			var shader:FlxRuntimeShader = getShader(obj);
			if(shader == null)
			{
				FunkinLua.luaTrace("setShaderInt: Shader is not FlxRuntimeShader!", false, false, FlxColor.RED);
				return false;
			}
			shader.setInt(prop, value);
			return true;
			#else
			FunkinLua.luaTrace("setShaderInt: Platform unsupported for Runtime Shaders!", false, false, FlxColor.RED);
			return false;
			#end
		});
		Lua_helper.add_callback(lua, "setShaderIntArray", function(obj:String, prop:String, values:Dynamic) {
			#if (!flash && MODS_ALLOWED && sys)
			var shader:FlxRuntimeShader = getShader(obj);
			if(shader == null)
			{
				FunkinLua.luaTrace("setShaderIntArray: Shader is not FlxRuntimeShader!", false, false, FlxColor.RED);
				return false;
			}
			shader.setIntArray(prop, values);
			return true;
			#else
			FunkinLua.luaTrace("setShaderIntArray: Platform unsupported for Runtime Shaders!", false, false, FlxColor.RED);
			return false;
			#end
		});
		Lua_helper.add_callback(lua, "setShaderFloat", function(obj:String, prop:String, value:Float) {
			#if (!flash && MODS_ALLOWED && sys)
			var shader:FlxRuntimeShader = getShader(obj);
			if(shader == null)
			{
				FunkinLua.luaTrace("setShaderFloat: Shader is not FlxRuntimeShader!", false, false, FlxColor.RED);
				return false;
			}
			shader.setFloat(prop, value);
			return true;
			#else
			FunkinLua.luaTrace("setShaderFloat: Platform unsupported for Runtime Shaders!", false, false, FlxColor.RED);
			return false;
			#end
		});
		Lua_helper.add_callback(lua, "setShaderFloatArray", function(obj:String, prop:String, values:Dynamic) {
			#if (!flash && MODS_ALLOWED && sys)
			var shader:FlxRuntimeShader = getShader(obj);
			if(shader == null)
			{
				FunkinLua.luaTrace("setShaderFloatArray: Shader is not FlxRuntimeShader!", false, false, FlxColor.RED);
				return false;
			}

			shader.setFloatArray(prop, values);
			return true;
			#else
			FunkinLua.luaTrace("setShaderFloatArray: Platform unsupported for Runtime Shaders!", false, false, FlxColor.RED);
			return false;
			#end
		});

		Lua_helper.add_callback(lua, "setShaderSampler2D", function(obj:String, prop:String, bitmapdataPath:String) {
			#if (!flash && MODS_ALLOWED && sys)
			var shader:FlxRuntimeShader = getShader(obj);
			if(shader == null)
			{
				FunkinLua.luaTrace("setShaderSampler2D: Shader is not FlxRuntimeShader!", false, false, FlxColor.RED);
				return false;
			}

			// trace('bitmapdatapath: $bitmapdataPath');
			var value = Paths.image(bitmapdataPath);
			if(value != null && value.bitmap != null)
			{
				// trace('Found bitmapdata. Width: ${value.bitmap.width} Height: ${value.bitmap.height}');
				shader.setSampler2D(prop, value.bitmap);
				return true;
			}
			return false;
			#else
			FunkinLua.luaTrace("setShaderSampler2D: Platform unsupported for Runtime Shaders!", false, false, FlxColor.RED);
			return false;
			#end
		});
	}
	
	#if (!flash && MODS_ALLOWED && sys)
	public static function getShader(obj:String):FlxRuntimeShader
	{
		var split:Array<String> = obj.split('.');
		var target:FlxSprite = null;
		if(split.length > 1) target = LuaUtils.getVarInArray(LuaUtils.getPropertyLoop(split), split[split.length-1]);
		else target = LuaUtils.getObjectDirectly(split[0]);

		if(target == null)
		{
			FunkinLua.luaTrace('Error on getting shader: Object $obj not found', false, false, FlxColor.RED);
			return null;
		}
		return cast (target.shader, FlxRuntimeShader);
	}
	#end
}
