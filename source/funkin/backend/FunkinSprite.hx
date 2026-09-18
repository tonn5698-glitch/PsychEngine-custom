package funkin.backend;

/**
 * Shim: CNE FunkinSprite → Psych FlxSprite.
 * FunkinSprite trong CNE extends FlxAnimate, có playAnim/addAnim/beatHit.
 * Shim này extends FlxSprite, delegate các method cần thiết.
 */
class FunkinSprite extends flixel.FlxSprite
{
	public var animOffsets:Map<String, Array<Float>> = new Map();
	public var zoomFactor:Float = 1;
	public var zoomFactorEnabled:Bool = true;
	public var angleFactor:Float = 1;
	public var angleFactorEnabled:Bool = true;

	public function new(?x:Float, ?y:Float)
	{
		super(x, y);
	}

	public function playAnim(name:String, ?forced:Bool = false, ?reverse:Bool = false, ?startFrame:Int = 0):Void
	{
		if (animation != null)
		{
			if (animation.getAnimationList().length == 0)
				return;
			var found:Bool = false;
			for (anim in animation.getAnimationList())
			{
				if (anim.name == name) { found = true; break; }
			}
			if (!found) return;
			animation.play(name, forced, reverse, startFrame);
		}
	}

	public function addAnim(name:String, prefix:String, framerate:Int = 24, loop:Bool = true):Void
	{
		if (animation != null)
			animation.addByPrefix(name, prefix, framerate, loop);
	}

	public function hasAnim(name:String):Bool
	{
		if (animation == null) return false;
		for (anim in animation.getAnimationList())
		{
			if (anim.name == name) return true;
		}
		return false;
	}

	public function getAnim():String
	{
		if (animation != null && animation.curAnim != null)
			return animation.curAnim.name;
		return '';
	}

	public function addOffset(name:String, x:Float, y:Float):Void
	{
		animOffsets.set(name, [x, y]);
		offset.set(x, y);
	}

	public function beatHit():Void
	{
		// Stub — CNE state có thể override
	}
}
