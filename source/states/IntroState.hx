package states;

import objects.VideoSprite;
#if android
import mobile.backend.PsychJNI;
import openfl.utils.Assets as OpenFlAssets;
#end

/**
 * Startup intro for the engine.
 * Plays <videoFileName> from disk (mods first, then /sdcard/.PsychEngine/videos on Android,
 * then assets/videos), skippable by holding accept, then switches to TitleState.
 * If a build ships the video embedded in the APK it is extracted once to storage
 * (hxvlc cannot read packaged assets directly).
 * If no video is found (or VIDEOS_ALLOWED is off) it jumps straight to the title.
 */
class IntroState extends MusicBeatState
{
	public static var videoFileName:String = 'engineIntro';

	var videoSprite:VideoSprite;
	var goingToTitle:Bool = false;

	#if sys
	static function dbg(msg:String):Void
	{
		try
		{
			#if android
			var dir:String = StorageUtil.getExternalStorageDirectory() + 'logs/';
			#else
			var dir:String = Sys.getCwd() + 'logs/';
			#end
			if (!FileSystem.exists(dir)) FileSystem.createDirectory(dir);
			var file:String = dir + 'intro.log';
			var prev:String = (FileSystem.exists(file)) ? File.getContent(file) : '';
			File.saveContent(file, prev + '\n' + Date.now().toString() + ' ' + msg);
		}
		catch (e:Dynamic) {}
		#if android
		try { PsychJNI.logDebug(msg); } catch (e:Dynamic) {}
		#end
	}
	#end

	override public function create():Void
	{
		super.create();

		trace('[IntroState] create()');
		#if sys
		dbg('[IntroState] create()');
		dbg('[IntroState] cwd="' + Sys.getCwd() + '"');
		#end

		#if VIDEOS_ALLOWED
		#if sys dbg('[IntroState] VIDEOS_ALLOWED = YES'); #end

		var videoFile:String = getVideoFile();

		#if sys dbg('[IntroState] videoFile = ' + videoFile); #end

		if (videoFile == null)
		{
			#if sys dbg('[IntroState] Video not found, skipping intro...'); #end
			goToTitle();
			return;
		}

		#if sys dbg('[IntroState] Playing intro video: ' + videoFile); #end
		videoSprite = new VideoSprite(videoFile, false, true); // skippable
		videoSprite.finishCallback = goToTitle;
		videoSprite.onSkip = goToTitle;
		add(videoSprite);
		videoSprite.play();

		#if mobile
		MobileData.init();
		addTouchPad('NONE', 'SINGLE'); // single A button, no d-pad
		if (touchPad != null)
			touchPad.alpha = 0.5;
		#end
		#else
		#if sys dbg('[IntroState] VIDEOS_ALLOWED = NO'); #end
		goToTitle();
		#end
	}

	function getVideoFile():String
	{
		#if sys
		dbg('[IntroState] cwd="' + Sys.getCwd() + '" storage="' + StorageUtil.getExternalStorageDirectory() + '"');
		#if MODS_ALLOWED
		var modPath:String = Paths.video(videoFileName);
		dbg('[IntroState] Paths.video -> "' + modPath + '" exists=' + (modPath != null && FileSystem.exists(modPath)));
		if (modPath != null && FileSystem.exists(modPath))
			return modPath;
		#end

		#if android
		var storageBase:String = StorageUtil.getExternalStorageDirectory();
		var cwd:String = Sys.getCwd();
		var candidates:Array<String> = [
			// where CopyState unpacks embedded assets (Android/data/<pkg>/files)
			'${cwd}assets/videos/${videoFileName}.${Paths.VIDEO_EXT}',
			'${cwd}assets/videos/${videoFileName}.webm',
			'${cwd}videos/${videoFileName}.${Paths.VIDEO_EXT}',
			'${cwd}videos/${videoFileName}.webm',
			// public PsychEngine storage
			'${storageBase}videos/${videoFileName}.webm',
			'${storageBase}videos/${videoFileName}.mp4',
			'${storageBase}assets/videos/${videoFileName}.webm',
			'${storageBase}assets/videos/${videoFileName}.mp4',
			'${storageBase}mods/videos/${videoFileName}.${Paths.VIDEO_EXT}',
			'${storageBase}videos/${videoFileName}.mkv'
		];
		for (candidate in candidates)
		{
			var exists:Bool = FileSystem.exists(candidate);
			dbg('[IntroState] check "' + candidate + '" -> ' + exists);
			if (exists)
				return candidate;
		}

		// If the APK ships the video embedded, extract it once to storage
		#if VIDEOS_ALLOWED
		var extracted:String = extractEmbeddedVideo();
		if (extracted != null)
			return extracted;
		#end
		#else
		var candidates:Array<String> = [
			'assets/videos/${videoFileName}.${Paths.VIDEO_EXT}',
			'assets/videos/${videoFileName}.webm'
		];
		for (candidate in candidates)
			if (FileSystem.exists(candidate))
				return candidate;
		#end
		#end
		return null;
	}

	#if (android && VIDEOS_ALLOWED)
	function extractEmbeddedVideo():String
	{
		var storageBase:String = StorageUtil.getExternalStorageDirectory();
		var videoDir:String = storageBase + 'videos/';

		for (ext in [Paths.VIDEO_EXT, 'webm'])
		{
			var assetKey:String = 'assets/videos/${videoFileName}.$ext';
			var embeddedExists:Bool = OpenFlAssets.exists(assetKey);
			dbg('[IntroState] embedded? "' + assetKey + '" -> ' + embeddedExists);
			if (!embeddedExists)
				continue;

			var output:String = videoDir + videoFileName + '.' + ext;
			if (FileSystem.exists(output))
				return output;

			try
			{
				var bytes:haxe.io.Bytes = OpenFlAssets.getBytes(assetKey);
				if (bytes == null)
					continue;
				if (!FileSystem.exists(videoDir))
					FileSystem.createDirectory(videoDir);
				File.saveBytes(output, bytes);
				trace('[IntroState] Extracted intro video to ' + output);
				return output;
			}
			catch (e:Dynamic)
			{
				trace('[IntroState] Failed to extract embedded intro video: ' + e);
			}
		}
		return null;
	}
	#end

	function goToTitle():Void
	{
		if (goingToTitle)
			return;
		goingToTitle = true;

		trace('[IntroState] goToTitle()');
		#if android PsychJNI.logDebug('[IntroState] goToTitle()'); #end

		FlxTransitionableState.skipNextTransIn = true;
		FlxTransitionableState.skipNextTransOut = true;
		MusicBeatState.switchState(new TitleState());
	}
}