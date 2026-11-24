# PsychEngine-Custom — Rendering Mode & Gameplay Recorder
## Báo cáo nghiên cứu source và kế hoạch triển khai

- **Ngày nghiên cứu:** 2026-11-24
- **Repository:** `/sdcard/Download/FNF/PsychEngine-Custom`
- **Branch / HEAD tại thời điểm nghiên cứu:** `main` / `1963e8a`
- **Phạm vi:** đọc source tích hợp gameplay, input, Lua/HScript, menu, camera, game loop và thư viện HaxeFlixel/OpenFL đang có trên thiết bị.
- **Trạng thái:** chỉ nghiên cứu và lập kế hoạch. **Không sửa source, không build, không commit, không push.**
- **Revision 2 (2026-11-24):** bổ sung yêu cầu **Offline Rendering phải chạy được khi thu nhỏ app, có notification và progress bar** (mục 6.8, Phase 6B); chốt cơ chế step offline và đường capture (mục 6.4a, 6.5); thêm quy trình typecheck local (mục 14). Các mục mới được đánh dấu rõ **[đã xác minh]** (đọc từ source/chạy thật trên thiết bị) hoặc **[chưa xác minh]**.

---

## 1. Kết luận tổng quan

Hai tính năng khả thi về mặt kiến trúc, nhưng độ khó không ngang nhau:

1. **Gameplay Recorder** có thể làm trước. Source đã có điểm thu thập input tương đối rõ: keyboard đi qua `PlayState.onKeyPress/onKeyRelease`; mobile controls phát tín hiệu `onButtonDown/onButtonUp`; các đường xử lý note cuối cùng gom về `keyPressed/keyReleased`. Có thể thêm recorder mà giữ nguyên cách xử lý hit/miss hiện tại.
2. **Rendering Mode — Real-time Capture** nên làm sau recorder. OpenFL có `BitmapData.encode(..., PNGEncoderOptions)`; HaxeFlixel có camera/display pipeline, nhưng phải xác định chính xác điểm lấy ảnh composite cuối cùng và kiểm tra cả tile renderer lẫn blit renderer.
3. **Rendering Mode — Offline Rendering** là phần rủi ro cao nhất. Không thể chỉ đổi FPS, bật `FlxG.fixedTimestep`, hay đặt `Conductor.songPosition`. PlayState hiện đồng bộ thời gian với audio thật, chạy nhiều hệ thống phụ thuộc `elapsed`, và Botplay đánh note bên trong update loop. Cần một đường chạy mô phỏng có clock được điều khiển, gọi đúng lifecycle update/draw của HaxeFlixel, đồng thời chặn các nguồn thời gian thực gây lệch.
4. **Lua-created UI recording** chưa có API button/checkbox/slider dành riêng cho Lua được tìm thấy trong các module đã rà. Các lớp `PsychUIButton`, `PsychUICheckBox`, `PsychUISlider` hiện là UI nội bộ, chủ yếu dùng ở editor và thao tác bằng mouse. Cần thiết kế một registry/API Lua có ID ổn định, không serialize closure.

**Thứ tự khuyến nghị:** chuẩn hóa schema + recorder → replay input → deterministic replay/desync → giao diện Render State → capture realtime → offline renderer → Lua UI bridge và tối ưu nâng cao.

5. **Offline Rendering khi thu nhỏ app (revision 2)** chỉ làm được ở mức **best-effort**: Android huỷ EGL surface khi app vào nền, còn pipeline capture dựa trên GL cần surface. Thiết kế chọn: Foreground Service + notification tiến trình, giữ loop chạy bằng hint SDL, và **fallback tự pause/resume không mất frame** khi mất surface. Chạy nền hoàn toàn không cần surface (EGL pbuffer native) nằm ngoài v1.

**Thứ tự khuyến nghị (cập nhật):** chuẩn hóa schema + recorder → replay input → deterministic replay/desync → giao diện Render State → capture realtime → Foreground Service/notification → offline renderer → chạy nền + pause/resume → Lua UI bridge và tối ưu nâng cao.

---

## 2. Môi trường và sự khác biệt phiên bản

### 2.1 Thông tin xác minh trực tiếp

| Thành phần | Giá trị quan sát được |
|---|---|
| Haxe trên thiết bị | 4.3.7 |
| HaxeFlixel cài local | 5.6.1, Git revision `b07c67a` |
| OpenFL cài local | 9.5.2, Git revision `fd7075460` |
| Lime cài local | 8.1.2, Git revision `4be60de` |
| flixel-addons | 3.2.2 |
| hscript-iris | 1.1.3 |
| hxvlc | 2.0.1 |
| tjson | 1.4.0 |
| Psych Engine app version trong Project.xml | 1.0.4c0.2.3 |

Các thư viện trên được đọc từ haxelib repository trên thiết bị, không suy ra từ tài liệu web.

### 2.2 Chú ý về toolchain

`AGENTS.md` và `setup/unix.sh` mô tả Haxe 4.3.6 và OpenFL 9.4.1, trong khi môi trường nghiên cứu hiện tại có Haxe 4.3.7 và OpenFL 9.5.2. Script setup có nhánh cài OpenFL 9.4.1. Vì vậy:

- Không được coi kết quả API của OpenFL 9.5.2 là bằng chứng rằng target build pin 9.4.1 chắc chắn tương thích.
- Trước khi code cần xác định chính xác dependency thực dùng trong quy trình build phát hành.
- Không nâng version hoặc đổi fork dependency chỉ để phục vụ tính năng này.
- Chỉ dùng API đã có trong version build thực tế, hoặc dùng compile guard khi API khác nhau theo target.

`Project.xml` có các define quan trọng:

- `MODS_ALLOWED` và `HSCRIPT_ALLOWED` cho desktop/mobile.
- `LUA_ALLOWED` cho cpp.
- `MULTITHREADED_LOADING` chỉ được bật theo define cpp.
- `FLX_RECORD` đang **comment**, tức recorder built-in của HaxeFlixel không được bật ở build này.

Không nên bật `FLX_RECORD` để thay thế hệ thống JSON mới: mục tiêu cần event schema riêng, raw touch/UI Lua events và playback có thể kiểm soát.

---

## 3. Những phần source đã xác minh

### 3.1 Game loop và timestep

**File:** `source/Main.hx`

- Game được khởi tạo bằng `new FlxGame(..., game.framerate, game.framerate, ...)`.
- Sau khởi tạo, source đặt `FlxG.fixedTimestep = false`.
- Tức trạng thái mặc định hiện tại là variable timestep.

**Thư viện local:** `flixel/FlxGame.hx` của HaxeFlixel 5.6.1

- `onEnterFrame()` là vòng ngoài nhận ENTER_FRAME.
- Khi `FlxG.fixedTimestep == true`, code cộng elapsed vào accumulator, giới hạn accumulator bởi `_maxAccumulation`, rồi gọi `step()` trong vòng while.
- Khi `fixedTimestep == false`, mỗi ENTER_FRAME chỉ gọi một `step()`.
- Sau update, vòng ngoài gọi `draw()`.
- `step()` gọi lifecycle update của game; trong `update()`, Flixel cập nhật input, sound, plugins, state và camera.
- `draw()` chạy preDraw, plugin draw, state draw, camera render, rồi postDraw.

**Hệ quả:** gọi riêng `PlayState.update()` trong một vòng lặp tự tạo sẽ bỏ qua hoặc làm sai thứ tự một phần lifecycle Flixel như input manager, sound manager, plugins, camera và các signal. Không nên xây Offline Renderer bằng cách gọi trực tiếp mỗi state update rồi tự gọi draw.

### 3.2 Conductor và thời gian bài hát

**File:** `source/backend/Conductor.hx`

- `Conductor.songPosition` là Float theo milliseconds.
- Có BPM map, `stepCrochet`, `crochet`, `getBPMFromSeconds()`, `getStep()`.
- `PlayState` dùng Conductor để xác định step/beat/section và thời điểm note.

**File:** `source/states/PlayState.hx`

Đường thời gian được đọc trong `PlayState.update(elapsed)`:

1. Chạy callbacks script và `super.update(elapsed)`.
2. Tăng `Conductor.songPosition` theo `elapsed * 1000 * playbackRate`.
3. Khi bài hát đã bắt đầu, kéo vị trí này về gần `FlxG.sound.music.time + Conductor.offset` bằng phép nội suy.
4. Dựa vào songPosition để spawn note, update note, xử lý event, hit/miss và kết thúc bài hát.

`startSong()` phát instrumental và vocal bằng FlxSound, đặt callback `onComplete`, rồi gọi `setSongTime()`. Hàm `setSongTime()` thay đổi cả audio time lẫn `Conductor.songPosition`.

**Hệ quả:** Offline Renderer phải có chế độ clock riêng; audio time không được làm master clock. Đường realtime giữ nguyên behavior hiện có.

### 3.3 Manual input và Botplay

**File:** `source/states/PlayState.hx`

- Keyboard listener được đăng ký trên `FlxG.stage` bằng OpenFL `KeyboardEvent.KEY_DOWN/KEY_UP`.
- `onKeyPress()` đổi keyCode thành `FlxKey`, tìm lane qua `getKeyFromEvent(keysArray, key)`, sau đó gọi `keyPressed(lane)`.
- `onKeyRelease()` gọi `keyReleased(lane)`.
- `keyPressed/keyReleased` gọi callback Lua/HScript tương ứng và xử lý note, animation, ghost tap/miss.
- Listener được gỡ trong `destroy()`.
- Mobile controls nối signal `onButtonDown/onButtonUp` vào `onButtonPress/onButtonRelease`.
- Hai callback mobile chuyển `TouchButton.IDs` thành lane và gọi chung `keyPressed/keyReleased`.
- `keysCheck()` đọc trạng thái held/just pressed/just released qua Controls để xử lý sustain.
- Botplay dùng `cpuControlled`; trong vòng update của note, Botplay gọi trực tiếp `goodNoteHit(daNote)` khi note có thể hit.

**Khuyến nghị:** recorder nên ghi cả:
- Raw input event (để có thể audit nguồn input).
- Logical lane press/release sau khi đã map input thành lane.
- Gameplay checkpoint/kết quả hit/miss để phát hiện desync.

