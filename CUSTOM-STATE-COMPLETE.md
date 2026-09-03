# Custom State — Tổng hợp đầy đủ (dành cho fork Psych Engine của bạn)

> File này gói **toàn bộ** cách làm Custom State: từ kiến trúc engine, các file cần sửa/tạo, đến source code port **Custom Freeplay** (Lua chuẩn) theo phong cách Codename Engine nhưng chạy **trong bản Psych fork của bạn**.
>
> Nối kết 2 tài liệu: `Custom-State-Implementation-Guide.md` (khung CustomState) + `New up.md` (global scripts, custom freeplay/main menu, fix 2 lỗi hardcode). Mọi đường dẫn đều khớp source trong `PsychEngine-Custom-source.zip` và code đã triển khai thực tế (commit đã build thành công).

---

## 1. Tổng quan: Custom State là gì

Codename Engine cho phép modder viết **1 State hoàn toàn mới** bằng script (menu, minigame, cutscene độc lập) mà không cần sửa/biên dịch lại engine. Psych Engine bản của bạn **trước đây chưa có** (chỉ có `CustomSubstate` — substate gắn cứng vào `PlayState.instance`, không làm menu độc lập được).

`CustomState` là **1 FlxState thật**, load toàn bộ logic từ Lua (`state.lua`) hoặc HScript (`state.hx`) theo tên, switch được từ bất kỳ đâu. Script sống trong `customStates/<tênState>/`.

```
customStates/<tênState>/state.lua    ← màn hình chính (Lua)
customStates/<tênState>/helper.lua   ← script phụ, tự động được load chung
customStates/<tênState>/state.hx     ← hoặc dùng HScript thay Lua
```

Đặt ở 2 nơi (độ ưu tiên: mod override > game gốc):
```
mods/<Mod>/customStates/<tênState>/...
assets/shared/customStates/<tênState>/...
```
> ⚠️ **Android:** trên điện thoại, `assets/shared/` bên trong APK **KHÔNG được quét** (vì `Mods.directoriesWithFile` dùng `FileSystem.exists`, không thấy folder trong APK). Chỉ folder thật trên storage (`mods/`) mới hoạt động. Vì vậy trên mobile bạn **phải** để script+asset trong một mod ở `/sdcard/.PsychEngine/mods/`.

---

## 2. Kiến trúc engine đã triển khai

```
backend/MusicBeatState.hx   ← script engine dùng chung (luaArray, hscriptArray,
                               callOnScripts, initHScript...) + hook GlobalScript
        │
        ├── states/PlayState.hx        (bỏ phần trùng, kế thừa từ base)
        ├── states/MainMenuState.hx    (nút Freeplay → CustomState)
        └── psychlua/CustomState.hx    (state cho custom content)
             ├── CustomStateFunctions.hx      switchCustomState / exitCustomState
             ├── CustomFreeplayFunctions.hx   API freeplay thật (bài/độ khó/điểm/load)
             ├── CustomMenuFunctions.hx       điều hướng menu
             └── PsychGlobalScript.hx         script xuyên suốt phiên chơi

psychlua/FunkinLua.hx    (bỏ hardcode PlayState; đăng ký mọi implement())
psychlua/ExtraFunctions.hx (fix keyJustPressed/keyPressed/keyReleased — Controls.instance)
psychlua/HScript.hx      (fix createGlobalCallback)
```

---

## 3. Các file engine đã sửa/tạo (đầy đủ)

### 3.1 `backend/MusicBeatState.hx` — script engine dùng chung

Thêm tại đầu file:
```haxe
import backend.Mods;
import psychlua.LuaUtils;
#if (LUA_ALLOWED || HSCRIPT_ALLOWED)
import psychlua.PsychGlobalScript;
#end
#if LUA_ALLOWED import psychlua.FunkinLua; #end
#if HSCRIPT_ALLOWED
import psychlua.HScript;
import crowplexus.iris.Iris;
import crowplexus.hscript.Expr.Error as IrisError;
import crowplexus.hscript.Printer;
import psychlua.HScript.HScriptInfos;
#end
```

