package options;

import states.MainMenuState;
import backend.StageData;
import flixel.FlxG;
import flixel.math.FlxMath;
import flixel.tweens.FlxTween;
import flixel.input.mouse.FlxMouse;
import flixel.group.FlxSpriteGroup;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.FlxSprite;
import flixel.tweens.FlxEase;

class OptionsState extends MusicBeatState
{
	public var options:Array<String> = [
		Language.get("note_colors"),
		Language.get("controls"),
		Language.get("adjust_delay_combo"),
		Language.get("graphics"),
		Language.get("visuals"),
		Language.get("gameplay"),
		Language.get("extra_options")
		//#if TRANSLATIONS_ALLOWED , Language.get("language") #end
		#if mobile , Language.get("mobile_options") #end
	];
	
	public var optionDescriptions:Array<String> = [
		Language.get("note_colors_desc"),
		Language.get("controls_desc"),
		Language.get("adjust_delay_combo_desc"),
		Language.get("graphics_desc"),
		Language.get("visuals_desc"),
		Language.get("gameplay_desc"),
		Language.get("extra_options_desc")
		#if mobile , Language.get("mobile_options_desc") #end
	];

	private var grpOptions:FlxTypedGroup<FlxSpriteGroup>;
	private static var curSelected:Int = 0;
	public static var onPlayState:Bool = false;

	var descriptionText:FlxText;

	private var allowInput:Bool = true;
	private var isScrolling:Bool = false;
	public var bg:FlxSprite;

	override function create()
	{
		#if DISCORD_ALLOWED
		DiscordClient.changePresence("Options Menu", null);
		#end

		bg = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
		bg.antialiasing = ClientPrefs.data.antialiasing;
		
		var colorMap:Map<String, Int> = [
			'Default' => 0x00BFFF,
			'Black' => 0x000000,
			'Gray' => 0x808080,
			'Red' => 0xFF0000,
			'Green' => 0x00FF00,
			'Blue' => 0x0000FF
		];
		if (ClientPrefs.data.optionsBGColor != null && colorMap.exists(ClientPrefs.data.optionsBGColor))
			bg.color = colorMap.get(ClientPrefs.data.optionsBGColor);
		else
			bg.color = 0xFF00BFFF;
		bg.updateHitbox();
		bg.screenCenter();
		add(bg);

		grpOptions = new FlxTypedGroup<FlxSpriteGroup>();
		add(grpOptions);

		for (i in 0...options.length)
		{
			var optionItem = new FlxSpriteGroup();

			var bgSprite = new FlxSprite(0, 0).makeGraphic(300, 100, FlxColor.BLACK);
			bgSprite.alpha = 0.5;
			optionItem.add(bgSprite);

			var optionText:FlxText = new FlxText(0, 0, 300, options[i], 32);
			optionText.setFormat(Paths.font("ResourceHanRoundedCN-Bold.ttf"), 32, FlxColor.WHITE, CENTER);
			optionText.y = (bgSprite.height - optionText.height) / 2;
			optionItem.add(optionText);

			optionItem.x = FlxG.width / 2 - bgSprite.width / 2 + (i - curSelected) * 350;
			optionItem.y = FlxG.height / 2 - bgSprite.height / 2;
			grpOptions.add(optionItem);
		}

		descriptionText = new FlxText(0, FlxG.height * 0.75, FlxG.width, "", 24);
		descriptionText.setFormat(Paths.font("ResourceHanRoundedCN-Bold.ttf"), 24, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		descriptionText.borderSize = 1.5;
		add(descriptionText);

		changeSelection(0);
		super.create();
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (allowInput && !isScrolling)
		{
			if (controls.UI_LEFT_P)
				changeSelection(-1);
			if (controls.UI_RIGHT_P)
				changeSelection(1);

			if (controls.BACK)
			{
				FlxG.sound.play(Paths.sound('cancelMenu'));
				if (onPlayState)
				{
					StageData.loadDirectory(PlayState.SONG);
					LoadingState.loadAndSwitchState(new PlayState());
					FlxG.sound.music.volume = 0;
				}
				else
					MusicBeatState.switchState(new MainMenuState());
			}

			if (controls.ACCEPT)
			{
				openSelectedSubstate(options[curSelected]);
			}
		}

		// Mouse wheel scrolling
		if (FlxG.mouse.wheel != 0 && allowInput && !isScrolling)
		{
			changeSelection(-FlxG.mouse.wheel);
		}
	}

	function changeSelection(change:Int = 0)
	{
		if (change != 0)
			FlxG.sound.play(Paths.sound('scrollMenu'));

		curSelected = FlxMath.wrap(curSelected + change, 0, options.length - 1);

		isScrolling = true;

		for (i in 0...grpOptions.length)
		{
			var item = grpOptions.members[i];
			var targetX = FlxG.width / 2 - item.width / 2 + (i - curSelected) * 350;
			var targetAlpha = (i == curSelected) ? 1 : 0.6;
			var targetScale = (i == curSelected) ? 1.2 : 1.0;

			FlxTween.tween(item, {x: targetX, alpha: targetAlpha}, 0.4, {ease: FlxEase.quadOut});
			FlxTween.tween(item.scale, {x: targetScale, y: targetScale}, 0.4, {ease: FlxEase.quadOut, onComplete: function(twn:FlxTween) {
				if (i == grpOptions.length - 1)
					isScrolling = false;
			}});
		}

		descriptionText.text = optionDescriptions[curSelected];
		descriptionText.alpha = 0;
		FlxTween.tween(descriptionText, {alpha: 1}, 0.4, {ease: FlxEase.quadOut, startDelay: 0.2});
	}

	function openSelectedSubstate(label:String)
	{
		// Same as before
		if (label != Language.get("adjust_delay_combo") && label != Language.get("extra_options")) {
			persistentUpdate = false;
		} else if (label == Language.get("extra_options")) {
			persistentUpdate = true;
			allowInput = false;
		}

		var substateMap:Map<String, () -> Void> = [
			Language.get("note_colors") => () -> openSubState(new options.NotesColorSubState()),
			Language.get("controls") => () -> openSubState(new options.ControlsSubState()),
			Language.get("graphics") => () -> openSubState(new options.GraphicsSettingsSubState()),
			Language.get("visuals") => () -> openSubState(new options.VisualsSettingsSubState()),
			Language.get("gameplay") => () -> openSubState(new options.GameplaySettingsSubState()),
			Language.get("extra_options") => () -> {
				persistentUpdate = true;
				openSubState(new options.ExtraGameplaySettingSubState());
			},
			Language.get("adjust_delay_combo") => () -> MusicBeatState.switchState(new options.NoteOffsetState()),
			#if mobile Language.get("mobile_options") => () -> openSubState(new mobile.options.MobileOptionsSubState()) #end
		];

		if (substateMap.exists(label)) {
			substateMap.get(label)();
		}
	}

	override function closeSubState()
	{
		super.closeSubState();
		ClientPrefs.saveSettings();
		#if DISCORD_ALLOWED
		DiscordClient.changePresence("Options Menu", null);
		#end
		allowInput = true;
	}

	public function refreshTexts() {
        for (i in 0...grpOptions.length) {
            var item = grpOptions.members[i];
            var optionText:FlxText = cast(item.members[1], FlxText);
            optionText.text = options[i];
        }
        descriptionText.text = optionDescriptions[curSelected];
    }
}