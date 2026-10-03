package funkin.backend.system;

/**
 * Shim: CNE Controls API → Psych Engine Controls.
 * CNE dùng UP/UP_P/LEFT_P, Psych dùng UI_UP_P/NOTE_LEFT_P.
 * Shim này alias các tên control phổ biến.
 */
class Controls
{
	// Delegate to Psych Controls
	public static var instance(get, never):backend.Controls;
	static inline function get_instance():backend.Controls return backend.Controls.instance;

	// CNE-style properties → delegate to Psych Controls.instance
	public static var UP(get, never):Bool;
	static inline function get_UP():Bool return backend.Controls.instance.UI_UP;

	public static var UP_P(get, never):Bool;
	static inline function get_UP_P():Bool return backend.Controls.instance.UI_UP_P;

	public static var UP_R(get, never):Bool;
	static inline function get_UP_R():Bool return backend.Controls.instance.UI_UP_R;

	public static var DOWN(get, never):Bool;
	static inline function get_DOWN():Bool return backend.Controls.instance.UI_DOWN;

	public static var DOWN_P(get, never):Bool;
	static inline function get_DOWN_P():Bool return backend.Controls.instance.UI_DOWN_P;

	public static var DOWN_R(get, never):Bool;
	static inline function get_DOWN_R():Bool return backend.Controls.instance.UI_DOWN_R;

	public static var LEFT(get, never):Bool;
	static inline function get_LEFT():Bool return backend.Controls.instance.UI_LEFT;

	public static var LEFT_P(get, never):Bool;
	static inline function get_LEFT_P():Bool return backend.Controls.instance.UI_LEFT_P;

	public static var LEFT_R(get, never):Bool;
	static inline function get_LEFT_R():Bool return backend.Controls.instance.UI_LEFT_R;

	public static var RIGHT(get, never):Bool;
	static inline function get_RIGHT():Bool return backend.Controls.instance.UI_RIGHT;

	public static var RIGHT_P(get, never):Bool;
	static inline function get_RIGHT_P():Bool return backend.Controls.instance.UI_RIGHT_P;

	public static var RIGHT_R(get, never):Bool;
	static inline function get_RIGHT_R():Bool return backend.Controls.instance.UI_RIGHT_R;

	public static var NOTE_UP(get, never):Bool;
	static inline function get_NOTE_UP():Bool return backend.Controls.instance.NOTE_UP;

	public static var NOTE_UP_P(get, never):Bool;
	static inline function get_NOTE_UP_P():Bool return backend.Controls.instance.NOTE_UP_P;

	public static var NOTE_UP_R(get, never):Bool;
	static inline function get_NOTE_UP_R():Bool return backend.Controls.instance.NOTE_UP_R;

	public static var NOTE_DOWN(get, never):Bool;
	static inline function get_NOTE_DOWN():Bool return backend.Controls.instance.NOTE_DOWN;

	public static var NOTE_DOWN_P(get, never):Bool;
	static inline function get_NOTE_DOWN_P():Bool return backend.Controls.instance.NOTE_DOWN_P;

	public static var NOTE_DOWN_R(get, never):Bool;
	static inline function get_NOTE_DOWN_R():Bool return backend.Controls.instance.NOTE_DOWN_R;

	public static var NOTE_LEFT(get, never):Bool;
	static inline function get_NOTE_LEFT():Bool return backend.Controls.instance.NOTE_LEFT;

	public static var NOTE_LEFT_P(get, never):Bool;
	static inline function get_NOTE_LEFT_P():Bool return backend.Controls.instance.NOTE_LEFT_P;

	public static var NOTE_LEFT_R(get, never):Bool;
	static inline function get_NOTE_LEFT_R():Bool return backend.Controls.instance.NOTE_LEFT_R;

	public static var NOTE_RIGHT(get, never):Bool;
	static inline function get_NOTE_RIGHT():Bool return backend.Controls.instance.NOTE_RIGHT;

	public static var NOTE_RIGHT_P(get, never):Bool;
	static inline function get_NOTE_RIGHT_P():Bool return backend.Controls.instance.NOTE_RIGHT_P;

	public static var NOTE_RIGHT_R(get, never):Bool;
	static inline function get_NOTE_RIGHT_R():Bool return backend.Controls.instance.NOTE_RIGHT_R;

	public static var ACCEPT(get, never):Bool;
	static inline function get_ACCEPT():Bool return backend.Controls.instance.ACCEPT;

	public static var ACCEPT_R(get, never):Bool;
	static inline function get_ACCEPT_R():Bool return false;

	public static var BACK(get, never):Bool;
	static inline function get_BACK():Bool return backend.Controls.instance.BACK;

	public static var BACK_R(get, never):Bool;
	static inline function get_BACK_R():Bool return false;

	public static var PAUSE(get, never):Bool;
	static inline function get_PAUSE():Bool return backend.Controls.instance.PAUSE;

	public static var RESET(get, never):Bool;
	static inline function get_RESET():Bool return false;

	// String-based API (Psych style)
	public static function justPressed(key:String):Bool
		return backend.Controls.instance.justPressed(key);

	public static function pressed(key:String):Bool
		return backend.Controls.instance.pressed(key);

	public static function justReleased(key:String):Bool
		return backend.Controls.instance.justReleased(key);
}
