package options;

import backend.LoadingPerformance;
import backend.MusicBeatSubstate;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import haxe.Json;

class PerformanceBenchmarkSubState extends MusicBeatSubstate
{
	var title:FlxText;
	var status:FlxText;
	var result:FlxText;
	var step:Int = 0;
	var assetMs:Float = 0;
	var objectMs:Float = 0;
	var chartMs:Float = 0;
	var started:Float;

	public function new()
	{
		super();
		title = new FlxText(0, 90, FlxG.width, 'Performance / Benchmark Test', 32);
		title.setFormat(Paths.font('vcr.ttf'), 32, FlxColor.WHITE, CENTER, OUTLINE_FAST, FlxColor.BLACK);
		add(title);

		status = new FlxText(0, 190, FlxG.width, 'Preparing benchmark...', 24);
		status.setFormat(Paths.font('vcr.ttf'), 24, FlxColor.WHITE, CENTER, OUTLINE_FAST, FlxColor.BLACK);
		add(status);

		result = new FlxText(120, 320, FlxG.width - 240, '', 20);
		result.setFormat(Paths.font('vcr.ttf'), 20, FlxColor.WHITE, LEFT, OUTLINE_FAST, FlxColor.BLACK);
		add(result);

		started = Sys.time();
		new FlxTimer().start(0.1, function(_) runNext());
	}

	function runNext():Void
	{
		var t:Float = Sys.time();

		switch(step)
		{
			case 0:
				status.text = 'Testing asset loading...';
				Paths.image('menuDesat');
				Paths.image('loading_screen/icon');
				assetMs = (Sys.time() - t) * 1000;

			case 1:
				status.text = 'Testing object creation...';
				var sprites:Array<FlxSprite> = [];
				for(i in 0...300) sprites.push(new FlxSprite());
				for(sprite in sprites) sprite.destroy();
				objectMs = (Sys.time() - t) * 1000;

			case 2:
				status.text = 'Testing chart/object preparation...';
				var data:Array<Dynamic> = [];
				for(i in 0...12000) data.push([i * 16.666, i % 4, i % 2, 0]);
				var encoded:String = Json.stringify(data);
				Json.parse(encoded);
				chartMs = (Sys.time() - t) * 1000;

			case 3:
				var total:Float = assetMs + objectMs + chartMs;
				var score:Float = 1000.0 / Math.max(250.0, total);
				LoadingPerformance.save(assetMs, objectMs, chartMs, score);
				status.text = 'Benchmark complete.';
				result.text = 'Asset loading: ' + Math.round(assetMs) + ' ms\n'
					+ 'Object creation: ' + Math.round(objectMs) + ' ms\n'
					+ 'Chart preparation: ' + Math.round(chartMs) + ' ms\n\n'
					+ 'Profile saved.\n\nPress BACK to return.';
				return;
		}

		step++;
		new FlxTimer().start(0.08, function(_) runNext());
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);
		if(controls.BACK)
		{
			FlxG.sound.play(Paths.sound('cancelMenu'));
			close();
		}
	}
}
