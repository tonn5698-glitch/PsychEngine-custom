/*
 * Copyright (C) 2025 Mobile Porting Team
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 * DEALINGS IN THE SOFTWARE.
 */

package mobile.backend;

import flixel.system.scaleModes.BaseScaleMode;

/**
 * ...
 * @author: Karim Akra
 */
class MobileScaleMode extends BaseScaleMode
{
	public static var allowWideScreen(default, set):Bool = true;

	override function updateGameSize(Width:Int, Height:Int):Void
	{
		// Wide Screen Mode: FlxG.width đã expand từ startup theo aspect ratio
		// (Main.hx). Khi đó ratio FlxG.width/height đã khớp màn hình → letterbox
		// mặc định fit đúng, không cần stretch branch riêng.
		// Chỉ stretch khi wideScreen bật NHƯNG width chưa expand (vd đổi setting
		// giữa session chưa restart) — giữ fallback an toàn.
		var ratio:Float = FlxG.width / FlxG.height;
		var realRatio:Float = Width / Height;
		var expandedToScreen:Bool = Math.abs(realRatio - ratio) < 0.01; // gần khớp → không cần letterbox

		if ((ClientPrefs.data.wideScreen && allowWideScreen) || expandedToScreen)
		{
			// Fit đúng tỷ lệ (đã khớp hoặc muốn lấp): full size, không cắt
			gameSize.x = Width;
			gameSize.y = Height;
		}
		else
		{
			var scaleY:Bool = realRatio < ratio;

			if (scaleY)
			{
				gameSize.x = Width;
				gameSize.y = Math.floor(gameSize.x / ratio);
			}
			else
			{
				gameSize.y = Height;
				gameSize.x = Math.floor(gameSize.y * ratio);
			}
		}
	}

	override function updateGamePosition():Void
	{
		// Khi wideScreen hoặc ratio đã khớp → neo góc trên-trái (lấp màn hình)
		// không còn thanh đen do letterbox.
		var ratio:Float = FlxG.width / FlxG.height;
		var realRatio:Float = FlxG.stage != null && FlxG.stage.stageHeight > 0
			? FlxG.stage.stageWidth / FlxG.stage.stageHeight : ratio;
		var fillScreen:Bool = (ClientPrefs.data.wideScreen && allowWideScreen)
			|| Math.abs(realRatio - ratio) < 0.01;

		if (fillScreen)
			FlxG.game.x = FlxG.game.y = 0;
		else
			super.updateGamePosition();
	}

	@:noCompletion
	private static function set_allowWideScreen(value:Bool):Bool
	{
		allowWideScreen = value;
		FlxG.scaleMode = new MobileScaleMode();
		return value;
	}
}
