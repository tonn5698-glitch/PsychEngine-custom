package backend;

import openfl.utils.Assets;

import haxe.Json;

typedef ModsList = {
	enabled:Array<String>,
	disabled:Array<String>,
	all:Array<String>
};

class Mods
{
	static public var currentModDirectory:String = '';
	public static final ignoreModFolders:Array<String> = [
		'characters',
		'custom_events',
		'custom_notetypes',
		'data',
		'songs',
		'music',
		'sounds',
		'shaders',
		'videos',
		'images',
		'stages',
		'weeks',
		'fonts',
		'scripts',
		'achievements'
	];

	private static var globalMods:Array<String> = [];

	inline public static function getGlobalMods()
		return globalMods;

	inline public static function pushGlobalMods() // prob a better way to do this but idc
	{
		globalMods = [];
		for(mod in parseList().enabled)
		{
			var pack:Dynamic = getPack(mod);
			if(pack != null && pack.runsGlobally) globalMods.push(mod);
		}
		return globalMods;
	}

	inline public static function getModDirectories():Array<String>
	{
		var list:Array<String> = [];
		#if MODS_ALLOWED
		// Scan TẤT CẢ root dirs (mods, mods1, mods2...)
		for (root in Paths.modRootDirs)
		{
			var modsFolder:String = Paths.modsRootByName(root);
			if(FileSystem.exists(modsFolder)) {
				for (folder in Paths.readDirectory(modsFolder))
				{
					var path = haxe.io.Path.join([modsFolder, folder]);
					if (FileSystem.isDirectory(path) && !ignoreModFolders.contains(folder.toLowerCase()) && !list.contains(folder))
						list.push(folder);
				}
			}
		}
		#end
		return list;
	}
	
	inline public static function mergeAllTextsNamed(path:String, ?defaultDirectory:String = null, allowDuplicates:Bool = false)
	{
		if(defaultDirectory == null) defaultDirectory = Paths.getSharedPath();
		defaultDirectory = defaultDirectory.trim();
		if(!defaultDirectory.endsWith('/')) defaultDirectory += '/';
		if(!defaultDirectory.startsWith('assets/')) defaultDirectory = 'assets/$defaultDirectory';

		var mergedList:Array<String> = [];
		var paths:Array<String> = directoriesWithFile(defaultDirectory, path);

		var defaultPath:String = defaultDirectory + path;
		if(paths.contains(defaultPath))
		{
			paths.remove(defaultPath);
			paths.insert(0, defaultPath);
		}

		for (file in paths)
		{
			var list:Array<String> = CoolUtil.coolTextFile(file);
			for (value in list)
				if((allowDuplicates || !mergedList.contains(value)) && value.length > 0)
					mergedList.push(value);
		}
		return mergedList;
	}

	inline public static function directoriesWithFile(path:String, fileToFind:String, mods:Bool = true)
	{
		var foldersToCheck:Array<String> = [];
		//Main folder
		if(FileSystem.exists(path + fileToFind))
			foldersToCheck.push(path + fileToFind);

		// Week folder
		if(Paths.currentLevel != null && Paths.currentLevel != path)
		{
			var pth:String = Paths.getFolderPath(fileToFind, Paths.currentLevel);
			if(!foldersToCheck.contains(pth) && FileSystem.exists(pth))
				foldersToCheck.push(pth);
		}

		#if MODS_ALLOWED
		if(mods)
		{
			// Global mods first — scan TẤT CẢ root dirs
			for(mod in Mods.getGlobalMods())
			{
				for (root in Paths.modRootDirs)
				{
					var folder:String = Paths.modsRootByName(root) + mod + '/' + fileToFind;
					if(FileSystem.exists(folder) && !foldersToCheck.contains(folder)) foldersToCheck.push(folder);
				}
			}

			// Then root dirs main folder
			for (root in Paths.modRootDirs)
			{
				var folder:String = Paths.modsRootByName(root) + fileToFind;
				if(FileSystem.exists(folder) && !foldersToCheck.contains(folder)) foldersToCheck.push(folder);
			}

			// And lastly, the loaded mod's folder
			if(Mods.currentModDirectory != null && Mods.currentModDirectory.length > 0)
			{
				for (root in Paths.modRootDirs)
				{
					var folder:String = Paths.modsRootByName(root) + Mods.currentModDirectory + '/' + fileToFind;
					if(FileSystem.exists(folder) && !foldersToCheck.contains(folder)) foldersToCheck.push(folder);
				}
			}
		}
		#end
		return foldersToCheck;
	}

	public static function getPack(?folder:String = null):Dynamic
	{
		#if MODS_ALLOWED
		if(folder == null) folder = Mods.currentModDirectory;

		var path = Paths.mods(folder + '/pack.json');
		if(FileSystem.exists(path)) {
			try {
				#if sys
				var rawJson:String = File.getContent(path);
				#else
				var rawJson:String = Assets.getText(path);
				#end
				if(rawJson != null && rawJson.length > 0) return tjson.TJSON.parse(rawJson);
			} catch(e:Dynamic) {
				trace(e);
			}
		}
		#end
		return null;
	}

	/**
	 * CustomBuild flag — mod opt-in vào widescreen layout mới.
	 * Đọc từ pack.json HOẶC data/engine.json (data/Engine.json) của mod:
	 *   "CustomBuild": true   hoặc   "CustomBuild": 1
	 * Khi KHÔNG có flag: PlayState giữ layout 1280x720 chuẩn Psych
	 * (stretch lấp màn hình nếu user bật Wide Screen) → HUD không bị kéo trái.
	 * Khi CÓ flag: mod tự aware widescreen, engine expand width theo aspect.
	 */
	public static var customBuild:Bool = false;