Replay phải inject logical input qua một gateway Haxe riêng trong PlayState, thay vì giả lập sự kiện bàn phím của hệ điều hành. Gateway đó cần đi qua cùng logic `keyPressed/keyReleased`, có guard chống double-injection.

### 3.4 Mobile / hitbox / multi-touch

**Các file đã đọc:**

- `source/backend/Controls.hx`
- `source/mobile/input/MobileInputManager.hx`
- `source/mobile/objects/TouchButton.hx`
- `source/mobile/objects/Hitbox.hx`
- `source/mobile/objects/TouchPad.hx`
- `source/mobile/backend/TouchUtil.hx`

Đã xác minh:

- `Controls` tổng hợp keyboard, gamepad và mobile control theo action name.
- `MobileInputManager` theo dõi `TouchButton` bằng `MobileInputID`, có trạng thái pressed/justPressed/justReleased.
- `TouchButton` có `IDs`, `tag`, `multiTouch`, `currentInput` và các callback onDown/onUp/onOver/onOut.
- Hitbox lane có ID kết hợp hitbox và logical note lane, ví dụ `HITBOX_LEFT` cùng `NOTE_LEFT`.
- TouchPad cũng dùng ID để ánh xạ sang hành động.
- `TouchUtil` duyệt `FlxG.touches.list` và lấy trạng thái touch.

**Hệ quả:** không nên chỉ poll `Controls.pressed()` mỗi frame rồi ghi lại. Polling có thể không giữ lại mọi chuyển trạng thái xảy ra giữa hai update. Cần capture cạnh press/release từ nơi event được phát ra, sau đó chuẩn hóa thành lane event. Với nhiều ngón tay phải lưu pointer ID; không gộp tất cả touch thành một boolean.

### 3.5 Lua/HScript và UI

**File:** `source/psychlua/FunkinLua.hx`

- Lua script được gắn với `MusicBeatState.luaArray`.
- Script được gọi qua tên callback, như `onUpdate`, `onKeyPress`, `goodNoteHit`.
- Closure runtime không có định dạng serialize ổn định; không đưa function/closure vào JSON.

**File:** `source/psychlua/StateScriptManager.hx`

- Có state override của mod và custom-state resolution.
- Có thể dùng Render State native Haxe; không bắt buộc phải implement Render State bằng Lua.

**UI classes đã tìm thấy:**

- `source/backend/ui/PsychUIButton.hx`
- `source/backend/ui/PsychUICheckBox.hx`
- `source/backend/ui/PsychUISlider.hx`

Chúng có callback runtime và broadcast event. Tuy nhiên:

- Các lớp hiện thấy được dùng nhiều trong editor.
- Input implementation đọc `FlxG.mouse` (mouse click/move/release); không thấy xử lý touch đa điểm trong ba class này.
- Không tìm thấy constructor/API Lua tương ứng cho các lớp này trong các psychlua module đã rà.

**Kết luận:** yêu cầu ghi UI do Lua tạo cần một lớp registry/API mới hoặc adapter dành cho UI được tạo qua engine API. Mỗi control cần ID ổn định và callback name/action ID; JSON chỉ ghi ID/action/value/timestamp, không lưu closure. Khi replay, script được gọi bằng một callback quy ước như `onReplayUIAction(id, action, value)`, hoặc adapter dispatch tới callback ID đã đăng ký trong phiên replay.

### 3.6 Freeplay / Story Mode và điều hướng

**File:** `source/states/FreeplayState.hx`

- Có nhánh tự chuyển sang OsuFreeplayState nếu setting osuFreeplay được bật.
- Có kiểm tra mod và tuần hợp lệ; nếu không hợp lệ thì chuyển ErrorState.
- Có vòng update và điều khiển bằng Controls.
- Vì vậy nút mở Render State chỉ nên được thêm sau khi menu chuẩn đã vượt qua các điều kiện hợp lệ; không làm thay đổi nhánh OsuFreeplay hoặc thông báo no-mod/no-week.

**File:** `source/states/StoryMenuState.hx`

- Có kiểm tra mod và tuần hợp lệ.
- Dùng tuần hiện tại, difficulty, nhóm sprite/character và touchpad.
- Back hiện tại trở về MainMenuState.

**Khuyến nghị:** truyền rõ nguồn vào Render State, ví dụ enum `Freeplay` hoặc `Story`. Khi Back, phải khôi phục đúng menu nguồn và trạng thái chọn song/week/difficulty cần thiết; tránh chỉ gọi `new FreeplayState()` hoặc `new StoryMenuState()` rồi làm mất selection.

### 3.7 Settings và output path

**File:** `source/backend/ClientPrefs.hx`

Đã thấy hai setting liên quan là `lowQuality` và `shaders`. Render Settings nên được áp dụng trong một scope tạm thời của phiên render, sau đó restore toàn bộ preference cũ; không ghi đè setting người dùng khi chỉ muốn xuất một bản render khác.

**File:** `source/mobile/backend/StorageUtil.hx`

- Android external root của engine là `/sdcard/.PsychEngine/`.
- Android app storage directory được lấy từ `AndroidContext.getExternalFilesDir()`.
- Có luồng permission và tạo thư mục.
- `StorageUtil.saveContent()` hiện tạo thư mục saves và lưu text; chưa phải một PNG sequence writer.

**Output đề xuất:** thư mục con trong engine external root, ví dụ:

```text
/sdcard/.PsychEngine/renders/<song>/<render-id>/frame_00000000.png
/sdcard/.PsychEngine/recordings/<song>/<recording-id>.json
```

Desktop cần dùng thư mục do người dùng chọn hoặc thư mục output mặc định riêng. Tách path policy theo target và kiểm tra ghi file/thư mục trước khi bắt đầu render.

---

## 4. Thiết kế Gameplay Recorder

### 4.1 Thành phần đề xuất

Đặt module ở `source/backend/recording/`:

| Class | Trách nhiệm |
|---|---|
| `RecordingData.hx` | Metadata, settings snapshot, schema version |
| `RecordingEvent.hx` | Event model có type, timestamp, sequence và payload |
| `GameplayRecorder.hx` | Start/stop, capture, clock, sequence ordering |
| `RecordingEventQueue.hx` | Buffer event, bounded queue, batching |
| `RecordingWriter.hx` | Serialize và lưu JSON |
| `GameplayReplay.hx` | Load/validate recording, sort/dispatch event |
| `ReplayInputGateway.hx` | Inject lane/input mà không giả lập OS event |
| `ReplayVerifier.hx` | Checkpoint, compare trạng thái và báo desync |

Tên class có thể đổi khi bắt đầu code, nhưng nên giữ một owner duy nhất cho recorder state và một event contract duy nhất.

### 4.2 Event cần ghi

| Nhóm | Event đề xuất | Payload chính |
|---|---|---|
| Keyboard | `key.down`, `key.up` | key code/name, mapped lane nếu có |
| Gameplay lane | `lane.down`, `lane.up` | lane, source, logical action |
| Touch | `touch.down`, `touch.move`, `touch.up` | pointerId, x/y normalized, pressure nếu target hỗ trợ |
| Mouse | `mouse.down`, `mouse.move`, `mouse.up`, `mouse.wheel` | button, position normalized, delta |
| Lua UI | `ui.action` | uiId, controlType, action, value |
| Menu/game flow | `game.pause`, `game.resume`, `game.restart`, `game.quit` | source, reason, state |
| Verification | `checkpoint` | song time, note counters, score/health/hash |

Không ghi cùng một thao tác thành hai logical lane press. Nếu cùng hành động xuất phát từ hitbox, raw touch và logical lane đều có thể tồn tại, nhưng replay chỉ inject đúng một lớp canonical (khuyến nghị `lane.down/up`). Raw events giữ vai trò chẩn đoán hoặc mô phỏng UI pointer.

### 4.3 Timestamp và ordering

Đề xuất dùng:

- `tUs`: integer microseconds tính từ mốc bắt đầu recording.
- `seq`: integer tăng đơn điệu cho toàn bộ events.
- `clockDomain`: ghi rõ event dùng monotonic/session clock hay song timeline.
- Với gameplay input, lưu cả timestamp session và song position nếu có thể; pause/resume làm hai mốc này khác nhau.
- Event cùng timestamp được phát lại theo `seq`, tuyệt đối không dựa vào thứ tự key trong JSON hoặc thứ tự Map.
- Ghi key-down và key-up thành hai event tách biệt; không lưu một trạng thái "pressed=true" duy nhất.

Độ phân giải timestamp thực tế phụ thuộc monotonic clock có sẵn ở target. Dùng integer microseconds làm đơn vị schema không đồng nghĩa mọi thiết bị có đồng hồ phần cứng chính xác đến từng microsecond; cần ghi/kiểm thử độ phân giải thực tế của clock trên từng target.

Touch coordinates nên normalized theo viewport/logical game size (0..1), kèm metadata viewport và rotation/orientation. Giữ cả pointer ID để nhiều ngón không bị gộp.

### 4.4 JSON schema đề xuất v1

Schema minh họa dưới đây là đề xuất thiết kế, chưa phải file format đã triển khai:

```json
{
  "format": "psychengine-gameplay-recording",
  "version": 1,
  "metadata": {
    "engineVersion": "1.0.4c0.2.3",
    "modId": "mod-folder",
    "song": "Song Name",
    "difficulty": "normal",
    "chartHash": "optional-hash",
    "scriptManifest": [],
    "createdAt": "2026-11-24T00:00:00Z",
    "timeUnit": "microseconds"
  },
  "session": {
    "seed": 123456,
    "initialSettings": {},
    "viewport": { "width": 1280, "height": 720 },
    "storyMode": false,
    "playbackRate": 1.0
  },
  "events": [
    {
      "tUs": 1200000,
      "seq": 0,
      "clockDomain": "session",
      "type": "lane.down",
      "source": "keyboard",
      "lane": 0,
      "raw": { "key": "A" }
    },
    {
      "tUs": 1260000,
      "seq": 1,
      "clockDomain": "session",
      "type": "lane.up",
      "source": "keyboard",
      "lane": 0,
      "raw": { "key": "A" }
    },
    {
      "tUs": 1300000,
      "seq": 2,
      "clockDomain": "session",
      "type": "ui.action",
      "uiId": "mod.pauseButton",
      "action": "click",
      "value": null
    }
  ]
}
```

