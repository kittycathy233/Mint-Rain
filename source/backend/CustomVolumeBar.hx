package backend;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup;
import flixel.text.FlxText;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;

/**
 * Android风格的音量条，显示在屏幕顶部
 */
class CustomVolumeBar extends FlxGroup
{
    private var background:FlxSprite;
    private var volumeBar:FlxSprite;
    private var volumeText:FlxText;
    private var hintText:FlxText; // 提示文本
    private var hideTimer:FlxTimer;
    private var showTween:FlxTween;
    private var hideTween:FlxTween;
    
    private var barWidth:Float = 300;
    private var barHeight:Float = 6;
    private var padding:Float = 20;
    
    // 状态跟踪
    private var isVisible:Bool = false;
    
    public function new()
    {
        super();
        
        // 创建背景
        background = new FlxSprite();
        background.makeGraphic(Std.int(barWidth + padding * 2), 60, FlxColor.BLACK);
        background.alpha = 0.8;
        background.x = (FlxG.width - background.width) / 2;
        background.y = -background.height;
        add(background);
        
        // 创建音量条背景
        var barBg = new FlxSprite();
        barBg.makeGraphic(Std.int(barWidth), Std.int(barHeight), FlxColor.GRAY);
        barBg.alpha = 0.5;
        barBg.x = background.x + padding;
        barBg.y = background.y + 35;
        add(barBg);
        
        // 创建音量条
        volumeBar = new FlxSprite();
        volumeBar.makeGraphic(Std.int(barWidth), Std.int(barHeight), FlxColor.WHITE);
        volumeBar.x = barBg.x;
        volumeBar.y = barBg.y;
        volumeBar.origin.set(0, 0); // 设置原点为左上角，从左到右填充
        add(volumeBar);
        
        // 创建提示文本（黄色，左侧）
        hintText = new FlxText();
        hintText.setFormat(Paths.font("unifont-16.0.02.otf"), 16, FlxColor.YELLOW, LEFT);
        hintText.x = background.x + padding;
        hintText.y = background.y + 10;
        hintText.text = "(音量)";
        add(hintText);
        
        // 创建音量文本（白色，右侧）
        volumeText = new FlxText();
        volumeText.setFormat(Paths.font("unifont-16.0.02.otf"), 16, FlxColor.WHITE, RIGHT);
        volumeText.x = background.x;
        volumeText.y = background.y + 10;
        volumeText.fieldWidth = background.width - padding;
        add(volumeText);
        
        // 创建定时器
        hideTimer = new FlxTimer();
        
        // 初始化音量显示
        updateVolumeDisplay();
        
        // 设置所有元素的滚动因子为0，确保固定在屏幕上
        background.scrollFactor.set(0, 0);
        barBg.scrollFactor.set(0, 0);
        volumeBar.scrollFactor.set(0, 0);
        hintText.scrollFactor.set(0, 0);
        volumeText.scrollFactor.set(0, 0);
        
        // 设置摄像机 - 创建一个专门的HUD摄像机
        setupHUDCamera();
    }
    
    public function show(volumeChanged:Bool = false, playSound:Bool = true, changeSource:String = "音量"):Void
    {
        // 更新音量显示
        updateVolumeDisplay();
        
        // 播放音效 - 只在手动按键且音量真正改变时播放
        if (volumeChanged && playSound && !FlxG.sound.muted)
        {
            var volume = FlxG.sound.volume;
            // 只在音量达到100%时播放confirmMenu
            if (Math.abs(volume - 1.0) < 0.001) // 使用浮点数比较
                FlxG.sound.play(Paths.sound('confirmMenu'), 0.4);
            else if (volume > 0)
                FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
        }
        
        // 只在音量条隐藏时才播放显示动画
        // 设置提示文本 - 无论是否可见都要更新
        if (hintText != null) {
            hintText.text = changeSource;
        }
        
        if (!isVisible)
        {
            // 取消之前的补间动画
            if (showTween != null) showTween.cancel();
            if (hideTween != null) hideTween.cancel();
            
            // 重新计算所有元素的初始位置，避免Y轴错位
            resetElementPositions();
            
            // 显示动画
            showTween = FlxTween.tween(background, {y: 10}, 0.3, {
                ease: FlxEase.backOut,
                onComplete: function(_) {
                    isVisible = true;
                }
            });
            
            // 同步其他元素位置 - 使用固定的偏移量
            forEach(function(member) {
                if (Std.isOfType(member, FlxSprite)) {
                    var sprite:FlxSprite = cast member;
                    if (sprite != background) {
                        var targetY:Float;
                        if (sprite == volumeBar || (members.indexOf(sprite) == 1)) { // barBg
                            targetY = 10 + 35; // background.y + 35
                        } else if (sprite == volumeText || (members.indexOf(sprite) == 3)) { // volumeText
                            targetY = 10 + 10; // background.y + 10
                        } else {
                            targetY = 10; // 默认与background同高度
                        }
                        FlxTween.tween(sprite, {y: targetY}, 0.3, {ease: FlxEase.backOut});
                    }
                }
            });
        }
        
        // 重置或启动隐藏定时器
        hideTimer.cancel();
        hideTimer.start(2.0, function(_) {
            hide();
        });
    }
    
