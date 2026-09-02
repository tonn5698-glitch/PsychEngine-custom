# Project.md — Psych Engine Custom Loading System

> Tài liệu này là specification kỹ thuật, dùng làm context/instruction cho AI coding agent trong suốt quá trình phát triển. Mọi thông tin trong mục **"Current Architecture" / "LoadingState flow hiện tại"** đều được trích trực tiếp từ source thật đã đọc, không suy đoán. Các phần **chưa xác minh được** (do chưa có đủ file) được đánh dấu rõ `[CẦN XÁC MINH]`.

---

## 1. Project Overview

Custom fork của Psych Engine (bản mobile) với 2 mục tiêu kỹ thuật duy nhất:

1. **Custom Mod Loading Screen**: cho phép mỗi Mod tự định nghĩa giao diện Loading Screen riêng (không sửa source engine).
2. **Real Loading Gate**: sửa Loading System để engine chỉ `switchState` sang `PlayState` sau khi **toàn bộ required assets của bài hát hiện tại** đã thực sự nằm trong cache (không chỉ dựa vào counter dễ bị race).

Không rewrite engine. Không thêm tính năng ngoài 2 mục tiêu trên.

---

## 2. Base / Version

- Base repo đã clone vào project: `kittycathy233/FNF-PsychEngine-Mobile-1.0.4-Archive` (fork lưu bản ổn định cuối của "Psych Engine Mobile", generated from `kittycathy114/FNF-KathyEngine`).
- **Lưu ý discrepancy**: yêu cầu ban đầu ghi "Psych Engine Android 1.0.1", nhưng repo thực tế đã clone vào thư mục project là bản **1.0.4**. Spec này dựa hoàn toàn trên source 1.0.4 đã đọc thực tế — không dùng giả định từ bản 1.0.1 hay bất kỳ Android port nào khác.
- Compile flags xác nhận có tồn tại trong source: `HSCRIPT_ALLOWED`, `MODS_ALLOWED`, `MULTITHREADED_LOADING`, `SHOW_LOADING_SCREEN`, `PSYCH_WATERMARKS`, `ACHIEVEMENTS_ALLOWED`, `TRANSLATIONS_ALLOWED`, `flxanimate`, `DISCORD_ALLOWED`.

---

## 3. Project Path

- Local (thiết bị người dùng): `/mnt/sdcard/Download/PsychEngine-Custôm` (còn gọi là `PsychEngine-Custom`).
- Source đã phân tích cho spec này (upload):
  - `source/states/LoadingState.hx` — full file (829 dòng)
  - `source/backend/Paths.hx` — full file (665 dòng)
  - `source/backend/Mods.hx` — full file (240 dòng)
  - `source/states/PlayState.hx` — **chỉ excerpt** (dòng 1265–1366 / tổng 3847 dòng), phần `startSong()` + `generateSong()`
- **Xác nhận không tồn tại trong repo** (do user xác nhận): `source/states/TransitionSubState.hx`, `source/backend/ModsFolder.hx` / `Mods.hx` dạng khác. → Không có class transition riêng; chuyển state dùng thẳng `MusicBeatState.switchState()`.

---

## 4. Current Architecture (sau khi phân tích source)

Các thành phần liên quan trực tiếp tới loading:

| Component | File | Vai trò xác nhận từ source |
|---|---|---|
| `LoadingState` | `source/states/LoadingState.hx` | State hiển thị progress bar, quản lý toàn bộ vòng đời preload (thread pool, danh sách asset cần load, HScript hook cho mod). |
| `Paths` | `source/backend/Paths.hx` | Resolve đường dẫn asset (mod-first), cache `FlxGraphic` (`currentTrackedAssets`) và `Sound` (`currentTrackedSounds`), cung cấp load đồng bộ on-demand nếu asset chưa có trong cache. |
| `Mods` | `source/backend/Mods.hx` | Quản lý danh sách mod bật/tắt (`modsList.txt`), `currentModDirectory` (mod đang active), `getGlobalMods()` (mod chạy global). Không có class `ModsFolder`. |
| `PlayState` (excerpt) | `source/states/PlayState.hx` | `generateSong()` gọi `Paths.inst()` / `Paths.voices()` **trực tiếp, đồng bộ**, không kiểm tra asset đã được `LoadingState` preload hay chưa. |

