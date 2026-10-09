package objects;

#if VIDEOS_ALLOWED
import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxState;
import openfl.utils.Assets as OpenFlAssets;
import backend.Paths;
import states.PlayState;

class VideoManager
{
	public var state:FlxState;
	public var customCamera:FlxCamera;
	public var videos:Map<String, VideoSprite> = new Map<String, VideoSprite>();

	public function new(state:FlxState)
	{
		this.state = state;
		customCamera = new FlxCamera();
		customCamera.bgColor.alpha = 0;

		var hudIndex:Int = FlxG.cameras.list.length;
		if (PlayState.instance != null && PlayState.instance.camHUD != null)
		{
			var found:Int = FlxG.cameras.list.indexOf(PlayState.instance.camHUD);
			if (found >= 0) hudIndex = found;
		}
		FlxG.cameras.insert(customCamera, hudIndex, false);
	}

	public function play(name:String, cameraName:String = 'custom', layer:Int = -1, loop:Bool = false, canSkip:Bool = false):VideoSprite
	{
		if (name == null || name.trim().length == 0) return null;

		var existing:VideoSprite = videos.get(name);
		if (existing != null)
		{
			var existingCamera:FlxCamera = getCamera(cameraName);
			existing.cameras = [existingCamera];
			existing.videoSprite.cameras = [existingCamera];
			existing.play();
			return existing;
		}

		var path:String = Paths.video(name);
		#if sys
		if (!sys.FileSystem.exists(path)) return null;
		#else
		if (!OpenFlAssets.exists(path)) return null;
		#end

		var video:VideoSprite = new VideoSprite(path, true, canSkip, loop);
		var camera:FlxCamera = getCamera(cameraName);
		video.cameras = [camera];
		video.videoSprite.cameras = [camera];
		video.videoSprite.autoPause = false;

		if (!loop)
		{
			video.finishCallback = function() videos.remove(name);
			video.onSkip = function() videos.remove(name);
		}

		videos.set(name, video);
		if (layer >= 0 && layer <= state.members.length)
			state.insert(layer, video);
		else
			state.add(video);

		video.play();
		return video;
	}

	public function stop(name:String):Void
	{
		var video:VideoSprite = videos.get(name);
		if (video == null) return;
		video.destroy();
		videos.remove(name);
	}

	public function pauseAll():Void
	{
		for (video in videos)
			if (video != null) video.pause();
	}

	public function resumeAll():Void
	{
		for (video in videos)
			if (video != null) video.resume();
	}

	public function destroy():Void
	{
		for (video in videos)
			if (video != null) video.destroy();
		videos.clear();

		if (customCamera != null && FlxG.cameras.list.contains(customCamera))
			FlxG.cameras.remove(customCamera);
		customCamera = null;
	}

	function getCamera(name:String):FlxCamera
	{
		if (name == null) name = 'custom';
		switch (name.toLowerCase().trim())
		{
			case 'game' | 'stage':
				if (PlayState.instance != null && PlayState.instance.camGame != null) return PlayState.instance.camGame;
			case 'hud':
				if (PlayState.instance != null && PlayState.instance.camHUD != null) return PlayState.instance.camHUD;
			case 'other':
				if (PlayState.instance != null && PlayState.instance.camOther != null) return PlayState.instance.camOther;
		}
		return customCamera;
	}
}
#end