Quy tắc schema:

- `version` bắt buộc và phải được validate khi load.
- Unknown event type không được âm thầm chuyển thành input khác; báo warning hoặc dừng theo compatibility policy.
- Không serialize function, callback closure, object reference, sprite reference hoặc Haxe class instance.
- Chỉ lưu primitive/array/object JSON an toàn.
- Có giới hạn file size, số events, nesting depth và dữ liệu chuỗi khi load file từ mod.
- Khi đổi schema phải tăng version và có migration/compatibility handler.

### 4.5 Metadata và tính tái lập

Tối thiểu lưu:

- Engine version/build identifier.
- Mod identifier, mod version/hash nếu lấy được.
- Song/chart/difficulty và chart hash.
- BPM map hoặc dữ liệu đủ để xác thực chart tương ứng.
- Gameplay settings ảnh hưởng hit logic: downscroll, middlescroll, playbackRate, noteOffset, ghost tapping, scroll speed, mania/key count, sustain mode và settings tương đương.
- Random seed ban đầu.
- Danh sách script liên quan và hash tùy khả năng.
- Game resolution/viewport, aspect/orientation.
- Version của recorder schema.

`FlxG.random` có `initialSeed` và `currentSeed` trong Flixel source. Có thể lưu/restore seed và dùng seed làm nền cho replay. Tuy nhiên không phải tất cả randomness đều đi qua `FlxG.random`: Haxe `Math.random()` và Lua `math.random` là nguồn riêng. Cần audit thêm các lần gọi RNG trong game và script; không được hứa replay bit-for-bit deterministic chỉ vì đã lưu FlxG seed.

### 4.6 Lua UI registry

Mỗi UI control có ID do mod/script cung cấp, ví dụ `settings.shaderToggle`.

Registry runtime giữ:

- `uiId`
- `scriptName`
- `controlType`
- `callbackId` hoặc action name
- state/value hiện tại
- policy xử lý khi replay (dispatch callback, set value, hoặc cả hai)

Replay chỉ lưu `uiId`, `action`, `value` và thời điểm. Khi phát lại, registry tìm control đã đăng ký và gửi callback đã bind trong runtime. Nếu ID không tồn tại, verifier ghi lỗi UI binding thay vì bỏ qua lặng lẽ.

Không dùng tên biến Lua ngẫu nhiên làm ID tự động vì có thể khác theo thứ tự load hoặc script version. Mod nên khai báo ID ổn định rõ ràng.

### 4.7 Recorder optimization riêng

| Tùy chọn | Thiết kế |
|---|---|
| Event buffering | Gom event vào buffer theo dung lượng/thời gian; flush ở checkpoint và stop |
| Async JSON writer | Tách serialization/file I/O khỏi frame update khi target hỗ trợ thread |
| Memory management | Giới hạn buffer và giải phóng sau flush |
| Input event queue | Capture event tức thì ở source, enqueue theo sequence |
| Event batching | Ghi batch liên tục, giảm số lần gọi I/O |
| No input loss | Queue đầy phải back-pressure/flush hoặc dừng recording với lỗi rõ ràng; không drop im lặng |

Thread chỉ nên xử lý dữ liệu snapshot/bytes độc lập sau khi main thread đã sao chép an toàn. Không truy cập FlxSprite, FlxCamera, BitmapData hoặc Lua state từ writer thread nếu chưa có bảo đảm thread safety. Haxe threading cho phép chia sẻ memory và có nguy cơ race condition/deadlock; queue cần synchronization phù hợp.

---

## 5. Thiết kế Gameplay Replay và phát hiện desync

### 5.1 Replay flow

1. Validate schema/version và metadata.
2. Xác định đúng mod/song/chart/difficulty.
3. So sánh engine/mod/chart hash và gameplay settings.
4. Khởi tạo PlayState với seed và state đầu vào tương đương recording.
5. Tắt hardware input dành cho gameplay trong replay để tránh trộn input thật với replay.
6. Sắp event theo `tUs`, rồi `seq`; inject sự kiện đến hạn qua ReplayInputGateway.
7. Cho gameplay chạy cùng note/event/script logic gốc.
8. Tạo checkpoint đều đặn theo song time/beat/section và so sánh với recording.
9. Nếu mismatch vượt tolerance, dừng hoặc đánh dấu desync; hiển thị thời điểm, expected và actual.

### 5.2 Checkpoint đề xuất

Các giá trị có thể so sánh:

- `Conductor.songPosition`
- curStep/curBeat/curSection
- songScore, songMisses, combo, songHits
- health
- count note hit/miss và event đã dispatch
- RNG current seed
- optional hash của state gameplay được chọn

Không nên hash toàn bộ object graph Haxe vì reference, object pooling và thứ tự nội bộ có thể thay đổi dù gameplay tương đương. Dùng tập checkpoint deterministic và có tolerance rõ ràng.

### 5.3 Nguồn desync đã nhận diện

- Chart/mod/script không giống recording.
- Input event bị mất, duplicate hoặc sai sequence.
- RNG khác seed hoặc khác đường gọi.
- Script dùng timer real-time, `Date.now`, `Sys.time`, network, random Lua hoặc side effect ngoài game loop.
- Audio resync và `onComplete` chạy theo wall clock.
- Tween/timer hoặc animation nhận elapsed khác nhau.
- Multi-touch bị mất pointer ID.
- UI action ID không resolve được callback.
- Replay start từ song position hoặc countdown state khác.

Replay nên có mode strict (mismatch thì dừng) và mode diagnostic (tiếp tục nhưng đánh dấu kết quả không còn đáng tin).

---

## 6. Thiết kế Rendering Mode

### 6.1 Thành phần đề xuất

Đặt module ở `source/backend/rendering/`:

| Class | Trách nhiệm |
|---|---|
| `RenderSettings.hx` | Resolution, FPS, graphics flags, output path, naming |
| `RenderSession.hx` | Một phiên capture/render và trạng thái tiến trình |
| `RenderClock.hx` | Clock/timestep do offline renderer kiểm soát |
| `OfflineRenderController.hx` | Điều phối replay, update tick, frame schedule |
| `FrameCapture.hx` | Lấy ảnh từ final game composite |
| `PngFrameEncoder.hx` | Encode PNG |
| `PngFrameWriter.hx` | Ghi frame sequence xuống filesystem |
| `RenderProgress.hx` | Frame count, progress, throughput, error |

Recorder writer và PNG writer là hai pipeline tách biệt; không dùng chung queue/config vì bản chất dữ liệu và mức ưu tiên khác nhau.

### 6.2 Hai chế độ

**Real-time Capture**

- Capture sau khi game render frame bình thường.
- Có thể chạy với tốc độ người chơi đang thấy.
- Theo dõi số frame captured và số frame bỏ lỡ.
- Không được làm chậm gameplay đáng kể; nếu queue đầy thì chính sách drop phải được hiển thị rõ, không báo rằng đã lưu đủ.
- Dùng để kiểm tra chất lượng capture và đường PNG trước khi triển khai Offline Rendering.

**Offline Rendering**

- Đọc gameplay recording hoặc Botplay timeline.
- Tiến thời gian theo lịch cố định; tốc độ xử lý có thể chậm hơn realtime.
- Mỗi frame output phải có index liên tiếp; không skip frame.
- Queue PNG đầy thì pause/back-pressure update simulation cho đến khi có chỗ; không tăng thời gian game để “đuổi kịp”.
- Không lấy audio playback time làm clock.
- Dùng cùng PlayState, stage, characters, scripts, notes, events, camera, tweens và HUD.

### 6.3 FPS và simulation step

Cần phân biệt:

- **Output FPS:** số ảnh PNG muốn xuất mỗi giây timeline.
- **Simulation timestep:** độ lớn mỗi update của game.

Nếu v1 đặt hai giá trị bằng nhau, dễ triển khai và có tính tái lập theo cấu hình đó, nhưng cùng replay render ở hai FPS có thể cho kết quả animation/tween khác nhau. Nếu muốn chất lượng độc lập output FPS về sau, cần fixed simulation tick riêng (ví dụ 120 Hz) và render interpolation; đó là phase nâng cao, không nên hứa trong bản đầu.

Để tránh sai số tích lũy, frame time nên tính theo index và rational schedule thay vì cộng Float lặp đi lặp lại. Ví dụ timestamp mục tiêu của frame dựa trên `frameIndex * 1_000_000 / outputFPS`.

### 6.4 Kiểm soát thời gian PlayState

Trong offline mode cần một nhánh time source riêng:

- Tắt logic blend `Conductor.songPosition` với `FlxG.sound.music.time`.
- Đặt Conductor theo RenderClock.
- Không để audio `onComplete` kết thúc bài theo thời gian thiết bị.
- Bắt đầu/kết thúc song dựa trên timeline simulation.
- Disable hoặc thay thế thread/worker đồng bộ audio của PlayState khi đang offline render.
- Giữ callbacks Lua/HScript và stage/event processing trong đúng thứ tự update.
- Update timer/tween/animation bằng cùng elapsed cố định.
- Chặn keyboard/touch thực làm thay đổi gameplay trong replay; vẫn cho phép UI Render State nhận nút Cancel/Stop bên ngoài session.
- Botplay tiếp tục dùng logic note gốc, nhưng thời điểm update do RenderClock quyết định.

Không được sửa behavior realtime mặc định. Nhánh offline phải được bật bằng session flag, có cleanup/restore đầy đủ khi cancel, crash hoặc render xong.

### 6.4a Cơ chế step offline đã chốt (revision 2)

**[đã xác minh trong source local]** `FlxGame.onEnterFrame` tính `_elapsedMS = getTicks() - _total`; khi `FlxG.fixedTimestep == true` thì cộng vào `_accumulator` và gọi `step()` trong `while (_accumulator >= _stepMS)`, với `FlxG.elapsed = timeScale * _stepSeconds` (cố định). OpenFL `Stage.__onLimeRender` phát `ENTER_FRAME` (cùng FRAME_CONSTRUCTED/EXIT_FRAME) **trước** `__render(context)`.

