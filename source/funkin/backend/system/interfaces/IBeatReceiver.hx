package funkin.backend.system.interfaces;

interface IBeatReceiver
{
	public function stepHit(step:Int):Void;
	public function beatHit(beat:Int):Void;
}
