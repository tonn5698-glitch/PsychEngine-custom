#!/bin/sh
# SETUP FOR MAC AND LINUX SYSTEMS!!!
# REMINDER THAT YOU NEED HAXE INSTALLED PRIOR TO USING THIS
# https://haxe.org/download
set -eu
cd ..
echo Setting up haxelib...
mkdir -p ~/haxelib
haxelib setup ~/haxelib
echo Installing dependencies...
echo This might take a few moments depending on your internet speed.

install_haxelib() {
	if ! haxelib list | grep -q "^$1:"; then
		shift
		haxelib "$@"
	fi
}

haxelib git hxcpp https://github.com/kittycathy233/hxcpp --quiet
haxelib git lime https://github.com/kittycathy233/lime --quiet
install_haxelib openfl install openfl 9.4.1 --quiet
haxelib git flixel https://github.com/kittycathy233/flixel --quiet
# Force reinstall flixel-addons (cache có thể giữ version cũ không tương thích)
haxelib remove flixel-addons --quiet 2>/dev/null || true
haxelib install flixel-addons 3.2.3 --quiet
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