Thêm field script engine (cạnh `variables`):
```haxe
#if LUA_ALLOWED public var luaArray:Array<FunkinLua> = []; #end
#if HSCRIPT_ALLOWED public var hscriptArray:Array<HScript> = []; #end
```

Hook GlobalScript (trong `create()` và `update()`):
```haxe
override function create() {
    var skip:Bool = FlxTransitionableState.skipNextTransOut;
    #if MODS_ALLOWED Mods.updatedOnState = false; #end

    #if (LUA_ALLOWED || HSCRIPT_ALLOWED)
    PsychGlobalScript.init();
    PsychGlobalScript.notifyStateSwitch(Type.getClassName(Type.getClass(this)));
    #end

    if(!_psychCameraInitialized) initPsychCamera();
    super.create();
    ...
}

override function update(elapsed:Float)
{
    #if (LUA_ALLOWED || HSCRIPT_ALLOWED)
    if (PsychGlobalScript.instance != null) PsychGlobalScript.instance.callOnScripts('onUpdate', [elapsed]);
    #end
    var oldStep:Int = curStep;
    ...
}
```

Patch `destroy()` (dọn script trước `super.destroy()`):
```haxe
override function destroy()
{
    removeTouchPad();
    removeMobileControls();

    #if LUA_ALLOWED
    for (lua in luaArray) { lua.call('onDestroy', []); lua.stop(); }
    luaArray = null;
    FunkinLua.customFunctions.clear();
    #end

    #if HSCRIPT_ALLOWED
    for (script in hscriptArray)
        if(script != null) { if(script.exists('onDestroy')) script.call('onDestroy'); script.destroy(); }
    hscriptArray = null;
    #end

    super.destroy();
}
```

Copy các hàm script vào base (đã đưa lên từ `PlayState`):
```haxe
#if HSCRIPT_ALLOWED
public function initHScript(file:String) { ... }   // như PlayState cũ
#end
public function callOnScripts(...):Dynamic { ... }
public function callOnLuas(...):Dynamic { ... }
public function callOnHScript(...):Dynamic { ... }
public function setOnScripts(...) { ... }
public function setOnLuas(...) { ... }
public function setOnHScript(...) { ... }
```

### 3.2 `states/PlayState.hx` — bỏ phần trùng
- Xóa field `hscriptArray` (dòng ~100) và `luaArray` (dòng ~254).
- Xóa khối dọn script trong `destroy()` (giữ `super.destroy()`).
- Xóa 7 hàm (`initHScript`, `callOnScripts`, `callOnLuas`, `callOnHScript`, `setOnScripts`, `setOnLuas`, `setOnHScript`) đã chuyển lên base. Đóng đúng `#if HSCRIPT_ALLOWED` quanh `startHScriptsNamed`.

### 3.3 `psychlua/FunkinLua.hx` — hết hardcode PlayState

Đầu constructor — đăng ký script vào **state hiện tại** + giữ biến `game`:
```haxe
this.scriptName = scriptName.trim();

var currentState:backend.MusicBeatState = Std.isOfType(FlxG.state, backend.MusicBeatState)
    ? cast FlxG.state : null;
if(currentState != null) currentState.luaArray.push(this);

var game:PlayState = Std.isOfType(currentState, PlayState) ? cast currentState : null;
```

Khối "Song/Week shit" — thêm null-check (bài học: crash khi `PlayState.SONG == null` từ Main Menu):
```haxe
if(PlayState.SONG != null) {
    set('bpm', PlayState.SONG.bpm); set('scrollSpeed', PlayState.SONG.speed); ... set('hasVocals', PlayState.SONG.needsVoices);
} else {
    set('bpm', 0); set('scrollSpeed', 1); ... set('hasVocals', false);   // giá trị an toàn
}
```

