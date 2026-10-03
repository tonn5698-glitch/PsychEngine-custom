package funkin.backend.system;

/**
 * Shim: CNE Conductor API → Psych Engine Conductor.
 * Psych Conductor không có signals, curStep/curBeat fields (chúng ở MusicBeatState).
 * Shim này thêm các field thiếu và delegate.
 */
class Conductor
{
	// Delegate từ Psych Conductor
	public static var bpm(get, set):Float;
	static inline function get_bpm():Float return backend.Conductor.bpm;
	static inline function set_bpm(v:Float):Float { backend.Conductor.bpm = v; return v; }

	public static var crochet(get, never):Float;
	static inline function get_crochet():Float return backend.Conductor.crochet;

	public static var stepCrochet(get, never):Float;
	static inline function get_stepCrochet():Float return backend.Conductor.stepCrochet;

	public static var songPosition(get, set):Float;
	static inline function get_songPosition():Float return backend.Conductor.songPosition;
	static inline function set_songPosition(v:Float):Float { backend.Conductor.songPosition = v; return v; }

	public static var offset(get, set):Float;
	static inline function get_offset():Float return backend.Conductor.offset;
	static inline function set_offset(v:Float):Float { backend.Conductor.offset = v; return v; }

	// CNE-specific fields (đã có trong MusicBeatState Psych, nhưng CNE state có thể truy cập trực tiếp)
	public static var curStep:Int = 0;
	public static var curBeat:Int = 0;
	public static var curMeasure:Int = 0;

	public static var curStepFloat:Float = 0;
	public static var curBeatFloat:Float = 0;
	public static var curMeasureFloat:Float = 0;

	public static var startingBPM:Float = 0;
	public static var beatsPerMeasure:Float = 4;
	public static var stepsPerBeat:Int = 4;
	public static var denominator:Float = 4;

	public static var bpmChangeMap:Array<BPMChangeEvent> = [];

	// Signals (stub - không dùng trong Psych, nhưng CNE state có thể khai báo)
	// Nếu CNE state cần signal, nó sẽ crash. Tuy nhiên大多数 state không dùng trực tiếp.

	public static function changeBPM(newBPM:Float, ?beatsPerMeasure:Float, ?stepsPerBeat:Int):Void
	{
		backend.Conductor.bpm = newBPM;
		startingBPM = newBPM;
		if (beatsPerMeasure != null) Conductor.beatsPerMeasure = beatsPerMeasure;
		if (stepsPerBeat != null) Conductor.stepsPerBeat = stepsPerBeat;
	}

	public static function reset():Void
	{
		backend.Conductor.bpm = 0;
		backend.Conductor.songPosition = 0;
		startingBPM = 0;
		curStep = 0;
		curBeat = 0;
		curMeasure = 0;
	}

	public static function getBeats(?every:Bool, ?interval:Float, ?offset:Float):Float
	{
		var time:Float = backend.Conductor.songPosition;
		if (offset != null) time += offset;
		return time / backend.Conductor.crochet;
	}

	// BPMChangeEvent typedef
	public static function getBPMFromSeconds(time:Float):Dynamic
	{
		return backend.Conductor.getBPMFromSeconds(time);
	}
}

typedef BPMChangeEvent = {
	var songTime:Float;
	var bpm:Float;
	var ?beatsPerMeasure:Float;
	var ?stepsPerBeat:Int;
	var stepTime:Int;
	var ?stepCrochet:Float;
	var ?beatTime:Int;
	var ?measureTime:Int;
}