Không có class `TransitionSubState` trong source — mọi transition dùng `MusicBeatState.switchState(target)` gọi thẳng từ `LoadingState.onLoad()` hoặc `getNextState()`.

---

## 5. LoadingState Flow hiện tại

### 5.1 Entry point
```haxe
LoadingState.loadAndSwitchState(target, stopMusic=false, intrusive=true)
  -> MusicBeatState.switchState(getNextState(target, stopMusic, intrusive))
```

### 5.2 `getNextState()`
- Nếu compile flag `!SHOW_LOADING_SCREEN` → ép `intrusive = false`.
- `_startPool()` khởi tạo `FixedThreadPool(threadCount)`.
- `loadNextDirectory()` set `Paths.currentLevel` theo `StageData.forceNextDirectory`.
- **Nếu `intrusive == true`**: trả về `new LoadingState(target, stopMusic)` — có màn hình loading bar.
- **Nếu `intrusive == false`**: **block thread gọi hàm này** bằng vòng lặp:
  ```haxe
  while(true) {
      if (checkLoaded()) { _loaded(); break; }
      else Sys.sleep(0.001);
  }
  return target;
  ```
  → Đây là busy-wait đồng bộ, không có UI, không có timeout.

### 5.3 `prepareToSong()` (xây danh sách required asset cho bài hát hiện tại)
Chạy qua chuỗi `lime.app.Future` (async phụ thuộc biến `isIntrusive`):
1. Future 1: build `imagesToPrepare` (note skin, splash skin) + đọc `data/preload.json` của bài hát/mod.
2. `.then()` → Future 2: đọc `stageData.preload` + object trong stage, push `Inst` vào `songsToPrepare`, gọi `preloadCharacter(player1, ...)` **đồng bộ**, còn `player2`/`gfVersion` (nếu khác `player1`) được preload **trên thread riêng** qua `threadPool.run()`, mỗi thread xong gọi `completedThread()`.
3. `completedThread()`: `threadsCompleted++` (không mutex) → khi `threadsCompleted == threadsMax` thì gọi `clearInvalids()` → `startThreads()` → `initialThreadCompleted = true`.

### 5.4 `startThreads()` / `_threadFunc()`
- `loadMax = imagesToPrepare.length + soundsToPrepare.length + musicToPrepare.length + songsToPrepare.length`, `loaded = 0`.
- Mỗi asset được giao cho `threadPool.run()` riêng qua `initThread()`.
- Trong `initThread()`, sau khi load xong: `loaded++` — **dòng mutex bị comment sẵn trong source** (`// mutex.acquire(); loaded++; // mutex.release();`).

### 5.5 `update()` (mỗi frame khi LoadingState đang hiển thị)
- Gọi `checkLoaded()`.
- Nếu `true` và `stateChangeDelay <= 0` → gọi `onLoad()` → `_loaded()` reset static state → `MusicBeatState.switchState(target)`.

### 5.6 `checkLoaded()`
```haxe
for key => bitmap in requestedBitmaps:
    Paths.cacheBitmap(originalBitmapKeys[key], bitmap)   // cache GPU texture, chạy trên main thread
return (loaded >= loadMax && initialThreadCompleted)
```

### 5.7 Custom Mod Loading Screen — **đã tồn tại một phần**
Trong `create()`, nếu `HSCRIPT_ALLOWED` và `Mods.currentModDirectory` không rỗng:
```haxe
mods/<ModDir>/data/LoadingScreen.hx
```
Nếu file tồn tại → khởi tạo `HScript`, expose `getLoaded`, `getLoadMax`, `barBack`, `bar` cho script, gọi `onCreate()`. Nếu tồn tại `onUpdate`/`onDestroy` thì các hàm mặc định (Psych/base loading UI) **bị bỏ qua hoàn toàn**, hscript tự vẽ UI. Nếu file không tồn tại hoặc không có `onCreate` → fallback về UI mặc định (`PSYCH_WATERMARKS` hoặc base UI).

→ **Đây chính là cơ chế hook có sẵn cho Mục tiêu 1**, chưa có lớp cấu hình khai báo (JSON) — chỉ có full-script override.

---

## 6. Nguyên nhân black screen (đã xác định từ source)

### ✅ CONFIRMED — có bằng chứng trực tiếp trong source

