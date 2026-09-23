package states;

import flixel.text.FlxText;
import flixel.FlxSprite;
import backend.CrashHandler;

/**
 * Crash Handler State — hiển thị thông tin crash thay vì đóng app.
 * Android: BACK hoặc D-pad B → về MainMenu. Nút Reload → reset game.
 * Có recursion protection: nếu crash lần nữa → chỉ hiện text, không switch tiếp.
 */
class CrashHandlerState extends MusicBeatState
{
	public static var lastCrashMessage:String = '';
	public static var lastCrashStack:String = '';

	var msgText:FlxText;
	var stackText:FlxText;
	var hintText:FlxText;
	var bg:FlxSprite;

	// Recursion protection
	static var enteringCrashState:Bool = false;

	public function new(message:String, stack:String)
	{
		super();
		lastCrashMessage = message;
		lastCrashStack = stack;
	}

	override function create()
	{
		// Recursion protection: nếu đã đang ở CrashHandlerState → không switch tiếp
		if (enteringCrashState)
		{
			trace('[CrashHandler] Recursion detected, showing minimal UI');
		}
		enteringCrashState = true;

		FlxTransitionableState.skipNextTransIn = true;
		FlxTransitionableState.skipNextTransOut = true;

		// Nền đen đơn giản — không load asset (tránh crash lần 2)
		bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, 0xFF1A1A2E);
		bg.scrollFactor.set();
		add(bg);

		// Tiêu đề
		var title:FlxText = new FlxText(0, 20, FlxG.width, 'GAME CRASHED', 48);
		title.setFormat(Paths.font("vcr.ttf"), 48, 0xFFFF4444, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		title.borderSize = 3;
		title.scrollFactor.set();
		add(title);

		// Thông báo lỗi
		msgText = new FlxText(0, 80, FlxG.width - 40, lastCrashMessage, 20);
		msgText.setFormat(Paths.font("vcr.ttf"), 20, 0xFFCCCCCC, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		msgText.borderSize = 2;
		msgText.x = 20;
		msgText.scrollFactor.set();
		add(msgText);

		// Stack trace (giới hạn 2000 ký tự để không lag)
		var displayStack:String = lastCrashStack;
		if (displayStack.length > 2000)
			displayStack = displayStack.substring(0, 2000) + '\n... (truncated, full log in crash/)';
		stackText = new FlxText(0, 140, FlxG.width - 40, displayStack, 14);
		stackText.setFormat(Paths.font("vcr.ttf"), 14, 0xFF888888, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		stackText.borderSize = 1;
		stackText.x = 20;
		stackText.scrollFactor.set();
		add(stackText);

		// Hướng dẫn
		hintText = new FlxText(0, FlxG.height - 70, FlxG.width,
			'BACK / B → Main Menu   |   R / A → Reload Game', 22);
		hintText.setFormat(Paths.font("vcr.ttf"), 22, 0xFFFFAA00, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		hintText.borderSize = 2;
		hintText.scrollFactor.set();
		add(hintText);

		// D-pad cho Android
		#if mobile
		addTouchPad('NONE', 'A_B');
		addTouchPadCamera();
		#end

		trace('[CrashHandler] CrashHandlerState loaded: ' + lastCrashMessage);

		super.create();
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		// BACK / ESC → về Main Menu
		if (controls.BACK || (touchPad != null && touchPad.buttonB.justPressed))
		{
			trace('[CrashHandler] Returning to Main Menu');
			enteringCrashState = false;
			CrashHandler.crashHandlerActive = false;
			FlxG.sound.music.stop();

			FlxTransitionableState.skipNextTransIn = true;
			FlxTransitionableState.skipNextTransOut = true;
			MusicBeatState.switchState(new MainMenuState());
		}

		// R / A → reload game (reset toàn bộ)
		if (FlxG.keys.justPressed.R || (touchPad != null && touchPad.buttonA.justPressed))
		{
			trace('[CrashHandler] Reloading game');
			enteringCrashState = false;
			CrashHandler.crashHandlerActive = false;
			FlxG.sound.music.stop();

			FlxTransitionableState.skipNextTransIn = true;
			FlxTransitionableState.skipNextTransOut = true;
			FlxG.resetState();
		}
	}

	override function destroy()
	{
		enteringCrashState = false;
		super.destroy();
	}
}