Cuối constructor, đăng ký mọi `implement()`:
```haxe
CustomSubstate.implement(this);
CustomStateFunctions.implement(this);
CustomFreeplayFunctions.implement(this);
CustomMenuFunctions.implement(this);
```

### 3.4 `psychlua/ExtraFunctions.hx` — fix 18 chỗ hardcode `PlayState.instance.controls`
Thay toàn bộ `PlayState.instance.controls` → `Controls.instance` trong 3 hàm:
- `keyJustPressed` (cases left/down/up/right/space/default)
- `keyPressed`
- `keyReleased`

Ví dụ:
```haxe
case 'left': return Controls.instance.NOTE_LEFT_P;
...
default: return Controls.instance.justPressed(name);
```

### 3.5 `psychlua/HScript.hx` — fix `createGlobalCallback`
```haxe
set('createGlobalCallback', function(name:String, func:Dynamic)
{
    var currentState:MusicBeatState = MusicBeatState.getState();
    if (currentState != null)
        for (script in currentState.luaArray)
            if(script != null && script.lua != null && !script.closed)
                Lua_helper.add_callback(script.lua, name, func);

    #if LUA_ALLOWED
    if (PsychGlobalScript.instance != null)
        for (script in PsychGlobalScript.instance.luaArray)
            if(script != null && script.lua != null && !script.closed)
                Lua_helper.add_callback(script.lua, name, func);
    #end

    FunkinLua.customFunctions.set(name, func);
});
```

> Lưu ý: `FunkinLua.customFunctions.set(...)` đã tự "toàn cục" — mọi `FunkinLua` mới tạo sau đó tự nhận callback qua vòng lặp cuối constructor. Không cần viết lại cơ chế này.

### 3.6 `psychlua/CustomState.hx` — state tổng quát (MỚI)

```haxe
package psychlua;

import backend.MusicBeatState;
import backend.Paths;
import backend.Mods;
import backend.CoolUtil;
import states.MainMenuState;

#if LUA_ALLOWED import psychlua.FunkinLua; #end
#if HSCRIPT_ALLOWED import psychlua.HScript; #end

class CustomState extends MusicBeatState
{
    public static var instance:CustomState;
    public var stateName:String = 'unnamed';

    public function new(stateName:String) { this.stateName = stateName; super(); }

    override function create()
    {
        instance = this;
        super.create(); // camera + fade-in

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
                if (file.toLowerCase().endsWith('.lua')) new FunkinLua(folder + file);
                #end
                #if HSCRIPT_ALLOWED
                if (file.toLowerCase().endsWith('.hx')) initHScript(folder + file);
                #end
            }
        }
        #end

        #if (LUA_ALLOWED || HSCRIPT_ALLOWED)
        if (luaArray.length == 0 && hscriptArray.length == 0)
            trace('[CustomState] Không thấy script nào cho "$stateName"');
        #end

        callOnScripts('onCreate', [stateName]);
        callOnScripts('onCreatePost', [stateName]);
    }

    override function update(elapsed:Float)
    {
        callOnScripts('onUpdate', [elapsed]);
        super.update(elapsed);
        callOnScripts('onUpdatePost', [elapsed]);
    }
    override function beatHit() { super.beatHit(); callOnScripts('onBeatHit'); }
    override function stepHit() { super.stepHit(); callOnScripts('onStepHit'); }
    override function destroy() { callOnScripts('onDestroy', [stateName]); instance = null; super.destroy(); }

    public static function openState(stateName:String)
        MusicBeatState.switchState(new CustomState(stateName));

    public static function exitToMenu()
        MusicBeatState.switchState(new MainMenuState());
}
```
> ⚠️ Tên hàm dùng **`openState`**, KHÔNG phải `switchTo` — vì `FlxState` đã có sẵn instance method `switchTo` (deprecated), Haxe: *"Same field name can't be used for both static and instance"*.

