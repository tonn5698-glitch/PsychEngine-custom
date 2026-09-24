package options;

import backend.FunkyMode;

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

		option = new Option('Bop Style',
			'Tween ease dùng cho Funky Mode HUD bop.\nLeft/Right đổi trực tiếp. Press A để mở tab test — preview từng style trên 1 HUD element.\n(Mặc định lấy từ mod Engine.json "bop-style" nếu có)',
			'bopStyle', STRING, FunkyMode.BOP_STYLES);
		option.onAccept = () ->
		{
			persistentUpdate = false;
			openSubState(new options.BopStyleSubState());
		};
		addOption(option);

		option = new Option('Bop BPM',
			'BPM dùng để nhịp bop cho Funky Mode.\nMặc định lấy từ mod Engine.json "bop-bpm" nếu có.',
			'bopBpm', INT);
		option.minValue = 60;
		option.maxValue = 300;
		addOption(option);

		option = new Option('Skip Title After Intro',
			'If checked, after intro.mp4 ends (or is skipped) the game fades directly into the Main Menu.\nThe intro video is muted and freakyMenu starts immediately.\nSkips the Title Screen.',
			'introToMenu', BOOL);
		addOption(option);

		option = new Option('Enable Custom Intro Video',
			'If checked, loads the intro video from the top mod\'s Engine.json.\nMod cần: MyMod/data/Engine.json ("video": "intro.mp4") + MyMod/videos/intro.mp4.',
			'customIntroVideo', BOOL);
		addOption(option);

		super();
	}

	override function closeSubState():Void
	{
		persistentUpdate = true;
		controls.isInSubstate = true; // BopStyleSubState destroy set false — mình vẫn là substate
		super.closeSubState();
		refreshOptionValues(); // bopStyle có thể đổi từ BopStyleSubState
	}
}
