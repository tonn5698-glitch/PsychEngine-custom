# Codename Engine mods

Place each Codename Engine mod in its own folder inside this directory.

- The engine creates or updates `modsList.txt` automatically.
- Newly discovered folders are added as `folder|0` (disabled).
- Only one CNE mod may be enabled at a time.
- Enabling a CNE mod temporarily suppresses Psych mods and Psych Global Mods without rewriting the Psych `mods/modsList.txt`.
- Disabling the last CNE mod restores the Psych mod selection from its existing list.

CNE runtime compatibility is still being integrated. Not every Codename Engine API or mod feature is supported yet.
