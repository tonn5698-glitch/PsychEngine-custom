package psychlua;

#if (!flash && sys)
import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.util.FlxColor;
import openfl.filters.ShaderFilter;
import shaders.FunkinShader;
#end

// Funkin API: Codename-style shader functions. Separate from the Psych API (ShaderFunctions).
class FunkinShaderFunctions
{
	static var funkinShaders:Map<String, FunkinShader> = new Map();

	static function resolveCamera(camera:String):FlxCamera
	{
		var cam:FlxCamera = LuaUtils.getObjectDirectly(camera);
		if (cam == null)
		{
			switch (camera.toLowerCase())
			{
				case 'game' | 'camgame': cam = FlxG.camera;
				case 'hud' | 'camhud' | 'camother': cam = FlxG.cameras.list[FlxG.cameras.list.length - 1];
			}
		}
		return cam;
	}

	public static function implement(funk:FunkinLua)
	{
		funk.addLocalCallback("initFunkinShader", function(name:String) {
			if (!ClientPrefs.data.shaders) return false;
			#if (!flash && sys)
			if (funkinShaders.exists(name)) return true;
			var shader = FunkinShader.fromName(name);
			if (shader == null)
			{
				FunkinLua.luaTrace('initFunkinShader: missing $name .frag/.vert', false, false, FlxColor.RED);
				return false;
			}
			funkinShaders.set(name, shader);
			return true;
			#else
			return false;
			#end
		});

		funk.addLocalCallback("setFunkinShaderFloat", function(name:String, prop:String, value:Float) {
			#if (!flash && sys)
			var s = funkinShaders.get(name);
			if (s == null) return false;
			s.setFloat(prop, value);
			return true;
			#else
			return false;
			#end
		});

		funk.addLocalCallback("setFunkinShaderInt", function(name:String, prop:String, value:Int) {
			#if (!flash && sys)
			var s = funkinShaders.get(name);
			if (s == null) return false;
			s.setInt(prop, value);
			return true;
			#else
			return false;
			#end
		});

		funk.addLocalCallback("setFunkinShaderFloatArray", function(name:String, prop:String, values:Array<Float>) {
			#if (!flash && sys)
			var s = funkinShaders.get(name);
			if (s == null) return false;
			s.setFloatArray(prop, values);
			return true;
			#else
			return false;
			#end
		});

		funk.addLocalCallback("setSpriteFunkinShader", function(obj:String, name:String) {
			#if (!flash && sys)
			var s = funkinShaders.get(name);
			if (s == null) return false;
			var sprite:FlxSprite = LuaUtils.getObjectDirectly(obj);
			if (sprite == null) return false;
			sprite.shader = s;
			return true;
			#else
			return false;
			#end
		});

		funk.addLocalCallback("setCameraFunkinShader", function(camera:String, name:String) {
			#if (!flash && sys)
			var s = funkinShaders.get(name);
			if (s == null) return false;
			var cam = resolveCamera(camera);
			if (cam == null) return false;
			var list = (cam.filters == null) ? [] : cam.filters.copy();
			list.push(new ShaderFilter(s));
			cam.filtersEnabled = true;
			cam.setFilters(list);
			return true;
			#else
			return false;
			#end
		});

		funk.addLocalCallback("removeFunkinCameraShader", function(camera:String, name:String) {
			#if (!flash && sys)
			var s = funkinShaders.get(name);
			var cam = resolveCamera(camera);
			if (s == null || cam == null || cam.filters == null) return false;
			var kept = [];
			for (f in cam.filters)
			{
				var isTarget = Std.isOfType(f, ShaderFilter) && cast(f, ShaderFilter).shader == s;
				if (!isTarget) kept.push(f);
			}
			cam.setFilters(kept);
			return true;
			#else
			return false;
			#end
		});
	}
}
