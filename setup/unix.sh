#!/bin/sh
# SETUP FOR MAC AND LINUX SYSTEMS!!!
# REMINDER THAT YOU NEED HAXE INSTALLED PRIOR TO USING THIS
# https://haxe.org/download
set -eu
cd ..
echo Setting up haxelib...
HAXELIB_PATH="$HOME/haxelib"
mkdir -p "$HAXELIB_PATH"
haxelib setup "$HAXELIB_PATH"
echo Installing dependencies...
echo This might take a few moments depending on your internet speed.

# True when $name is installed locally at $2 (any version if $2 is empty).
# The layout is $HAXELIB_PATH/<name>/<version>, so this is checked on disk
# rather than with `haxelib list` - that command needs the package index too and
# therefore prints nothing while lib.haxe.org is unreachable. Dots are escaped so
# a version like 9.4.1 cannot match 9x4y1.
haxelib_has() {
	haxelib_name=$1
	haxelib_want=$2
	if [ -d "$HAXELIB_PATH/$haxelib_name" ]; then
		if [ -z "$haxelib_want" ]; then
			for haxelib_dir in "$HAXELIB_PATH/$haxelib_name"/*/; do
				[ -d "$haxelib_dir" ] && return 0
			done
		elif [ -d "$HAXELIB_PATH/$haxelib_name/$haxelib_want" ]; then
			return 0
		fi
	fi
	[ -z "$haxelib_want" ] && return 1
	# Not in ~/.haxelib, but Haxe ships its own copy of some libraries
	# (flixel-addons, tink_core, ...) in its bundled lib directory, and those
	# are perfectly usable. `haxelib path` resolves across every repository.
	haxelib path "$haxelib_name" "$haxelib_want" >/dev/null 2>&1
}

install_haxelib() {
	name=$1
	shift
	want=""
	if [ "$1" = "install" ] && [ $# -ge 3 ]; then
		case $3 in
			""|-*) want="" ;;
			*) want=$3 ;;
		esac
	fi
	if haxelib_has "$name" "$want"; then
		return 0
	fi
	# haxelib resolves the package list through lib.haxe.org, which is backed by
	# a MySQL server. When that database is unreachable every install fails even
	# though the ~/.haxelib cache restored fine and the library is already there.
	# Only tolerate the failure if the exact library really is present locally;
	# a genuinely missing library must still fail the build.
	if haxelib "$@" || haxelib_has "$name" "$want"; then
		return 0
	fi
	echo "ERROR: '$name' could not be installed and no usable local copy was found." >&2
	echo "Currently installed haxelibs:" >&2
	haxelib list >&2 || true
	return 1
}

# Same fallback as install_haxelib, but if lib.haxe.org is unreachable it
# installs the pinned release straight from the project's git tag instead. Used
# for openfl, which is the one library that was missing from the cache, so a
# package-index outage would otherwise block every build.
install_haxelib_or_git() {
	name=$1
	repo=$2
	ref=$3
	version=$4
	shift 4
	# A library installed by `haxelib git` lives under the version directory
	# "git", not under the tag it was pinned to, so accept either.
	if haxelib_has "$name" "$version" || haxelib_has "$name" git; then
		return 0
	fi
	if haxelib "$@" && haxelib_has "$name" "$version"; then
		return 0
	fi
	echo "Could not get '$name' $version from lib.haxe.org, installing $ref from git." >&2
	if haxelib git "$name" "$repo" "$ref" --quiet && haxelib_has "$name" git; then
		return 0
	fi
	echo "ERROR: '$name' could not be installed from lib.haxe.org or git." >&2
	echo "Present under $HAXELIB_PATH:" >&2
	ls -1 "$HAXELIB_PATH" >&2 || true
	return 1
}
haxelib git hxcpp https://github.com/kittycathy233/hxcpp --quiet
haxelib git lime https://github.com/kittycathy233/lime --quiet
install_haxelib_or_git openfl https://github.com/openfl/openfl.git 9.4.1 9.4.1 install openfl 9.4.1 --quiet
haxelib git flixel https://github.com/kittycathy233/flixel --quiet
install_haxelib flixel-addons install flixel-addons 3.2.2 --quiet
install_haxelib flixel-tools install flixel-tools 1.5.1 --quiet
install_haxelib hscript-iris install hscript-iris 1.1.3 --quiet
install_haxelib tjson install tjson 1.4.0 --quiet
haxelib git flxanimate https://github.com/Dot-Stuff/flxanimate 768740a56b26aa0c072720e0d1236b94afe68e3e --quiet
haxelib git linc_luajit https://github.com/kittycathy233/linc_luajit --quiet
install_haxelib hxdiscord_rpc install hxdiscord_rpc --quiet --skip-dependencies
install_haxelib hxvlc install hxvlc 2.0.1 --quiet --skip-dependencies
install_haxelib hxcpp-debug-server install hxcpp-debug-server --quiet
haxelib git funkin.vis https://github.com/FunkinCrew/funkVis 22b1ce089dd924f15cdc4632397ef3504d464e90 --quiet --skip-dependencies
haxelib git grig.audio https://gitlab.com/haxe-grig/grig.audio.git cbf91e2180fd2e374924fe74844086aab7891666 --quiet
echo Finished!
