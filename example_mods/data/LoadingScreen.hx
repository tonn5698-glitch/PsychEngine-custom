// ============================================================
//  LoadingScreen.hx — ví dụ loading screen SOFTCODED cho mod
//  Vị trí: mods/<TenMod>/data/LoadingScreen.hx
//
//  Engine chỉ đọc 4 hook:
//    onCreate()          — chạy 1 lần khi script được nạp (BẮT BUỘC phải có,
//                           thiếu là engine bỏ qua script luôn)
//    onUpdate(elapsed)   — mỗi frame
//    shouldContinue()    — trả false → engine CHỜ, chưa switch sang PlayState
//                           (không có hook này = engine tự switch như mặc định)
//    onDestroy()         — khi loading kết thúc
//
//  Biến engine cấp cho script: getLoaded(), getLoadMax(), bar, barBack
//  (khai báo SAU khi script được parse → chỉ dùng bên trong function)
//
//  File này làm: logo Psych bounce tới khi load xong → hiện
//  "Load finished, click to continue" → bấm/tap mới vào game.
// ============================================================

var time = 0.0;
var baseY = 0.0;
var logo = null;
var hintText = null;
var uiBuilt = false;
var loadedDone = false;
var clicked = false;

function onCreate()
{
	// KHÔNG vẽ gì ở đây: engine còn dựng background/logo mặc định của nó
	// SAU khi gọi onCreate() → sprite mình sẽ bị đè. Build ở frame đầu của
	// onUpdate để UI của mình luôn nằm trên cùng.
}

function buildUI()
{
	uiBuilt = true;

	// nền đen che UI mặc định của engine (logo watermark/loadingText nằm dưới cái này)
	var bg = new FlxSprite(0, 0).makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
	bg.scrollFactor.set();
	add(bg);

	// logo Psych
	logo = new FlxSprite(0, 0);
	var icon = null;
	try { icon = Paths.image('loading_screen/icon'); } catch(e:Dynamic) {}
	if(icon != null)
	{
		logo.loadGraphic(icon);
		logo.scale.set(0.75, 0.75);
		logo.updateHitbox();
	}
	else
	{
		logo.makeGraphic(160, 160, 0xFFAA44CC); // thiếu asset → ô vuông thay thế
	}
	logo.x = (FlxG.width - logo.width) / 2;
	logo.y = FlxG.height * 0.30;
	baseY = logo.y;
	add(logo);

	// chữ hint (width = 0 → auto-size, canh giữa bằng tay)
	hintText = new FlxText(0, FlxG.height * 0.70, 0, 'Now Loading...', 32);
	hintText.setFormat(Paths.font('vcr.ttf'), 32, FlxColor.WHITE);
	add(hintText);

	// đưa progress bar của engine lên trên nền đen của mình
	// (barGroup là field của LoadingState — resolve qua parentInstance)
	// bar/barBack do engine tự cập nhật scale mỗi frame, mình không cần đụng
	var grp = barGroup;
	if(grp != null)
	{
		remove(grp);
		add(grp);
	}
}

function onUpdate(elapsed:Float)
{
	time += elapsed;
	if(!uiBuilt) buildUI();

	// logo bounce tới khi hết loading
	if(!loadedDone && logo != null)
		logo.y = baseY + Math.sin(time * Math.PI * 2 / 0.6) * 12;

	// tiến độ load asset
	var pct = 100.0;
	try
	{
		var mx:Float = getLoadMax();
		if(mx > 0) pct = Math.floor(getLoaded() / mx * 100);
	}
	catch(e:Dynamic) { pct = 100.0; }

	if(!loadedDone && pct >= 100)
	{
		loadedDone = true;
		if(logo != null) logo.y = baseY; // hết load → logo đứng yên
	}

	if(hintText != null)
	{
		if(!loadedDone) hintText.text = 'Now Loading... ' + pct + '%';
		else if(!clicked) hintText.text = 'Load finished, click to continue';
		else hintText.text = 'Loading...';

		// canh giữa (text đổi thì width đổi)
		hintText.x = (FlxG.width - hintText.width) / 2;
	}

	// bấm/tap/Enter-Space để vào game (chỉ khi đã load xong)
	if(loadedDone && !clicked && isClicked())
		clicked = true;
}

function isClicked():Bool
{
	if(FlxG.mouse.justPressed) return true;
	var t = FlxG.touches.getFirst();
	if(t != null && t.justPressed) return true;
	if(keyboardJustPressed('ENTER') || keyboardJustPressed('SPACE')) return true;
	return false;
}

// Engine gọi mỗi frame sau khi assets xong — false = còn chờ
function shouldContinue():Bool
{
	return loadedDone && clicked;
}

function onDestroy()
{
	// sprite là member của state → để state tự hủy, KHÔNG remove ở đây
}
