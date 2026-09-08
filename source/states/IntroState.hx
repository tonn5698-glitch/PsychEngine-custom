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

	override public function create():Void
	{
		super.create();

		trace('[IntroState] create()');
		#if android
		PsychJNI.logDebug('[IntroState] create()');
		#end

		#if VIDEOS_ALLOWED
		trace('[IntroState] VIDEOS_ALLOWED = YES');
		#if android PsychJNI.logDebug('[IntroState] VIDEOS_ALLOWED = YES'); #end

		var videoFile:String = getVideoFile();

		trace('[IntroState] videoFile = ' + videoFile);
		#if android PsychJNI.logDebug('[IntroState] videoFile = ' + videoFile); #end

		if (videoFile == null)
		{
			trace('[IntroState] Video not found, skipping intro...');
			#if android PsychJNI.logDebug('[IntroState] Video not found, skipping intro...'); #end
			goToTitle();
			return;
		}

		trace('[IntroState] Playing intro video: ' + videoFile);
		#if android PsychJNI.logDebug('[IntroState] Playing intro video: ' + videoFile); #end
		videoSprite = new VideoSprite(videoFile, false, true); // skippable
		videoSprite.finishCallback = goToTitle;
		videoSprite.onSkip = goToTitle;
		add(videoSprite);
		videoSprite.play();

		#if mobile
		addTouchPad('LEFT_RIGHT', 'A_B'); // hold A to skip
		if (touchPad != null)
			touchPad.alpha = 0.5;
		#end
		#else
		trace('[IntroState] VIDEOS_ALLOWED = NO');
		#if android PsychJNI.logDebug('[IntroState] VIDEOS_ALLOWED = NO'); #end
		goToTitle();
		#end
	}

	function getVideoFile():String
	{
		#if sys
		#if android
		PsychJNI.logDebug('[IntroState] cwd="' + Sys.getCwd() + '" storage="' + StorageUtil.getExternalStorageDirectory() + '"');
		#end
		#if MODS_ALLOWED
		var modPath:String = Paths.video(videoFileName);
		#if android PsychJNI.logDebug('[IntroState] Paths.video -> "' + modPath + '" exists=' + (modPath != null && FileSystem.exists(modPath))); #end
		if (modPath != null && FileSystem.exists(modPath))
			return modPath;
		#end

		#if android
		var storageBase:String = StorageUtil.getExternalStorageDirectory();
		var candidates:Array<String> = [
			'${storageBase}videos/${videoFileName}.webm',
			'${storageBase}videos/${videoFileName}.mp4',
			'${storageBase}assets/videos/${videoFileName}.webm',
			'${storageBase}assets/videos/${videoFileName}.mp4',
			'${storageBase}mods/videos/${videoFileName}.${Paths.VIDEO_EXT}'
		];
		for (candidate in candidates)
		{
			var exists:Bool = FileSystem.exists(candidate);
			#if android PsychJNI.logDebug('[IntroState] check "' + candidate + '" -> ' + exists); #end
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
			#if android PsychJNI.logDebug('[IntroState] embedded? "' + assetKey + '" -> ' + OpenFlAssets.exists(assetKey)); #end
			if (!OpenFlAssets.exists(assetKey))
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