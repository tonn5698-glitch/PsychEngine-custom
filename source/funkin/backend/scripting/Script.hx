package funkin.backend.scripting;

#if HSCRIPT_ALLOWED
class Script extends backend.psychcne.CNEScript
{
	public function new(path:String)
		super(path, flixel.FlxG.state, false);

	public static function create(path:String):Script
		return new Script(path);
}
#end
