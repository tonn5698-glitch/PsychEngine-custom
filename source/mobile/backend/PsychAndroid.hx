package mobile.backend;

#if android
import lime.system.JNI;

class PsychAndroid #if (lime >= "8.0.0") implements JNISafety #end
{
	public static inline function requestNotifPermission():Void
		requestNotifPermission_jni();

	public static inline function hasNotifPermission():Bool
		return hasNotifPermission_jni();

	public static inline function showNotification(title:String, message:String, id:Int = 1):Bool
		return showNotification_jni(title, message, id);

	public static inline function openApp(pkg:String):Bool
		return openApp_jni(pkg);

	public static inline function openFile(path:String, mime:String = "*/*"):Bool
		return openFile_jni(path, mime);

	public static inline function openUrl(url:String):Bool
		return openUrl_jni(url);

	@:noCompletion private static var requestNotifPermission_jni:Dynamic = JNI.createStaticMethod('org/libsdl/app/PsychAndroid', 'requestNotifPermission', '()V');
	@:noCompletion private static var hasNotifPermission_jni:Dynamic = JNI.createStaticMethod('org/libsdl/app/PsychAndroid', 'hasNotifPermission', '()Z');
	@:noCompletion private static var showNotification_jni:Dynamic = JNI.createStaticMethod('org/libsdl/app/PsychAndroid', 'showNotification', '(Ljava/lang/String;Ljava/lang/String;I)Z');
	@:noCompletion private static var openApp_jni:Dynamic = JNI.createStaticMethod('org/libsdl/app/PsychAndroid', 'openApp', '(Ljava/lang/String;)Z');
	@:noCompletion private static var openFile_jni:Dynamic = JNI.createStaticMethod('org/libsdl/app/PsychAndroid', 'openFile', '(Ljava/lang/String;Ljava/lang/String;)Z');
	@:noCompletion private static var openUrl_jni:Dynamic = JNI.createStaticMethod('org/libsdl/app/PsychAndroid', 'openUrl', '(Ljava/lang/String;)Z');
}
#end
