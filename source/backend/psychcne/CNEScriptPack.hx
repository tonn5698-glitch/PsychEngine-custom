package backend.psychcne;

#if HSCRIPT_ALLOWED
class CNEScriptPack extends CNEScript
{
	public var name:String;
	public var scripts:Array<CNEScript> = [];
	public var additionalDefaultVariables:Map<String, Dynamic> = [];

	public function new(name:String)
	{
		super(name, null, false);
		this.name = name;
		additionalDefaultVariables.set("importScript", importScript);
	}

	override public function load():Void
	{
		for (script in scripts) script.load();
	}

	public function contains(path:String):Bool
	{
		for (script in scripts) if (script.path == path) return true;
		return false;
	}

	public function getByPath(path:String):CNEScript
	{
		for (script in scripts) if (script.path == path) return script;
		return null;
	}

	public function getByName(name:String):CNEScript
	{
		for (script in scripts) if (script.fileName == name) return script;
		return null;
	}

	public function importScript(path:String):CNEScript
	{
		var resolved = CNEScript.resolvePath(path);
		#if sys
		if (!sys.FileSystem.exists(resolved))
			throw 'Script at ' + path + ' does not exist.';
		#end
		var script = new funkin.backend.scripting.Script(resolved);
		add(script);
		script.load();
		return script;
	}

	override public function call(func:String, ?parameters:Array<Dynamic>):Dynamic
	{
		for (script in scripts) if (script.active) script.call(func, parameters);
		return null;
	}

	override public function callOne(func:String, arg:Dynamic):Dynamic
	{
		for (script in scripts) if (script.active) script.call(func, [arg]);
		return null;
	}

	public function event(func:String, event:Dynamic):Dynamic
	{
		for (script in scripts)
		{
			if (!script.active) continue;
			script.call(func, [event]);
			if (event != null && Reflect.getProperty(event, "cancelled") == true
				&& Reflect.getProperty(event, "__continueCalls") != true) break;
		}
		return event;
	}

	override public function get(name:String):Dynamic
	{
		for (script in scripts)
		{
			var value = script.get(name);
			if (value != null) return value;
		}
		return super.get(name);
	}

	override public function set(name:String, value:Dynamic):Void
	{
		for (script in scripts) script.set(name, value);
		super.set(name, value);
	}

	override public function setParent(value:Dynamic):Void
	{
		super.setParent(value);
		for (script in scripts)
		{
			script.setParent(value);
			configure(script);
		}
	}

	override public function setPublicMap(map:Map<String, Dynamic>):Void
	{
		super.setPublicMap(map);
		for (script in scripts) script.setPublicMap(map);
	}

	public function add(script:CNEScript):Void
	{
		if (script == null || scripts.contains(script)) return;
		scripts.push(script);
		configure(script);
	}

	public function remove(script:CNEScript):Void
		scripts.remove(script);

	public function insert(position:Int, script:CNEScript):Void
	{
		if (script == null) return;
		scripts.insert(position, script);
		configure(script);
	}

	function configure(script:CNEScript):Void
	{
		if (parent != null) script.setParent(parent);
		script.setPublicMap(publicVariables);
		for (key => variable in additionalDefaultVariables) script.set(key, variable);
	}

	override public function reload():Void
	{
		for (script in scripts) script.reload();
	}

	override public function destroy():Void
	{
		for (script in scripts) if (script != null) script.destroy();
		scripts = [];
		super.destroy();
	}
}
#end
