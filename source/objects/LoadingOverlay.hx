package objects;

import backend.Mods;
import backend.Paths;
import flixel.FlxBasic;
import mobile.backend.TouchUtil;
#if MODS_ALLOWED
import sys.FileSystem;
#end
#if HSCRIPT_ALLOWED
import psychlua.HScript;
#end

/**
 * Overlay hiển thị trong lúc PlayState khởi tạo theo từng phase (xem PlayState.create()/runNextCreationPhase).
 * Nằm trên camera riêng (camLoad) nên che phủ toàn bộ stage/HUD đang được dựng dở.
 * Không hardcode UI theo kiểu loading screen của mod — đây chỉ là màn progress trung tính.
 */
class LoadingOverlay extends FlxSpriteGroup
{
	public var onFaded:Void->Void = null;
	#if HSCRIPT_ALLOWED
	var customScript:HScript;
	#end
	var awaitingContinue:Bool = false;
	var completedNotified:Bool = false;

	var bg:FlxSprite;
	var logo:FlxSprite;
	var barBack:FlxSprite;
	var bar:FlxSprite;
	var statusText:FlxText;
	var percentText:FlxText;

	var barWidth:Float = 0;
	var targetPercent:Float = 0;
	var shownPercent:Float = 0;
	var time:Float = 0;
	var logoBaseY:Float = 0;
	var bouncing:Bool = true;

	var fading:Bool = false;
	var fadeTime:Float = 0;
	static inline var FADE_TIME:Float = 0.35;

