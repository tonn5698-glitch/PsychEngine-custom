# Hướng Dẫn Triển Khai Custom State (kiểu Codename Engine) cho Psych Engine

> Tài liệu này được viết dựa trên việc đọc trực tiếp source code trong `PsychEngine-Custom-source.zip` mà bạn đã upload (không phải lý thuyết chung chung). Các đường dẫn file, tên hàm, số dòng đều khớp với bản source hiện tại của bạn tại thời điểm viết tài liệu.

---

## 1. Mục tiêu

Codename Engine cho phép modder viết một **State hoàn toàn mới** (không phải PlayState, không phải substate) bằng script, gắn vào hệ thống mod mà không cần sửa/biên dịch lại engine gốc. Psych Engine bản của bạn **chưa có tính năng này** — nó chỉ có `psychlua/CustomSubstate.hx`, vốn là **substate gắn cứng vào `PlayState.instance`**, không dùng được cho menu, minigame, cutscene độc lập, v.v.

Tài liệu này hướng dẫn xây dựng **`CustomState`**: một FlxState thật, load toàn bộ logic từ Lua/HScript theo tên, switch được từ bất kỳ đâu (menu, freeplay, chart event...), theo đúng tinh thần Codename Engine.

---

## 2. Phân tích kiến trúc hiện tại (căn cứ đọc source)

### 2.1. `backend/MusicBeatState.hx` là base state của mọi state
Mọi state (`MainMenuState`, `FreeplayState`, `PlayState`, ...) đều kế thừa `MusicBeatState`. Class này đã có sẵn:
- Vòng lặp `beatHit()/stepHit()/sectionHit()` chạy theo `Conductor`.
- `switchState()` / `resetState()` tĩnh, có transition fade sẵn (`CustomFadeTransition`).
- `variables:Map<String, Dynamic>` để lưu object theo tag.

→ Đây chính là class ta sẽ mở rộng, **không phải PlayState**.

### 2.2. Hệ thống script (Lua/HScript) hiện chỉ tồn tại trong `PlayState.hx`
`luaArray`, `hscriptArray`, `callOnScripts()`, `callOnLuas()`, `callOnHScript()`, `initHScript()`, `setOnScripts()` đều được khai báo **trực tiếp trong `PlayState.hx`** (dòng ~101, ~254, ~3400–3537). Không state nào khác có các hàm này. Đây là lý do bạn **không thể** chạy `.lua`/`.hx` từ `MainMenuState` hay bất kỳ menu nào hiện tại.

### 2.3. `CustomSubstate.hx` đã tồn tại nhưng KHÔNG phải giải pháp cho yêu cầu của bạn
File `source/psychlua/CustomSubstate.hx` cho phép Lua gọi `openCustomSubstate(name)`, nhưng:
```haxe
PlayState.instance.openSubState(new CustomSubstate(name));
```
Nó bắt buộc `PlayState.instance` phải tồn tại và **luôn mở dưới dạng substate đè lên PlayState**, không thể dùng làm màn hình menu độc lập, không thể dùng khi chưa vào PlayState. → Giữ nguyên file này (không đụng vào), nó phục vụ mục đích khác (pause menu, popup trong lúc chơi).

### 2.4. Tin tốt: hệ thống thao tác object đã tổng quát hóa sẵn
`psychlua/LuaUtils.hx` dòng 268–271:
```haxe
public static function getTargetInstance()
    return MusicBeatState.getState();
```
Tức là các hàm Lua như `addLuaSprite`, `makeLuaSprite`, `screenCenter`, `setObjectX`... **đã hoạt động với bất kỳ `MusicBeatState` nào đang active**, không hardcode `PlayState`. Đây là nền tảng quan trọng giúp việc này khả thi mà không cần viết lại toàn bộ hệ hàm dựng sprite.

