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

/**
 * A storage class for mobile.
 * @author Karim Akra and Homura Akemi (HomuHomu833)
 */
class StorageUtil
{
	#if sys
	public static function getStorageDirectory():String
		return #if android haxe.io.Path.addTrailingSlash(AndroidContext.getExternalFilesDir()) #elseif ios lime.system.System.documentsDirectory #else Sys.getCwd() #end;

	public static function saveContent(fileName:String, fileData:String, ?alert:Bool = true):Void
	{
		final folder:String = #if android StorageUtil.getExternalStorageDirectory() + #else Sys.getCwd() + #end 'saves/';
		try
		{
			if (!FileSystem.exists(folder))
				FileSystem.createDirectory(folder);

			File.saveContent('$folder/$fileName', fileData);
			if (alert)
				CoolUtil.showPopUp(LanguageBasic.getPhrase('file_save_success', '{1} has been saved.', [fileName]), LanguageBasic.getPhrase('mobile_success', "Success!"));
		}
		catch (e:Dynamic)
			if (alert)
				CoolUtil.showPopUp(LanguageBasic.getPhrase('file_save_fail', '{1} couldn\'t be saved.\n({2})', [fileName, e.message]), LanguageBasic.getPhrase('mobile_error', "Error!"));
			else
				trace('$fileName couldn\'t be saved. (${e.message})');
	}

	#if android
	// Android 12+ 兼容的存储路径
	public static function getExternalStorageDirectory():String
	{
		// Android 12+ 使用应用专用外部存储目录
		if (AndroidVersion.SDK_INT >= AndroidVersionCode.S) // Android 12 (API 31)
		{
			var appSpecificDir = AndroidContext.getExternalFilesDir();
			if (appSpecificDir != null)
				return haxe.io.Path.addTrailingSlash(appSpecificDir);
		}
		
		// 回退到传统路径（Android 11及以下）
		return '/sdcard/.MintRhythm Extended/';
	}

	public static function requestPermissions():Void
	{
		// Android 13+ (API 33) 使用细分媒体权限
		if (AndroidVersion.SDK_INT >= AndroidVersionCode.TIRAMISU)
		{
			AndroidPermissions.requestPermissions([
				'READ_MEDIA_IMAGES', 
				'READ_MEDIA_VIDEO', 
				'READ_MEDIA_AUDIO', 
				'READ_MEDIA_VISUAL_USER_SELECTED'
			]);
		}
		// Android 6-12 使用传统存储权限
		else if (AndroidVersion.SDK_INT >= AndroidVersionCode.M) // Android 6 (API 23)
		{
			AndroidPermissions.requestPermissions(['READ_EXTERNAL_STORAGE', 'WRITE_EXTERNAL_STORAGE']);
		}

		// Android 11+ 请求所有文件访问权限（如果需要）
		if (AndroidVersion.SDK_INT >= AndroidVersionCode.R && !AndroidEnvironment.isExternalStorageManager()) // Android 11 (API 30)
		{
			try 
			{
				AndroidSettings.requestSetting('MANAGE_APP_ALL_FILES_ACCESS_PERMISSION');
			}
			catch (e:Dynamic)
			{
				trace('Failed to request MANAGE_APP_ALL_FILES_ACCESS_PERMISSION: ${e.message}');
			}
		}

		// 检查权限状态
		var hasPermission = false;
		if (AndroidVersion.SDK_INT >= AndroidVersionCode.TIRAMISU)
		{
			hasPermission = AndroidPermissions.getGrantedPermissions().contains('android.permission.READ_MEDIA_IMAGES') ||
							AndroidPermissions.getGrantedPermissions().contains('android.permission.READ_MEDIA_AUDIO');
		}
		else if (AndroidVersion.SDK_INT >= AndroidVersionCode.M)
		{
			hasPermission = AndroidPermissions.getGrantedPermissions().contains('android.permission.READ_EXTERNAL_STORAGE');
		}
		else
		{
			hasPermission = true; // Android 6以下默认有权限
		}

		if (!hasPermission)
		{
			CoolUtil.showPopUp(LanguageBasic.getPhrase('permissions_message', 'If you accepted the permissions you are all good!\nIf you didn\'t then expect a crash\nPress OK to see what happens'),
				LanguageBasic.getPhrase('mobile_notice', "Notice!"));
		}

		// 创建应用存储目录
		try
		{
			var storageDir = StorageUtil.getStorageDirectory();
			if (!FileSystem.exists(storageDir))
				FileSystem.createDirectory(storageDir);
		}
		catch (e:Dynamic)
		{
			CoolUtil.showPopUp(LanguageBasic.getPhrase('create_directory_error', 'Please create directory to\n{1}\nPress OK to close the game', [StorageUtil.getStorageDirectory()]), LanguageBasic.getPhrase('mobile_error', "Error!"));
			lime.system.System.exit(1);
		}

		// 创建外部存储目录（如果可访问）
		try
		{
			var externalDir = StorageUtil.getExternalStorageDirectory();
			if (!FileSystem.exists(externalDir))
				FileSystem.createDirectory(externalDir);
				
			var modsDir = externalDir + 'mods';
			if (!FileSystem.exists(modsDir))
				FileSystem.createDirectory(modsDir);
		}
		catch (e:Dynamic)
		{
			// Android 12+ 可能无法访问外部存储，这是正常的
			trace('Could not create external storage directory (this is normal on Android 12+): ${e.message}');
		}
	}
	#end
	#end
}