	public function new(cam:FlxCamera)
	{
		super();
		scrollFactor.set();

		bg = new FlxSprite(0, 0).makeGraphic(FlxG.width, FlxG.height, 0xFF000000);
		add(bg);

		logo = new FlxSprite(0, 0);
		var icon:Dynamic = null;
		try { icon = Paths.image('loading_screen/icon'); } catch(e:Dynamic) {}
		if(icon != null)
		{
			logo.loadGraphic(icon);
			logo.scale.set(0.75, 0.75);
			logo.updateHitbox();
		}
		else
		{
			// thiếu asset → ô vuông thay thế, không chặn loading
			logo.makeGraphic(160, 160, 0xFF6644AA);
		}
		logo.x = (FlxG.width - logo.width) / 2 - 50;
		logo.y = FlxG.height * 0.30;
		logoBaseY = logo.y;
		add(logo);

		barBack = new FlxSprite(0, FlxG.height - 115).makeGraphic(1, 1, 0xFF111111);
		barBack.scale.set(FlxG.width - 300, 25);
		barBack.updateHitbox();
		barBack.x = (FlxG.width - barBack.width) / 2;
		add(barBack);

		bar = new FlxSprite(barBack.x + 5, barBack.y + 5).makeGraphic(1, 1, FlxColor.WHITE);
		bar.scale.set(0, 15);
		bar.updateHitbox();
		barWidth = barBack.width - 10;
		add(bar);

		statusText = new FlxText(0, barBack.y - 44, FlxG.width, 'Preparing gameplay...', 24);
		statusText.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		statusText.borderSize = 2;
		statusText.scrollFactor.set();
		add(statusText);

		percentText = new FlxText(0, barBack.y + barBack.height + 8, FlxG.width, '0%', 20);
		percentText.setFormat(Paths.font("vcr.ttf"), 20, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		percentText.borderSize = 2;
		percentText.scrollFactor.set();
		add(percentText);

		if (cam != null)
		{
			cameras = [cam];
			for (m in members)
				if (m != null) m.cameras = [cam];
		}
		loadCustomScript();
	}

	/** Preload callback is run by LoadingState before PlayState is created. */
	public static function preloadForCurrentMod():Void
	{
		#if (MODS_ALLOWED && HSCRIPT_ALLOWED)
		var path:String = resolveCustomScriptPath();
		if (path == null) return;
		var preloadScript:HScript = null;
		try
		{
			preloadScript = new HScript(null, path);
			if (preloadScript.exists('onPreload')) preloadScript.call('onPreload');
		}
		catch(e:Dynamic) trace('[LoadingOverlay] onPreload failed: ' + e);
		if (preloadScript != null) preloadScript.destroy();
		#end
	}

	#if (MODS_ALLOWED && HSCRIPT_ALLOWED)
	static function resolveCustomScriptPath():Null<String>
	{
		var modsToCheck:Array<String> = [];
		if (Mods.currentModDirectory != null && Mods.currentModDirectory.length > 0)
			modsToCheck.push(Mods.currentModDirectory);
		// LoadLogo is a global loading-overlay mod: check it before the song mod.
		if (!modsToCheck.contains('LoadLogo')) modsToCheck.insert(0, 'LoadLogo');
		for (mod in modsToCheck)
		for (root in Paths.modRootDirs)
		{
			var base:String = Paths.modsRootByName(root) + mod + '/CustomStates/loading-overlay/';
			for (file in ['OverlayLoading.hx', 'main.hx', 'loading-overlay.hx'])
			{
				var candidate:String = base + file;
				if (FileSystem.exists(candidate) && !FileSystem.isDirectory(candidate)) return candidate;
			}
		}
		return null;
	}
	#end

	function loadCustomScript():Void
	{
		#if (MODS_ALLOWED && HSCRIPT_ALLOWED)
		var path:String = resolveCustomScriptPath();
		if (path == null) return;
		try
		{
			customScript = new HScript(null, path);
			customScript.set('overlay', this);
			customScript.set('addObject', function(object:FlxBasic) {
				if (object == null) return null;
				add(cast object);
				object.cameras = cameras;
				return object;
			});
			customScript.set('removeObject', function(object:FlxBasic) {
				if (object != null) remove(cast object, true);
			});
			customScript.set('background', bg);
			customScript.set('logo', logo);
			customScript.set('statusText', statusText);
			customScript.set('percentText', percentText);
			customScript.set('bar', bar);
			customScript.set('barBack', barBack);
			if (customScript.exists('onCreate')) customScript.call('onCreate');
		}
		catch(e:Dynamic)
		{
			trace('[LoadingOverlay] custom script failed: ' + e);
			if (customScript != null) customScript.destroy();
			customScript = null;
		}
		#end
	}

	public function loadingCompleted():Void
	{
		if (completedNotified) return;
		completedNotified = true;
		#if HSCRIPT_ALLOWED
		if (customScript != null)
		{
			try
			{
				if (customScript.exists('onLoadingCompleted')) customScript.call('onLoadingCompleted');
				if (customScript.exists('waitForContinue') && customScript.call('waitForContinue').returnValue == true)
				{
					awaitingContinue = true;
					stopBounce();
					return;
				}
			}
			catch(e:Dynamic) trace('[LoadingOverlay] completion callback failed: ' + e);
		}
		#end
		beginFade();
	}

	function continueFromOverlay():Void
	{
		if (!awaitingContinue || fading) return;
		awaitingContinue = false;
		#if HSCRIPT_ALLOWED
		if (customScript != null && customScript.exists('onContinue'))
			try customScript.call('onContinue') catch(e:Dynamic) trace('[LoadingOverlay] onContinue failed: ' + e);
		#end
		beginFade();
	}

	public function setProgress(percent:Float, status:String):Void
	{
		targetPercent = FlxMath.bound(percent, 0, 1);
		if (status != null && status.length > 0) statusText.text = status;
	}

	/** Dừng bounce (đã load xong) — giữ logo đứng yên chờ splash/fade. */
	public function stopBounce():Void
	{
		bouncing = false;
	}

	public function beginFade():Void
	{
		stopBounce();
		fading = true;
		fadeTime = 0;
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);
		time += elapsed;
		#if HSCRIPT_ALLOWED
		if (customScript != null && customScript.exists('onUpdate'))
			try customScript.call('onUpdate', [elapsed]) catch(e:Dynamic) trace('[LoadingOverlay] onUpdate failed: ' + e);
		#end
		if (awaitingContinue && (FlxG.keys.justPressed.ENTER || FlxG.keys.justPressed.SPACE || FlxG.mouse.justPressed || TouchUtil.justPressed))
			continueFromOverlay();

		if (bouncing && logo != null)
		{
			// bounce dồn dập (sin) + lắc nhẹ theo nhịp
			var wave:Float = Math.sin(time * Math.PI * 2 / 0.6);
			logo.y = logoBaseY + wave * 9;
			logo.angle = wave * 4;
		}

		if (shownPercent != targetPercent)
		{
			if (Math.abs(shownPercent - targetPercent) < 0.001) shownPercent = targetPercent;
			else shownPercent = FlxMath.lerp(targetPercent, shownPercent, Math.exp(-elapsed * 12));

			bar.scale.x = barWidth * shownPercent;
			bar.updateHitbox();
			percentText.text = Math.round(shownPercent * 100) + '%';
		}

		if (fading)
		{
			fadeTime += elapsed;
			var a:Float = 1 - Math.min(1, fadeTime / FADE_TIME);
			for (m in members)
				if (m != null) m.alpha = a;

			if (fadeTime >= FADE_TIME && onFaded != null)
			{
				var cb:Void->Void = onFaded;
				onFaded = null;
				cb();
			}
		}
	}

	public function disposeCustomScript():Void
	{
		#if HSCRIPT_ALLOWED
		if (customScript != null)
		{
			try if (customScript.exists('onDestroy')) customScript.call('onDestroy') catch(e:Dynamic) trace('[LoadingOverlay] onDestroy failed: ' + e);
			customScript.destroy();
			customScript = null;
		}
		#end
	}
}
