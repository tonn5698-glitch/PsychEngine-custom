package funkin.game;

/**
 * Shim cho funkin.game.PlayState (Codename Engine) — delegate sang states.PlayState (Psych fork).
 * Không extend (tránh thừa kế toàn bộ state); chỉ expose static mà state CNE cần.
 */
class PlayState
{
	public static var isStoryMode(get, set):Bool;
	static inline function get_isStoryMode():Bool return states.PlayState.isStoryMode;
	static inline function set_isStoryMode(v:Bool):Bool { states.PlayState.isStoryMode = v; return v; }

	public static var storyDifficulty(get, set):Int;
	static inline function get_storyDifficulty():Int return states.PlayState.storyDifficulty;
	static inline function set_storyDifficulty(v:Int):Int { states.PlayState.storyDifficulty = v; return v; }

	public static var SONG(get, set):Dynamic;
	static inline function get_SONG():Dynamic return states.PlayState.SONG;
	static inline function set_SONG(v:Dynamic):Dynamic { states.PlayState.SONG = v; return v; }
}