Thiết kế driver, đi qua đúng lifecycle Flixel (input, sound, plugins, state, camera, draw):

1. Khi session offline bắt đầu: lưu rồi đặt `FlxG.fixedTimestep = true`, `FlxG.updateFramerate = outputFPS`.
2. Đăng ký listener `ENTER_FRAME` trên `FlxG.game` với priority cao (ví dụ 1000) để chạy trước handler của chính FlxGame (priority 0, cùng một đối tượng nên thứ tự theo priority được áp dụng).
3. Mỗi frame, listener này đặt (qua `@:privateAccess`) `FlxG.game._total = Lib.getTimer()` và `FlxG.game._accumulator = FlxG.game._stepMS`. Kết quả: đúng **một** `step()` với elapsed cố định, rồi `draw()`.
4. Back-pressure: nếu writer queue đầy thì đặt `_accumulator = 0` (không step, chỉ draw lại), không tăng frameIndex, không capture.
5. Kết thúc/cancel: restore `fixedTimestep`, `updateFramerate`, `FlxG.sound.muted`, gỡ listener.

Điểm chặn bắt buộc trong `PlayState` khi session offline (không đổi behavior realtime):

- `update()`: bỏ đoạn lerp `Conductor.songPosition` về `FlxG.sound.music.time` (chỉ cộng `elapsed * 1000 * playbackRate`).
- `keyPressed`: dùng `songMs` của event replay thay cho `FlxG.sound.music.time + Conductor.offset`.
- `keysCheck`: lấy `holdArray` từ replay gateway thay cho `controls.pressed` (nếu không, sustain sai khi replay).
- `startSong`: pause music/vocals, bỏ `onComplete`, mute; kết thúc bài khi `Conductor.songPosition >= songLength` bằng cách gọi `finishSong()`.
- `runSongSyncThread` / `checkForResync` / `resyncVocals`: tắt (thread này seek lại audio khi một frame chạy quá 0.25s, sẽ phát lại audio và gây lệch).
- `endSong`: hiện gọi `Highscore.saveScore` vô điều kiện, phải chặn trong session replay/render; sau khi xong phải quay về `RenderState` thay vì Freeplay/Story (đặt `isStoryMode = false`, `storyPlaylist = []` khi khởi động session).
- `doDeathCheck`: trong session render/replay thì kết thúc session với lý do `game_over` thay vì mở GameOver.
- `LoadingOverlay` có thể chờ "Click to continue": trong session tự gọi `@:privateAccess overlay.continueFromOverlay()` sau `loadingCompleted()`.
- Capture bắt đầu từ `startCountdown()`, còn fixed stepping bắt đầu từ lúc `creationComplete`.

**Giới hạn [đã xác minh bằng suy luận từ source]:** mỗi lần `onRender` chỉ có một step + một capture, nên tốc độ render tối đa bằng tần số render của màn hình (60 fps output ≈ không nhanh hơn realtime). Muốn nhanh hơn phải gọi stage render thủ công nhiều lần trong một frame — **[chưa xác minh]**, nằm ngoài v1.

### 6.5 Frame capture và PNG

Local Flixel camera source cho thấy:

- `FlxCamera.buffer` tồn tại, nhưng đây là buffer BitmapData của blit renderer.
- Camera có `flashSprite`; ở tile renderer có canvas/display list.
- Camera render, camera FX, filters và camera overlays có thứ tự riêng.
- Một buffer của camera đơn lẻ không đại diện chắc chắn cho toàn bộ hình ảnh cuối cùng (gameplay camera + HUD camera + other camera + mobile/control overlay).

Do đó không chốt lấy `FlxG.camera.buffer` làm nguồn ảnh cuối. **Hướng prototype ưu tiên** là capture game display composite sau khi `FlxGame.draw()` hoàn tất, hoặc tự composite các camera theo display order nếu điều đó cần thiết để bảo toàn shader/filters. Phải test cả hai backend render mode và các camera trong PlayState trước khi quyết định API cuối.

Local OpenFL source có:

- `BitmapData.encode(rect, compressor, byteArray)`
- `openfl.display.PNGEncoderOptions`

Nghĩa là PNG encode có API phù hợp về mặt khả năng. Tuy nhiên BitmapData encode là bước xử lý đồng bộ trong API đã đọc; chưa có benchmark của engine trên Android/desktop. Phải kiểm tra version OpenFL thực dùng khi build, vì môi trường local nghiên cứu đang khác setup pin.

**Pipeline đề xuất:**

1. Render frame ở main/render thread.
2. Capture final composite vào buffer độc lập hoặc copy pixel bytes immutable.
3. Chuyển bytes/buffer snapshot tới bounded writer queue.
4. Encode và/hoặc save bằng writer phù hợp target, không dùng object render sống trong worker.
5. Chỉ tăng completedFrame sau khi file được ghi thành công.
6. Khi offline queue đầy, chờ/back-pressure; không bỏ frame.
7. Khi lỗi disk/full permission/encode, dừng session và báo frame index/path/error.

Không giả định `BitmapData` hoặc OpenFL display object thread-safe. Background writer chỉ được thao tác trên dữ liệu đã tách khỏi rendering API.

**Quyết định đường capture (revision 2):**

- **[đã xác minh trong `BitmapData.draw` của OpenFL local]** Nếu bitmap `readable` thì `draw` đi qua Cairo (CPU, không có shader); chỉ bitmap không readable + có `context3D` mới đi qua `OpenGLRenderer`. Dự án đang có `-D lime-cairo`. Vì vậy **không** dùng `BitmapData.draw(FlxG.game)` làm đường chính.
- Đường chính: `GL.readPixels` chạy trong `Application.current.window.onRender` với priority thấp hơn OpenFL (OpenFL đăng ký `__onLimeRender` ở priority mặc định), tức sau khi display list đã render xong trong cùng frame.
- Vùng ảnh: crop theo `FlxG.scaleMode.gameSize` và offset của `FlxG.game` (nhân `window.scale`), đổi hệ trục y của GL (gốc dưới-trái), copy sang `Bytes` độc lập rồi chuyển cho writer thread.
- Writer thread: lật dọc, scale (nếu chọn độ phân giải khác native, chỉ downscale/upscale ảnh, không phải render độ phân giải thật), `lime.graphics.Image.encode(PNG)`, ghi file.
- **[chưa xác minh]** `GL.readPixels` trên Android thật, thứ tự listener priority trên `window.onRender`, và hiệu năng encode. Phase 5 phải prototype trước khi chốt.

### 6.6 Output naming và memory

Tên file mặc định:

```text
frame_00000000.png
frame_00000001.png
frame_00000002.png
...
```

Ghi metadata cạnh sequence, ví dụ `render-manifest.json`, gồm song, replay ID, output FPS/resolution, frame count hoàn thành, graphics settings, engine/mod version và timestamp.

Một frame RGBA 1920×1080 chiếm khoảng 7.9 MiB raw; 3840×2160 khoảng 31.6 MiB raw. Nhiều frame tồn trong queue có thể tiêu tốn RAM rất nhanh, chưa tính buffer capture, staging và encoder. Vì vậy:

- Bắt buộc bounded queue.
- Tái sử dụng capture buffer khi đảm bảo không còn consumer đang đọc.
- Đưa số lượng byte đang chờ lên UI progress/debug.
- Không giữ tất cả BitmapData trong mảng đến cuối phiên.
- Có ngưỡng cảnh báo dung lượng trống và bắt lỗi ghi file.
- Offline mode cần back-pressure thay vì drop frame.

### 6.7 Graphics Settings và Optimization Settings riêng

**Graphics Settings:**

- Enable Shader
- Low Details Mode
- Resolution
- Output FPS
- Output folder
- File naming / frame sequence
- Chọn recording hoặc Botplay source

Các setting đồ họa phải được override tạm thời cho phiên render, không làm đổi config người dùng vĩnh viễn.

**Rendering Optimization:**

- Framebuffer/capture-buffer reuse.
- PNG writer queue.
- Async file writing khi target hỗ trợ.
- Memory cap/back-pressure.
- Batch filesystem operations nếu an toàn.
- Giảm copy pixel không cần thiết.
- Pipeline tối ưu capture/composite.
- **Không drop frame trong Offline Rendering.**

Real-time capture có thể có chính sách skip/drop riêng, nhưng phải hiển thị số frame đã mất.

### 6.8 Offline Rendering khi thu nhỏ app (revision 2)

**Yêu cầu:** session offline vẫn tiến triển khi người dùng thu nhỏ app, có notification với progress bar, và kết quả không sai lệch.

**Sự thật kỹ thuật đã nắm:**

- **[đã xác minh]** Lime SDL local có `SDL_HINT_ANDROID_BLOCK_ON_PAUSE` (`SDL_hints.h`). Mặc định SDL chặn main thread khi Android pause.
- **[chưa xác minh]** Đặt hint bằng `Sys.putEnv("SDL_ANDROID_BLOCK_ON_PAUSE", "0")` lúc runtime có được SDL đọc tại thời điểm pause hay không.
- **[chưa xác minh]** Khi vào nền Android huỷ EGL window surface; không có surface thì không render GL/`readPixels` được. Việc loop Haxe còn chạy nhưng không có `onRender` là khả năng cao.
- **[đã xác minh]** Lime template Android có `AndroidManifest.xml` và `java/org/haxe/lime/GameActivity.java`; `Project.xml` hiện **chưa** có `<java>`/`<template>` cho Android; đã có `mobile/backend/PsychJNI.hx` dùng `lime.system.JNI` làm tiền lệ gọi JNI.

**Thiết kế:**

1. **Foreground Service `RenderService` (Java)** kèm notification ongoing:
   - Progress bar determinate `completedFrame / totalFrames`, text tốc độ (fps xử lý) và thời gian ước tính còn lại.
   - Action Cancel (gửi lệnh về Haxe qua cờ/file, không giết process).
   - Notification riêng khi hoàn tất hoặc lỗi; kênh notification riêng, mức ưu tiên thấp để không kêu mỗi lần cập nhật.
   - Giới hạn tần suất cập nhật (ví dụ ≤ 2 lần/giây hoặc theo % thay đổi).
