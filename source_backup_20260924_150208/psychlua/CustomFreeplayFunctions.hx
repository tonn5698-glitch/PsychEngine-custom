package psychlua;

import backend.WeekData;
import backend.Highscore;
import backend.Song;
import states.StoryMenuState;

#if LUA_ALLOWED
class CustomFreeplayFunctions
{
	public static function implement(funk:FunkinLua)
	{
		var lua = funk.lua;
		Lua_helper.add_callback(lua, "getFreeplaySongList", getFreeplaySongList);
		Lua_helper.add_callback(lua, "selectFreeplaySong", selectFreeplaySong);
		Lua_helper.add_callback(lua, "getFreeplayScore", getFreeplayScore);
		Lua_helper.add_callback(lua, "playFreeplaySong", playFreeplaySong);
	}

	/**
	 * Trả về mảng bài hát dạng bảng Lua: {songName, week, character, color, folder}.
	 * Logic y hệt FreeplayState.hx dòng 84-118 (kể cả kiểm tra khóa tuần).
	 */
	public static function getFreeplaySongList():Array<Dynamic>
	{
		WeekData.reloadWeekFiles(false);
		var result:Array<Dynamic> = [];

		for (i in 0...WeekData.weeksList.length)
		{
			var leWeek:WeekData = WeekData.weeksLoaded.get(WeekData.weeksList[i]);
			var locked:Bool = !leWeek.startUnlocked && leWeek.weekBefore.length > 0
				&& (!StoryMenuState.weekCompleted.exists(leWeek.weekBefore) || !StoryMenuState.weekCompleted.get(leWeek.weekBefore));
			if (locked) continue;

			WeekData.setDirectoryFromWeek(leWeek);
			for (song in leWeek.songs)
			{
				var colors:Array<Int> = song[2];
				if(colors == null || colors.length < 3) colors = [146, 113, 253];

				result.push({
					songName: song[0],
					week: i,
					character: song[1],
					color: FlxColor.fromRGB(colors[0], colors[1], colors[2]),
					folder: Mods.currentModDirectory
				});
			}
		}
		return result;
	}

	/**
	 * Gọi khi người chơi di chuyển tới 1 bài (trước khi bấm Accept).
	 * Set đúng mod directory + nạp danh sách độ khó của tuần đó.
	 * Trả về Difficulty.list (mảng tên độ khó) để hiển thị UI.
	 */
	public static function selectFreeplaySong(week:Int, folder:String):Array<String>
	{
		Mods.currentModDirectory = folder;
		PlayState.storyWeek = week;
		Difficulty.loadFromWeek();
		return Difficulty.list;
	}

	public static function getFreeplayScore(songName:String, diffIndex:Int):Int
	{
		var formatted:String = Paths.formatToSongPath(songName);
		return Highscore.getScore(formatted, diffIndex);
	}

	/**
	 * Load bài đã chọn và chuyển sang PlayState — y hệt flow ACCEPT gốc.
	 * Trả về false nếu chart lỗi/thiếu file (không switch state).
	 */
	public static function playFreeplaySong(songName:String, diffIndex:Int):Bool
	{
		var songLowercase:String = Paths.formatToSongPath(songName);
		var poop:String = Highscore.formatSong(songLowercase, diffIndex);

		try
		{
			Song.loadFromJson(poop, songLowercase);
			PlayState.isStoryMode = false;
			PlayState.storyDifficulty = diffIndex;
		}
		catch(e:haxe.Exception)
		{
			trace('[CustomFreeplay] Lỗi load chart "$songName": ${e.message}');
			return false;
		}

		LoadingState.prepareToSong();
		LoadingState.loadAndSwitchState(new PlayState());
		return true;
	}
}
#end
