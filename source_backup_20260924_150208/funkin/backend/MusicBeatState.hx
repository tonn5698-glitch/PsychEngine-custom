package funkin.backend;

import flixel.FlxState;

/**
 * Shim: CNE MusicBeatState → Psych MusicBeatState.
 * Delegate tất cả calls, thêm field CNE thiếu.
 */
class MusicBeatState extends backend.MusicBeatState
{
	public static var skipTransIn:Bool = false;
	public static var skipTransOut:Bool = false;

	// CNE có curMeasure — Psych không có, thêm在这里
	public var curMeasure(get, never):Int;
	function get_curMeasure():Int return 0; // stub

	public var curMeasureFloat(get, never):Float;
	function get_curMeasureFloat():Float return 0; // stub

	public var songPos(get, never):Float;
	function get_songPos():Float return backend.Conductor.songPosition;

	// CNE controlsP1/P2
	public var controlsP1(get, never):backend.Controls;
	function get_controlsP1():backend.Controls return backend.Controls.instance;

	public var controlsP2(get, never):backend.Controls;
	function get_controlsP2():backend.Controls return backend.Controls.instance;

	// CNE graphicCache (stub)
	public var graphicCache:Dynamic = null;

	public function new()
	{
		super();
	}

	public static function switchState(nextState:FlxState = null)
		backend.MusicBeatState.switchState(nextState);
}
