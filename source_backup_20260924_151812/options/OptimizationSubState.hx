package options;

class OptimizationSubState extends BaseOptionsMenu
{
	public function new()
	{
		title = 'Optimization';
		rpcTitle = 'Optimization Settings Menu'; //for Discord Rich Presence

		//Ported from FNF-JS-Engine OptimizationSubState
		var option:Option = new Option('Enable GC',
			"If checked, then the game will be allowed to garbage collect, reducing RAM usage I suppose.\nIf you experience memory leaks, turn this on, and\nif you experience lag with it on then turn it off.",
			'enableGC',
			BOOL);
		addOption(option);

		var option:Option = new Option('Light Opponent Strums',
			"If this is unchecked, the Opponent strums won't light up when the Opponent hits a note.",
			'opponentLightStrum',
			BOOL);
		addOption(option);

		var option:Option = new Option('Light Botplay Strums',
			"If this is unchecked, the Player strums won't light when Botplay is active.",
			'botLightStrum',
			BOOL);
		addOption(option);

		var option:Option = new Option('Light Player Strums',
			"If this is unchecked, then uh.. the player strums won't light up.\nit's as simple as that.",
			'playerLightStrum',
			BOOL);
		addOption(option);

		var option:Option = new Option('Show Ratings',
			"If unchecked, the game will not show a rating sprite when hitting a note.",
			'ratingPopups',
			BOOL);
		addOption(option);

		var option:Option = new Option('Show Combo Numbers',
			"If unchecked, the game will not show combo numbers when hitting a note.",
			'comboPopups',
			BOOL);
		addOption(option);

		var option:Option = new Option('Show MS Popup',
			"If checked, hitting a note will also show how late/early you hit it.",
			'showMS',
			BOOL);
		addOption(option);

		var option:Option = new Option('Disable onSpawnNote Lua Calls',
			"If checked, the game will not call onSpawnNote when a note is spawned.\nIf you have a script that uses that, maybe leave it on.",
			'noSpawnFunc',
			BOOL);
		addOption(option);

		var option:Option = new Option('Disable Note Hit Lua Calls',
			"If checked, the game will not call note hit functions when a note is hit.",
			'noHitFuncs',
			BOOL);
		addOption(option);

		var option:Option = new Option('Disable Skipped Note Lua Calls',
			"If checked, the game will not call note hit functions for skipped notes.",
			'noSkipFuncs',
			BOOL);
		addOption(option);

		var option:Option = new Option('Even LESS Botplay Lag',
			"Reduce Botplay lag even further.",
			'lessBotLag',
			BOOL);
		addOption(option);

		super();
	}
}