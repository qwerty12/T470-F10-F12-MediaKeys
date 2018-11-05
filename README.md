# X250-F10-F12-MediaKeys
Running Windows and yearning for dedidated media keys like on the ThinkPads of old? Fret no longer!

It is assumed you have the Lenovo Power Management driver installed.

1. Install [AutoHotkey](https://autohotkey.com/download/). NOTE: Unless your Windows account is a non-administrative one, and you never run any elevated programs, or always plan to run this script elevated/as an administrator, I strongly recommend choosing the advanced installation option and enabling the UIAccess option. This will allow the script to send the media keypresses even if the foreground window belongs to an elevated/UIAccess program.

2. Optionally, using `regedit`, export `HKEY_LOCAL_MACHINE\SOFTWARE\Lenovo\ShortcutKey\AppLaunch` somewhere.

3. Run this script elevated once so that it can add Registry entries to stop the Lenovo hotkey software from performing the original actions on Fn+F10,F11,F12. (NOTE: This may have to be repeated every time the Lenovo Hotkey software is upgraded)

4. Hit Win+R, run `shell:startup` and drop the script in there. If you have installed AHK with UIAccess support, the script will automatially relaunch itself accordingly.
