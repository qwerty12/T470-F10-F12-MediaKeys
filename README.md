# T470-F10-F12-MediaKeys
It is assumed you have the Lenovo Power Management driver installed.

1. Install [AutoHotkey](https://autohotkey.com/download/). I recommend choosing the advanced installation option and enabling the UIAccess option (be aware, however, this option adds a self-signed cert to the store). This will allow the script if non-elevated to send the media keypresses even if the foreground window belongs to an elevated/UIAccess program.

2. Using `regedit`, export/BACKUP! `HKEY_LOCAL_MACHINE\SOFTWARE\Lenovo\ShortcutKey\AppLaunch` somewhere.

3. Run this script as admin once so that it can add Registry entries to stop the Lenovo hotkey software from performing the original actions on Fn+F9,10,F11,F12. (NOTE: This may have to be repeated every time the Lenovo Hotkey software is upgraded)

4. Hit Win+R, run `shell:startup` and drop the script in there. If you have installed AHK with UIAccess support, the script will automatially relaunch itself accordingly.

Do Step 2 and backup that key mentioned; this script will stop the original key functions of Fn + F9 to F12.

X250 version here: https://github.com/qwerty12/T470-F10-F12-MediaKeys/blob/528240d5c1d8f162cce5bfd402e6142baaf8dc4c/X250%20Mediakeys.ahk
