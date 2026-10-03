package funkin.savedata;

import backend.Highscore;

/**
 * Shim: CNE FunkinSave API → Psych Engine Highscore.
 * CNE dùng FunkinSave với SongScore struct.
 * Psych dùng Highscore với int/float trực tiếp.
 * Shim này bridge 2 hệ thống.
 */
class FunkinSave
{
	public static var save:Dynamic = null;

	public static function getSongHighscore(songName:String, ?diff:String):SongScore
	{
		var diffIdx:Int = diffToInt(diff);
		var formatted:String = backend.Paths.formatToSongPath(songName);
		var score:Int = Highscore.getScore(formatted, diffIdx);
		var rating:Float = Highscore.getRating(formatted, diffIdx);
		return {
			score: score,
			accuracy: rating,
			misses: 0,
			hits: null,
			date: ''
		};
	}

	public static function setSongHighscore(songName:String, ?diff:String, highscore:SongScore, ?changes:Dynamic, ?force:Bool = false):Bool
	{
		// Psych tự lưu qua Highscore.saveScore, không cần manual set
		return true;
	}

	public static function getWeekHighscore(weekName:String, ?diff:String):SongScore
	{
		var diffIdx:Int = diffToInt(diff);
		var score:Int = Highscore.getWeekScore(weekName, diffIdx);
		return {
			score: score,
			accuracy: 0,
			misses: 0,
			hits: null,
			date: ''
		};
	}

	public static function flush():Void
	{
		// Psych tự lưu, không cần flush
	}

	static function diffToInt(?diff:String):Int
	{
		if (diff == null) return 2; // default hard
		return switch (diff.toLowerCase()) {
			case 'easy': 0;
			case 'normal': 1;
			case 'hard': 2;
			default: 2;
		}
	}
}

typedef SongScore = {
	var score:Int;
	var accuracy:Float;
	var misses:Int;
	var hits:Dynamic;
	var date:String;
}