    public function hide():Void
    {
        // 如果已经隐藏，不需要重复执行
        if (!isVisible) return;
        
        // 取消定时器
        hideTimer.cancel();
        
        // 取消之前的补间动画
        if (showTween != null) showTween.cancel();
        if (hideTween != null) hideTween.cancel();
        
        // 隐藏动画
        hideTween = FlxTween.tween(background, {y: -background.height}, 0.3, {
            ease: FlxEase.backIn,
            onComplete: function(_) {
                isVisible = false;
            }
        });
        
        // 同步其他元素位置 - 使用固定的偏移量
        forEach(function(member) {
            if (Std.isOfType(member, FlxSprite)) {
                var sprite:FlxSprite = cast member;
                if (sprite != background) {
                    var targetY:Float;
                    if (sprite == volumeBar || (members.indexOf(sprite) == 1)) { // barBg
                        targetY = -background.height + 35; // background.y + 35
                    } else if (sprite == volumeText || (members.indexOf(sprite) == 3)) { // volumeText
                        targetY = -background.height + 10; // background.y + 10
                    } else {
                        targetY = -background.height; // 默认与background同高度
                    }
                    FlxTween.tween(sprite, {y: targetY}, 0.3, {ease: FlxEase.backIn});
                }
            }
        });
    }
    
    /**
     * 重置所有元素的位置，避免Y轴错位
     */
    private function resetElementPositions():Void
    {
        // 确保background在正确的隐藏位置
        background.y = -background.height;
        
        // 重置其他元素的位置
        forEach(function(member) {
            if (Std.isOfType(member, FlxSprite)) {
                var sprite:FlxSprite = cast member;
                if (sprite != background) {
                    if (sprite == volumeBar || (members.indexOf(sprite) == 1)) { // barBg
                        sprite.y = background.y + 35;
                    } else if (sprite == volumeText || (members.indexOf(sprite) == 3)) { // volumeText
                        sprite.y = background.y + 10;
                    } else {
                        sprite.y = background.y; // 默认与background同高度
                    }
                }
            }
        });
    }
    
    public function updateVolumeDisplay():Void
    {
        var volume = FlxG.sound.volume;
        var volumePercent = Math.round(volume * 1000) / 10; // 精确到0.1%
        
        if (FlxG.sound.muted || volume == 0)
        {
            volumeText.text = "静音";
            // 使用补间动画让音量条从左到右缩放
            FlxTween.tween(volumeBar.scale, {x: 0}, 0.1, {ease: FlxEase.quadOut});
        }
        else
        {
            if (changeSource != null && changeSource != "") {
                volumeText.text = changeSource + " " + volumePercent + "%";
            } else {
                volumeText.text = "音量: " + volumePercent + "%";
            }
            // 使用补间动画让音量条从左到右缩放
            FlxTween.tween(volumeBar.scale, {x: volume}, 0.1, {ease: FlxEase.quadOut});
        }
        
        // 根据音量调整颜色，使用补间动画让颜色变化更丝滑
        var targetColor:FlxColor;
        if (FlxG.sound.muted || volume == 0)
            targetColor = FlxColor.RED;
        else if (volume < 0.3)
            targetColor = FlxColor.YELLOW;
        else
            targetColor = FlxColor.WHITE;
            
        // 如果颜色需要改变，使用补间动画
        if (volumeBar.color != targetColor)
        {
            FlxTween.color(volumeBar, 0.1, volumeBar.color, targetColor, {ease: FlxEase.quadOut});
        }
    }
    
    private function setupHUDCamera():Void
    {
        // 延迟设置摄像机，确保在状态完全初始化后执行
        FlxG.signals.postUpdate.addOnce(function() {
            var targetCamera = FlxG.camera; // 使用默认摄像机
            
            // 如果有多个摄像机，使用最后一个（通常是HUD摄像机）
            if (FlxG.cameras.list.length > 1) {
                targetCamera = FlxG.cameras.list[FlxG.cameras.list.length - 1];
            }
            
            // 设置所有元素使用目标摄像机
            background.cameras = [targetCamera];
            forEach(function(member) {
                if (Std.isOfType(member, FlxSprite)) {
                    var sprite:FlxSprite = cast member;
                    sprite.cameras = [targetCamera];
                }
            });
        });
    }
    
    override public function destroy():Void
    {
        if (hideTimer != null) hideTimer.destroy();
        if (showTween != null) showTween.cancel();
        if (hideTween != null) hideTween.cancel();
        super.destroy();
    }
}ncel();
        super.destroy();
    }
}deTween.cancel();
        super.destroy();
    }
}