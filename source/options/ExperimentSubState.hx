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

		super();
	}
}
