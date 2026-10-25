package funkin.backend;

#if hxvlc
import hxvlc.flixel.FlxVideoSprite;

class Video4 extends FlxVideoSprite
{
	public static final muted:String = ':no-audio';
	public static final looped:String = 'input-repeat=65545';

	var _formatReady:Bool = false;
	var _startQueued:Bool = false;
	var _onFormat:Void->Void;

	public function new(x:Float = 0, y:Float = 0)
	{
		super(x, y);
		antialiasing = ClientPrefs.data.antialiasing;
		bitmap.onFormatSetup.add(function()
		{
			_formatReady = true;
			if (_onFormat != null) _onFormat();
			if (_startQueued) { _startQueued = false; play(); }
		});
	}

	public function onFormat(cb:Void->Void):Void _onFormat = cb;

	public function delayAndStart():Void
	{
		if (_formatReady) play(); else _startQueued = true;
	}

	override function destroy()
	{
		_onFormat = null;
		super.destroy();
	}
}
#end