### 2.5. Điểm nghẽn thật sự: `psychlua/FunkinLua.hx` (constructor, dòng 61–130)
```haxe
var game:PlayState = PlayState.instance;
if(game != null) game.luaArray.push(this);
...
set('bpm', PlayState.SONG.bpm);          // (*) không null-check
set('scrollSpeed', PlayState.SONG.speed);
set('songName', PlayState.SONG.song);
...
```
Hai vấn đề cụ thể:
1. `FunkinLua` **chỉ tự đăng ký vào `PlayState.instance.luaArray`**, không có khái niệm "state hiện tại". Nếu gọi `new FunkinLua(...)` ngoài PlayState, script sẽ không được track ở đâu cả (không nhận `onUpdate`/`onDestroy`, rò rỉ interpreter).
2. `PlayState.SONG` là `static var SONG:SwagSong = null;` (dòng 143) — **null cho đến khi người chơi vào một bài hát**. Nếu bạn mở Custom State ngay từ Main Menu (trường hợp phổ biến nhất — menu tùy chỉnh), dòng `PlayState.SONG.bpm` sẽ **crash NullObjectReference** ngay khi interpreter khởi tạo.

→ Đây là lý do bắt buộc phải **patch `FunkinLua.hx`**, không thể chỉ thêm file mới mà bỏ qua bước này.

### 2.6. `psychlua/HScript.hx` — tin tốt: đã tổng quát hóa gần như hoàn chỉnh
Constructor dùng `customInterp.parentInstance = FlxG.state;` (dòng 116), không hardcode PlayState, không tự push vào mảng nào (việc push là do nơi gọi nó quyết định — ví dụ `PlayState.initHScript()`). Chỉ vài hàm phụ (touchpad, `addTextToDebug`) còn gọi `PlayState.instance` trực tiếp — đây là các API chỉ có ý nghĩa trong gameplay nên **giữ nguyên, không cần patch**, custom state sẽ đơn giản không dùng các hàm đó.

---

## 3. Kiến trúc đề xuất

```
backend/MusicBeatState.hx   ← chuyển "script engine" (luaArray, hscriptArray,
                               callOnScripts, initHScript...) lên đây (dùng chung)
        │
        ├── states/PlayState.hx        (đã có, chỉ xóa phần trùng lặp)
        ├── states/MainMenuState.hx    (tự động được "ké" khả năng chạy script)
        └── psychlua/CustomState.hx    (MỚI — state cho custom content của mod)

psychlua/FunkinLua.hx        ← patch: bỏ hardcode PlayState, dùng MusicBeatState.getState()
psychlua/CustomStateFunctions.hx  ← MỚI — expose switchCustomState()/exitCustomState() cho Lua
```

Quy ước thư mục script cho custom state (giống cách PlayState quét `scripts/`):
```
assets/shared/customStates/<tenState>/state.lua
mods/<TenMod>/customStates/<tenState>/state.lua
mods/<TenMod>/customStates/<tenState>/helper.lua
```
Dùng lại nguyên hàm có sẵn `Mods.directoriesWithFile()` (không cần viết thêm code merge mod) — chỉ cần truyền đúng path.

---

## 4. Triển khai chi tiết

### Bước 1 — `backend/MusicBeatState.hx`: đưa script engine lên base class

Thêm import ở đầu file:
```haxe
import backend.Mods;
#if LUA_ALLOWED
import psychlua.FunkinLua;
#end
#if HSCRIPT_ALLOWED
import psychlua.HScript;
import crowplexus.iris.Iris;
import crowplexus.hscript.Expr.Error as IrisError;
import crowplexus.hscript.Printer;
#end
```

Thêm field (đặt cạnh `variables`):
```haxe
#if LUA_ALLOWED public var luaArray:Array<FunkinLua> = []; #end
#if HSCRIPT_ALLOWED public var hscriptArray:Array<HScript> = []; #end
```

