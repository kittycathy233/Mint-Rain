package options;

import flixel.input.keyboard.FlxKey;
import flixel.input.gamepad.FlxGamepad;
import flixel.input.gamepad.FlxGamepadInputID;
import flixel.input.gamepad.FlxGamepadManager;
import objects.CheckboxThingie;
import objects.AttachedText;
import options.Option;
import backend.InputFormatter;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.text.FlxText;
import flixel.util.FlxColor;

class BaseOptionsMenu extends MusicBeatSubstate
{
	private var selector:FlxSprite;
	private var curOption:Option = null;
	private var curSelected:Int = 0;
	private var optionsArray:Array<Option>;

	private var grpOptions:FlxTypedGroup<FlxText>;
	private var checkboxGroup:FlxTypedGroup<CheckboxThingie>;
	private var grpTexts:FlxTypedGroup<AttachedText>;

	private var descBox:FlxSprite;
	private var descText:FlxText;

	public var title:String;
	public var rpcTitle:String;

	public var bg:FlxSprite;
	private var titleText:FlxText;

	// 滚动相关变量
	private var scrollBar:FlxSprite;
	private var scrollThumb:FlxSprite;
	private var scrollY:Float = 0;
	private var maxScrollY:Float = 0;
	private var visibleAreaHeight:Float = 0;
	private var itemSpacing:Float = 60;
	private var scrollTween:FlxTween;

	public function new()
	{
		// 提前初始化 optionsArray，这样子类就可以在调用 super() 之前使用 addOption
		if(optionsArray == null) optionsArray = [];
		
		controls.isInSubstate = true;
		super();

		if(title == null) title = 'Options';
		if(rpcTitle == null) rpcTitle = 'Options Menu';
		
		#if DISCORD_ALLOWED
		DiscordClient.changePresence(rpcTitle, null);
		#end

		bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, 0xFF1a1a1a);
		add(bg);

		titleText = new FlxText(0, 20, FlxG.width, title, 32);
		titleText.setFormat(Paths.font("ResourceHanRoundedCN-Bold.ttf"), 32, FlxColor.WHITE, CENTER);
		titleText.screenCenter(X);
		add(titleText);

		descBox = new FlxSprite(0, FlxG.height).makeGraphic(FlxG.width, 120, 0xFF000000);
		descBox.alpha = 0.6;
		descBox.y -= descBox.height;
		add(descBox);

		descText = new FlxText(40, descBox.y + 20, FlxG.width - 80, "", 24);
		descText.setFormat(Paths.font("ResourceHanRoundedCN-Bold.ttf"), 24, FlxColor.WHITE, LEFT);
		add(descText);

		grpOptions = new FlxTypedGroup<FlxText>();
		add(grpOptions);

		grpTexts = new FlxTypedGroup<AttachedText>();
		add(grpTexts);

		checkboxGroup = new FlxTypedGroup<CheckboxThingie>();
		add(checkboxGroup);

		selector = new FlxSprite(0, 0).makeGraphic(FlxG.width, 4, 0xFF33B5E5); // Holo Blue
		add(selector);

		// 计算可视区域高度
		visibleAreaHeight = descBox.y - 80; // 从标题下方到描述框上方

		var startY:Float = 80;
		itemSpacing = 60;
		for (i in 0...optionsArray.length)
		{
			var optionText:FlxText = new FlxText(40, startY + i * itemSpacing, FlxG.width - 80, optionsArray[i].name, 28);
			optionText.setFormat(Paths.font("ResourceHanRoundedCN-Bold.ttf"), 28, FlxColor.WHITE, LEFT);
			grpOptions.add(optionText);

			if(optionsArray[i].type == BOOL)
			{
				var checkbox:CheckboxThingie = new CheckboxThingie(FlxG.width - 80, optionText.y, Std.string(optionsArray[i].getValue()) == 'true');
				checkbox.sprTracker = optionText;
				checkbox.checkboxID = i;
				checkboxGroup.add(checkbox);
			}
			else
			{
				var valueText:AttachedText = new AttachedText('' + optionsArray[i].getValue(), FlxG.width - 80, 0);
				valueText.sprTracker = optionText;
				valueText.copyAlpha = true;
				valueText.ID = i;
				valueText.setFormat(Paths.font("ResourceHanRoundedCN-Bold.ttf"), 28, 0xFFCCCCCC, RIGHT);
				valueText.x -= valueText.width;
				grpTexts.add(valueText);
				optionsArray[i].child = valueText;
			}
			updateTextFrom(optionsArray[i]);
		}