1. **Race condition trên counter `loaded`** (`LoadingState.hx`, `initThread()`): `loaded++` chạy từ nhiều `sys.thread.Thread` (qua `FixedThreadPool`) đồng thời, không có khóa (dòng mutex bị comment sẵn). Read-modify-write không atomic trên các thread native → có thể **mất increment**. Hệ quả: `loaded` không bao giờ đạt `loadMax` → `checkLoaded()` không bao giờ `true` → loading **treo vĩnh viễn**.
2. **Race tương tự trên `threadsCompleted`** trong `prepareToSong()`: nếu cả `player2` và `gfVersion` cần preload riêng (2 thread song song gọi `completedThread()` cùng lúc), `threadsCompleted++` không khóa → có thể không bao giờ bằng `threadsMax` → `startThreads()` không bao giờ được gọi → `loadMax` mãi mãi = 0, `initialThreadCompleted` mãi mãi `false`.
3. **Non-intrusive path block main thread vô thời hạn**: khi `intrusive == false`, `getNextState()` block chính thread gọi nó bằng `while(true) { ...; Sys.sleep(0.001); }`, không timeout. Nếu (1) hoặc (2) xảy ra trong lúc này, thread gọi (nếu là main/render thread) bị treo vĩnh viễn → trên Android: surface ngừng swap buffer → biểu hiện y hệt "black screen"/ANR.
4. **Không có gate xác thực thực tế** — `checkLoaded()` chỉ so sánh **số lượng** (`loaded >= loadMax`), không verify từng required asset đã thực sự có trong `Paths.currentTrackedAssets` / `Paths.currentTrackedSounds`. Một counter đúng số nhưng sai nội dung (ví dụ do lỗi thread) vẫn được coi là "loaded".
5. **`PlayState.generateSong()` không phụ thuộc vào kết quả LoadingState**: gọi thẳng `Paths.inst(songData.song)` và `Paths.voices(...)` bất kể asset đã được preload hay chưa. Nếu chưa có trong cache, `Paths.returnSound()`/`Paths.image()` sẽ tự load đồng bộ **trên main thread ngay trong lúc tạo PlayState** — gây block/hitch đúng vào thời điểm chuyển màn hình, đặc biệt nặng với file OGG lớn.

### ⚠️ CẦN XÁC MINH — chưa đủ source để khẳng định

- Call site thực tế gọi `LoadingState.loadAndSwitchState(...)` để vào `PlayState` (ví dụ từ `FreeplayState.hx`, `StoryMenuState.hx`, hoặc trong chính `PlayState`) — **không có trong source đã cung cấp**. Cần xác minh: gọi với `intrusive = true` hay `false`? `prepareToSong()` có được gọi **trước** `loadAndSwitchState()` hay không, và độ trễ giữa 2 lệnh gọi là bao nhiêu?
  - Rủi ro nếu chưa xác minh: giá trị mặc định class-level của `initialThreadCompleted` là `true` (chỉ bị set `false` bên trong `prepareToSong()`). Nếu `LoadingState` được tạo trước khi `prepareToSong()` kịp set `false`, `checkLoaded()` ở `create()` có thể trả `true` ngay lập tức (loadMax=0, initialThreadCompleted=true mặc định) → chuyển state với 0 asset được preload → toàn bộ asset fallback về load đồng bộ trong `PlayState`.
- AI agent **phải đọc phần còn lại của `PlayState.hx` (constructor/`create()`) và call site trước khi implement**, không được giả định thứ tự gọi.

---

## 7. Loading Flow mới (Target Architecture)

Nguyên tắc: **sửa tại chỗ (in-place fix)**, giữ nguyên toàn bộ tên class/hàm public hiện có, không đổi kiến trúc tổng thể.

```
prepareToSong()
  → build required-asset manifest (giữ nguyên logic hiện tại: note skin, splash, Inst,
     Voices, character images/vocals, stage preload list)
  → [MỚI] snapshot manifest thành Array<String> bất biến (requiredAssetManifest)
     TRƯỚC khi set loadMax, dùng để verify ở bước cuối
startThreads()
  → loadMax/loaded như cũ, NHƯNG loaded++ và threadsCompleted++ được bọc mutex.acquire()/release()
     (Mutex đã có sẵn trong class, chỉ cần bỏ comment + áp dụng đúng chỗ, không thêm primitive mới)
checkLoaded()
  → giữ cacheBitmap loop như cũ
  → giữ so sánh loaded >= loadMax && initialThreadCompleted
  → [MỚI] thêm verifyManifestLoaded(): kiểm tra từng key trong requiredAssetManifest
     thực sự có trong Paths.currentTrackedAssets / Paths.currentTrackedSounds
  → chỉ return true khi CẢ HAI điều kiện đúng
onLoad() / switchState()
  → không đổi, chỉ chạy khi checkLoaded() (đã fix) == true
```