### 3.7 `psychlua/CustomStateFunctions.hx` (MỚI)
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
    public static function switchCustomState(stateName:String) { CustomState.openState(stateName); return true; }
    public static function exitCustomState() { CustomState.exitToMenu(); return true; }
}
#end
```

### 3.8 `psychlua/CustomFreeplayFunctions.hx` (MỚI) — API freeplay thật
```haxe
package psychlua;

import backend.WeekData;
import backend.Highscore;
import backend.Song;
import states.StoryMenuState;

#if LUA_ALLOWED
class CustomFreeplayFunctions
{
    public static function implement(funk:FunkinLua)
    {
        var lua = funk.lua;
        Lua_helper.add_callback(lua, "getFreeplaySongList", getFreeplaySongList);
        Lua_helper.add_callback(lua, "selectFreeplaySong", selectFreeplaySong);
        Lua_helper.add_callback(lua, "getFreeplayScore", getFreeplayScore);
        Lua_helper.add_callback(lua, "playFreeplaySong", playFreeplaySong);
    }

    public static function getFreeplaySongList():Array<Dynamic>
    {
        WeekData.reloadWeekFiles(false);
        var result:Array<Dynamic> = [];
        for (i in 0...WeekData.weeksList.length)
        {
            var leWeek:WeekData = WeekData.weeksLoaded.get(WeekData.weeksList[i]);
            var locked:Bool = !leWeek.startUnlocked && leWeek.weekBefore.length > 0
                && (!StoryMenuState.weekCompleted.exists(leWeek.weekBefore) || !StoryMenuState.weekCompleted.get(leWeek.weekBefore));
            if (locked) continue;

            WeekData.setDirectoryFromWeek(leWeek);
            for (song in leWeek.songs)
            {
                var colors:Array<Int> = song[2];
                if(colors == null || colors.length < 3) colors = [146, 113, 253];
                result.push({
                    songName: song[0],
                    week: i,
                    character: song[1],
                    color: FlxColor.fromRGB(colors[0], colors[1], colors[2]),
                    folder: Mods.currentModDirectory
                });
            }
        }
        return result;
    }

    public static function selectFreeplaySong(week:Int, folder:String):Array<String>
    {
        Mods.currentModDirectory = folder;
        PlayState.storyWeek = week;
        Difficulty.loadFromWeek();
        return Difficulty.list;
    }

    public static function getFreeplayScore(songName:String, diffIndex:Int):Int
    {
        return Highscore.getScore(Paths.formatToSongPath(songName), diffIndex);
    }

    public static function playFreeplaySong(songName:String, diffIndex:Int):Bool
    {
        var songLowercase:String = Paths.formatToSongPath(songName);
        var poop:String = Highscore.formatSong(songLowercase, diffIndex);
        try {
            Song.loadFromJson(poop, songLowercase);
            PlayState.isStoryMode = false;
            PlayState.storyDifficulty = diffIndex;
        } catch(e:haxe.Exception) {
            trace('[CustomFreeplay] Lỗi load "$songName": ${e.message}');
            return false;
        }
        LoadingState.prepareToSong();
        LoadingState.loadAndSwitchState(new PlayState());
        return true;
    }
}
#end
```

### 3.9 `psychlua/CustomMenuFunctions.hx` (MỚI) — điều hướng menu
```haxe
package psychlua;

import states.MainMenuState;
import states.StoryMenuState;
import states.FreeplayState;
import states.CreditsState;
import options.OptionsState;
#if MODS_ALLOWED import states.ModsMenuState; #end
#if ACHIEVEMENTS_ALLOWED import states.AchievementsMenuState; #end
import lime.app.Application;

