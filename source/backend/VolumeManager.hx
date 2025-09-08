package backend;

import flixel.FlxG;
import flixel.FlxState;
import flixel.input.keyboard.FlxKey;

/**
 * 全局音量管理器
 * 监听游戏音量控制并显示音量条，支持丝滑调整和长按连续调整
 * 仅在桌面平台使用，其他平台使用Flixel默认soundtray
 */
class VolumeManager
{
    private static var instance:VolumeManager;
    private var volumeBar:CustomVolumeBar;
    private var currentState:FlxState;
    private var lastVolume:Float = -1;
    private var lastMuted:Bool = false;
    
    // 长按连续调整相关
    private var volumeUpPressed:Bool = false;
    private var volumeDownPressed:Bool = false;
    private var mutePressed:Bool = false;
    private var holdTimer:Float = 0;
    private var adjustTimer:Float = 0;
    private var holdThreshold:Float = 1.0; // 1秒后开始连续调整
    private var adjustInterval:Float = 0.02; // 每0.02秒调整一次
    private var volumeStep:Float = 0.05; // 5%的音量步长（HaxeFlixel默认）
    private var fineStep:Float = 0.001; // 0.1%的精细步长（长按连续调整）
    
    // 后台模式相关
    private var isInBackgroundMode:Bool = false;
    private var backgroundVolumeBeforeChange:Float = 1.0;
    
    public static function getInstance():VolumeManager
    {
        #if desktop
        if (instance == null)
            instance = new VolumeManager();
        return instance;
        #else
        // 非桌面平台返回空实例，不执行任何操作
        if (instance == null)
            instance = new VolumeManager();
        return instance;
        #end
    }
    
    private function new()
    {
        // 初始化音量状态
        lastVolume = FlxG.sound.volume;
        lastMuted = FlxG.sound.muted;
    }
    
    public function init(state:FlxState):Void
    {
        #if desktop
        currentState = state;
        
        // 创建音量条
        if (volumeBar != null)
        {
            if (currentState.members.contains(volumeBar))
                currentState.remove(volumeBar);
            volumeBar.destroy();
        }
        
        volumeBar = new CustomVolumeBar();
        currentState.add(volumeBar);
        
        // 重置音量状态
        lastVolume = FlxG.sound.volume;
        lastMuted = FlxG.sound.muted;
        #else
        // 非桌面平台不执行任何操作
        #end
    }
    
    public function update(elapsed:Float):Void
    {
        #if desktop
        if (volumeBar == null) return;
        
        // 检查音量控制键状态
        checkVolumeKeys(elapsed);
        
        // 检测音量变化（包括外部变化）
        var currentVolume = FlxG.sound.volume;
        var currentMuted = FlxG.sound.muted;
        
        if (Math.abs(currentVolume - lastVolume) > 0.0001 || currentMuted != lastMuted)
        {
            // 音量发生变化，显示音量条（外部变化不播放音频）
            if (volumeBar != null && !isInBackgroundMode)
                volumeBar.show(false, false); // 外部音量变化不播放音频
            
            // 更新记录的状态
            lastVolume = currentVolume;
            lastMuted = currentMuted;
            
            // 保存音量设置
            saveVolumeSettings();
        }
        #else
        // 非桌面平台不执行任何操作
        #end
    }
    
    private function checkVolumeKeys(elapsed:Float):Void
    {
        // 获取音量控制键的状态
        var volumeUpKeys = ClientPrefs.keyBinds.get('volume_up');
        var volumeDownKeys = ClientPrefs.keyBinds.get('volume_down');
        var muteKeys = ClientPrefs.keyBinds.get('volume_mute');
        
        var upPressed = isAnyKeyPressed(volumeUpKeys);
        var downPressed = isAnyKeyPressed(volumeDownKeys);
        var muteJustPressed = isAnyKeyJustPressed(muteKeys);
        
        // 处理静音切换
        if (muteJustPressed)
        {
            FlxG.sound.muted = !FlxG.sound.muted;
            return;
        }
        
        // 处理音量调整
        var volumeChanged = false;
        
        if (upPressed && !volumeUpPressed)
        {
            // 刚开始按下音量增加键 - 使用5%步长
            volumeUpPressed = true;
            holdTimer = 0;
            adjustTimer = 0;
            adjustVolume(volumeStep);
            volumeChanged = true;
        }
        else if (downPressed && !volumeDownPressed)
        {
            // 刚开始按下音量减少键 - 使用5%步长
            volumeDownPressed = true;
            holdTimer = 0;
            adjustTimer = 0;
            adjustVolume(-volumeStep);
            volumeChanged = true;
        }
        
        // 处理长按连续调整
        if (upPressed && volumeUpPressed)
        {
            holdTimer += elapsed;
            if (holdTimer >= holdThreshold)
            {
                adjustTimer += elapsed;
                if (adjustTimer >= adjustInterval)
                {
                    adjustVolume(fineStep); // 长按时使用0.1%精细步长
                    adjustTimer = 0;
                    volumeChanged = true;
                }
            }
        }
        else if (downPressed && volumeDownPressed)
        {
            holdTimer += elapsed;
            if (holdTimer >= holdThreshold)
            {
                adjustTimer += elapsed;
                if (adjustTimer >= adjustInterval)
                {
                    adjustVolume(-fineStep); // 长按时使用0.1%精细步长
                    adjustTimer = 0;
                    volumeChanged = true;
                }
            }
        }
        
        // 重置按键状态
        if (!upPressed) volumeUpPressed = false;
        if (!downPressed) volumeDownPressed = false;
        
        // 如果音量发生变化，立即更新显示
        if (volumeChanged)
        {
            lastVolume = FlxG.sound.volume;
            lastMuted = FlxG.sound.muted;
            
            // 只在非后台模式下显示音量条，并播放音效（手动按键）
            if (volumeBar != null && !isInBackgroundMode)
            {
                volumeBar.updateVolumeDisplay();
                volumeBar.show(true, true); // volumeChanged=true, playSound=true
            }
        }
    }
    
