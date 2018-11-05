; Thanks to https://github.com/ithinkso117/X330Backlight/blob/master/X330Backlight/Services/HotkeyService.cs#L73 for HKEvent ^ oldHKVal
; Add OutputDebug %newHKEvent% after it if you want to find out the value corresponding to one of your ThinkPad's hotkeys

#NoTrayIcon
#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
#KeyHistory 0
SetBatchLines, -1
ListLines, Off
SendMode, Input  ; Recommended for new scripts due to its superior speed and reliability.
SetFormat, IntegerFast, D
Process, Priority, , A
SetKeyDelay, -1, -1
SetWorkingDir %A_ScriptDir%  ; Ensures a consistent starting directory.
#Persistent

main(), return

main()
{
	global oldHKVal := 0

	if (!A_IsAdmin) {
		isUiAccess := True
		if (DllCall("Advapi32\OpenProcessToken", "Ptr", DllCall("GetCurrentProcess", "Ptr"), "UInt", TOKEN_QUERY := 0x0008, "Ptr*", hToken)) {
			DllCall("Advapi32\GetTokenInformation", "Ptr", hToken, "UInt", TokenUIAccess := 26, "UInt*", isUiAccess, "UInt", 4, "UInt*", dwLengthNeeded)
			DllCall("CloseHandle", "Ptr", hToken)
		}

		if (!isUiAccess) {
			if (DllCall("Shlwapi\AssocQueryString", "UInt", ASSOCF_INIT_IGNOREUNKNOWN := 0x00000400, "UInt", ASSOCSTR_COMMAND := 1, "Str", ".ahk", "Str", "uiAccess", "Ptr", 0, "UInt*", 0) == 1) {
				if not (RegExMatch(DllCall("GetCommandLine", "str"), " /restart(?!\S)")) {
					try if not A_IsCompiled
						Run *uiAccess "%A_ScriptFullPath%" /restart
					ExitApp
				}

			}
		}
	} else {
		; As you can see, shtctky.exe can be told to launch a program in response to pressing a hotkey, even with UIAccess capabilities if needed!
		; So, why not just use that to launch, say, an AHK script that just does Send Media_Next etc.?
		; I tend to press such keys in quick succession; starting 10+ AHK processes in response is not an efficient way to do it

		; SharpKeys remapping the keypresses shtctky sends out by default would have been the best option but it did not recognise the sequences

		; use procmon with the following filters to get the key names for your own ThinkPad when pressing:
		; Process Name is shtctky.exe then Include
		; Path begins with HKLM\SOFTWARE\Lenovo\ShortcutKey\AppLaunch then Include

		if (A_Is64bitOS && A_PtrSize == 4)
			SetRegView 64

		baseKey := "HKEY_LOCAL_MACHINE\SOFTWARE\Lenovo\ShortcutKey\AppLaunch\"
		for _, key in ["Ex_1D", "Ex_1E", "Ex_1F"] {
			keyKey := baseKey . key
			desktop := keyKey . "\Desktop"
			RegWrite, REG_DWORD, %keyKey%, AppType, 1
			RegWrite, REG_SZ, %desktop%, File, NUL
			RegWrite, REG_SZ, %desktop%, Parameters
		}

		SetRegView Default
	}

	RegRead, oldHKVal, HKEY_LOCAL_MACHINE, SYSTEM\CurrentControlSet\Services\IBMPMSVC\Parameters\Notification
	OnExit("AtExit")
	SetTimer, StartMonitoring, -0
}

StartMonitoring()
{
	global watchReg, oldHKVal
	static MsgWaitForMultipleObjectsEx := DllCall("GetProcAddress", "Ptr", DllCall("GetModuleHandleW", "WStr", "user32.dll", "Ptr"), "AStr", "MsgWaitForMultipleObjectsEx", "Ptr")
	static RegOpenKeyExW := DllCall("GetProcAddress", "Ptr", DllCall("GetModuleHandleW", "WStr", "advapi32.dll", "Ptr"), "AStr", "RegOpenKeyExW", "Ptr")
	static RegNotifyChangeKeyValue := DllCall("GetProcAddress", "Ptr", DllCall("GetModuleHandleW", "WStr", "advapi32.dll", "Ptr"), "AStr", "RegNotifyChangeKeyValue", "Ptr")
	static RegCloseKey := DllCall("GetProcAddress", "Ptr", DllCall("GetModuleHandleW", "WStr", "advapi32.dll", "Ptr"), "AStr", "RegCloseKey", "Ptr")

	HKEY_LOCAL_MACHINE_ := 0x80000002
	,KEY_NOTIFY := 0x0010
	,REG_NOTIFY_CHANGE_LAST_SET := 0x00000004

	watchKey := "SYSTEM\CurrentControlSet\Services\IBMPMSVC\Parameters\Notification"

	if (!(hEvent := DllCall("CreateEvent", "Ptr", 0, "Int", False, "Int", False, "Ptr", 0, "Ptr")))
		return

	watchReg := True

	while (watchReg) {
		if (DllCall(RegOpenKeyExW, "Ptr", HKEY_LOCAL_MACHINE_, "WStr", watchKey, "UInt", 0, "UInt", KEY_NOTIFY, "Ptr*", hKey := 0) != 0)
			break

		if (DllCall(RegNotifyChangeKeyValue, "Ptr", hKey, "Int", False, "Int", REG_NOTIFY_CHANGE_LAST_SET, "Ptr", hEvent, "Int", True) != 0) {
			DllCall(RegCloseKey, "Ptr", hKey)
			break
		}

		Loop {
			r := DllCall(MsgWaitForMultipleObjectsEx, "UInt", 1, "Ptr*", hEvent, "UInt", -1, "UInt", 0x4FF, "UInt", 0x6, "UInt")
			Sleep -1
		} until (!watchReg || r == 0 || r == 0xFFFFFFFF || r == 258)

		if (r == 0 && watchReg) {
			RegRead, HKEvent, HKEY_LOCAL_MACHINE, %watchKey%
			if (HKEvent != oldHKVal) {
				newHKEvent := HKEvent ^ oldHKVal

				if (newHKEvent == 536870912) {
					Send {Media_Prev}
				} else if (newHKEvent == 1073741824) {
					Send {Media_Play_Pause}
				} else if (newHKEvent == 2147483648) {
					Send {Media_Next}
				}

				oldHKVal := HKEvent
			}
		}

		DllCall(RegCloseKey, "Ptr", hKey)
	}

	DllCall("CloseHandle", "Ptr", hEvent)
}

AtExit()
{
	global watchReg
	Critical
	OnExit(A_ThisFunc, 0)

	if (watchReg) {
		watchReg := False
		PostMessage, 0x0000,,,, ahk_id %A_ScriptHwnd%
		SetTimer, StartMonitoring, Off
	}

	Critical Off
	return 0
}