		// 计算最大滚动距离
		var totalHeight = optionsArray.length * itemSpacing;
		maxScrollY = Math.max(0, totalHeight - visibleAreaHeight + 100);

		// 创建滚动条
		createScrollBar();

		changeSelection();
		reloadCheckboxes();
		
		addTouchPad('LEFT_FULL', 'A_B_C');
	}

	public function addOption(option:Option) {
		if(optionsArray == null || optionsArray.length < 1) optionsArray = [];
		optionsArray.push(option);
		return option;
	}

	function createScrollBar() {
		if(maxScrollY <= 0) return; // 不需要滚动条

		// 滚动条背景
		scrollBar = new FlxSprite(FlxG.width - 20, 80).makeGraphic(8, Std.int(visibleAreaHeight), 0xFF333333);
		add(scrollBar);

		// 滚动条滑块
		var thumbHeight = Math.max(20, (visibleAreaHeight / (maxScrollY + visibleAreaHeight)) * visibleAreaHeight);
		scrollThumb = new FlxSprite(FlxG.width - 20, 80).makeGraphic(8, Std.int(thumbHeight), 0xFF33B5E5);
		add(scrollThumb);
	}

	function updateScrollBar() {
		if(scrollThumb == null || maxScrollY <= 0) return;

		var scrollPercent = scrollY / maxScrollY;
		var maxThumbY = scrollBar.y + scrollBar.height - scrollThumb.height;
		scrollThumb.y = scrollBar.y + scrollPercent * (maxThumbY - scrollBar.y);
	}

	function scrollToItem(itemIndex:Int) {
		if(maxScrollY <= 0) return;

		var targetY = itemIndex * itemSpacing;
		var viewportTop = scrollY;
		var viewportBottom = scrollY + visibleAreaHeight - 100;

		var newScrollY = scrollY;

		// 如果选中项在视口上方
		if(targetY < viewportTop) {
			newScrollY = targetY - 50; // 留一些边距
		}
		// 如果选中项在视口下方
		else if(targetY > viewportBottom) {
			newScrollY = targetY - visibleAreaHeight + 150; // 留一些边距
		}

		newScrollY = FlxMath.bound(newScrollY, 0, maxScrollY);

		if(newScrollY != scrollY) {
			if(scrollTween != null) scrollTween.cancel();
			scrollTween = FlxTween.tween(this, {scrollY: newScrollY}, 0.3, {
				ease: FlxEase.quadOut,
				onUpdate: function(tween:FlxTween) {
					updateScrollPosition();
				}
			});
		}
	}

	function updateScrollPosition() {
		// 直接更新各个成员的 y 坐标
		var offsetY = -scrollY;
		
		// 更新选项文本的位置
		if(grpOptions != null) {
			for(i in 0...grpOptions.members.length) {
				var item = grpOptions.members[i];
				if(item != null) {
					item.y = 80 + i * itemSpacing + offsetY;
				}
			}
		}
		
		// 更新值文本的位置
		if(grpTexts != null) {
			for(text in grpTexts.members) {
				if(text != null && text.sprTracker != null) {
					text.y = text.sprTracker.y + (text.sprTracker.height - text.height) / 2;
				}
			}
		}
		
		// 更新复选框的位置
		if(checkboxGroup != null) {
			for(checkbox in checkboxGroup.members) {
				if(checkbox != null && checkbox.sprTracker != null) {
					checkbox.y = checkbox.sprTracker.y + (checkbox.sprTracker.height - checkbox.height) / 2;
				}
			}
		}
		
		// 更新选择器的位置
		if(selector != null && curSelected >= 0 && curSelected < grpOptions.members.length) {
			var item = grpOptions.members[curSelected];
			if(item != null) {
				selector.y = item.y + item.height;
			}
		}
		
		updateScrollBar();
	}

	var nextAccept:Int = 5;
	var holdTime:Float = 0;
	var holdValue:Float = 0;

	var bindingKey:Bool = false;
	var holdingEsc:Float = 0;
	var bindingBlack:FlxSprite;
	var bindingText:FlxText;
	var bindingText2:FlxText;
	var lastMouseClickTime:Float = 0;
	var lastMouseClickIndex:Int = -1;
	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (bindingKey)
		{
			bindingKeyUpdate(elapsed);
			return;
		}

		if (controls.UI_UP_P) changeSelection(-1);
		if (controls.UI_DOWN_P) changeSelection(1);
		if (FlxG.mouse.wheel != 0) changeSelection(FlxG.mouse.wheel > 0 ? -1 : 1);

		if (controls.BACK) {
			close();
			FlxG.sound.play(Paths.sound('cancelMenu'));
		}

		if(nextAccept <= 0 && curOption != null)
		{
			switch(curOption.type)
			{
				case BOOL:
					if(controls.ACCEPT)
					{
						FlxG.sound.play(Paths.sound('scrollMenu'));
						curOption.setValue(!(curOption.getValue() == true));
						curOption.change();
						reloadCheckboxes();
					}
				case KEYBIND:
					if(controls.ACCEPT)
					{
						bindingBlack = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
						bindingBlack.alpha = 0;
						FlxTween.tween(bindingBlack, {alpha: 0.6}, 0.35, {ease: FlxEase.linear});
						add(bindingBlack);
	
						bindingText = new FlxText(0, 160, FlxG.width, LanguageBasic.getPhrase('controls_rebinding', 'Rebinding {1}', [curOption.name]), 32);
						bindingText.setFormat(Paths.font("ResourceHanRoundedCN-Bold.ttf"), 32, FlxColor.WHITE, CENTER);
						add(bindingText);

						final escape:String = (controls.mobileC) ? "B" : "ESC";
						final backspace:String = (controls.mobileC) ? "C" : "Backspace";
						
						bindingText2 = new FlxText(0, 340, FlxG.width, LanguageBasic.getPhrase('controls_rebinding2', 'Hold {1} to Cancel\\nHold {2} to Delete', [escape, backspace]), 24);
						bindingText2.setFormat(Paths.font("ResourceHanRoundedCN-Bold.ttf"), 24, FlxColor.WHITE, CENTER);
						add(bindingText2);
	
						bindingKey = true;
						holdingEsc = 0;
						ClientPrefs.toggleVolumeKeys(false);
						FlxG.sound.play(Paths.sound('scrollMenu'));
					}
				default:
					if(controls.UI_LEFT || controls.UI_RIGHT)
					{
						var pressed = (controls.UI_LEFT_P || controls.UI_RIGHT_P);
						if(holdTime > 0.5 || pressed)
						{
							if(pressed)
							{
								var add:Dynamic = null;
								if(curOption.type != STRING)
									add = controls.UI_LEFT ? -curOption.changeValue : curOption.changeValue;
		
								switch(curOption.type)
								{
									case INT, FLOAT, PERCENT:
										holdValue = curOption.getValue() + add;
										if(holdValue < curOption.minValue) holdValue = curOption.minValue;
										else if (holdValue > curOption.maxValue) holdValue = curOption.maxValue;
		
										if(curOption.type == INT)
											curOption.setValue(Math.round(holdValue));
										else
											curOption.setValue(FlxMath.roundDecimal(holdValue, curOption.decimals));
		
									case STRING:
										var num:Int = curOption.curOption;
										if(controls.UI_LEFT_P) --num; else num++;
		
										if(num < 0) num = curOption.options.length - 1;
										else if(num >= curOption.options.length) num = 0;
		
										curOption.curOption = num;
										curOption.setValue(curOption.options[num]);
									default:
								}
								updateTextFrom(curOption);
								curOption.change();
								FlxG.sound.play(Paths.sound('scrollMenu'));
							}
							else if(curOption.type != STRING)
							{
								holdValue += curOption.scrollSpeed * elapsed * (controls.UI_LEFT ? -1 : 1);
								if(holdValue < curOption.minValue) holdValue = curOption.minValue;
								else if (holdValue > curOption.maxValue) holdValue = curOption.maxValue;
		
								switch(curOption.type)
								{
									case INT: curOption.setValue(Math.round(holdValue));
									case PERCENT: curOption.setValue(FlxMath.roundDecimal(holdValue, curOption.decimals));
									default:
								}
								updateTextFrom(curOption);
								curOption.change();
							}
						}
		
						if(curOption.type != STRING)
							holdTime += elapsed;
					}
					else if(controls.UI_LEFT_R || controls.UI_RIGHT_R)
					{
						if(holdTime > 0.5) FlxG.sound.play(Paths.sound('scrollMenu'));
						holdTime = 0;
					}
			}

			if(controls.RESET || touchPad.buttonC.justPressed)
			{
				var leOption:Option = optionsArray[curSelected];
				if(leOption.type != KEYBIND)
				{
					leOption.setValue(leOption.defaultValue);
					if(leOption.type != BOOL)
					{
						if(leOption.type == STRING) leOption.curOption = leOption.options.indexOf(leOption.getValue());
						updateTextFrom(leOption);
					}
				}
				else
				{
					leOption.setValue(!Controls.instance.controllerMode ? leOption.defaultKeys.keyboard : leOption.defaultKeys.gamepad);
					updateBind(leOption);
				}
				leOption.change();
				FlxG.sound.play(Paths.sound('cancelMenu'));
				reloadCheckboxes();
			}
		}

		if(nextAccept > 0) nextAccept -= 1;
	}

	function bindingKeyUpdate(elapsed:Float)
	{
		if(touchPad.buttonB.pressed || FlxG.keys.pressed.ESCAPE || FlxG.gamepads.anyPressed(FlxGamepadInputID.B))
		{
			holdingEsc += elapsed;
			if(holdingEsc > 0.5)
			{
				FlxG.sound.play(Paths.sound('cancelMenu'));
				closeBinding();
			}
		}
		else if (touchPad.buttonC.pressed || FlxG.keys.pressed.BACKSPACE || FlxG.gamepads.anyPressed(FlxGamepadInputID.BACK))
		{
			holdingEsc += elapsed;
			if(holdingEsc > 0.5)
			{
				if (!controls.controllerMode) curOption.keys.keyboard = FlxKey.NONE;
				else curOption.keys.gamepad = FlxGamepadInputID.NONE;
				updateBind(!controls.controllerMode ? InputFormatter.getKeyName(FlxKey.NONE) : InputFormatter.getGamepadName(FlxGamepadInputID.NONE));
				FlxG.sound.play(Paths.sound('cancelMenu'));
				closeBinding();
			}
		}
		else
		{
			holdingEsc = 0;
			var changed:Bool = false;
			if(!controls.controllerMode)
			{
				if(FlxG.keys.justPressed.ANY || FlxG.keys.justReleased.ANY)
				{
					var keyPressed:FlxKey = cast (FlxG.keys.firstJustPressed(), FlxKey);
					var keyReleased:FlxKey = cast (FlxG.keys.firstJustReleased(), FlxKey);

					if(keyPressed != FlxKey.NONE && keyPressed != FlxKey.ESCAPE && keyPressed != FlxKey.BACKSPACE)
					{
						changed = true;
						curOption.keys.keyboard = keyPressed;
					}
					else if(keyReleased != FlxKey.NONE && (keyReleased == FlxKey.ESCAPE || keyReleased == FlxKey.BACKSPACE))
					{
						changed = true;
						curOption.keys.keyboard = keyReleased;
					}
				}
			}
			else if(FlxG.gamepads.anyJustPressed(ANY) || FlxG.gamepads.anyJustPressed(FlxGamepadInputID.LEFT_TRIGGER) || FlxG.gamepads.anyJustPressed(FlxGamepadInputID.RIGHT_TRIGGER) || FlxG.gamepads.anyJustReleased(ANY))
			{
				var keyPressed:FlxGamepadInputID = FlxGamepadInputID.NONE;
				var keyReleased:FlxGamepadInputID = FlxGamepadInputID.NONE;
				if(FlxG.gamepads.anyJustPressed(FlxGamepadInputID.LEFT_TRIGGER)) keyPressed = FlxGamepadInputID.LEFT_TRIGGER;
				else if(FlxG.gamepads.anyJustPressed(FlxGamepadInputID.RIGHT_TRIGGER)) keyPressed = FlxGamepadInputID.RIGHT_TRIGGER;
				else
				{
					for (i in 0...FlxG.gamepads.numActiveGamepads)
					{
						var gamepad:FlxGamepad = FlxG.gamepads.getByID(i);
						if(gamepad != null)
						{
							keyPressed = gamepad.firstJustPressedID();
							keyReleased = gamepad.firstJustReleasedID();
							if(keyPressed != FlxGamepadInputID.NONE || keyReleased != FlxGamepadInputID.NONE) break;
						}
					}
				}

				if(keyPressed != FlxGamepadInputID.NONE && keyPressed != FlxGamepadInputID.BACK && keyPressed != FlxGamepadInputID.B)
				{
					changed = true;
					curOption.keys.gamepad = keyPressed;
				}
				else if(keyReleased != FlxGamepadInputID.NONE && (keyReleased == FlxGamepadInputID.BACK || keyReleased == FlxGamepadInputID.B))
				{
					changed = true;
					curOption.keys.gamepad = keyReleased;
				}
			}

			if(changed)
			{
				var key:String = null;
				if(!controls.controllerMode)
				{
					if(curOption.keys.keyboard == null) curOption.keys.keyboard = FlxKey.NONE;
					curOption.setValue(Std.string(curOption.keys.keyboard));
					key = InputFormatter.getKeyName(curOption.keys.keyboard);
				}
				else
				{
					if(curOption.keys.gamepad == null) curOption.keys.gamepad = FlxGamepadInputID.NONE;
					curOption.setValue(Std.string(curOption.keys.gamepad));
					key = InputFormatter.getGamepadName(curOption.keys.gamepad);
				}
				updateBind(key);
				FlxG.sound.play(Paths.sound('confirmMenu'));
				closeBinding();
			}
		}
	}

	final MAX_KEYBIND_WIDTH = 320;
	function updateBind(?text:String = null, ?option:Option = null)
	{
		if(option == null) option = curOption;
		if(text == null)
		{
			text = option.getValue();
			if(text == null) text = 'NONE';

			if(!controls.controllerMode)
				text = InputFormatter.getKeyName(FlxKey.fromString(text));
			else
				text = InputFormatter.getGamepadName(FlxGamepadInputID.fromString(text));
		}

		var bind:AttachedText = cast option.child;
		bind.text = text;
		bind.x = FlxG.width - 80 - bind.width;
	}

	function closeBinding()
	{
		bindingKey = false;
		if(bindingBlack != null) bindingBlack.destroy();
		remove(bindingBlack, true);

		if(bindingText != null) bindingText.destroy();
		remove(bindingText, true);

		if(bindingText2 != null) bindingText2.destroy();
		remove(bindingText2, true);
		ClientPrefs.toggleVolumeKeys(true);
	}

	function updateTextFrom(option:Option) {
		if(option.type == KEYBIND)
		{
			updateBind(null, option);
			return;
		}

		var text:String = option.displayFormat;
		var val:Dynamic = option.getValue();
		if(option.type == PERCENT) val *= 100;
		var def:Dynamic = option.defaultValue;
		var newText = text.replace('%v', val).replace('%d', def);

		var child:AttachedText = cast(option.child, AttachedText);
		if(child != null) {
			child.text = newText;
		}
	}
	
	public function changeSelection(change:Int = 0)
	{
		if(optionsArray == null || optionsArray.length <= 0) return;
		
		curSelected = FlxMath.wrap(curSelected + change, 0, optionsArray.length - 1);

		descText.text = optionsArray[curSelected].description;

		var item = grpOptions.members[curSelected];
		selector.y = item.y + item.height;

		for (num => item in grpOptions.members)
		{
			item.color = (num == curSelected) ? FlxColor.WHITE : 0xFF999999;
		}
		for (text in grpTexts)
		{
			text.color = (text.ID == curSelected) ? FlxColor.WHITE : 0xFF999999;
		}

		curOption = optionsArray[curSelected];
		
		// 滚动到当前选中的项目
		scrollToItem(curSelected);
		
		if(change != 0) FlxG.sound.play(Paths.sound('scrollMenu'));
	}

	public function reloadCheckboxes()
		for (checkbox in checkboxGroup)
			checkbox.daValue = Std.string(optionsArray[checkbox.checkboxID].getValue()) == 'true';
	
	public function refreshAllTexts() {
		if(titleText != null) titleText.text = title;
	
		for (i in 0...grpOptions.length) {
			var opt = grpOptions.members[i];
			if(opt != null) opt.text = optionsArray[i].name;
		}
	
		if(optionsArray != null && optionsArray.length > 0 && curSelected < optionsArray.length)
			descText.text = optionsArray[curSelected].description;
	}
}