Không thêm hệ thống loading song song mới, không thêm cache mới — chỉ vá race condition + thêm bước verify.

---

## 8. Required Asset Preloading

- Phạm vi bắt buộc: **chỉ asset của bài hát hiện tại** — đúng theo `prepareToSong()` hiện có:
  - Note skin (`Note.defaultNoteSkin` hoặc `SONG.arrowSkin`)
  - Note splash skin (`NoteSplash.defaultNoteSplash` hoặc `SONG.splashSkin`)
  - `data/preload.json` của bài hát (mod-aware qua `Paths.modsJson`)
  - Stage: `stageData.preload` + object hình ảnh trong `stageData.objects`
  - Nhạc nền: `$folder/Inst`
  - Giọng hát: `Voices` theo `needsVoices`, ưu tiên `-Player`/`-Opponent` nếu tồn tại
  - Nhân vật (`player1`, `player2`, `gfVersion`): ảnh (`character.image`, hỗ trợ cả sprite sheet thường và `flxanimate`/Animation.json) + vocal file riêng nếu có `character.vocals_file`
- **Nghiêm cấm**: preload toàn bộ thư mục mod vào RAM. Không mở rộng danh sách này ra ngoài phạm vi 1 bài hát.
- `clearInvalids()` (lọc key không tồn tại trước khi tạo thread) **giữ nguyên**, không đổi logic.

---

## 9. Asset Cache

- Dùng nguyên hệ thống cache đã có trong `Paths.hx`, không tạo cache song song:
  - `Paths.currentTrackedAssets: Map<String, FlxGraphic>` — ảnh đã cache (GPU texture nếu `ClientPrefs.data.cacheOnGPU`).
  - `Paths.currentTrackedSounds: Map<String, Sound>` — âm thanh đã cache.
  - `Paths.localTrackedAssets: Array<String>` — asset "đang dùng" ở state hiện tại, dùng cho `clearUnusedMemory()`/`clearStoredMemory()`.
- Bước verify mới ở mục 7 chỉ **đọc** 2 map trên bằng key đã build sẵn trong `requiredAssetManifest`, không ghi thêm gì vào chúng.
- Format key phải khớp chính xác cách các hàm `image()`/`returnSound()` build key (bao gồm `Language.getFileTranslation`, extension `.png`/`.$SOUND_EXT`) — nếu build sai format, verify sẽ luôn fail dù asset đã load. AI agent phải tái dùng logic build key có sẵn (gọi lại đúng hàm, không tự viết lại chuỗi path).

---

## 10. Real Loading Progress

- Nguồn dữ liệu cho progress bar: `LoadingState.loaded` / `LoadingState.loadMax` — **giữ nguyên interface**, HScript hook (`getLoaded`, `getLoadMax`) vẫn hoạt động không đổi.
- Vấn đề hiện tại: `loadMax` chỉ được set thật (khác 0) sau khi Future chain ở `prepareToSong()` chạy xong — có độ trễ không xác định nếu `isIntrusive == true` (Future async). Trong khoảng trễ này, progress bar hiển thị `0/0` hoặc giá trị cũ.
- Đề xuất: build xong `requiredAssetManifest` (mục 7) **trước** khi construct `LoadingState`, để `loadMax` có giá trị đúng ngay từ frame đầu tiên. Việc build manifest chỉ là đọc JSON + tính path (I/O nhẹ), không phải load asset thật, nên có thể chạy đồng bộ mà không ảnh hưởng frame rate.

---

## 11. Custom Mod Loading Screen (Mục tiêu 1)

### Cơ chế hiện có (giữ nguyên, không sửa)
`mods/<ModDir>/data/LoadingScreen.hx` chạy qua `HScript` (chỉ khi `HSCRIPT_ALLOWED`), với các hook: `onCreate()` (bắt buộc để kích hoạt), `onUpdate(elapsed)`, `onDestroy()`. Script được cấp: `getLoaded()`, `getLoadMax()`, `barBack` (FlxSprite nền thanh bar), `bar` (FlxSprite thanh bar). Đây là **full override** — khi kích hoạt, toàn bộ UI mặc định (Psych watermark hoặc base UI) bị bỏ qua.

