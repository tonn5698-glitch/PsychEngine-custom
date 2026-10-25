package objects;

#if !flash
import flixel.addons.display.FlxRuntimeShader;
#end

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

	/**
	 * true: rotationY dùng perspective thật bằng shader (cạnh gần to, cạnh xa nhỏ) thay vì chỉ scale.x * cos.
	 * Mặc định false → giữ cách cũ.
	 */
	public var persp3d:Bool = false;
	/** Khoảng cách camera tính theo bề rộng icon (nhỏ = perspective mạnh, tối thiểu ~1.2). */
	public var persp3dDist:Float = 2.5;

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

	#if !flash
	var _perspShader:FlxRuntimeShader;

	static final PERSP_FRAG:String = "
#pragma header
uniform float uAngle;
uniform float uDist;
uniform vec4 uRect;
uniform float uFlip;

void main()
{
	vec2 size = uRect.zw - uRect.xy;
	vec2 lc = (openfl_TextureCoordv - uRect.xy) / size;
	if (uFlip < 0.0) lc.x = 1.0 - lc.x;

	float c = cos(uAngle);
	float sn = sin(uAngle);
	float s = (uDist - 0.5 * abs(sn)) / uDist;
	vec2 p = (lc - 0.5) / s;

	float den = uDist * c - p.x * sn;
	if (abs(den) < 0.0001) { gl_FragColor = vec4(0.0); return; }

	float u = p.x * uDist / den;
	float v = p.y * (uDist + u * sn) / uDist;
	vec2 src = vec2(u, v) + 0.5;

	if (src.x < 0.0 || src.x > 1.0 || src.y < 0.0 || src.y > 1.0) { gl_FragColor = vec4(0.0); return; }

	if (uFlip < 0.0) src.x = 1.0 - src.x;
	gl_FragColor = flixel_texture2D(bitmap, uRect.xy + src * size);
}
";

	function updatePerspShader():Void
	{
		if (_perspShader == null) _perspShader = new FlxRuntimeShader(PERSP_FRAG);
		var uv = frame.uv;
		_perspShader.setFloat('uAngle', rotationY * Math.PI / 180);
		_perspShader.setFloat('uDist', Math.max(1.2, persp3dDist));
		_perspShader.setFloatArray('uRect', [uv.left, uv.top, uv.right, uv.bottom]);
		var flipped:Bool = flipX != (animation.curAnim != null && animation.curAnim.flipX);
		_perspShader.setFloat('uFlip', flipped ? -1 : 1);
		if (shader != _perspShader) shader = _perspShader;
	}
	#end

	override function draw()
	{
		var usePersp:Bool = false;
		#if !flash
		usePersp = persp3d && rotationY != 0 && frame != null && frame.uv != null;
		if (!usePersp && _perspShader != null && shader == _perspShader) shader = null;
		#end

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

		#if !flash
		if (usePersp) updatePerspShader();
		#end

		angle = oldAngle + rotationZ;
		scale.x = oldScaleX * (usePersp ? 1 : Math.cos(rotationY * Math.PI / 180)) * persp;
		scale.y = oldScaleY * Math.cos(rotationX * Math.PI / 180) * persp;

		super.draw();

		angle = oldAngle;
		scale.set(oldScaleX, oldScaleY);
	}
}