    private function isAnyKeyPressed(keys:Array<FlxKey>):Bool
    {
        for (key in keys)
        {
            if (FlxG.keys.anyPressed([key]))
                return true;
        }
        return false;
    }
    
    private function isAnyKeyJustPressed(keys:Array<FlxKey>):Bool
    {
        for (key in keys)
        {
            if (FlxG.keys.anyJustPressed([key]))
                return true;
        }
        return false;
    }
    
    private function adjustVolume(delta:Float):Void
    {
        if (FlxG.sound.muted && delta > 0)
        {
            // 如果当前静音且要增加音量，先取消静音
            FlxG.sound.muted = false;
        }
        
        var newVolume = FlxG.sound.volume + delta;
        // 精确计算，避免浮点数误差导致的额外0.1%
        newVolume = Math.round(newVolume * 1000) / 1000; // 精确到0.001
        FlxG.sound.volume = Math.max(0, Math.min(1, newVolume));
        
        // 如果音量调到0，自动静音
        if (FlxG.sound.volume <= 0)
        {
            FlxG.sound.muted = true;
        }
    }
    
    private function saveVolumeSettings():Void
    {
        #if FLX_SAVE
        if (FlxG.save.isBound)
        {
            FlxG.save.data.mute = FlxG.sound.muted;
            FlxG.save.data.volume = FlxG.sound.volume;
            FlxG.save.flush();
        }
        #end
    }
    
    public function cleanup():Void
    {
        #if desktop
        if (volumeBar != null && currentState != null)
        {
            if (currentState.members.contains(volumeBar))
                currentState.remove(volumeBar);
        }
        #else
        // 非桌面平台不执行任何操作
        #end
    }
    

    
    public function showVolumeBar():Void
    {
        #if desktop
        if (volumeBar != null && !isInBackgroundMode)
            volumeBar.show(false, false); // volumeChanged=false, playSound=false
        #else
        // 非桌面平台不执行任何操作
        #end
    }
    
    public function hideVolumeBar():Void
    {
        #if desktop
        if (volumeBar != null)
            volumeBar.hide();
        #else
        // 非桌面平台不执行任何操作
        #end
    }
    
    /**
     * 设置后台模式状态
     * @param isBackground 是否处于后台模式
     */
    public function setBackgroundMode(isBackground:Bool):Void
    {
        #if desktop
        if (isBackground && !isInBackgroundMode)
        {
            // 进入后台模式，保存当前音量
            isInBackgroundMode = true;
            backgroundVolumeBeforeChange = FlxG.sound.volume;
            // 显示音量条但不播放音频，提示后台更改
            if (volumeBar != null)
            {
                volumeBar.show(false, false, "(后台更改)");
            }
        }
        else if (!isBackground && isInBackgroundMode)
        {
            // 退出后台模式，恢复音量显示
            isInBackgroundMode = false;
            // 更新音量条显示，因为音量可能在后台被系统改变了
            // 注意：后台切换时显示音量条但不播放音效
            if (volumeBar != null)
            {
                volumeBar.show(false, false, "(前台恢复)");
            }
        }
        #else
        // 非桌面平台不执行任何操作
        #end
    }
    
    /**
     * 检查是否处于后台模式
     */
    public function isBackgroundMode():Bool
    {
        return isInBackgroundMode;
    }
    
    public function destroy():Void
    {
        #if desktop
        if (volumeBar != null)
        {
            volumeBar.destroy();
            volumeBar = null;
        }
        #end
        instance = null;
    }
}