### Mở rộng đề xuất (bổ sung, không phá cơ chế cũ)
Thêm lớp cấu hình khai báo, dùng cho mod không muốn viết HScript:
```
mods/<ModDir>/data/loadingScreen.json
```
- Nếu file này tồn tại **và** không có `LoadingScreen.hx` hợp lệ → dùng UI mặc định của engine nhưng thay các asset con (background, logo, màu bar, font) theo config, KHÔNG thay đổi logic tính progress/threading.
- Nếu cả `LoadingScreen.hx` và `loadingScreen.json` cùng tồn tại → `LoadingScreen.hx` ưu tiên (full override thắng config đơn giản), giữ đúng thứ tự ưu tiên tự nhiên của engine (script > config > default).
- Không bắt buộc mod phải có 1 trong 2 file — mặc định vẫn dùng UI gốc như hiện tại.

---

## 12. Loading Screen Configuration

Schema đề xuất cho `loadingScreen.json` (đọc qua `Paths.modsJson`/`File.getContent`, resolve theo đúng thứ tự mod hiện có trong `Mods.hx`/`Paths.modFolders`, không tạo cơ chế resolve path mới):

```json
{
  "background": "loading_bg",       // key ảnh, resolve qua Paths.image() như bình thường
  "barColor": "#FFFFFF",
  "barBackgroundColor": "#000000",
  "text": "Loading...",
  "logo": null                       // optional, key ảnh hoặc null để ẩn
}
```
- Toàn bộ key ảnh trong config phải đi qua `Paths.image()`/`Paths.getPath()` hiện có (mod-first resolution) — không tự đọc file trực tiếp.
- Field không có trong JSON → dùng giá trị mặc định của engine (không bắt buộc mod khai báo đủ toàn bộ field).

---

## 13. Fallback Behavior

| Tình huống | Fallback |
|---|---|
| Không có `LoadingScreen.hx` và không có `loadingScreen.json` | Dùng UI mặc định (`PSYCH_WATERMARKS` hoặc base UI) — **hành vi hiện tại, giữ nguyên**. |
| `LoadingScreen.hx` tồn tại nhưng lỗi cú pháp / throw khi parse | Bắt bằng `catch(e:IrisError)` **đã có sẵn** trong `create()` → log qua `Iris.error()`, `hscript = null`, rơi về UI mặc định. Không crash. |
| `loadingScreen.json` tồn tại nhưng field ảnh không tìm thấy file | Dùng asset mặc định tương ứng của engine (không throw, không để trống). |
| Required asset (trong `requiredAssetManifest`) không tồn tại trên đĩa | Giữ hành vi hiện có của `preloadSound`/`preloadGraphic`: trace lỗi + `FlxG.log.error(...)`, sound fallback về `flixel/sounds/beep`; ảnh fallback: **cần xác định rõ hành vi mong muốn** — hiện tại `preloadGraphic` chỉ `trace` và trả `null`, không có placeholder ảnh. AI agent cần bổ sung placeholder ảnh mặc định tương tự cách âm thanh đã làm, KHÔNG để `null` đi vào `verifyManifestLoaded()` gây treo loading vĩnh viễn. |

---

## 14. Error Handling

- Không tạo hệ thống exception mới. Tái dùng đúng convention hiện có trong source:
  - `trace(...)` cho log debug.
  - `FlxG.log.error(...)` cho lỗi hiển thị trong Flixel log.
  - `catch(e:IrisError)` + `Iris.error(...)` cho lỗi HScript (đã có sẵn trong `LoadingState.create()`).
  - `catch(e:Dynamic)`/`catch(e:haxe.Exception)` cho lỗi I/O/parse JSON.
- Verify step mới (`verifyManifestLoaded`) khi phát hiện asset thiếu: log rõ key bị thiếu + loại asset (image/sound), **không** silent-skip nếu asset thuộc `requiredAssetManifest` (khác với asset optional trong `preload.json` có `filters < 0` bị lọc theo `StageData.validateVisibility`).

---

## 15. Android Performance

