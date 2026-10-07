package backend;

class LoadingPerformance
{
	public static inline var VERSION:Int = 1;

	public static function hasProfile():Bool
	{
		return ClientPrefs.data.loadingBenchmarkVersion == VERSION && ClientPrefs.data.loadingBenchmarkDone;
	}

	public static function save(assetMs:Float, objectMs:Float, chartMs:Float, score:Float):Void
	{
		ClientPrefs.data.loadingBenchmarkVersion = VERSION;
		ClientPrefs.data.loadingBenchmarkDone = true;
		ClientPrefs.data.loadingBenchmarkAssetMs = assetMs;
		ClientPrefs.data.loadingBenchmarkObjectMs = objectMs;
		ClientPrefs.data.loadingBenchmarkChartMs = chartMs;
		ClientPrefs.data.loadingBenchmarkScore = score;
		ClientPrefs.saveSettings();
	}

	public static function reset():Void
	{
		ClientPrefs.data.loadingBenchmarkVersion = 0;
		ClientPrefs.data.loadingBenchmarkDone = false;
		ClientPrefs.data.loadingBenchmarkAssetMs = 0;
		ClientPrefs.data.loadingBenchmarkObjectMs = 0;
		ClientPrefs.data.loadingBenchmarkChartMs = 0;
		ClientPrefs.data.loadingBenchmarkScore = 0;
		ClientPrefs.saveSettings();
	}

	public static function getMultiplier():Float
	{
		if(!hasProfile()) return 1.0;
		return Math.max(0.65, Math.min(2.5, ClientPrefs.data.loadingBenchmarkScore));
	}

	public static function estimate(baseMs:Float):Float
	{
		return baseMs / getMultiplier();
	}
}