2. **Cầu nối Haxe↔Java:** `RenderBackgroundBridge.hx` dùng `lime.system.JNI` (theo mẫu `PsychJNI`) gồm `start(total, title)`, `update(done, total, fps)`, `paused(reason)`, `finish(ok, message)`, `isCancelRequested()`. Toàn bộ bọc `#if android`; desktop là no-op.
3. **Manifest/Project.xml:** thêm quyền `FOREGROUND_SERVICE`, `POST_NOTIFICATIONS` (Android 13+), quyền/`foregroundServiceType` phù hợp Android 14+ (khai báo loại mà dịch vụ thực sự thuộc về; chọn và kiểm tra lại theo tài liệu Android trước khi code), khai báo `<service>`; nhúng Java và manifest qua `<java path>` và `<template>` trong `Project.xml`. Xin quyền notification trước khi bắt đầu render (nếu bị từ chối vẫn render được, chỉ không có notification).
4. **Giữ loop chạy:** khi session offline bắt đầu đặt hint `SDL_ANDROID_BLOCK_ON_PAUSE=0` và giữ `PARTIAL_WAKE_LOCK` trong service; restore khi kết thúc/cancel.
5. **Phát hiện mất surface và fallback an toàn:** `OfflineRenderController` theo dõi `onRenderContextLost` và việc không có `onRender` trong N ms. Khi mất:
   - Controller chuyển sang trạng thái `SuspendedNoSurface`: không step, không tăng `frameIndex`, không mất frame; simulation đã dừng ở frame biên nên **không làm lệch kết quả** (step theo index).
   - Notification đổi thành "Tạm dừng — mở lại app để tiếp tục" kèm tiến độ hiện tại.
   - Khi `onRenderContextRestored`/app foreground trở lại: chuyển về `Running` và tiếp tục đúng `frameIndex`.
6. **Persist & recovery:** sau mỗi batch ghi PNG thành công, cập nhật `render-manifest.json` (`completedFrame`, `outputFps`, replay ID, hash chart/mod, settings). Nếu process bị kill: lần mở sau phát hiện manifest dở dang và đề nghị resume; simulation chạy lại từ đầu nhưng **bỏ ghi** các frame đã có (so với `completedFrame`), vì chỉ replay deterministic mới cho phép resume như vậy. Nếu verifier phát hiện checkpoint lệch, từ chối resume và render lại từ đầu.
7. **Trạng thái session:** `Idle → Preparing → Running ⇄ SuspendedNoSurface → Finishing → Done | Failed | Cancelled`, mọi chuyển trạng thái đi qua `RenderSession` và được phản ánh sang notification.

**Hai mức hỗ trợ (phải nói rõ với người dùng trong UI):**

- **Mức A (v1, best-effort):** tiếp tục nếu thiết bị cho phép, nếu không thì tự pause rồi resume như trên.
- **Mức B (ngoài v1):** render hoàn toàn không cần surface bằng EGL pbuffer/offscreen context native (cần Java/C++ riêng, rủi ro theo từng GPU/ROM). Chỉ cân nhắc sau khi pipeline cơ bản đã ổn trên máy thật.

**Việc không được làm:** không giữ BitmapData/GL object trong service; service chỉ hiển thị trạng thái, không xử lý frame; không để notification update chặn render thread; không cập nhật progress từ writer thread mà không qua một điểm gom trạng thái.

---

## 7. Render State và menu navigation---

## 7. Render State và menu navigation

### 7.1 Navigation flow

```text
Freeplay ─┐
          ├── RenderState
Story ────┘      ├── Rendering Mode
                 │    ├── Graphics Settings
                 │    ├── Optimization
                 │    ├── Replay Selection
                 │    └── PNG Export
                 └── Gameplay Recorder
                      ├── Recording Settings
                      ├── Optimization
                      ├── Input Recording
                      ├── Lua UI Recording
                      └── JSON Export
```

### 7.2 Nút truy cập

- Thêm button kiểu D-Pad/shortcut ở cả Freeplay và Story Mode.
- Không thay đổi luồng gameplay hoặc UI trong PlayState.
- Dùng sprite/image asset, panel/card illustration, animation/transition; không làm màn hình chỉ có text.
- Mouse, keyboard và touch phải dùng chung navigation action.
- Touch hit area đủ lớn; có focus/selected state cho keyboard/controller.
- Chỉ thêm sau khi menu vượt qua validation mod/week sẵn có.
- Giữ nhánh OsuFreeplayState không bị ảnh hưởng.

### 7.3 RenderState

Constructor nhận origin menu context. Ví dụ enum `RenderMenuOrigin.Freeplay` hoặc `RenderMenuOrigin.Story`.

RenderState chứa hai panel chính:

- Rendering Mode.
- Gameplay Recorder.

Back phải trả về đúng source menu và khôi phục selection data cần thiết. Không nên chỉ dựng state mới với default values; hãy snapshot song/week/difficulty/mod filter nếu các field đó không tồn tại tĩnh.

### 7.4 Asset direction

Trong `assets/shared/images` đã thấy những image có thể tham khảo phong cách/UI hiện hữu như `menuBG`, `menuDesat`, `campaign_menu_UI_assets`, `modsMenuButtons`, `logoBumpin`, `titleEnter`, `Menu_Tracks`, cùng các thư mục `mainmenu`, `storymenu`, `menubackgrounds`, `menucharacters`, `editors`.

Nên tạo nhóm asset riêng cho Render State để không phụ thuộc atlas đang dùng bởi Story/Freeplay. Trước khi tạo mới, rà asset thực tế của target mobile/desktop và asset naming convention. Không chỉnh/xóa asset hiện hữu không liên quan.

---

## 8. File-level integration plan

Đây là danh sách file dự kiến, chưa tạo file code nào:

| File / module dự kiến | Phạm vi |
|---|---|
| `source/backend/recording/RecordingData.hx` | Metadata/schema model |
| `source/backend/recording/RecordingEvent.hx` | Event model |
| `source/backend/recording/GameplayRecorder.hx` | Capture lifecycle |
| `source/backend/recording/RecordingEventQueue.hx` | Buffering/ordering |
| `source/backend/recording/RecordingWriter.hx` | JSON writer |
| `source/backend/recording/GameplayReplay.hx` | Reader + playback schedule |
| `source/backend/recording/ReplayInputGateway.hx` | Safe logical input injection |
| `source/backend/recording/ReplayVerifier.hx` | Checkpoints/desync |
| `source/backend/rendering/RenderSettings.hx` | Render config |
| `source/backend/rendering/RenderClock.hx` | Offline timeline |
| `source/backend/rendering/OfflineRenderController.hx` | Deterministic stepping |
| `source/backend/rendering/FrameCapture.hx` | Final composite capture |
| `source/backend/rendering/PngFrameEncoder.hx` | PNG encode |
| `source/backend/rendering/PngFrameWriter.hx` | PNG file writer/back-pressure |
| `source/backend/rendering/RenderProgress.hx` | Status/progress/errors |
| `source/states/RenderState.hx` | Hai panel mode selection |
| `source/states/substates/RenderingSettingsSubState.hx` | Graphics/export options |
| `source/states/substates/RecorderSettingsSubState.hx` | Recorder settings |
| `source/backend/recording/LuaUIRegistry.hx` | Stable Lua UI IDs and callback dispatch |
| `source/states/FreeplayState.hx` | Access button only |
| `source/states/StoryMenuState.hx` | Access button only |
| `source/states/PlayState.hx` | Recorder hook, replay input gateway, offline time branch |
| `source/mobile/objects/TouchButton.hx` or adapter riêng | Capture pointer identity/raw touch edge khi cần |
| `source/backend/rendering/RenderBackgroundBridge.hx` | JNI bridge tới service, no-op ngoài Android |
| `source/backend/rendering/RenderSurfaceMonitor.hx` | Phát hiện mất/khôi phục surface, trạng thái `SuspendedNoSurface` |
| `source/backend/rendering/RenderManifest.hx` | Đọc/ghi `render-manifest.json`, resume |
| Java `RenderService` (nhúng qua `<java path>` trong `Project.xml`) | Foreground service, notification, progress, wake lock |
| Manifest template Android (qua `<template>` trong `Project.xml`) | Quyền, `<service>`, `foregroundServiceType` |
| `Project.xml` | Khai báo java/template Android, chỉ khi `android` |
| `source/psychlua/RecorderFunctions.hx` | Lua API đăng ký UI ID và ghi `ui.action`; đăng ký trong `FunkinLua.hx` (cạnh `MobileFunctions.implement`) |

### Nguyên tắc giới hạn sửa đổi

- Không đổi default realtime update/audio behavior.
- Không sửa engine Flixel dependency trước khi chứng minh không có integration point khác.
- Không để recorder phụ thuộc RenderState; recorder dùng được độc lập.
- Không để PNG writer giữ reference đến sprite/camera/BitmapData đang được update.
- Không thêm UI Lua bằng cách serialize callback.
- Không đổi menu gate hoặc bỏ state transition hiện có.
- Tất cả nhánh offline/recording phải có cleanup rõ ràng, gồm stop thread/queue, restore setting, gỡ listener và đóng file.

---

## 9. Kế hoạch triển khai theo phase

### Phase 0 — Chốt contract và kiểm tra target

- Chốt schema JSON v1 và event vocabulary.
- Xác định build target ưu tiên (desktop + Android).
- Đối chiếu Haxe/OpenFL/Flixel đúng version được pin trong build release.
- Kiểm tra song/chart/mod/script hashes và path output.
- Xác định điểm capture final composite bằng prototype không đụng logic gameplay.

**Gate:** schema/documentation được thống nhất; có compile target xác định.

### Phase 1 — Recorder cơ bản

- Tạo model/schema + validator.
- Capture keyboard lane down/up.
- Capture mobile lane down/up từ touchpad/hitbox signal.
- Capture pause/resume/restart.
- Buffer event theo `tUs + seq`.
- Lưu JSON an toàn, có error handling.
- Ghi metadata và settings snapshot.