- Thread count hiện tại: `Std.int(Math.max(1, CoolUtil.getCPUThreadsCount() - (DISCORD_ALLOWED ? 2 : 1)))` — dùng chung công thức cho mọi platform, không có nhánh riêng cho Android trong source đã đọc.
- Rủi ro trên Android: nhiều thread cùng đọc file từ storage (đặc biệt scoped storage / thẻ SD tốc độ chậm) có thể gây I/O contention thay vì tăng tốc — cần đo thực tế trên thiết bị thật trước khi đổi công thức này (không đoán số liệu).
- GPU texture upload (`bitmap.getTexture(FlxG.stage.context3D)` trong `Paths.cacheBitmap`) **bắt buộc chạy trên main thread** — hiện đã đúng vì được gọi từ `checkLoaded()` (chạy trong `update()`). Không được di chuyển lệnh này sang thread pool khi implement fix.
- Không được thêm allocation nặng (sprite mới, texture mới) trong `update()` của `LoadingState` mỗi frame — chỉ số liệu `loaded`/`loadMax` đọc, không tạo object mới lặp lại.
- Tuyệt đối không preload toàn bộ mod vào RAM (đã nêu ở mục 8) — đây là ràng buộc performance quan trọng nhất trên Android do RAM giới hạn.

---

## 16. Threading / Asynchronous Loading

Primitive có sẵn trong source, **chỉ được dùng những cái này, không thêm thư viện threading mới**:
- `sys.thread.FixedThreadPool` — pool cố định, khởi tạo lại mỗi lần `_startPool()`.
- `sys.thread.Mutex` — đã khai báo (`static var mutex:Mutex`) nhưng dùng chưa đầy đủ (một số chỗ mutex-protected, chỗ `loaded++`/`threadsCompleted++` thì không).
- `lime.app.Future<T>(work, async)` — `async` truyền vào chính là `isIntrusive`; khi `false`, Future chạy đồng bộ ngay lập tức (không phải background thread).

Việc sửa race condition (mục 6, 7) **phải** dùng `Mutex` hiện có, không dùng API atomic khác chưa xác nhận có tồn tại trong target Haxe/hxcpp của project này.

---

## 17. Mod Compatibility

- Mod không có `LoadingScreen.hx`/`loadingScreen.json` → hoạt động y hệt hiện tại, không có thay đổi hành vi.
- Không yêu cầu mod khai báo thêm bất kỳ manifest asset nào — required-asset manifest do engine tự tính từ `SONG`/`stageData`/`character.json` như hiện tại.
- Giữ nguyên toàn bộ thứ tự resolve của `Paths`/`Mods` (mod hiện tại ưu tiên hơn global mods, global mods ưu tiên hơn base game) khi resolve asset cho cả loading screen config lẫn required asset.

---

## 18. PlayState Transition Rules

`MusicBeatState.switchState(target)` (gọi từ `LoadingState.onLoad()`) chỉ được thực thi khi **đồng thời**:
1. `loaded >= loadMax` (counter đã fix mutex) **và** `initialThreadCompleted == true`.
2. `verifyManifestLoaded()` (mục 7) trả `true` cho toàn bộ `requiredAssetManifest`.

Không dùng busy-wait `Sys.sleep` trên main/render thread để chờ điều kiện trên (loại bỏ rủi ro mục 6.3) khi target là `PlayState` — **cần xác minh call site (mục 6, phần CẦN XÁC MINH) trước khi quyết định có giữ path `intrusive = false` cho trường hợp vào PlayState hay không.**

---

## 19. Compatibility Requirements

- Không đổi signature public: `loadAndSwitchState`, `prepare`, `prepareToSong`, `checkLoaded`, `startThreads`, `loadNextDirectory` — các nơi khác trong engine (ngoài phạm vi source đã đọc) có thể đang gọi trực tiếp các hàm này.
- Không đổi/xóa compile flag hiện có (`HSCRIPT_ALLOWED`, `MODS_ALLOWED`, `MULTITHREADED_LOADING`, `SHOW_LOADING_SCREEN`, `PSYCH_WATERMARKS`).
- Không đổi cấu trúc thư mục mod hiện có (`mods/<ModDir>/data/...`), chỉ thêm file mới tùy chọn (`loadingScreen.json`).

---

## 20. Implementation Constraints (nhắc lại từ yêu cầu gốc)

- ❌ Không đoán API không có trong source đã đọc.
- ❌ Không dựa vào Psych Engine desktop hoặc Android port khác nếu source hiện tại (1.0.4 mobile archive) khác đi.
- ❌ Không rewrite toàn bộ engine.
- ❌ Không thêm tính năng ngoài 2 mục tiêu (custom loading screen + real loading gate).
- ❌ Không dùng delay giả (`Sys.sleep`/timer cố định) để mô phỏng tiến trình loading — progress phải phản ánh trạng thái thật.
- ❌ Không preload toàn bộ mod vào RAM.
- ✅ Ưu tiên required assets của bài hát hiện tại theo đúng danh sách đã có trong `prepareToSong()`.