#if LUA_ALLOWED
class CustomMenuFunctions
{
    public static function implement(funk:FunkinLua)
    {
        var lua = funk.lua;
        Lua_helper.add_callback(lua, "goToStoryMode", function() { MusicBeatState.switchState(new StoryMenuState()); return true; });
        Lua_helper.add_callback(lua, "goToFreeplay", function() { MusicBeatState.switchState(new FreeplayState()); return true; });
        Lua_helper.add_callback(lua, "goToCredits", function() { MusicBeatState.switchState(new CreditsState()); return true; });
        Lua_helper.add_callback(lua, "goToOptions", function() { MusicBeatState.switchState(new OptionsState()); return true; });
        #if MODS_ALLOWED Lua_helper.add_callback(lua, "goToModsMenu", function() { MusicBeatState.switchState(new ModsMenuState()); return true; }); #end
        #if ACHIEVEMENTS_ALLOWED Lua_helper.add_callback(lua, "goToAchievements", function() { MusicBeatState.switchState(new AchievementsMenuState()); return true; }); #end
        Lua_helper.add_callback(lua, "initMenuMods", initMenuMods);
        Lua_helper.add_callback(lua, "quitGame", function() { Application.current.window.close(); return true; });
    }
    public static function initMenuMods():Bool
    {
        #if MODS_ALLOWED Mods.pushGlobalMods(); Mods.loadTopMod(); #end
        return true;
    }
}
#end
```

### 3.10 `psychlua/PsychGlobalScript.hx` (MỚI) — script xuyên suốt phiên chơi
```haxe
package psychlua;
#if (LUA_ALLOWED || HSCRIPT_ALLOWED)
class PsychGlobalScript
{
    public static var instance:PsychGlobalScript;
    #if LUA_ALLOWED public var luaArray:Array<FunkinLua> = []; #end
    #if HSCRIPT_ALLOWED public var hscriptArray:Array<HScript> = []; #end

    public static function init()
    {
        if (instance != null) return;
        instance = new PsychGlobalScript();
        instance.loadScripts();
    }
    public function new() {}

    function loadScripts()
    {
        var owner:MusicBeatState = MusicBeatState.getState();
        for (folder in Mods.directoriesWithFile(Paths.getSharedPath(), 'customStates/global/'))
        {
            for (file in Paths.readDirectory(folder))
            {
                #if LUA_ALLOWED
                if (file.toLowerCase().endsWith('.lua')) {
                    var lua = new FunkinLua(folder + file);
                    if (owner != null) owner.luaArray.remove(lua); // rút khỏi owner, tránh bị hủy
                    luaArray.push(lua);
                }
                #end
                #if HSCRIPT_ALLOWED
                if (file.toLowerCase().endsWith('.hx')) {
                    var script = new HScript(null, folder + file);
                    if (script.exists('onCreate')) script.call('onCreate');
                    hscriptArray.push(script);
                }
                #end
            }
        }
        callOnScripts('onCreate', []);
    }

    public function callOnScripts(funcToCall:String, args:Array<Dynamic> = null):Void
    {
        if(args == null) args = [];
        #if LUA_ALLOWED
        for (script in luaArray) if(script != null && !script.closed) script.call(funcToCall, args);
        #end
        #if HSCRIPT_ALLOWED
        for (script in hscriptArray) if(script != null && script.exists(funcToCall)) script.call(funcToCall, args);
        #end
    }

    public static function notifyStateSwitch(stateName:String)
    {
        if (instance != null) instance.callOnScripts('onStateSwitch', [stateName]);
    }
}
#end
```
> ⚠️ Không đặt tên là `GlobalScript` (xung đột type → *"does not have a constructor"*). Dùng `PsychGlobalScript`.

---

## 4. CÁCH PORT CUSTOM FREEPLAY (Lua chuẩn) — từng bước

### Bước 1: Cấu trúc thư mục mod
```
/sdcard/.PsychEngine/mods/MyMod/
└── customStates/
    └── freeplay/
        └── state.lua
```
Rồi thêm mod vào `/sdcard/.PsychEngine/modsList.txt`:
```
# thêm dòng (số = thứ tự bật)
MyMod|2
```

### Bước 2: `state.lua` — freeplay hoàn chỉnh

```lua
-- CUSTOM FREEPLAY — chạy trong CustomState('freeplay')
local songList = {}      -- danh sách bài (getFreeplaySongList)
local selected = 1
local difficulties = {}  -- danh sách độ khó của bài đang chọn
local curDiff = 1