	public static function hasCustomBuild(?folder:String = null):Bool
	{
		#if MODS_ALLOWED
		if(folder == null) folder = Mods.currentModDirectory;
		if(folder == null || folder.length < 1) return false;

		// pack.json
		var pack:Dynamic = getPack(folder);
		if(pack != null && Reflect.hasField(pack, 'CustomBuild'))
		{
			if(flagTruthy(Reflect.field(pack, 'CustomBuild'))) return true;
		}

		// data/engine.json hoặc data/Engine.json
		for(root in Paths.modRootDirs)
		{
			var base:String = haxe.io.Path.join([Paths.modsRootByName(root), folder]);
			for(rel in ['/data/engine.json', '/data/Engine.json'])
			{
				var p:String = base + rel;
				#if sys
				if(!FileSystem.exists(p)) continue;
				try
				{
					var json:Dynamic = haxe.Json.parse(File.getContent(p));
					if(json != null && Reflect.hasField(json, 'CustomBuild') && flagTruthy(Reflect.field(json, 'CustomBuild')))
						return true;
				}
				catch(e:Dynamic) {}
				#end
			}
		}
		#end
		return false;
	}

	static function flagTruthy(v:Dynamic):Bool
	{
		if(v == null || v == false) return false;
		if(v == true) return true;
		var s:String = StringTools.trim(Std.string(v)).toLowerCase();
		return s == 'true' || s == '1';
	}

	public static var updatedOnState:Bool = false;

	/**
	 * modsList.txt theo từng root (mods/modsList.txt, mods1/modsList.txt...)
	 * để enable/disable của root này không ghi đè root khác.
	 * Migration: nếu root chưa có file mà còn file legacy ở thư mục game gốc
	 * ('modsList.txt' cũ) thì copy sang làm điểm bắt đầu.
	 */
	public static function modsListPath():String
	{
		var base:String = #if android StorageUtil.getExternalStorageDirectory() #else Sys.getCwd() #end;
		var rootDir:String = base + Paths.currentModRoot;
		var perRoot:String = rootDir + '/modsList.txt';
		var legacy:String = base + 'modsList.txt';
		#if MODS_ALLOWED
		try {
			if(!FileSystem.exists(rootDir)) FileSystem.createDirectory(rootDir);
			if(!FileSystem.exists(perRoot) && FileSystem.exists(legacy))
				File.saveContent(perRoot, File.getContent(legacy));
		} catch(e:Dynamic) {
			trace(e);
		}
		#end
		return perRoot;
	}

	inline public static function parseList():ModsList {
		if(!updatedOnState) updateModList();
		var list:ModsList = {enabled: [], disabled: [], all: []};

		#if MODS_ALLOWED
		try {
			for (mod in CoolUtil.coolTextFile(modsListPath()))
			{
				//trace('Mod: $mod');
				if(mod.trim().length < 1) continue;

				var dat = mod.split("|");
				list.all.push(dat[0]);
				if (dat[1] == "1")
					list.enabled.push(dat[0]);
				else
					list.disabled.push(dat[0]);
			}
		} catch(e) {
			trace(e);
		}
		#end
		return list;
	}
	
	private static function updateModList()
	{
		#if MODS_ALLOWED
		var listPath:String = modsListPath();
		// Find all that are already ordered — CHỈ theo root hiện tại
		var list:Array<Array<Dynamic>> = [];
		var added:Array<String> = [];
		try {
			for (mod in CoolUtil.coolTextFile(listPath))
			{
				var dat:Array<String> = mod.split("|");
				var folder:String = dat[0];
				// Check folder exists trong CURRENT root (không quét root khác
				// — tránh merge enabled-state giữa các root)
				var exists:Bool = FileSystem.exists(Paths.modsRootByName(Paths.currentModRoot) + folder);
				if(folder.trim().length > 0 && exists && !added.contains(folder))
				{
					added.push(folder);
					list.push([folder, (dat[1] == "1")]);
				}
			}
		} catch(e) {
			trace(e);
		}
		
		// Scan folders chưa có trong modsList.txt — CHỈ root hiện tại
		var modsFolder:String = Paths.modsRootByName(Paths.currentModRoot);
		if(FileSystem.exists(modsFolder))
		{
			for (folder in Paths.readDirectory(modsFolder))
			{
				var path:String = haxe.io.Path.join([modsFolder, folder]);
				if(FileSystem.isDirectory(path) && folder.trim().length > 0
					&& !ignoreModFolders.contains(folder.toLowerCase()) && !added.contains(folder))
				{
					added.push(folder);
					list.push([folder, true]);
				}
			}
		}

		// Now save file
		var fileStr:String = '';
		for (values in list)
		{
			if(fileStr.length > 0) fileStr += '\n';
			fileStr += values[0] + '|' + (values[1] ? '1' : '0');
		}

		File.saveContent(listPath, fileStr);
		updatedOnState = true;
		//trace('Saved modsList.txt');
		#end
	}

	public static function loadTopMod()
	{
		Mods.currentModDirectory = '';
		
		#if MODS_ALLOWED
		var list:Array<String> = Mods.parseList().enabled;
		if(list != null && list[0] != null)
			Mods.currentModDirectory = list[0];
		#end
	}
}
