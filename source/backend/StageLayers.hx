package backend;

import flixel.FlxBasic;
import haxe.ds.ObjectMap;

/**
 * Layer cho object của stage (JSON "layer" + Lua setObjectLayer/getObjectLayer).
 * Layer lớn hơn = vẽ phía trước. Cùng layer thì giữ thứ tự gốc.
 */
class StageLayers
{
	public static var map:ObjectMap<FlxBasic, Int> = new ObjectMap();

	public static function clear():Void
	{
		map = new ObjectMap();
	}

	public static function layerOf(data:Dynamic):Int
	{
		var l:Dynamic = (data != null) ? Reflect.field(data, 'layer') : null;
		if(l == null) return 0;
		var f:Float = Std.parseFloat(Std.string(l));
		return Math.isNaN(f) ? 0 : Std.int(f);
	}

	public static function register(obj:FlxBasic, data:Dynamic):Void
	{
		if(obj != null) map.set(obj, layerOf(data));
	}

	public static function get(obj:FlxBasic):Int
	{
		var v:Null<Int> = (obj != null) ? map.get(obj) : null;
		return v != null ? v : 0;
	}

	/** Thứ tự index của objectList sau khi sort ổn định theo layer. */
	public static function sortedOrder(list:Array<Dynamic>):Array<Int>
	{
		var order:Array<Int> = [for (i in 0...list.length) i];
		order.sort(function(a:Int, b:Int):Int
		{
			var la:Int = layerOf(list[a]);
			var lb:Int = layerOf(list[b]);
			return la != lb ? (la < lb ? -1 : 1) : a - b;
		});
		return order;
	}

	/**
	 * Runtime (PlayState / Lua): đổi layer rồi đưa object tới đúng vị trí trong group,
	 * so với các object đã có layer (JSON object, character group, hoặc object từng gọi setLayer).
	 */
	public static function setLayer(group:Dynamic, obj:FlxBasic, layer:Int):Void
	{
		if(obj == null || group == null) return;
		map.set(obj, layer);

		var members:Array<FlxBasic> = group.members;
		if(members == null || members.indexOf(obj) < 0) return;

		group.remove(obj, true);
		members = group.members;

		var lastLE:Int = -1;
		var firstGT:Int = -1;
		for (i in 0...members.length)
		{
			var m:FlxBasic = members[i];
			if(m == null || !map.exists(m)) continue;
			if(map.get(m) <= layer) lastLE = i;
			else if(firstGT < 0) firstGT = i;
		}

		var pos:Int;
		if(lastLE >= 0) pos = lastLE + 1;
		else if(firstGT >= 0) pos = firstGT;
		else pos = members.length;

		group.insert(pos, obj);
	}
}
