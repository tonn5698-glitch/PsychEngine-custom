package options;

class ExperimentSubState extends BaseOptionsMenu
{
	var option:Option;

	public function new()
	{
		title = 'Experiment';
		rpcTitle = 'Experiment Menu';

		option = new Option('Full Screen Mode (Restart)',
			'If checked, the game will use the actual device resolution.\nRequires restart to take effect. (Experimental — may break UI layout)',
			'fullScreenMode', BOOL);
		addOption(option);

		option = new Option('Enable Funky Mode',
			'If checked, menu HUD elements bounce (scale) on every beat.\nBeat is tracked automatically from the menu music.\nDoes not apply during gameplay (PlayState).',
			'funkyMode', BOOL);
		addOption(option);

		super();
	}
}
