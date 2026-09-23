package backend;

#if sys
import sys.FileSystem;
import sys.io.File;
#end

using StringTools;

/**
 * Haxe Log — ghi trace/error output vào file khi được bật.
 * Hữu ích cho modding: xem mod bị lỗi gì mà không cần debug build.
 * Bật/tắt qua Settings → Graphics → Enable Haxe Logs
 */
class HaxeLog
{
	public static var enabled:Bool = false;
	public static var logPath:String = '';

	static var buffer:Array<String> = [];
	static var flushThreshold:Int = 20; // flush sau mỗi N dòng
	static var currentSession:String = '';

	/**
	 * Gọi khi game start. Nếu enabled → mở file log mới + override trace().
	 */
	public static function init():Void
	{
		if (!ClientPrefs.data.enableHaxeLogs) return;

		try {
			#if sys
			var folder:String = #if android
				mobile.backend.StorageUtil.getExternalStorageDirectory() + #else Sys.getCwd() + #end
				'logs/Haxe/';
			if (!FileSystem.exists(folder))
				FileSystem.createDirectory(folder);

			var now = Date.now();
			currentSession = now.getFullYear() +
				StringTools.lpad(Std.string(now.getMonth() + 1), '0', 2) +
				StringTools.lpad(Std.string(now.getDate()), '0', 2) + '_' +
				StringTools.lpad(Std.string(now.getHours()), '0', 2) +
				StringTools.lpad(Std.string(now.getMinutes()), '0', 2) +
				StringTools.lpad(Std.string(now.getSeconds()), '0', 2);

			logPath = folder + currentSession + '.log';
			File.saveContent(logPath, '=== Haxe Log Session ' + currentSession + ' ===\n');
			enabled = true;

			// Override global trace() để capture mọi output
			var origTrace = haxe.Log.trace;
			haxe.Log.trace = function(v:Dynamic, ?pos:haxe.PosInfos) {
				write('[TRACE] ' + Std.string(v) + (pos != null ? ' (' + pos.fileName + ':' + pos.lineNumber + ')' : ''));
				origTrace(v, pos); // vẫn ghi vào logcat
			};

			trace('[HaxeLog] Log enabled: ' + logPath);
			#end
		} catch (e:Dynamic) {
			trace('[HaxeLog] Failed to init: ' + e);
			enabled = false;
		}
	}

	/**
	 * Ghi 1 dòng vào log. Gọi từ bất kỳ đâu.
	 */
	public static function write(message:String):Void
	{
		if (!enabled || logPath == null) return;

		buffer.push(Std.string(message));

		// Flush định kỳ
		if (buffer.length >= flushThreshold)
			flush();
	}

	/**
	 * Ghi error (với timestamp + tag).
	 */
	public static function error(message:String, ?tag:String):Void
	{
		var prefix:String = tag != null ? '[$tag] ' : '';
		write('[ERROR] ' + prefix + Std.string(message));
		// Error luôn flush ngay
		flush();
	}

	/**
	 * Ghi warning.
	 */
	public static function warn(message:String, ?tag:String):Void
	{
		var prefix:String = tag != null ? '[$tag] ' : '';
		write('[WARN] ' + prefix + Std.string(message));
	}

	/**
	 * Flush buffer → file.
	 */
	public static function flush():Void
	{
		if (buffer.length == 0 || logPath == null) return;

		try {
			#if sys
			var now = Date.now();
			var ts:String = StringTools.lpad(Std.string(now.getHours()), '0', 2) + ':' +
				StringTools.lpad(Std.string(now.getMinutes()), '0', 2) + ':' +
				StringTools.lpad(Std.string(now.getSeconds()), '0', 2);

			var lines:Array<String> = [];
			for (msg in buffer)
				lines.push('[' + ts + '] ' + msg);

			File.append(logPath, lines.join('\n') + '\n');
			buffer = [];
			#end
		} catch (e:Dynamic) {
			// Không crash vì log fail
			buffer = [];
		}
	}

	/**
	 * Gọi khi game exit để flush lần cuối.
	 */
	public static function shutdown():Void
	{
		flush();
		enabled = false;
	}
}
