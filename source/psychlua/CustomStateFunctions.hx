package psychlua;

#if LUA_ALLOWED
class CustomStateFunctions
{
	public static function implement(funk:FunkinLua)
	{
		var lua = funk.lua;
		Lua_helper.add_callback(lua, "switchCustomState", switchCustomState);
		Lua_helper.add_callback(lua, "exitCustomState", exitCustomState);
	}

	public static function switchCustomState(stateName:String)
	{
		CustomState.openState(stateName);
		return true;
	}

	public static function exitCustomState()
	{
		CustomState.exitToMenu();
		return true;
	}
}
#end