Copy nguyên 5 hàm sau từ `PlayState.hx` (dòng 3400–3537) sang `MusicBeatState.hx`, **giữ nguyên logic**, không cần sửa gì vì chúng vốn đã không đụng tới `PlayState`:
`initHScript()`, `callOnScripts()`, `callOnLuas()`, `callOnHScript()`, `setOnScripts()`, `setOnLuas()`, `setOnHScript()`.

Thêm dọn dẹp vào `override function destroy()` (đặt **trước** dòng `super.destroy();` hiện có):
```haxe
override function destroy()
{
    removeTouchPad();
    removeMobileControls();

    #if LUA_ALLOWED
    for (lua in luaArray)
    {
        lua.call('onDestroy', []);
        lua.stop();
    }
    luaArray = null;
    FunkinLua.customFunctions.clear();
    #end

    #if HSCRIPT_ALLOWED
    for (script in hscriptArray)
        if(script != null)
        {
            if(script.exists('onDestroy')) script.call('onDestroy');
            script.destroy();
        }
    hscriptArray = null;
    #end

    super.destroy();
}
```

> **Vì sao an toàn:** `PlayState.destroy()` hiện tại kết thúc bằng `super.destroy();` (dòng 3264), nên phần dọn script bạn xóa khỏi `PlayState.hx` ở Bước 2 sẽ tự động được gọi lại thông qua `super.destroy()` — thứ tự hủy không đổi về mặt logic (script vẫn được dọn ở cuối cùng của quá trình destroy).

### Bước 2 — `states/PlayState.hx`: xóa phần bị trùng

Xóa các khai báo field đã chuyển lên base:
```haxe
#if HSCRIPT_ALLOWED
public var hscriptArray:Array<HScript> = [];
#end
```
(dòng ~100) và
```haxe
#if LUA_ALLOWED public var luaArray:Array<FunkinLua> = []; #end
```
(dòng ~254).

Xóa khối dọn script trong `override function destroy()` (dòng 3219–3238, từ `#if LUA_ALLOWED ... for (lua in luaArray)` đến `#end` của `hscriptArray = null;`) — **giữ nguyên** dòng `super.destroy();` ở cuối, vì nó giờ sẽ gọi `MusicBeatState.destroy()` đã có logic này.

Xóa 7 hàm đã copy sang base ở Bước 1 khỏi `PlayState.hx` (dòng 3400–3537): `initHScript`, `callOnScripts`, `callOnLuas`, `callOnHScript`, `setOnScripts`, `setOnLuas`, `setOnHScript`.

Compile lại để chắc chắn không còn hàm nào trong `PlayState.hx` gọi các hàm này theo kiểu `PlayState.instance.callOnScripts(...)` bị lỗi trùng định nghĩa — không cần sửa gì thêm vì Haxe cho phép class con dùng hàm kế thừa bình thường.

### Bước 3 — Patch `psychlua/FunkinLua.hx` (constructor)

Thay đoạn:
```haxe
this.scriptName = scriptName.trim();
var game:PlayState = PlayState.instance;
if(game != null) game.luaArray.push(this);
```
bằng:
```haxe
this.scriptName = scriptName.trim();

var currentState:backend.MusicBeatState = Std.isOfType(FlxG.state, backend.MusicBeatState)
    ? cast FlxG.state
    : null;
if(currentState != null) currentState.luaArray.push(this);

var game:PlayState = Std.isOfType(currentState, PlayState) ? cast currentState : null;
```
(biến `game` vẫn giữ nguyên tên để không phải sửa toàn bộ các dòng dùng `game` bên dưới, ví dụ đoạn "PlayState-only variables" ở cuối constructor).

