package funkin.backend;

import flixel.FlxState;

/**
 * Shim cho funkin.backend.MusicBeatState (Codename Engine)
 * Delegate sang backend.MusicBeatState (Psych fork).
 * Bổ sung các static/field mà state CNE hay dùng (skipTransIn/skipTransOut).
 */
class MusicBeatState extends backend.MusicBeatState
{
	public static var skipTransIn:Bool = false;
	public static var skipTransOut:Bool = false;

	public function new()
	{
		super();
	}

	public static function switchState(nextState:FlxState = null)
		backend.MusicBeatState.switchState(nextState);
}
