package backend;

import flixel.FlxState;
import flixel.FlxSprite;
import flixel.FlxCamera;
import backend.ui.PsychUIButton;

class FloatingMenu
{
    static var cam:FlxCamera;
    static var btn:PsychUIButton;

    // Gọi sau super.create() trong MusicBeatState.create(), mỗi state có nút MENU riêng
    public static function attach(state:FlxState):Void
    {
        // Camera add sau cùng nên được vẽ trên cùng
        cam = new FlxCamera();
        cam.bgColor = 0;
        FlxG.cameras.add(cam, false);

        btn = new PsychUIButton(FlxG.width / 2 - 32, 4, 'MENU', open, 64, 26);
        btn.alpha = 0.6;
        btn.cameras = [cam];
        state.add(btn);
    }

    public static function hasAction(name:String):Bool
    {
        var s:Dynamic = FlxG.state;
        return Reflect.isFunction(Reflect.field(s, name));
    }

    static function open():Void
    {
        if (FlxG.state.subState != null) return;
        FlxG.state.openSubState(new ReloadMenuSubState());
    }
}

class ReloadMenuSubState extends MusicBeatSubstate
{
    var prevPersist:Bool = true;

    override function create()
    {
        // Dừng update state cha khi menu mở để không bấm xuyên qua
        var parent = FlxG.state;
        prevPersist = parent.persistentUpdate;
        parent.persistentUpdate = false;

        var bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, 0xB0000000);
        bg.scrollFactor.set();
        add(bg);

        var y:Float = FlxG.height / 2 - 150;
        var x:Float = (FlxG.width - 300) / 2;

        add(makeBtn(x, y, 'Resume', function() close()));
        y += 70;

        var defs:Array<Array<String>> = [
            ['Reload Chart', 'reloadChart'],
            ['Reload Events', 'reloadEvents'],
            ['Reload Stage', 'reloadStage']
        ];
        for (d in defs)
        {
            if (!FloatingMenu.hasAction(d[1])) continue;
            var fn = d[1];
            add(makeBtn(x, y, d[0], function() run(fn)));
            y += 70;
        }

        super.create();
    }

    function makeBtn(x:Float, y:Float, label:String, cb:Void->Void):PsychUIButton
    {
        return new PsychUIButton(x, y, label, cb, 300, 56);
    }

    // Đóng menu trước, rồi mới gọi hàm reload trên state cha
    function run(name:String)
    {
        close();
        var s:Dynamic = FlxG.state;
        Reflect.callMethod(s, Reflect.field(s, name), []);
    }

    override function destroy()
    {
        if (FlxG.state != null) FlxG.state.persistentUpdate = prevPersist;
        super.destroy();
    }
}