**Gate:** test đồng thời nhiều lane, hold/sustain, hitbox và multi-touch không mất/duplicate event.

### Phase 2 — Replay và verification

- Load/validate JSON.
- Kiểm tra song/chart/mod/settings tương thích.
- Inject logical lane input qua PlayState gateway.
- Tắt input gameplay vật lý khi replay.
- Thêm checkpoint và desync report.
- Test cùng một replay nhiều lần với kết quả gameplay trùng nhau.

**Gate:** replay manual ổn định với chart không script; sau đó mới mở rộng script-heavy mod.

### Phase 3 — Lua UI recording

- Đưa stable ID registry vào Lua UI API.
- Đăng ký loại control và callback/action ID.
- Ghi button click, checkbox change, slider value, UI pointer khi có yêu cầu.
- Replay UI action qua registry/callback runtime.
- Báo lỗi khi ID hoặc callback thiếu.

**Gate:** UI do script tạo có thể record → save → reload → replay callback đúng control.

### Phase 4 — RenderState và menu navigation

- Tạo RenderState với origin context.
- Thêm nút truy cập tại Freeplay/Story.
- Xây hai panel Rendering/Recorder với art assets.
- Hoàn thiện mouse/keyboard/touch focus, Back navigation.
- Thêm options và file selector/output path UI.

**Gate:** menu gốc không mất selection/flow; không ảnh hưởng OsuFreeplay, menu gate và gameplay.

### Phase 5 — Real-time Capture

- Prototype capture final composite.
- Xác minh shader/filter, HUD, camOther và overlay camera.
- Thêm capture buffer và PNG encode.
- Ghi sequence và manifest.
- Kiểm thử output path trên desktop/Android.
- Đo hiệu năng, queue size và file throughput.

**Gate:** ảnh PNG khớp với frame game, đúng composite và không có ảnh bị rách/thiếu layer.

### Phase 6 — Offline Rendering

- Tạo RenderClock và deterministic stepping adapter.
- Tích hợp với FlxGame lifecycle (input/update/plugins/sound/camera/draw).
- Bỏ real-time audio clock correction chỉ trong offline session.
- Đồng bộ song time, Conductor, timer/tween/animation, Botplay và chart events.
- Tắt hardware gameplay input; phát replay events theo clock.
- Frame schedule dựa trên index/FPS; không drop frame.
- Thực hiện back-pressure writer.
- Đối chiếu checkpoint với replay chuẩn.

**Gate:** một recording render nhiều lần cho frame count, event timing và checkpoint ổn định; không thiếu sequence number, kể cả khi writer chậm hơn renderer.

### Phase 6B — Chạy nền: Foreground Service, notification, pause/resume (revision 2)

- Thêm Java `RenderService`, manifest template, quyền, kênh notification.
- `RenderBackgroundBridge` (JNI) + trạng thái session + cập nhật progress có giới hạn tần suất.
- Đặt/restore hint `SDL_ANDROID_BLOCK_ON_PAUSE` và wake lock theo vòng đời session.
- `RenderSurfaceMonitor`: phát hiện mất surface → `SuspendedNoSurface` → resume đúng `frameIndex`.
- `render-manifest.json` ghi theo batch + luồng resume sau khi process bị kill.
- Nút Cancel trên notification; thông báo hoàn tất/lỗi.

**Gate:** (1) thu nhỏ app giữa chừng rồi mở lại: frame count liên tục, không trùng/không thiếu số thứ tự, checkpoint khớp bản render không bị gián đoạn; (2) notification hiển thị đúng progress và cập nhật khi app ở nền; (3) cancel từ notification dừng sạch và restore setting; (4) quyền notification bị từ chối vẫn render được. Phần "có tiến triển thật khi ở nền" cần test trên thiết bị thật, ghi lại kết quả theo từng máy/ROM.

### Phase 7 — Hardening và optimization### Phase 7 — Hardening và optimization

- Rendering Optimization độc lập Recorder Optimization.
- Memory budget, cancellation, disk full, permission denied, crash recovery.
- Regression test các mod script, shader, event notes, multiple cameras, video/cutscene policy.
- Kiểm tra song lớn và event density cao.
- Benchmark Android cấu hình thấp và desktop.

**Gate:** không làm thay đổi hành vi gameplay mặc định và không tạo file hỏng khi dừng giữa phiên.

---

## 10. Test matrix bắt buộc

| Nhóm | Test | Kết quả mong đợi |
|---|---|---|
| Keyboard | Press/release nhanh, nhiều phím cùng frame | Đủ edge events, sequence đúng |
| Gameplay | Note tap, sustain, ghost tap, miss | Replay hit/miss khớp |
| Mania | 4-key và chart nhiều lane | Map lane không sai |
| Mobile | Touchpad, hitbox, nhiều ngón | Đủ pointer và lane events |
| Mouse | Click/release/move/wheel | Tọa độ và trạng thái đúng |
| Game flow | Pause/resume/restart | Timeline pause/resume chính xác |
| Botplay | Cùng seed/replay nhiều lần | Checkpoint trùng |
| Lua UI | Button/checkbox/slider | Callback đúng ID/action/value |
| Script | onUpdate/tween/timer/random/event | Desync được phát hiện |
| Render | HUD + camGame + camHUD + camOther | Ảnh composite đủ layer |
| Shader | Enable/disable shader, filter | Output đúng trạng thái render |
| Export | FPS/resolution khác nhau | Tên file/manifest/sequence đúng |
| Queue | Writer chậm, queue đầy | Offline back-pressure, không drop |
| Storage | Disk đầy, permission thiếu, folder không tồn tại | Dừng an toàn, báo lỗi |
| Navigation | Freeplay/Story/Back | Trở về đúng menu và selection |
| Regression | Play song bình thường | Không thay đổi realtime gameplay |
| Background | Thu nhỏ app khi đang offline render | Tiến triển tiếp hoặc pause an toàn; không mất/trùng frame |
| Background | Mở lại app sau khi pause do mất surface | Resume đúng `frameIndex`, checkpoint khớp |
| Notification | Progress bar, ước tính thời gian, Cancel | Cập nhật đúng; Cancel dừng sạch |
| Notification | Từ chối quyền POST_NOTIFICATIONS | Vẫn render, không crash |
| Recovery | Kill process giữa chừng | Manifest dở dang được phát hiện, resume bỏ ghi frame đã có |
| Power | Màn hình tắt / chế độ tiết kiệm pin | Ghi nhận hành vi, không hỏng file |
| Offline stepping | Cùng replay ở máy chậm và nhanh | Frame count và checkpoint trùng nhau |
| Capture | Shader bật/tắt qua `GL.readPixels` | Ảnh đúng trạng thái, không ảnh ngược/lệch crop |

---

## 11. Rủi ro và quyết định thiết kế

### Rủi ro mức cao

1. **Offline stepping:** HaxeFlixel game loop có nhiều bước nội bộ; chạy riêng State update không đủ. Cần adapter điều khiển game lifecycle chính xác.
2. **Audio sync:** PlayState đang dùng audio thật làm tham chiếu thời gian; phải có nhánh offline clock được cô lập.
3. **Lua/HScript nondeterminism:** script có thể dựa thời gian thực, random riêng hoặc side effect ngoài simulation.
4. **Final frame capture:** một camera buffer không chắc chứa HUD/camOther/filter. Phải xác minh final composite.
5. **Thread safety:** không đụng OpenFL render object từ worker thread nếu không có bảo đảm.
6. **Input completeness:** polling state có thể bỏ lỡ edge; phải capture ở event source.
7. **Lua UI identity:** UI closure không thể lưu vào JSON; cần stable ID và callback dispatch contract.
8. **Mất EGL surface khi vào nền (revision 2):** có thể làm đường capture GL ngừng hoạt động; giải pháp v1 là pause/resume không mất frame, không phải chạy nền tuyệt đối.
9. **Hành vi SDL/ROM khác nhau:** hint `SDL_ANDROID_BLOCK_ON_PAUSE`, foreground service, tiết kiệm pin và giới hạn nền của từng hãng có thể làm service bị dừng; cần test nhiều máy.
10. **Android 13/14+:** `POST_NOTIFICATIONS`, `foregroundServiceType` và giới hạn khởi động foreground service từ nền; khai báo sai gây crash hoặc service bị từ chối. Phải đối chiếu tài liệu Android trước khi code.
11. **Không build được local:** chỉ có GitHub Actions (~20 phút/lần). Java/manifest không typecheck được bằng Haxe; cần review thủ công kỹ và gom thay đổi vào ít lần build.

### Quyết định nên chốt trước khi code

| Câu hỏi | Đề xuất ban đầu |
|---|---|
| Target v1 | Desktop + Android |
| Recording clock | Session monotonic `tUs` + song position phụ trợ |
| Event ordering | Global `seq` |
| Canonical replay input | Logical lane down/up |
| Raw input | Lưu riêng để audit/UI replay |
| Offline FPS | Output FPS đồng thời là simulation step ở v1 |
| Offline queue đầy | Back-pressure, tuyệt đối không drop |
| Real-time queue đầy | Policy skip/drop được báo rõ |
| Lua UI replay | Registry + stable control ID + callback/action ID |
| Render source | Capture final game composite sau game draw; prototype trước khi chốt |
| Output Android | `/sdcard/.PsychEngine/renders/` |
| Recorder Android | `/sdcard/.PsychEngine/recordings/` |
| Offline khi thu nhỏ app | Mức A best-effort: Foreground Service + hint SDL + pause/resume; mức B (EGL pbuffer) ngoài v1 |
| Đường capture | `GL.readPixels` trong `window.onRender` priority thấp; crop theo `scaleMode.gameSize`; không dùng `BitmapData.draw` (Cairo, mất shader) làm đường chính |
| Driver step offline | Listener `ENTER_FRAME` priority cao trên `FlxG.game` + `fixedTimestep` + đặt `_total`/`_accumulator` để đúng một step mỗi frame |
| Progress | Cập nhật notification giới hạn tần suất, qua một điểm gom trạng thái duy nhất |

