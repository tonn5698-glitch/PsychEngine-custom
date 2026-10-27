# Custom Loading Overlay (modding)

Create `mods/<ModName>/CustomStates/loading-overlay/OverlayLoading.hx`. The script is loaded for the active mod only. Assets are resolved through the normal engine paths, so place images in `mods/<ModName>/images/` and fonts in `mods/<ModName>/fonts/` (or use assets already available to `Paths`).

```haxe
function onPreload() {
    // Called by LoadingState before PlayState creation. Cache anything used later.
    Paths.image('loading-overlay/background');
    Paths.image('loadingpet');
    Paths.image('pet-Continue');
    Paths.image('destroy-particle');
    Paths.font('custom.ttf');
}

var pet:FlxSprite;
var continueText:FlxText;
var elapsedTime:Float = 0;

function onCreate() {
    background.loadGraphic(Paths.image('loading-overlay/background'));
    logo.visible = false;
    bar.visible = false;
    barBack.visible = false;
    percentText.visible = false;
    statusText.visible = false;

    pet = new FlxSprite(0, 0);
    pet.loadGraphic(Paths.image('loadingpet'));
    pet.screenCenter();
    addObject(pet);

    continueText = new FlxText(0, FlxG.height - 100, FlxG.width, 'Loading...', 28);
    continueText.setFormat(Paths.font('custom.ttf'), 28, FlxColor.WHITE);
    addObject(continueText);
}

function onLoadingCompleted() {
    continueText.text = 'Ready to play! Please hit the screen to enter the game :3';
    continueText.alpha = 0;
    FlxTween.tween(continueText, {alpha: 1}, 0.5);
}

// Return true to wait for Enter, Space, mouse click, or touch before continuing.
function waitForContinue() {
    return true;
}

function onContinue() {
    // Optional particle / pet animation before the overlay fades.
}

function onUpdate(elapsed:Float) {
    elapsedTime += elapsed;
    if (pet != null) pet.y = FlxG.height * 0.5 + Math.sin(elapsedTime * 4) * 12;
}

function onDestroy() {
    // Cancel any tweens/timers created by the script if needed.
}
```

Callbacks: `onPreload`, `onCreate`, `onLoadingCompleted`, `waitForContinue`, `onContinue`, `onUpdate(elapsed)`, and `onDestroy`. `background`, `logo`, `statusText`, `percentText`, `bar`, and `barBack` refer to the default overlay objects. `addObject(object)` adds an object to the overlay camera; `removeObject(object)` removes it.

`waitForContinue()` is optional. If it returns `true`, the overlay waits for keyboard, mouse, or touch input after `onLoadingCompleted`; the gameplay countdown starts after the overlay fades out. Without the function (or when it returns false), the overlay fades automatically as before.