---

## 21. Testing Requirements

Test case bắt buộc trước khi merge:

1. Mod không có `LoadingScreen.hx`/`loadingScreen.json` → UI mặc định, hành vi không đổi so với trước fix.
2. Mod có `LoadingScreen.hx` hợp lệ (`onCreate` tồn tại) → override UI đúng, `getLoaded`/`getLoadMax` trả giá trị chính xác trong suốt quá trình.
3. Mod có `LoadingScreen.hx` lỗi cú pháp → không crash, fallback UI mặc định, có log lỗi.
4. Mod có `loadingScreen.json` hợp lệ, không có `.hx` → UI mặc định nhưng đổi đúng asset theo config.
5. Bài hát thiếu 1 file audio required (xóa thử 1 file Inst hoặc Voices) → không crash, không switchState sớm với asset thiếu; verify log rõ key thiếu.
6. Load lặp lại liên tục nhiều bài hát khác nhân vật (`player1 != player2`, có `gfVersion` riêng) nhiều lần liên tiếp trên thiết bị nhiều core → regression test cho race counter đã fix (mục 6.1, 6.2) — trước fix phải tái hiện được hang, sau fix không còn hang.
7. Test trên thiết bị/emulator Android CPU ít core (threadCount tính ra = 1) → đảm bảo path không phụ thuộc đa luồng vẫn hoạt động đúng.
8. Xác minh cụ thể call site vào `PlayState` (mục 6, phần CẦN XÁC MINH) bằng cách log timestamp `prepareToSong()` bắt đầu/kết thúc vs. thời điểm `LoadingState` được construct.

---

## 22. Build Verification

- Build và test trên **thiết bị Android thật** (không chỉ HashLink/desktop) — bắt buộc theo yêu cầu gốc, vì hành vi thread pool/GPU texture có thể khác biệt giữa desktop và Android.
- Build với các tổ hợp flag: `HSCRIPT_ALLOWED` on/off, `MULTITHREADED_LOADING` on/off, `SHOW_LOADING_SCREEN` on/off — đảm bảo fix không phụ thuộc ngầm vào 1 tổ hợp cụ thể.
- Kiểm tra không có warning/lỗi compile mới phát sinh từ việc dùng `Mutex` bổ sung.

---

## 23. Expected Architecture (sau khi hoàn thành)

```
LoadingState (không đổi class structure)
 ├─ requiredAssetManifest: Array<String>      [MỚI] snapshot bất biến từ prepareToSong()
 ├─ loaded / loadMax                          [giữ nguyên, tăng có mutex]
 ├─ checkLoaded()
 │    ├─ cache bitmap loop                    [giữ nguyên]
 │    ├─ counter check                        [giữ nguyên logic, fix race]
 │    └─ verifyManifestLoaded()               [MỚI]
 ├─ HScript hook: mods/<Mod>/data/LoadingScreen.hx   [giữ nguyên]
 └─ Config layer: mods/<Mod>/data/loadingScreen.json [MỚI, optional, thấp hơn HScript]

Paths (không đổi)
 └─ currentTrackedAssets / currentTrackedSounds — nguồn sự thật duy nhất cho verify

Mods (không đổi)
 └─ resolve order dùng lại nguyên vẹn cho cả 2 loại file mới
```

---

## 24. Development Priorities

- **P0 (chặn tất cả)**: Fix race condition `loaded++`/`threadsCompleted++` bằng `Mutex` có sẵn + đọc xác minh call site thật vào `PlayState` (mục 6, 21.8). Không làm gì khác trước khi mục này xong và có test tái hiện + xác nhận hết hang.
- **P1**: Thêm `verifyManifestLoaded()` + gate `switchState` theo mục 18.
- **P2**: Thêm `loadingScreen.json` config layer (mục 11, 12) — thuần bổ sung, không đụng logic loading.
- **P3**: Fallback ảnh placeholder cho `preloadGraphic` khi asset thiếu (mục 13), logging chi tiết hơn.
- **P4**: Test suite đầy đủ theo mục 21 + build verification theo mục 22.