### Ngoài phạm vi đã xác minh

- Chưa chạy build hoặc test capture trên màn hình thực tế.
- Chưa benchmark encode/write throughput trên thiết bị Android.
- Chưa chứng minh final composite capture giữ nguyên shader trên mọi renderer.
- Chưa audit toàn bộ mod script bên ngoài repository.
- Chưa xác minh mọi call site dùng `Math.random`/Lua `math.random`.
- Chưa xác minh API worker/file write trên từng build target.
- Chưa chốt giới hạn FPS/resolution an toàn.
- Chưa xác minh việc app vào nền có thực sự giữ được loop/`onRender` hay không (phụ thuộc SDL, ROM, thiết bị).
- Chưa xác minh `Sys.putEnv` có tác dụng với hint SDL tại thời điểm pause.
- Chưa xác minh `GL.readPixels`, thứ tự priority của `window.onRender` và listener `ENTER_FRAME` trên thiết bị thật.
- Chưa chọn và kiểm chứng `foregroundServiceType` phù hợp cho Android 14+.
- Chưa có Java service, manifest template hay JNI bridge; toàn bộ mới ở mức thiết kế.

---

## 12. Tài liệu tham khảo kỹ thuật

### Source trong repository

- `Project.xml`
- `AGENTS.md`
- `setup/unix.sh`
- `source/Main.hx`
- `source/backend/MusicBeatState.hx`
- `source/backend/Conductor.hx`
- `source/backend/Controls.hx`
- `source/backend/ClientPrefs.hx`
- `source/mobile/backend/StorageUtil.hx`
- `source/mobile/input/MobileInputManager.hx`
- `source/mobile/objects/TouchButton.hx`
- `source/mobile/objects/Hitbox.hx`
- `source/mobile/objects/TouchPad.hx`
- `source/mobile/backend/TouchUtil.hx`
- `source/states/PlayState.hx`
- `source/states/FreeplayState.hx`
- `source/states/StoryMenuState.hx`
- `source/psychlua/FunkinLua.hx`
- `source/psychlua/StateScriptManager.hx`
- `source/backend/ui/PsychUIButton.hx`
- `source/backend/ui/PsychUICheckBox.hx`
- `source/backend/ui/PsychUISlider.hx`

### Thư viện local đã xem

- HaxeFlixel: `/root/haxelib/flixel/git/flixel/FlxGame.hx`
- HaxeFlixel: `/root/haxelib/flixel/git/flixel/FlxCamera.hx`
- HaxeFlixel: `/root/haxelib/flixel/git/flixel/math/FlxRandom.hx`
- HaxeFlixel: `/root/haxelib/flixel/git/flixel/FlxGame.hx` (`onEnterFrame`, `_total`, `_accumulator`, `updateElapsed`)
- OpenFL: `/root/haxelib/openfl/git/src/openfl/display/Stage.hx` (`__onLimeRender`)
- Lime: `/root/haxelib/lime/git/project/lib/sdl/include/SDL_hints.h` (`SDL_HINT_ANDROID_BLOCK_ON_PAUSE`)
- Lime template: `/root/haxelib/lime/git/templates/android/template/app/src/main/` (`AndroidManifest.xml`, `java/org/haxe/lime/GameActivity.java`)
- Repo: `source/mobile/backend/PsychJNI.hx` (mẫu gọi JNI), `source/objects/LoadingOverlay.hx`
- OpenFL: `/root/haxelib/openfl/git/src/openfl/display/BitmapData.hx`
- OpenFL: `/root/haxelib/openfl/git/src/openfl/display/PNGEncoderOptions.hx`

### Tài liệu chính thức để đối chiếu API

- HaxeFlixel timestep: https://dev.haxeflixel.com/documentation/troubleshooting/#timestep
- Android foreground services: https://developer.android.com/develop/background-work/services/foreground-services
- Android notifications: https://developer.android.com/develop/ui/views/notifications
- SDL hint `SDL_HINT_ANDROID_BLOCK_ON_PAUSE`: https://wiki.libsdl.org/SDL2/SDL_HINT_ANDROID_BLOCK_ON_PAUSE
- HaxeFlixel FlxCamera API: https://api.haxeflixel.com/flixel/FlxCamera.html
- OpenFL BitmapData API: https://api.openfl.org/openfl/display/BitmapData.html
- OpenFL compressing bitmap data / PNGEncoderOptions: https://books.openfl.org/openfl-developers-guide/working-with-bitmaps/compressing-bitmap-data.html
- Haxe threading: https://haxe.org/manual/std-threading.html

Tài liệu web chỉ là tài liệu đối chiếu. Khi triển khai phải ưu tiên API của đúng fork/version được build thực tế trong repository.

---

## 13. Trạng thái repository sau nghiên cứu

- Đã đọc các source integration point được liệt kê trong báo cáo và thư viện local liên quan.
- Chỉ tạo báo cáo Markdown này.
- Không chỉnh sửa source hoặc assets.
- Không chạy build.
- Không commit/push và không chạy GitHub Actions.
- Hai file backup untracked đã tồn tại trước phiên nghiên cứu, được giữ nguyên:
  - `source/psychlua/FunkinLua.hx.bak_before_funkin_api`
  - `source/psychlua/ShaderFunctions.hx.bak_before_filterfix`

**Kết luận cuối:** bắt đầu bằng Recorder + replay/verifier trước.**Cập nhật revision 2:** file plan này là thay đổi duy nhất trong repo ở thời điểm cập nhật; chưa có code Haxe/Java nào được viết, chưa build, chưa commit.

**Kết luận cuối:** bắt đầu bằng Recorder + replay/verifier trước. Chỉ sau khi replay gameplay tái lập ổn định mới phát triển Offline Rendering. Đây là thứ tự giảm rủi ro nhất và tránh xây một bộ xuất PNG nhanh nhưng kết quả gameplay không thể tái tạo.


---

## 14. Quy trình typecheck local (revision 2)

**[đã xác minh trên thiết bị]** Dù không build APK được local, có thể typecheck toàn dự án:

1. `cd /sdcard/Download/FNF/PsychEngine-Custom && haxelib run lime display android -arm64 > /tmp/disp_android.txt`
2. Tạo `/tmp/check.hxml`: lấy toàn bộ args, bỏ dòng `-D no-compilation`, đổi dòng `-cpp ...` thành `-cpp /tmp/cppout`, thêm `--no-output` ở cuối. (Cần target cpp vì `linc_luajit` dùng `cpp.RawPointer`; target `cross` sẽ lỗi.)
3. `haxe /tmp/check.hxml` — baseline trước khi sửa: **EXIT 0, khoảng 36 giây**.
4. Class mới không được `PlayState`/`Main` tham chiếu sẽ không bị typecheck; thêm `--macro include('backend.recording')` và `--macro include('backend.rendering')` vào hxml khi kiểm tra.
5. Không chạy `pkill -f` với pattern trùng chính lệnh shell đang chạy (sẽ tự kill shell). Không có lệnh `time` trong shell này.

Typecheck chỉ kiểm tra Haxe; không kiểm tra Java, manifest, hành vi runtime hay Android.


---

# Revision 3 — Render Studio navigation, isolated sessions, and silent offline rendering

## UI navigation contract

Render Studio opens as a dedicated `MusicBeatState`, visually following the Freeplay-style selection pattern. It exposes two workspaces:

1. **Rendering Mode**
   - Open Settings → dedicated Render Settings state, using Render Studio settings only; must not mutate `ClientPrefs`.
   - Enter Render → song selection, then create a new independent render session for the selected song.
2. **Gameplay Recorder**
   - Open Settings → normal `OptionsState`.
   - Enter Gameplay → dedicated Gameplay Recorder state.

Render Settings:
- **Quality Output**
  - Resolution selector:
    - Normal Mode: 1280×720
    - Mobile Mode: 1600×720
- **Gameplay**
  - Use Gameplay file: checkbox
  - Show FPS: checkbox; description: “Enable this to show FPS and OS version in the rendered output.”

Settings are defaults for newly created render sessions. A session snapshots its effective values when created. Do not use `ClientPrefs.data` as storage for these Render Studio options.

## Per-song render isolation

Every selected song gets its own `RenderSession` instance. No shared mutable timeline cursor, frame index, output queue, frame buffer, replay source, or render progress may leak between songs. Each session owns:
- Song/chart identity and resolved chart data
- Its own render-settings snapshot
- Optional gameplay-recording file reference
- Timeline/frame cursor and total frame count
- Output directory, scoped to the song/session
- Render progress and cancellation state

Do not identify a session only by display title if duplicate song names can exist across mods/difficulties. Use a stable song/mod/difficulty identity and collision-safe output folder.

## Offline render timing contract

Rendering Mode does not play music. It uses a silent offline timeline:
1. Resolve the selected song/chart and timing metadata.
2. Calculate the exact timeline position for the next output frame from the configured output FPS.
3. Advance gameplay simulation to that timestamp using deterministic/fixed stepping, including notes, characters, animations, camera, events, Lua/HScript hooks, and applicable visual effects.
4. Capture and encode the completed frame.
5. Only after the frame has been captured/queued safely, advance to the next output frame.
6. Finish after the final timeline frame has been exported.

Audio playback and audio-clock synchronization are disabled for this mode. The song's chart/timing data remains the source of musical time. Do not skip frames to catch up with wall-clock time. If encoding or storage is slower, apply backpressure and wait; never silently drop an offline frame.

The simulation must still process all required gameplay updates even though no sound is emitted. Audio-dependent scripts/effects need a documented compatibility policy rather than being allowed to reintroduce audio playback.

## Current Haxe UI prototype status (Revision 3)

Added:
- `source/states/RenderState.hx` — two-workspace entry screen
- `source/states/RenderWorkspaceState.hx` — Open Settings / Enter Render or Enter Gameplay
- `source/states/RenderSettingsState.hx` — isolated Render Settings controls
- `source/states/RenderStudioSettings.hx` — independent settings values
- `source/states/RenderSession.hx` — per-song session data model with audio disabled by default
- `source/states/RenderSongSelectState.hx` — placeholder entry point for song selection
- `source/states/GameplayRecorderState.hx` — placeholder recorder entry point