Thay khối "Song/Week shit" (không null-check) bằng bản có null-check:
```haxe
// Song/Week shit — chỉ có giá trị thật khi đang ở trong PlayState
if(PlayState.SONG != null)
{
    set('curBpm', Conductor.bpm);
    set('bpm', PlayState.SONG.bpm);
    set('scrollSpeed', PlayState.SONG.speed);
    set('crochet', Conductor.crochet);
    set('stepCrochet', Conductor.stepCrochet);
    set('songLength', FlxG.sound.music != null ? FlxG.sound.music.length : 0);
    set('songName', PlayState.SONG.song);
    set('songPath', Paths.formatToSongPath(PlayState.SONG.song));
    set('loadedSongName', Song.loadedSongName);
    set('loadedSongPath', Paths.formatToSongPath(Song.loadedSongName));
    set('chartPath', Song.chartPath);
    set('curStage', PlayState.SONG.stage);
    set('hasVocals', PlayState.SONG.needsVoices);
}
else
{
    // Giá trị mặc định an toàn cho script chạy ngoài PlayState (menu, custom state...)
    set('curBpm', Conductor.bpm);
    set('bpm', 0);
    set('scrollSpeed', 1);
    set('crochet', Conductor.crochet);
    set('stepCrochet', Conductor.stepCrochet);
    set('songLength', 0);
    set('songName', '');
    set('songPath', '');
    set('loadedSongName', '');
    set('loadedSongPath', '');
    set('chartPath', '');
    set('curStage', '');
    set('hasVocals', false);
}
set('startedCountdown', false);
set('isStoryMode', PlayState.isStoryMode);
set('difficulty', PlayState.storyDifficulty);
set('difficultyName', Difficulty.getString(false));
set('difficultyPath', Difficulty.getFilePath());
set('difficultyNameTranslation', Difficulty.getString(true));
set('weekRaw', PlayState.storyWeek);
set('week', WeekData.weeksList[PlayState.storyWeek]);
set('seenCutscene', PlayState.seenCutscene);
```

Đoạn "PlayState-only variables" (`curSection`, `curBeat`, `curStep`...) ở ngay bên dưới **giữ nguyên không đổi** — nó đã có sẵn `if(game != null)`, và `game` giờ chỉ khác null khi state hiện tại thật sự là `PlayState`, đúng như ý nghĩa ban đầu.

Cuối constructor, tìm khối:
```haxe
CustomSubstate.implement(this);
```
Thêm ngay dòng dưới nó:
```haxe
CustomStateFunctions.implement(this);
```

### Bước 4 — Tạo file mới `source/psychlua/CustomState.hx`

```haxe
package psychlua;

import backend.MusicBeatState;
import backend.Paths;
import backend.Mods;
import backend.CoolUtil;
import states.MainMenuState;

#if LUA_ALLOWED
import psychlua.FunkinLua;
#end
#if HSCRIPT_ALLOWED
import psychlua.HScript;
#end

/**
 * Full FlxState điều khiển hoàn toàn bằng Lua/HScript, tương đương
 * "custom state" của Codename Engine. Khác với CustomSubstate.hx
 * (chỉ mở được đè lên PlayState), CustomState là màn hình độc lập,
 * dùng được cho menu phụ, minigame, cutscene ngoài gameplay, v.v.
 */
class CustomState extends MusicBeatState
{
    public static var instance:CustomState;
    public var stateName:String = 'unnamed';

    public function new(stateName:String)
    {
        this.stateName = stateName;
        super();
    }

    override function create()
    {
        instance = this;
        super.create(); // MusicBeatState.create() đã lo camera + fade-in

        #if (LUA_ALLOWED || HSCRIPT_ALLOWED)
        for (folder in Mods.directoriesWithFile(Paths.getSharedPath(), 'customStates/$stateName/'))
        {
            #if linux
            for (file in CoolUtil.sortAlphabetically(Paths.readDirectory(folder)))
            #else
            for (file in Paths.readDirectory(folder))
            #end
            {
                #if LUA_ALLOWED
                if (file.toLowerCase().endsWith('.lua'))
                    new FunkinLua(folder + file);
                #end

                #if HSCRIPT_ALLOWED
                if (file.toLowerCase().endsWith('.hx'))
                    initHScript(folder + file);
                #end
            }
        }
        #end

        if (luaArray.length == 0 && hscriptArray.length == 0)
            trace('[CustomState] Không tìm thấy script nào cho state "$stateName" — kiểm tra lại thư mục customStates/$stateName/');

        callOnScripts('onCreate', [stateName]);
        callOnScripts('onCreatePost', [stateName]);
    }

    override function update(elapsed:Float)
    {
        callOnScripts('onUpdate', [elapsed]);
        super.update(elapsed);
        callOnScripts('onUpdatePost', [elapsed]);
    }

    override function beatHit()
    {
        super.beatHit();
        callOnScripts('onBeatHit');
    }

    override function stepHit()
    {
        super.stepHit();
        callOnScripts('onStepHit');
    }

    override function destroy()
    {
        callOnScripts('onDestroy', [stateName]);
        instance = null;
        super.destroy(); // luaArray/hscriptArray được MusicBeatState.destroy() dọn (Bước 1)
    }

    public static function switchTo(stateName:String)
    {
        MusicBeatState.switchState(new CustomState(stateName));
    }

    public static function exitToMenu()
    {
        MusicBeatState.switchState(new MainMenuState());
    }
}
```

