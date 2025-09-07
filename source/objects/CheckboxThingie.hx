package objects;

import flixel.FlxSprite;
import flixel.util.FlxColor;
import flixel.text.FlxText;
import flixel.FlxG;
import openfl.display.Shape;

class CheckboxThingie extends FlxSprite
{
	public var sprTracker:FlxText;
	public var daValue(default, set):Bool;
	public var copyAlpha:Bool = true;
	public var offsetX:Float = 0;
	public var offsetY:Float = 0;
	public var checkboxID:Int = 0;

	public function new(x:Float = 0, y:Float = 0, ?checked = false) {
		super(x, y);

		makeGraphic(40, 40, FlxColor.TRANSPARENT, true);

		antialiasing = ClientPrefs.data.antialiasing;
		updateHitbox();

		daValue = checked;
	}

	override function update(elapsed:Float) {
		if (sprTracker != null) {
			setPosition(FlxG.width - 80, sprTracker.y + (sprTracker.height - height) / 2 + offsetY);
			if(copyAlpha) {
				alpha = sprTracker.alpha;
			}
		}
		super.update(elapsed);
	}

	private function set_daValue(check:Bool):Bool {
		daValue = check;
		
		var shape = new Shape();
		shape.graphics.lineStyle(2, 0xFF999999);
		shape.graphics.drawRect(0, 0, width, height);

		if(check) {
			shape.graphics.beginFill(0xFF33B5E5); // Holo Blue
			shape.graphics.drawRect(0, 0, width, height);
			shape.graphics.endFill();

			// Draw checkmark
			shape.graphics.lineStyle(4, FlxColor.WHITE);
			shape.graphics.moveTo(10, height / 2);
			shape.graphics.lineTo(width / 2 - 2, height - 10);
			shape.graphics.lineTo(width - 10, 10);
		}
		
		graphic.bitmap.fillRect(graphic.bitmap.rect, FlxColor.TRANSPARENT);
		graphic.bitmap.draw(shape);
		dirty = true;

		return check;
	}
}