-- Màu nền dynamic + các text
function onCreate()
    songList = getFreeplaySongList()

    -- nền tối đơn giản
    makeLuaSprite('bg', nil, 0, 0)
    makeGraphic('bg', screenWidth, screenHeight, '101018')
    addLuaSprite('bg')

    makeLuaText('titleTxt', 'FREEPLAY', screenWidth, 0, 20)
    setTextSize('titleTxt', 56)
    setTextAlignment('titleTxt', 'center')
    addLuaText('titleTxt')

    for i, song in ipairs(songList) do
        local tag = 'song' .. i
        makeLuaText(tag, song.songName, 500, 60, 120 + (i * 48))
        setTextSize(tag, 30)
        addLuaText(tag)
    end

    makeLuaText('diffText', '', screenWidth, 0, 640)
    setTextSize('diffText', 28)
    setTextAlignment('diffText', 'center')
    addLuaText('diffText')

    makeLuaText('exitText', 'Back', screenWidth, 0, 690)
    setTextSize('exitText', 22)
    setTextAlignment('exitText', 'center')
    addLuaText('exitText')

    if #songList > 0 then selectSong() end
end

function selectSong()
    difficulties = selectFreeplaySong(songList[selected].week, songList[selected].folder)
    if curDiff > #difficulties then curDiff = #difficulties end
    if curDiff < 1 then curDiff = 1 end

    for i, song in ipairs(songList) do
        setProperty('song' .. i .. '.alpha', (i == selected) and 1 or 0.4)
    end

    local score = getFreeplayScore(songList[selected].songName, curDiff - 1)
    setTextString('diffText', difficulties[curDiff] .. '  |  Score: ' .. score)
end

function onUpdate(elapsed)
    if keyJustPressed('up') then
        selected = selected - 1
        if selected < 1 then selected = #songList end
        selectSong()
    elseif keyJustPressed('down') then
        selected = selected + 1
        if selected > #songList then selected = 1 end
        selectSong()
    elseif keyJustPressed('left') then
        curDiff = curDiff - 1
        if curDiff < 1 then curDiff = #difficulties end
        selectSong()
    elseif keyJustPressed('right') then
        curDiff = curDiff + 1
        if curDiff > #difficulties then curDiff = 1 end
        selectSong()
    elseif keyJustPressed('accept') then
        if playFreeplaySong(songList[selected].songName, curDiff - 1) == false then
            -- chart lỗi: thông báo
        end
    elseif keyJustPressed('back') then
        exitCustomState()   -- quay về MainMenu
    end
