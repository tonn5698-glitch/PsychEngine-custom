package psychlua;

import states.MainMenuState;
import states.StoryMenuState;
import states.FreeplayState;
import states.CreditsState;
import options.OptionsState;
#if MODS_ALLOWED import states.ModsMenuState; #end
#if ACHIEVEMENTS_ALLOWED import states.AchievementsMenuState; #end
import lime.app.Application;

#if LUA_ALLOWED
class CustomMenuFunctions
{
	public static function implement(funk:FunkinLua)
	{
		var lua = funk.lua;
		Lua_helper.add_callback(lua, "goToStoryMode", function() { MusicBeatState.switchState(new StoryMenuState()); return true; });
		Lua_helper.add_callback(lua, "goToFreeplay", function() { MusicBeatState.switchState(new FreeplayState()); return true; });
		Lua_helper.add_callback(lua, "goToCredits", function() { MusicBeatState.switchState(new CreditsState()); return true; });
		Lua_helper.add_callback(lua, "goToOptions", function() { MusicBeatState.switchState(new OptionsState()); return true; });
		#if MODS_ALLOWED
		Lua_helper.add_callback(lua, "goToModsMenu", function() { MusicBeatState.switchState(new ModsMenuState()); return true; });
		#end
		#if ACHIEVEMENTS_ALLOWED
		Lua_helper.add_callback(lua, "goToAchievements", function() { MusicBeatState.switchState(new AchievementsMenuState()); return true; });
		#end
		Lua_helper.add_callback(lua, "initMenuMods", initMenuMods);
		Lua_helper.add_callback(lua, "quitGame", function() { Application.current.window.close(); return true; });
	}

	/** Gọi 1 lần trong onCreate của main menu custom — y hệt MainMenuState.create() dòng 40-42. */
	public static function initMenuMods():Bool
	{
		#if MODS_ALLOWED
		Mods.pushGlobalMods();
		Mods.loadTopMod();
		#end
		return true;
	}
}
#end
