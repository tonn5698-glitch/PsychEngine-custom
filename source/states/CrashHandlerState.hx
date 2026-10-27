package states;

import flixel.text.FlxText;
import flixel.FlxSprite;
import backend.CrashHandler;

/**
 * Crash Handler State — hiển thị thông tin crash thay vì đóng app.
 * 3 nút (chạm / chuột): Copy (clipboard), Back (về Main Menu), Exit (thoát app).
 * Phím tắt: C = copy, B / BACK = về menu, Q = thoát.
 * Không dùng TouchPad/controls của engine cho các nút, để màn hình này không phụ thuộc state đã hỏng.
 */
class CrashHandlerState extends MusicBeatState
{
	public static var lastCrashMessage:String = '';
	public static var lastCrashStack:String = '';

	var bg:FlxSprite;
	var msgText:FlxText;
	var stackText:FlxText;
	var statusText:FlxText;

	var buttons:Array<{bg:FlxSprite, label:FlxText, action:Void->Void}> = [];
	var leaving:Bool = false;

	public function new(message:String, stack:String)
	{
		super();
		lastCrashMessage = message;
		lastCrashStack = stack;
	}

	override function create()
	{
		FlxTransitionableState.skipNextTransIn = true;
		FlxTransitionableState.skipNextTransOut = true;

		// Nền đơn giản — không load asset ảnh (tránh crash lần 2)
		bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, 0xFF1A1A2E);
		bg.scrollFactor.set();
		add(bg);

		var title:FlxText = new FlxText(0, 20, FlxG.width, 'GAME CRASHED', 48);
		title.setFormat(Paths.font("vcr.ttf"), 48, 0xFFFF4444, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		title.borderSize = 3;
		title.scrollFactor.set();
		add(title);

		msgText = new FlxText(20, 80, FlxG.width - 40, lastCrashMessage, 20);
		msgText.setFormat(Paths.font("vcr.ttf"), 20, 0xFFCCCCCC, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		msgText.borderSize = 2;
		msgText.scrollFactor.set();
		add(msgText);

		// Chỉ hiện vài dòng đầu của stack (đủ chỗ cho nút); bản đầy đủ nằm trong nút Copy và file crash/
		var lines:Array<String> = lastCrashStack.split('\n');
		var maxLines:Int = 14;
		var displayStack:String = lines.slice(0, maxLines).join('\n');
		if (lines.length > maxLines)
			displayStack += '\n... (+' + (lines.length - maxLines) + ' lines, use Copy for the full report)';
		stackText = new FlxText(20, 190, FlxG.width - 40, displayStack, 14);
		stackText.setFormat(Paths.font("vcr.ttf"), 14, 0xFF888888, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		stackText.borderSize = 1;
		stackText.scrollFactor.set();
		add(stackText);

		// Thông báo trạng thái (Copied!...) nằm ngay trên hàng nút
		statusText = new FlxText(0, FlxG.height - 150, FlxG.width, '', 22);
		statusText.setFormat(Paths.font("vcr.ttf"), 22, 0xFF66FF99, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		statusText.borderSize = 2;
		statusText.scrollFactor.set();
		add(statusText);

		// 3 nút: Copy | Back | Exit
		var gap:Int = 30;
		var btnW:Int = Std.int(Math.min(300, (FlxG.width - gap * 4) / 3));
		var btnH:Int = 80;
		var startX:Float = (FlxG.width - (btnW * 3 + gap * 2)) / 2;
		var btnY:Float = FlxG.height - btnH - 40;
		addButton(startX, btnY, btnW, btnH, 'COPY', 0xFF2E7D32, doCopy);
		addButton(startX + btnW + gap, btnY, btnW, btnH, 'BACK', 0xFF1565C0, goBack);
		addButton(startX + (btnW + gap) * 2, btnY, btnW, btnH, 'EXIT', 0xFFC62828, doExit);

		#if !mobile
		FlxG.mouse.visible = true;
		#end

		trace('[CrashHandler] CrashHandlerState loaded: ' + lastCrashMessage);

		super.create();
	}

	function addButton(x:Float, y:Float, w:Int, h:Int, text:String, color:FlxColor, action:Void->Void)
	{
		var b:FlxSprite = new FlxSprite(x, y).makeGraphic(w, h, color);
		b.scrollFactor.set();
		add(b);

		var t:FlxText = new FlxText(x, y + (h - 30) / 2, w, text, 30);
		t.setFormat(Paths.font("vcr.ttf"), 30, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		t.borderSize = 2;
		t.scrollFactor.set();
		add(t);

		buttons.push({bg: b, label: t, action: action});
	}

	function pressed(spr:FlxSprite):Bool
	{
		if (FlxG.mouse.justPressed && spr.overlapsPoint(FlxG.mouse.getWorldPosition(FlxG.camera)))
			return true;
		#if FLX_TOUCH
		for (t in FlxG.touches.list)
			if (t.justPressed && spr.overlapsPoint(t.getWorldPosition(FlxG.camera)))
				return true;
		#end
		return false;
	}

	function showStatus(text:String, color:FlxColor = 0xFF66FF99)
	{
		statusText.text = text;
		statusText.color = color;
	}

	function doCopy()
	{
		try
		{
			lime.system.Clipboard.text = CrashHandler.buildReport(lastCrashMessage, lastCrashStack);
			showStatus('Copied to clipboard!');
		}
		catch (e:Dynamic)
		{
			showStatus('Copy failed: ' + e, 0xFFFF6666);
		}
	}

	function goBack()
	{
		if (leaving) return;
		leaving = true;
		trace('[CrashHandler] Returning to Main Menu');

		try { FlxG.sound.music.stop(); } catch (e:Dynamic) {}
		try { PlayState.instance = null; } catch (e:Dynamic) {}
		// dọn cache đúng cách (clearCache() sẽ destroy cả graphic mà Paths vẫn đang giữ → crash render sau đó)
		try { Paths.clearStoredMemory(); Paths.clearUnusedMemory(); } catch (e:Dynamic) {}

		CrashHandler.crashHandlerActive = false;
		FlxTransitionableState.skipNextTransIn = true;
		FlxTransitionableState.skipNextTransOut = true;
		try
		{
			MusicBeatState.switchState(new MainMenuState());
		}
		catch (e:Dynamic)
		{
			leaving = false;
			CrashHandler.crashHandlerActive = true;
			showStatus('Cannot go back: ' + e, 0xFFFF6666);
		}
	}

	function doExit()
	{
		lime.system.System.exit(0);
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (FlxG.keys.justPressed.C) doCopy();
		if (FlxG.keys.justPressed.Q) doExit();
		if (controls.BACK || FlxG.keys.justPressed.B) goBack();

		for (b in buttons)
			if (pressed(b.bg))
			{
				b.action();
				break;
			}
	}

	override function destroy()
	{
		buttons = [];
		super.destroy();
	}
}