### Bước 5 — Tạo file mới `source/psychlua/CustomStateFunctions.hx`

```haxe
package psychlua;

#if LUA_ALLOWED
class CustomStateFunctions
{
    public static function implement(funk:FunkinLua)
    {
        var lua = funk.lua;
        Lua_helper.add_callback(lua, "switchCustomState", switchCustomState);
        Lua_helper.add_callback(lua, "exitCustomState", exitCustomState);
    }

    public static function switchCustomState(stateName:String)
    {
        CustomState.switchTo(stateName);
        return true;
    }

    public static function exitCustomState()
    {
        CustomState.exitToMenu();
        return true;
    }
}
#end
```

Nhớ thêm dòng gọi `CustomStateFunctions.implement(this);` vào `FunkinLua.hx` như đã nêu ở cuối Bước 3.

**Cho HScript**: mở `psychlua/HScript.hx`, trong `preset()` (chỗ có `set('FlxSprite', flixel.FlxSprite);`), thêm:
```haxe
set('CustomState', psychlua.CustomState);
```
Nhờ vậy, script `.hx` có thể gọi trực tiếp `CustomState.switchTo("myMenu")` hoặc `CustomState.exitToMenu()` mà không cần callback riêng.

### Bước 6 — Cấu trúc thư mục cho mod

```
mods/
└── MyMod/
    └── customStates/
        └── extraMenu/
            ├── state.lua        ← script chính
            └── particles.lua    ← script phụ (tùy chọn, tự động được load cùng)
```
Hoặc đặt trong game gốc (không qua mod):
```
assets/shared/customStates/extraMenu/state.lua
```
Không cần code thêm để hỗ trợ mod override — `Mods.directoriesWithFile()` tự động gộp theo đúng thứ tự ưu tiên mod đang dùng (giống hệt cách `scripts/` của PlayState hoạt động).

### Bước 7 — Ví dụ `state.lua` thực tế

```lua
function onCreate()
    makeLuaSprite('bg', 'menuDesat', 0, 0)
    setGraphicSize('bg', screenWidth, screenHeight)
    updateHitbox('bg')
    addLuaSprite('bg')

    makeLuaText('title', 'EXTRA MENU', 0, screenWidth, 100)
    setTextSize('title', 48)
    setTextAlignment('title', 'center')
    screenCenter('title', 'x')
    addLuaText('title')
end

function onBeatHit()
    setObjectScale('title', 1.05, 1.05)
end

function onStepHit()
    if getPropertyFromClass('flixel.FlxG', 'width') then end -- ví dụ truy cập class tĩnh nếu cần
end

function onUpdate(elapsed)
    if keyJustPressed('back') then
        exitCustomState() -- quay lại MainMenuState, dùng callback ở Bước 5
    end
end
```

