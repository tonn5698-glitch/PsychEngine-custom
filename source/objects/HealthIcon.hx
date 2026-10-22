package objects;

class HealthIcon extends FlxSprite
{
	public var sprTracker:FlxSprite;
	private var isPlayer:Bool = false;
	private var char:String = '';

	public var rotationX:Float = 0;
	public var rotationY:Float = 0;
	public var rotationZ:Float = 0;
	public var z3d:Float = 0;
	public var perspDist:Float = 1000;
	public var spinX:Float = 0;
	public var spinY:Float = 0;
	public var spinZ:Float = 0;

	public function new(char:String = 'face', isPlayer:Bool = false, ?allowGPU:Bool = true)
	{
		super();
		this.isPlayer = isPlayer;
		changeIcon(char, allowGPU);
		scrollFactor.set();
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (sprTracker != null)
			setPosition(sprTracker.x + sprTracker.width + 12, sprTracker.y - 30);

		if (spinX != 0) rotationX += spinX * elapsed;
		if (spinY != 0) rotationY += spinY * elapsed;
		if (spinZ != 0) rotationZ += spinZ * elapsed;
	}

	private var iconOffsets:Array<Float> = [0, 0];
	public function changeIcon(char:String, ?allowGPU:Bool = true) {
		if(this.char != char) {
			var name:String = 'icons/' + char;
			if(!Paths.fileExists('images/' + name + '.png', IMAGE)) name = 'icons/icon-' + char; //Older versions of psych engine's support
			if(!Paths.fileExists('images/' + name + '.png', IMAGE)) name = 'icons/icon-face'; //Prevents crash from missing icon
			
			var graphic = Paths.image(name, allowGPU);
			var iSize:Float = Math.round(graphic.width / graphic.height);
			loadGraphic(graphic, true, Math.floor(graphic.width / iSize), Math.floor(graphic.height));
			iconOffsets[0] = (width - 150) / iSize;
			iconOffsets[1] = (height - 150) / iSize;
			updateHitbox();

			animation.add(char, [for(i in 0...frames.frames.length) i], 0, false, isPlayer);
			animation.play(char);
			this.char = char;

			if(char.endsWith('-pixel'))
				antialiasing = false;
			else
				antialiasing = ClientPrefs.data.antialiasing;
		}
	}

	public var autoAdjustOffset:Bool = true;
	override function updateHitbox()
	{
		super.updateHitbox();
		if(autoAdjustOffset)
		{
			offset.x = iconOffsets[0];
			offset.y = iconOffsets[1];
		}
	}

	public function getCharacter():String {
		return char;
	}

	override function draw()
	{
		if (rotationX == 0 && rotationY == 0 && rotationZ == 0 && z3d == 0)
		{
			super.draw();
			return;
		}

		var oldAngle:Float = angle;
		var oldScaleX:Float = scale.x;
		var oldScaleY:Float = scale.y;

		var persp:Float = 1;
		if (z3d != 0)
		{
			var dist:Float = perspDist - z3d;
			if (dist < 1) dist = 1;
			persp = perspDist / dist;
		}

		angle = oldAngle + rotationZ;
		scale.x = oldScaleX * Math.cos(rotationY * Math.PI / 180) * persp;
		scale.y = oldScaleY * Math.cos(rotationX * Math.PI / 180) * persp;

		super.draw();

		angle = oldAngle;
		scale.set(oldScaleX, oldScaleY);
	}
}
