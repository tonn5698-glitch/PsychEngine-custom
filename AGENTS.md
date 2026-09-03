# AGENTS.md — PsychEngine-Custom

Custom mobile fork of Psych Engine (Haxe/Lime/FNF). Builds an APK via GitHub Actions; do NOT build locally (ARM64 proot host lacks a viable toolchain — see setup notes).

## Build & CI

- **The only supported build path is GitHub Actions.** Run `git push origin main`; `.github/workflows/android-build.yml` auto-triggers and posts an `androidBuild` artifact.
- Android release step lives in `.github/workflows/build.yml` (reusable). It builds `android -final -arm64` on `macos-15` (+ NDK r27c + Haxe 4.3.6).
- **~20 min/build is expected.** Haxelib/hxcpp-obj/NDK/gradle caches exist but hxcpp rebuilds most objects whenever any source `.hx` changes, so cache only helps on trivial edits. Don't chase CI speed further.
- APK artifact path: `export/release/android/bin/app/build/outputs/apk/release/*.apk`
- `mobile-release.yml` is upstream boilerplate — it has an `REPO_PATH: kittycathy233/...` guard that makes it self-abort in this repo. Do not rely on it; `android-build.yml` is the real entry.
- Do NOT add commits solely to trigger builds (logs writes GitHub run history the other person dislikes).
- Release: `gh release create <tag> dist/PsychEngine-release.apk --repo tonn5698-glitch/PsychEngine-custom --prerelease --generate-notes`

## Repo state (post-debloat)

- **`assets/base_game/` is REMOVED** (FNF 0.6 classic: weeks 1-7, songs, chars, videos ~470MB). Do not reference it.
- `BASE_GAME_FILES` define + its asset section were removed from `Project.xml`. `VIDEOS_ALLOWED` and `TITLE_SCREEN_EASTER_EGG` remain under `officialBuild`.
- `assets/shared/weeks/weekList.txt` is **empty** — weeks come only from mods now.
- **Mod gate:** Story Mode, Freeplay, and Editor (`MasterEditorMenu`) show "NO MOD INSTALLED" + exit when `Mods.getModDirectories().length < 1`. Gate lives at the top of `create()` in:
  - `source/states/StoryMenuState.hx`
  - `source/states/FreeplayState.hx`
  - `source/states/editors/MasterEditorMenu.hx`
  - Keep this pattern (guarded `#if MODS_ALLOWED`, world-changes to MainMenu) if touching these states.

## Architecture

- `source/*.hx` are directly compiled (no module bundler/build step beyond Haxe). `source/import.hx` globally imports common types (`backend.Mods`, `FlxTransitionableState`, etc.) — many files use these without explicit `import`.
- States extend `MusicBeatState` / `MusicBeatSubstate` (in `source/backend/`), subclassing Flixel's `FlxState`. Switching uses `MusicBeatState.switchState(...)`.
- `LoadingState.hx` is the real loading gate; `Project.md` (repo root) is the full spec for its rework (mutex on `loaded++`/`threadsCompleted++`, `verifyManifestLoaded`, manifest snapshot before `loadMax`). Read it before touching loading.
- Mods system: `source/backend/Mods.hx` (enabled list via `modsList.txt`, `currentModDirectory`, `getModDirectories()`), `source/backend/Paths.hx` (mod-first asset resolution, `currentTrackedAssets`/`currentTrackedSounds` caches).
- `mods/` resolves to external storage on Android (`StorageUtil.getExternalStorageDirectory() + 'mods/'`), `Sys.getCwd() + 'mods/'` elsewhere.

## Haxelibs & setup

- Recreated by `setup/unix.sh` — uses **kittycathy233 forks** (lime, hxcpp, flixel, linc_luajit) + pinned versions (flixel-addons 3.3.2, hscript-iris 1.1.3, openfl 9.4.1, flxanimate). Never swap these for upstream openfl/lime/flixel.

## Git / push gotchas

- Push can be rejected unless the fine-grained PAT has **Workflows** scope (affects `.github/workflows/*`). `gh` token currently has it.
- `local.properties`, `keystore.properties`, `release-key.jks` are gitignored. `key.keystore` IS committed (password `psychengine`, alias `psychport`, used by Project.xml cert for release signing).
