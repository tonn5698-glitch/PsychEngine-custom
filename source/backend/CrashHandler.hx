package backend;

import openfl.events.UncaughtErrorEvent;
import openfl.events.ErrorEvent;
import openfl.errors.Error;
import flixel.addons.transition.FlxTransitionableState;
import backend.MusicBeatState;
#if sys
import sys.FileSystem;
import sys.io.File;
#end

using StringTools;
using flixel.util.FlxArrayUtil;

/**
 * Crash Handler — bắt lỗi Haxe/OpenFL, hiện CrashHandlerState thay vì đóng app.
 * Lưu crash log vào <storage>/crash/.
 * Có recursion protection: crash lần 2 → không switch tiếp.
 * KHÔNG bắt native crash (segfault, JNI, GPU driver, OOM kill).
 */
class CrashHandler
{
	// Recursion protection
	public static var crashHandlerActive:Bool = false;
	// Deferred crash: không switch state ngay trong error callback
	static var pendingCrash:Bool = false;
	static var pendingMsg:String = '';
	static var pendingStack:String = '';
	// Poll flag — kiểm tra mỗi frame
	public static var checkPendingCrash:Bool = false;

	public static function init():Void
	{
		openfl.Lib.current.loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR, onUncaughtError);
		#if cpp
		untyped __global__.__hxcpp_set_critical_error_handler(onError);
		#elseif hl
		hl.Api.setErrorHandler(onError);
		#end
	}

	/**
	 * Gọi mỗi frame từ MusicBeatState.update() để chuyển state an toàn.
	 */
	public static function processPendingCrash():Void
	{
		if (!pendingCrash) return;
		pendingCrash = false;
		crashHandlerActive = true;

		try {
			// Dọn cache an toàn
			try { FlxG.bitmap.clearCache(); } catch (e:Dynamic) {}
			try { FlxG.sound.music.stop(); } catch (e:Dynamic) {}

			FlxTransitionableState.skipNextTransIn = true;
			FlxTransitionableState.skipNextTransOut = true;
			MusicBeatState.switchState(new states.CrashHandlerState(pendingMsg, pendingStack));
		} catch (e:Dynamic) {
			trace('[CrashHandler] Failed to switch state: ' + e);
			// Fallback: vẫn exit nếu không switch được
			lime.system.System.exit(1);
		}
	}

	private static function onUncaughtError(e:UncaughtErrorEvent):Void
	{
		// Recursion protection
		if (crashHandlerActive)
		{
			trace('[CrashHandler] Recursion detected, ignoring second crash');
			return;
		}

		e.preventDefault();
		e.stopPropagation();
		e.stopImmediatePropagation();

		// Capture error message
		var m:String = 'Unknown error';
		try {
			m = e.error;
			if (Std.isOfType(e.error, Error))
			{
				var err = cast(e.error, Error);
				m = '${err.message}';
			}
			else if (Std.isOfType(e.error, ErrorEvent))
			{
				var err = cast(e.error, ErrorEvent);
				m = '${err.text}';
			}
		} catch (e:Dynamic) {
			m = 'Error capturing message: ' + e;
		}

		// Capture stack trace
		var stackLabel:String = '';
		try {
			stackLabel = captureStack();
		} catch (e:Dynamic) {
			stackLabel = 'Stack trace unavailable: ' + e;
		}

		// Save crash log
		saveCrashLog(m, stackLabel);

		// Defer state switch — KHÔNG switch ngay trong error callback
		pendingMsg = m;
		pendingStack = stackLabel;
		pendingCrash = true;
		checkPendingCrash = true;

		trace('[CrashHandler] Crash captured: ' + m);
	}

	#if (cpp || hl)
	private static function onError(message:Dynamic):Void
	{
		if (crashHandlerActive) return;

		var msg:String = 'Critical error';
		var stackStr:String = '';
		try {
			if (message != null) msg = Std.string(message);
			stackStr = haxe.CallStack.toString(haxe.CallStack.exceptionStack(true));
		} catch (e:Dynamic) {}

		saveCrashLog(msg, stackStr);

		pendingMsg = msg;
		pendingStack = stackStr;
		pendingCrash = true;
		checkPendingCrash = true;
	}
	#end

	static function captureStack():String
	{
		var stack = haxe.CallStack.exceptionStack(true);
		var lines:Array<String> = [];
		for (e in stack)
		{
			switch (e)
			{
				case CFunction:
					lines.push('Non-Haxe (C) Function');
				case Module(c):
					lines.push('Module ${c}');
				case FilePos(parent, file, line, col):
					switch (parent)
					{
						case Method(cla, func):
							lines.push('${file.replace('.hx', '')}.$func() [line $line]');
						case _:
							lines.push('${file.replace('.hx', '')} [line $line]');
					}
				case LocalFunction(v):
					lines.push('Local Function ${v}');
				case Method(cl, m):
					lines.push('${cl} - ${m}');
			}
		}
		return lines.join('\n');
	}

	static function saveCrashLog(message:String, stack:String):Void
	{
		try {
			#if sys
			var folder:String = #if android
				mobile.backend.StorageUtil.getExternalStorageDirectory() + #else Sys.getCwd() + #end
				'crash/';
			if (!FileSystem.exists(folder))
				FileSystem.createDirectory(folder);

			// Timestamp an toàn cho Android (không dùng ':')
			var now = Date.now();
			var ts:String = now.getFullYear() + '-' +
				StringTools.lpad(Std.string(now.getMonth() + 1), '0', 2) + '-' +
				StringTools.lpad(Std.string(now.getDate()), '0', 2) + '_' +
				StringTools.lpad(Std.string(now.getHours()), '0', 2) + '-' +
				StringTools.lpad(Std.string(now.getMinutes()), '0', 2) + '-' +
				StringTools.lpad(Std.string(now.getSeconds()), '0', 2);

			var content:String = [
				'---',
				'PSYCH ENGINE CRASH REPORT',
				'',
				'Date: ' + now.toString(),
				'Platform: ' + #if android 'Android' #elseif desktop 'Desktop' #else 'Unknown' #end,
				'Engine version: ' + states.MainMenuState.psychEngineVersion,
				'',
				'Exception:',
				message,
				'',
				'Stack trace:',
				stack,
				'---'
			].join('\n');

			File.saveContent(folder + 'crash_' + ts + '.txt', content);
			trace('[CrashHandler] Crash log saved to ' + folder);
			#end
		} catch (e:Dynamic) {
			trace('[CrashHandler] Failed to save crash log: ' + e);
		}
	}
}
