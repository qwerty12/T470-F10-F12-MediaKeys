; Thanks to https://github.com/ithinkso117/X330Backlight/blob/master/X330Backlight/Services/HotkeyService.cs#L73 for HKEvent ^ oldHKVal
; Add OutputDebug %newHKEvent% after it if you want to find out the value corresponding to one of your ThinkPad's hotkeys

;#NoTrayIcon
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
#SingleInstance Force

main(), return

main()
{
	if (!A_IsAdmin) {
		isUiAccess := True
		if (DllCall("advapi32\OpenProcessToken", "Ptr", DllCall("GetCurrentProcess", "Ptr"), "UInt", TOKEN_QUERY := 0x0008, "Ptr*", hToken)) {
			DllCall("advapi32\GetTokenInformation", "Ptr", hToken, "UInt", TokenUIAccess := 26, "UInt*", isUiAccess, "UInt", 4, "UInt*", dwLengthNeeded)
			DllCall("CloseHandle", "Ptr", hToken)
		}

		if (!isUiAccess) {
			if (DllCall("shlwapi\AssocQueryString", "UInt", ASSOCF_INIT_IGNOREUNKNOWN := 0x00000400, "UInt", ASSOCSTR_COMMAND := 1, "Str", ".ahk", "Str", "uiAccess", "Ptr", 0, "UInt*", 0) == 1) {
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

			RegDelete %keyKey%
			RegWrite, REG_DWORD, %keyKey%, AppType, 1
			RegWrite, REG_SZ, %desktop%, File, NUL
			RegWrite, REG_SZ, %desktop%, Parameters
		}

		SetRegView Default
	}

	if (!A_IsUnicode) {
		MsgBox This script must be ran with a Unicode build of AutoHotkey
		ExitApp 1
	}
	
	OnExit("AtExit")
	,StartWTSMonitoring()
	SetTimer, StartMonitoring, -0
}

StartMonitoring()
{
	global watchReg, inScriptSession

	SYNCHRONIZE := 0x00100000
	;,HKEY_LOCAL_MACHINE_ := 0x80000002
	;,KEY_QUERY_VALUE := 0x0001
	;,KEY_NOTIFY := 0x0010
	;,REG_NOTIFY_CHANGE_LAST_SET := 0x00000004

	watchKey := "SYSTEM\CurrentControlSet\Services\IBMPMSVC\Parameters\Notification"
	,oldHKVal := 0

	RegRead, oldHKVal, HKEY_LOCAL_MACHINE, %watchKey%

	if ((hDesk := DllCall("GetThreadDesktop", "UInt", DllCall("GetCurrentThreadId", "UInt"), "Ptr"))) 
		GetUserObjectName(hDesk, scriptDesktopName)
	VarSetCapacity(currentDesktopName, 64)

	handles := []

	if (!(hRegEvent := DllCall("CreateEvent", "Ptr", 0, "Int", False, "Int", False, "Ptr", 0, "Ptr")))
		ExitApp 1

	handles.Push(hRegEvent)
		
	if ((hEvent := DllCall("OpenEvent", "UInt", SYNCHRONIZE, "Int", False, "Str", "WinSta0_DesktopSwitch", "Ptr")))
		handles.Push(hEvent)

	dwHandleCount := handles.MaxIndex()
	VarSetCapacity(handlesArr, dwHandleCount * A_PtrSize)
	for i, hEvent in handles
		NumPut(hEvent, handlesArr, (i - 1) * A_PtrSize, "Ptr")

	handles := hEvent := hDesk := ""

	; TODO: determine onScriptDesktop by calling OpenInputDesktop
	onScriptDesktop := True, watchReg := True, hKey := 0

	Loop
	{
		If !hKey
		{
			if DllCall("advapi32\RegOpenKeyExW", "Ptr", 0x80000002, "Ptr", &watchKey, "UInt", 0, "UInt", 0x0011, "Ptr*", hKey) != 0
				Break
			Else
				r := 0
		}

		If (r == 0 && DllCall("advapi32\RegNotifyChangeKeyValue", "Ptr", hKey, "Int", 0, "Int", 0x00000004, "Ptr", hRegEvent, "Int", 1) != 0)
		{
			DllCall("advapi32\RegCloseKey", "Ptr", hKey)
			Break
		}

		Loop {
			r := DllCall("MsgWaitForMultipleObjectsEx", "UInt", dwHandleCount, "Ptr", &handlesArr, "UInt", -1, "UInt", 0x4FF, "UInt", 0x6)
			If r < dwHandleCount || r = -1 || !watchReg
				Break
			Sleep -1
		}

		If watchReg
		{
			If r = 0
			{
				If DllCall("advapi32\RegQueryValueExW", "Ptr", hKey, "Ptr", 0, "Ptr", 0, "Ptr", 0, "UInt*", HKEvent, "UInt*", 4) != 0
				{
					DllCall("advapi32\RegCloseKey", "Ptr", hKey), hKey := 0
					RegRead, HKEvent, HKEY_LOCAL_MACHINE, %watchKey%
				}

				If HKEvent = oldHKVal
					Continue

				If (inScriptSession && onScriptDesktop)
				{
					newHKEvent := HKEvent ^ oldHKVal

					If (newHKEvent == 1073741824) {
						Send {Media_Play_Pause}
					} Else If (newHKEvent == 2147483648) {
						Critical 1000
						Send {Media_Next}
						Critical Off
					} Else If (newHKEvent == 536870912) {
						Critical 1000
						Send {Media_Prev}
						Critical Off
					}
				}

				oldHKVal := HKEvent
				Continue
			}
			
			If r = 1
			{
				If (hDesk := DllCall("OpenInputDesktop", "UInt", 0, "Int", False, "UInt", 0, "Ptr")) {
					onScriptDesktop := GetUserObjectName(hDesk, currentDesktopName) && currentDesktopName == scriptDesktopName
					DllCall("CloseDesktop", "Ptr", hDesk)
				} Else onScriptDesktop := False
				
				DllCall("advapi32\RegCloseKey", "Ptr", hKey), hKey := 0
				Continue
			}
		} Else {
			DllCall("advapi32\RegCloseKey", "Ptr", hKey), hKey := 0
			Break
		}
	}

	Loop %dwHandleCount%
		DllCall("CloseHandle", "Ptr", NumGet(handlesArr, (A_Index - 1) * A_PtrSize, "Ptr"))
	
	ExitApp 1
}

StartWTSMonitoring()
{
	global WM_WTSSESSION_CHANGE := 0x2B1, scriptSessionID, inScriptSession, hModuleWtsapi
	DllCall("ProcessIdToSessionId", "UInt", DllCall("GetCurrentProcessId", "UInt"), "UInt*", scriptSessionID)
	inScriptSession := scriptSessionID == DllCall("WTSGetActiveConsoleSessionId", "UInt")

	if ((hModuleWtsapi := DllCall("LoadLibrary", "Str", "wtsapi32.dll", "Ptr"))) {
		if (DllCall("wtsapi32\WTSRegisterSessionNotification", "Ptr", A_ScriptHwnd, "UInt", NOTIFY_FOR_ALL_SESSIONS := 1))
			OnMessage(WM_WTSSESSION_CHANGE, "WM_WTSSESSION_CHANGEcb")
		else
			DllCall("FreeLibrary", "Ptr", hModuleWtsapi), hModuleWtsapi := 0
	}
}

WM_WTSSESSION_CHANGEcb(wParam, lParam)
{
	Critical
	global scriptSessionID, inScriptSession

	if (wParam == 1) ; WTS_CONSOLE_CONNECT
		inScriptSession := scriptSessionID == lParam

	Critical Off
}

GetUserObjectName(hObj, ByRef out)
{
	nLengthNeeded := VarSetCapacity(out)

	if (!(ret := DllCall("GetUserObjectInformationW", "Ptr", hObj, "Int", 2, "WStr", out, "UInt", nLengthNeeded, "UInt*", nLengthNeeded))) ; UOI_NAME
		if (A_LastError == 122 && VarSetCapacity(out, nLengthNeeded)) ; ERROR_INSUFFICIENT_BUFFER
			ret := DllCall("GetUserObjectInformationW", "Ptr", hObj, "Int", 2, "WStr", out, "UInt", nLengthNeeded, "Ptr", 0)

	return ret
}

AtExit()
{
	global watchReg, hModuleWtsapi, WM_WTSSESSION_CHANGE
	Critical
	OnExit(A_ThisFunc, 0)

	if (watchReg) {
		watchReg := False
		PostMessage, 0x0000,,,, ahk_id %A_ScriptHwnd%
		SetTimer, StartMonitoring, Off
	}

	if (hModuleWtsapi) {
		DllCall("wtsapi32\WTSUnRegisterSessionNotification", "Ptr", A_ScriptHwnd)
		OnMessage(WM_WTSSESSION_CHANGE, "")
		DllCall("FreeLibrary", "Ptr", hModuleWtsapi), hModuleWtsapi := 0
	}

	Critical Off
	return 0
}
