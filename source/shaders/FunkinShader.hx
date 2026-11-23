package shaders;

#if (!flash && sys)
import flixel.addons.display.FlxRuntimeShader;
import backend.Paths;

// Codename-style shader object (Funkin API). Stored separately from the Psych runtime shaders.
class FunkinShader extends FlxRuntimeShader
{
	public var shaderName:String = '';

	public function new(?fragmentSource:String, ?vertexSource:String):Void
	{
		super(fragmentSource, vertexSource);
	}

	// Loads <name>.frag / <name>.vert with the mod-aware lookup. Returns null if missing.
	public static function fromName(name:String):FunkinShader
	{
		var files:Array<String> = Paths.loadRuntimeShader(name);
		if (files == null) return null;
		var shader = new FunkinShader(files[0], files[1]);
		shader.shaderName = name;
		return shader;
	}
}
#end