### Bước 8 — Gọi Custom State từ nơi khác trong engine (không qua Lua)

Ví dụ thêm nút trong `MainMenuState.hx`, cạnh các dòng `MusicBeatState.switchState(new FreeplayState());` (dòng ~301):
```haxe
MusicBeatState.switchState(new psychlua.CustomState('extraMenu'));
```

---

## 5. Checklist kiểm thử

- [ ] Vào thẳng game (chưa từng chơi bài nào) → mở custom state từ Main Menu → không crash do `PlayState.SONG` null (kiểm chứng Bước 3).
- [ ] `onCreate`, `onUpdate`, `onBeatHit`, `onStepHit`, `onDestroy` đều được gọi đúng thứ tự.
- [ ] `addLuaSprite`/`makeLuaText`/`screenCenter` hoạt động bình thường trong CustomState (nhờ `LuaUtils.getTargetInstance()` đã tổng quát sẵn — mục 2.4).
- [ ] Vào PlayState chơi một bài, thoát ra, sau đó mở CustomState → không bị dính state/script cũ (kiểm tra `luaArray`/`hscriptArray` được null hóa đúng ở Bước 1).
- [ ] Test cả trường hợp mod override (`mods/<Mod>/customStates/...`) và bản gốc (`assets/shared/customStates/...`).
- [ ] Test HScript (`.hx`) song song với Lua trong cùng một CustomState.
- [ ] `exitCustomState()` quay đúng về `MainMenuState`, không rò rỉ camera/substate.

---

## 6. Giới hạn đã biết

- Các hàm Lua/HScript chỉ có ý nghĩa trong gameplay (health, score, notes, characters, touchpad, `addTextToDebug`...) **sẽ không hoạt động** trong `CustomState` vì chúng gắn cứng vào `PlayState.instance` (mục 2.6) — đây là hành vi đúng, giống Codename Engine (custom state không phải là PlayState).
- `CustomState` hiện dùng chung một `Conductor` toàn cục cho `beatHit`/`stepHit`, nên nhịp đập sẽ theo bài nhạc đang phát nền (nếu có), tương tự cách `MainMenuState` hiện đang nhún theo nhạc menu.
- Chưa hỗ trợ "class-based" script thật sự kiểu Codename (nơi một file `.hx` có thể `extends FlxState` và được biên dịch động qua macro). Đây là tính năng lớn hơn nhiều, xem gợi ý mở rộng bên dưới.

## 7. Hướng mở rộng (nếu muốn tiến gần hơn tới Codename Engine thật)

Codename Engine dùng `hscript-improved` với cơ chế cho phép class HScript **kế thừa trực tiếp một class Haxe có sẵn** (ví dụ `class MyState extends FlxState`), thay vì chỉ định nghĩa các hàm rời rạc như `onCreate`/`onUpdate`. Việc này đòi hỏi:
1. Nâng cấp thư viện hscript đang dùng (kiểm tra `Iris`/`crowplexus.hscript` trong `source/psychlua/HScript.hx` có hỗ trợ `extends` một class ngoài hay không — bản hiện tại của bạn dựa trên `crowplexus.iris.Iris`, cần xác nhận version).
2. Viết một lớp resolver để `new` một instance của class đã định nghĩa trong script rồi gọi `FlxG.switchState()` trực tiếp với instance đó, thay vì luôn bọc trong `CustomState` cố định.

Cách tiếp cận ở tài liệu này (dùng `CustomState` + callback theo tên hàm) là **giải pháp thực dụng, ít rủi ro, tương thích ngược 100% với hệ thống Lua/HScript hiện có của Psych Engine**, và đáp ứng đúng nhu cầu thực tế: mod định nghĩa toàn bộ nội dung/màn hình mới mà không cần sửa/biên dịch lại engine.
