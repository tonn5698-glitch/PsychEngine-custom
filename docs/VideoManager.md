# VideoManager API

The engine owns one VideoManager per PlayState. Videos are loaded from the active mod's `videos/` directory and are keyed by the supplied video name (without the file extension).

## Lua

```lua
-- Play on the engine's custom overlay camera.
playVideo('intro', 'custom', -1, false, false, 0, 0)

-- Other supported cameras: game/stage/camGame, hud/camHUD, other/camOther.
setVideoCamera('intro', 'camOther')

-- Position and appearance.
setVideoProperty('intro', 'x', 120)
setVideoProperty('intro', 'y', 80)
setVideoProperty('intro', 'scaleX', 0.75)
setVideoProperty('intro', 'scaleY', 0.75)
setVideoProperty('intro', 'alpha', 0.9)

pauseVideo('intro')
resumeVideo('intro')
skipVideo('intro') -- invokes the video's skip callback, then destroys it
stopVideo('intro') -- immediate stop
```

Function signature:

`playVideo(name, camera = 'custom', layer = -1, loop = false, canSkip = false, x = 0, y = 0)`

`setVideoProperty` supports: `x`, `y`, `alpha`, `visible`, `active`, `canSkip`, `angle`, `scaleX`, `scaleY`, `scrollFactorX`, and `scrollFactorY`.

## HScript

The same helpers are available globally in HScript:

```haxe
playVideo('intro', 'other', -1, false, false, 0, 0);
var video = getVideo('intro');
if (video != null) {
    video.x = 120;
    video.y = 80;
    video.alpha = 0.9;
}
skipVideo('intro');
```

## Haxe Stage

```haxe
override function createPost()
{
    var video = playVideo('intro', 'camOther', -1, false, false);
    if (video != null)
    {
        video.x = 120;
        video.y = 80;
    }
}
```

BaseStage also exposes `getVideo`, `stopVideo`, `pauseVideo`, `resumeVideo`, `skipVideo`, `setVideoCamera`, and `setVideoProperty`.

## Custom event

The Bikini Horrors mod's `custom_events/VideoSprite.lua` is now a thin adapter that calls `playVideo`. No Haxe script under `data/events/` is required. Its optional Value 2 settings are separated with semicolons, for example:

`camera=other;layer=-1;loop=false;skip=false`

The video name is also its manager key, so requesting the same name again reuses the existing video rather than creating a second simultaneous instance.
