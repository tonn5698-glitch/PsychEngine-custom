package backend;

/**
 * Mod Engine.json — MyMod/data/Engine.json
 * {
 *   "video": "intro.mp4",    // custom intro video (MyMod/videos/intro.mp4 hoặc path tương đối trong mod)
 *   "bop-bpm": 130,          // BPM dùng cho FunkyMode bop
 *   "bop-style": "Cube Out"  // ease bop (linear, cubeout, backout,...)
 * }
 * Chỉ mod đầu tiên có data/Engine.json được dùng (mod enabled ưu tiên trước).
 */
class EngineJSON
{
	#if MODS_ALLOWED
	public static var videoPath:Null<String> = null;
	public static var jsonBopBpm:Float = 0; // 0 = không có trong json
	public static var jsonBopStyle:Null<String> = null;

	/** Quét mods → parse Engine.json đầu tiên (video + bop config raw). */
	public static function load():Void
	{
		videoPath = null;
		jsonBopBpm = 0;
		jsonBopStyle = null;

		var candidates:Array<String> = [];
		var enabled:Array<String> = Mods.parseList().enabled;
		for (m in enabled) if (!candidates.contains(m)) candidates.push(m);
		for (f in Mods.getModDirectories()) if (!candidates.contains(f)) candidates.push(f);

		for (name in candidates)
		{
			var dir:Null<String> = findModDir(name);
			if (dir == null) continue;
			var jsonPath:String = dir + '/data/Engine.json';
			if (FileSystem.exists(jsonPath))
			{
				try
				{
					parse(File.getContent(jsonPath), dir);
				}
				catch (e:Dynamic) {}
				return; // chỉ mod đầu tiên
			}
		}
	}

	/**
	 * Áp dụng bop-bpm / bop-style từ json vào ClientPrefs.data
	 * CHỈ khi save chưa có giá trị user đã set (user chọn qua Experiment được giữ).
	 */
	public static function applyBopDefaults():Void
	{
		if (jsonBopBpm > 0 && (FlxG.save.data == null || !Reflect.hasField(FlxG.save.data, 'bopBpm')))
			ClientPrefs.data.bopBpm = Std.int(jsonBopBpm);
		if (jsonBopStyle != null && (FlxG.save.data == null || !Reflect.hasField(FlxG.save.data, 'bopStyle')))
			ClientPrefs.data.bopStyle = FunkyMode.normalizeStyle(jsonBopStyle);
	}

	static function findModDir(name:String):Null<String>
	{
		for (root in Paths.modRootDirs)
		{
			var dir:String = haxe.io.Path.join([Paths.modsRootByName(root), name]);
			if (FileSystem.exists(dir) && FileSystem.isDirectory(dir))
				return dir;
		}
		return null;
	}

	static function parse(content:String, dir:String):Void
	{
		var json:Dynamic = haxe.Json.parse(content);
		if (json == null) return;

		if (Reflect.hasField(json, 'bop-bpm'))
		{
			var v:Dynamic = Reflect.field(json, 'bop-bpm');
			if (v != null) jsonBopBpm = Std.parseFloat(Std.string(v));
		}
		if (Reflect.hasField(json, 'bop-style'))
		{
			var v:Dynamic = Reflect.field(json, 'bop-style');
			if (v != null) jsonBopStyle = Std.string(v);
		}
		if (Reflect.hasField(json, 'video'))
		{
			var v:Dynamic = Reflect.field(json, 'video');
			if (v != null) videoPath = resolveVideo(dir, Std.string(v));
		}
	}

	static function resolveVideo(dir:String, rel:String):Null<String>
	{
		var candidates:Array<String> = [
			dir + '/videos/' + rel,
			dir + '/' + rel,
			dir + '/videos/' + rel + '.' + Paths.VIDEO_EXT,
			dir + '/' + rel + '.' + Paths.VIDEO_EXT
		];
		for (c in candidates)
			if (FileSystem.exists(c))
				return c;
		return null;
	}
	#end
}