end
```

### Bước 3: Mở state từ đâu

**Từ Lua (bất kỳ script nào đang chạy):**
```lua
switchCustomState('freeplay')
```

**Từ HScript:**
```hx
CustomState.openState('freeplay');
```

**Từ code engine (Haxe) — ví dụ nút Freeplay trong MainMenuState.hx:**
```haxe
MusicBeatState.switchState(new psychlua.CustomState('freeplay'));
```
(Đó chính là thay đổi ta đã làm ở `MainMenuState.hx` dòng `case 'freeplay':`.)

---

## 5. Các hàm Lua có sẵn trong CustomState

Nhờ `LuaUtils.getTargetInstance()` đã tổng quát hóa sang `MusicBeatState.getState()`, hầu hết hàm dựng UI đều chạy được trong CustomState:

**Sprite / Text / UI**
- `makeLuaSprite(tag, img, x, y)`, `makeAnimatedLuaSprite`, `makeGraphic`
- `addLuaSprite(tag, ?inFront)`, `removeLuaSprite`, `screenCenter`, `setGraphicSize`, `scaleObject`, `updateHitbox`
- `makeLuaText(tag, text, w, x, y)`, `setTextString/Size/Alignment/Color/Font`, `addLuaText`
- `setObjectCamera`, `setObjectOrder`, `setScrollFactor`, `setBlendMode`
- `addAnimationByPrefix`, `addAnimationByIndices`, `playAnim`

**Tween / Timer / Sound**
- `doTweenX/Y/Alpha/Angle/Color/Zoom`, `startTween`, `cancelTween`
- `runTimer`, `cancelTimer`
- `playMusic`, `playSound`, `stopSound`, `soundFadeIn/Out`

**Camera**
- `cameraShake`, `cameraFlash`, `cameraFade`, `setCameraScroll`, `setCameraFollowPoint`

**Input** (đã fix qua `Controls.instance`)
- `keyJustPressed('left'/'down'/'up'/'right'/'accept'/'back'/'space'/...)`
- `keyPressed`, `keyReleased`
- `mouseClicked`, `mousePressed`, `mouseReleased`, `getMouseX/Y`

**Custom State**
- `switchCustomState(tên)` — mở state khác
- `exitCustomState()` — về MainMenu
- `getFreeplaySongList()`, `selectFreeplaySong(week, folder)`, `getFreeplayScore(song, diff)`, `playFreeplaySong(song, diff)`
- `goToStoryMode()`, `goToFreeplay()`, `goToCredits()`, `goToOptions()`, `goToModsMenu()`, `initMenuMods()`

**Callbacks mà CustomState tự gọi:**
- `onCreate(stateName)`, `onCreatePost(stateName)`
- `onUpdate(elapsed)`, `onUpdatePost(elapsed)`
- `onBeatHit()`, `onStepHit()`
- `onDestroy(stateName)`

**Global scripts (`customStates/global/`, chạy xuyên phiên):**
- `onCreate()`, `onUpdate(elapsed)`, `onStateSwitch(stateName)`

---

## 6. Checklist test

- [ ] Vào thẳng game (chưa từng chơi bài) → bấm Freeplay từ MainMenu → mở CustomState **không crash** (kiểm chứng fix `ExtraFunctions`).
- [ ] `onCreate/onUpdate/onBeatHit/onStepHit/onDestroy` gọi đúng thứ tự.
- [ ] Chọn bài bằng up/down, đổi độ khó bằng left/right, hiện đúng score.
- [ ] Accept → vào PlayState load đúng bài/đúng mod/đúng độ khó.
- [ ] Back → `exitCustomState()` về MainMenu, không rò rỉ camera/nhạc.
- [ ] Vào PlayState chơi 1 bài, thoát, mở CustomState → không dính state/script cũ.
- [ ] Nếu có mod khác trùng tên bài → kiểm tra load đúng mod (qua `Mods.currentModDirectory`).

---

## 7. Mở rộng (Story Mode / Main Menu thay hẳn)

- **Custom Main Menu:** tạo `customStates/mainmenu/state.lua` gọi `initMenuMods()` rồi `goToStoryMode()`/`goToFreeplay()`... Sửa `TitleState.hx` để mở `CustomState('mainmenu')` thay `MainMenuState` (nên bọc kiểm tra `FileSystem.exists` để fallback về menu gốc).
- **Custom Story Mode:** làm tương tự `CustomFreeplayFunctions`, nhưng set `PlayState.isStoryMode = true`, nạp `PlayState.storyPlaylist` (danh sách bài trong tuần), `PlayState.storyWeek`, `PlayState.campaignScore`... rồi vào PlayState.

---

## 8. Cách build / test

Đây là fork mobile Psych (Haxe/Lime). Build APK **chỉ qua GitHub Actions** (không build local):
1. Commit + `git push origin main` → workflow `android-build.yml` tự chạy.
2. Build ~20 phút. Download artifact `androidBuild`.
3. Cài APK, bật mod chứa `customStates/` trong `/sdcard/.PsychEngine/modsList.txt`, test.

Nếu lỗi compile, lấy `<Log failed>` từ run đó và sửa theo `file:line` đã ghi trong log.
