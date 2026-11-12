# Codename Engine mods

Place Codename Engine mod folders inside `modsCNE/` in the game's data directory. On Android this is `/sdcard/.PsychEngine/modsCNE/`.

You can also mark a folder in the Psych mod list as a Codename mod from that mod's Settings button. Folders ending in `_polymod` are detected automatically. Marked Psych folders are referenced in place; they are not moved or copied.

- The engine creates or updates `modsList.txt` automatically.
- Newly discovered mods are added as `folder|0` (disabled).
- Only one CNE mod may be enabled at a time.
- Enabling a CNE mod temporarily suppresses Psych mods and Psych Global Mods without rewriting the Psych `mods/modsList.txt`.
- Disabling the last CNE mod restores the Psych mod selection from its existing list.

The compatibility runtime currently supports a first set of CNE state/substate and global script callbacks using Psych's HScript runtime. It does not yet provide full `hscript-improved` language compatibility or all CNE gameplay systems.