Important: these files are UI/data scaffolding, not a completed renderer. Song selection is not yet connected to Freeplay's real song catalog; the per-song session model is not yet wired to gameplay simulation, frame capture, PNG encoding, or a render queue. The offline stepping contract above still requires source-level integration and runtime prototype. No claim of completed offline rendering should be made until each of those systems is verified.


## Revision 4 — FPS/resolution controls and first song-session wiring

- Render Settings now exposes four output presets: 1280×720, 1920×1080, 2560×1440, and 1600×720 Mobile.
- Added output FPS choices: 24, 30, 60, and 120.
- FPS and resolution are stored in RenderStudioSettings and copied into each RenderSession; ClientPrefs remains untouched.
- RenderSession now carries frameRate and computes the nominal frame duration in microseconds.
- RenderSongSelectState now collects song entries from loaded WeekData, preserves the owning mod directory, loads the selected chart using the same Highscore.formatSong/Song.loadFromJson path as Freeplay, assigns PlayState.SONG, and creates a fresh RenderSession for that song.
- Session creation displays chart section count, output dimensions, FPS, and the per-song output directory. Audio remains disabled by default.
- This is the first real data/session wiring only. It does not yet launch a render-specific PlayState, advance deterministic simulation, capture frames, encode PNG/video, or write files.
- A local Android build/typecheck was started with haxelib run lime test android; final result is pending and must be reported separately.
- No Git commit/push and no GitHub Actions were used.


## Revision 5 — exact frame clock foundation and engine timing audit

Implemented in `source/states/RenderSession.hx`:
- Added exact per-frame timestamp calculation from the frame index and configured FPS. Timestamps are calculated from the absolute frame index rather than repeatedly adding a rounded frame duration, avoiding cumulative drift at 24/30 FPS.
- Added adjacent-timestamp frame duration calculation, duration-to-total-frame configuration, one-frame advancement, completion checks, progress reporting, and reset behavior.
- Kept the clock independent of audio playback and global Conductor state. It is a session-level clock primitive only; it is not yet connected to PlayState.

Validation:
- A standalone Haxe interpreter test passed for 24 FPS / 1 second: 24 frames, expected fractional-microsecond timestamps, no overrun, progress=1, and reset.
- An attempted standalone compile against the full project source classpath was not a valid project typecheck because it omitted Lime/OpenFL/HaxeFlixel build defines and dependencies. Do not treat that failed attempt as a source regression or as a successful project compile.
- The earlier Android build process was still compiling hxcpp C++ translation units during this revision. It started before this RenderSession change, so it cannot validate the new Haxe source.

Engine timing audit:
- `MusicBeatState.update(elapsed)` derives step/beat/section callbacks from global `Conductor.songPosition`, updates stages, then runs the Flixel state update.
- `PlayState.update(elapsed)` advances Conductor by elapsed time, but after the song begins it also corrects against `FlxG.sound.music.time`; this audio-clock correction must be bypassed in a true offline render mode.
- `PlayState.startSong()` starts instrumental and vocal playback and starts a song-sync thread. A render-specific branch must prevent all of these audio-clock behaviors, not merely set volume to zero.
- HaxeFlixel exposes `FlxG.signals.postDraw`, per-camera `FlxCamera.buffer`, and update/draw framerate controls. These are potential integration points, but capture of the final composite (game + HUD + overlays), exact frame pacing, encoder backpressure, and Android output storage have not yet been implemented or verified.
- Do not manually call `PlayState.update()` outside the normal FlxGame loop as a shortcut. That would risk desynchronizing Flixel timers/tweens, stage updates, script callbacks, camera rendering, and draw timing.

Current status remains: frame-clock foundation implemented and unit-tested; render-specific PlayState, silent timeline integration, composite frame capture, PNG/video encoding, queue/backpressure, and Gameplay Recorder remain unfinished.

- Added `source/states/RenderFrameExporter.hx`: writes a full-stage snapshot to `frame_000000.png` style files in the session output directory. It scales the OpenFL stage to the session output dimensions, encodes PNG with fast compression, creates the output directory tree, and disposes its temporary BitmapData.
- The exporter is deliberately synchronous. When invoked from `FlxG.signals.postDraw`, the caller cannot advance to the next frame until encoding and storage finish, providing simple backpressure with no dropped requested frame. This is a PNG image-sequence writer, not a video encoder.
- Full project Haxe typecheck passed with Android Lime display flags and explicit inclusion of `states.RenderSession` and `states.RenderFrameExporter` (exit code 0, 56.98 seconds).
- Runtime capture has not yet been tested. The exporter must be called from `FlxG.signals.postDraw`; no PlayState integration currently registers that callback or advances the session clock.


## Revision 6 — PlayState render-mode integration

Implemented:
- `RenderSongSelectState` now launches a `PlayState` after loading the selected chart and creating its session. BACK clears the active session before leaving the selector.
- `PlayState.create()` detects an active RenderSession, snapshots the current mute/framerate/accumulator settings, mutes audio, applies the selected update/draw frame rate, caps Flixel's fixed-timestep accumulator to one simulation step, and registers render pre-update/post-draw callbacks.
- `onRenderPreUpdate()` marks that a fresh simulation step is ready and sets Conductor to the session's current timestamp. Flixel's fixed-timestep mode supplies the exact elapsed value to sounds, plugins, state objects, and cameras.
- Capping `FlxGame._maxAccumulation` to one `_stepMS` means at most one simulation step can occur before a draw. The post-draw callback exports only when the pre-update callback marked a fresh step, preventing duplicate captures on draw-only enter-frames. A slow PNG write blocks before the next frame can be processed.
- Render-mode `startCountdown()` still creates receptors and invokes countdown-start script callbacks, but skips the timed countdown and countdown sounds.
- Render-mode `startSong()` does not start instrumental/vocal playback and does not start the song-sync thread. It derives duration from the instrumental length, with a chart-note fallback, configures the session frame count, and invokes stage/script song-start callbacks.
- The normal PlayState audio-clock correction is bypassed while a RenderSession exists.
- `postDraw` exports the just-drawn stage as a PNG, then advances the session to the next exact timestamp. Completion or capture failure stops further simulation and displays a status line. ESC returns to the render song selector.
- Original mute state, update/draw framerates, and Flixel's previous maximum accumulator are restored when PlayState is destroyed.
- RenderSession now tracks completion/failure state and advances its cursor only after a frame has been exported.

Validation:
- Updated standalone Haxe interpreter test passed for 24 FPS / 1 second: 24 sequential frame advances, exact timestamps, completion state, progress=1, and reset.
- Full project Haxe typecheck was run with Android Lime defines and explicit inclusion of PlayState, RenderSongSelectState, RenderSession, and RenderFrameExporter. See final validation result below.
- `git diff --check` passed at the time of this revision.

Limitations / not yet verified:
- PNG capture from the live OpenFL stage and output directory permissions have not been tested on an actual Android gameplay session.
- This produces a PNG image sequence only; no video container/codec encoder exists yet.
- The `Use Gameplay file` setting is not yet connected to a recorder/replay input stream.
- Script-driven sound is globally muted during rendering; no audio track is exported.
- The old Android build process began before these PlayState changes and cannot validate this revision. Do not treat its result as validation for this code.


Final Revision 6 validation update:
- Full project Haxe typecheck passed after the final one-step accumulator implementation, using Android Lime defines and explicit inclusion of PlayState, RenderSongSelectState, RenderSession, and RenderFrameExporter (exit code 0; 96.88 seconds).
- Standalone RenderSession frame-stepping test passed after the cursor semantics change.
- The old Android C++ build is still running and was started before Revision 6 source changes; its output is not a valid build result for this revision.


## Revision 7 — JS Engine framebuffer capture port and PNG output

Implemented:
- Replaced the OpenFL `FlxG.stage` redraw/BitmapData capture with the JS Engine-style final framebuffer path: `Application.current.window.readPixels(FlxG.scaleMode.offset + gameSize)` after Flixel's `postDraw` signal. This captures the composed game viewport after camera rendering, including gameplay cameras, HUD, and rendered overlays.
- PNG encoding now uses `lime.graphics.Image.encode()` and the captured frame is resized to the selected Render Studio output resolution before synchronous file writing.
- Android output is now rooted at `/sdcard/.PsychEngine/output/<song-id>/`; desktop output is rooted at `.PsychEngine/output/<song-id>/` under the working directory.
- Each session writes `output-info.txt` with song/mod, resolution, FPS, planned and exported frame counts, source duration, gameplay-file toggle, FPS/OS overlay toggle, PNG naming pattern, and render status.
- The Show FPS setting now controls `Main.fpsVar` during rendering, so the existing FPS + OS-version display is included in the captured output. Its previous visibility is restored when leaving PlayState.
- Render metadata is updated to `completed` after the final PNG, or `failed` when capture/export fails.

Validation:
- `git diff --check` passed after the framebuffer exporter and output-path changes.
- A full Android-define Haxe typecheck is running against the updated source; record its final exit status after completion.
- JS Engine reference used: `Application.current.window.readPixels(...)` followed by pixel-buffer encoding; this project keeps PNG sequence output rather than importing the FFmpeg video pipe.

Not yet runtime-verified:
- Android `Window.readPixels()` framebuffer orientation/content, 4K/HD scaling, and storage permissions still require a live gameplay test on the device.
- No Android APK build has been started for Revision 7 because the pre-existing Android C++ build (started before Revision 6) is still active. That old build cannot validate these changes.
- `Use Gameplay file` remains a recorded setting only; Gameplay Recorder/replay input is outside this renderer port.
- No video file or audio track is produced; the output remains a silent PNG sequence.


Revision 7 final validation:
- `haxe /tmp/check-render.hxml` passed after the final framebuffer capture, output metadata, and FPS/OS overlay changes (exit code 0; 40.68 seconds).
- `git diff --check` passed.
- `source.zip` was refreshed in the repository root (606 KB).
- The pre-existing Android build process (PID 25719) remains active and predates Revision 6; no APK/build success is claimed for Revision 7.
