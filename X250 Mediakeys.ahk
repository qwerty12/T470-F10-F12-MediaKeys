; Thanks to https://github.com/ithinkso117/X330Backlight/blob/master/X330Backlight/Services/HotkeyService.cs#L73 for HKEvent ^ oldHKVal
; Add OutputDebug %newHKEvent% after it if you want to find out the value corresponding to one of your ThinkPad's hotkeys

; Some DllCall constants:
	;SYNCHRONIZE := 0x00100000
	;,HKEY_LOCAL_MACHINE_ := 0x80000002
	;,KEY_QUERY_VALUE := 0x0001
	;,KEY_NOTIFY := 0x0010
	;,REG_NOTIFY_CHANGE_LAST_SET := 0x00000004
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
#SingleInstance Off

main(), return

main()
{
	if (!A_IsUnicode) {
		MsgBox This script must be ran with a Unicode build of AutoHotkey
		ExitApp 1
	}

	if (!A_IsAdmin) {
		if not A_IsCompiled {
			isUiAccess := True
			if (DllCall("advapi32\OpenProcessToken", "Ptr", DllCall("GetCurrentProcess", "Ptr"), "UInt", TOKEN_QUERY := 0x0008, "Ptr*", hToken)) {
				DllCall("advapi32\GetTokenInformation", "Ptr", hToken, "UInt", TokenUIAccess := 26, "UInt*", isUiAccess, "UInt", 4, "UInt*", dwLengthNeeded)
				,DllCall("CloseHandle", "Ptr", hToken)
			}

			if (!isUiAccess) {
				if (DllCall("shlwapi\AssocQueryString", "UInt", ASSOCF_INIT_IGNOREUNKNOWN := 0x00000400, "UInt", ASSOCSTR_COMMAND := 1, "Str", ".ahk", "Str", "uiAccess", "Ptr", 0, "UInt*", 0) == 1) {
					if not (RegExMatch(DllCall("GetCommandLine", "str"), " /restart(?!\S)")) {
						try {
							Run *uiAccess "%A_ScriptFullPath%" /restart
							ExitApp
						}
					}
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
		for _, key in ["Ex_1C", "Ex_93", "Ex_94", "Ex_90"] {
			keyKey := baseKey . key
			,desktop := keyKey . "\Desktop"

			RegDelete %keyKey%
			RegWrite, REG_DWORD, %keyKey%, AppType, 1
			RegWrite, REG_SZ, %desktop%, File, NUL
			RegWrite, REG_SZ, %desktop%, Parameters
		}

		SetRegView Default
	}

	;DllCall("ChangeWindowMessageFilterEx", "ptr", A_ScriptHwnd, "uint", 0x44 , "uint", 1, "ptr", 0) ; https://autohotkey.com/boards/viewtopic.php?p=159849#p159849

	OnExit("AtExit")
	,StartWTSMonitoring()
	SetTimer, StartMonitoring, -0
}

StartMonitoring()
{
	global watchReg := True, inScriptSession, onScriptDesktop
	ConEmuDir := A_ProgramFiles . "\ConEmu"
	,ConEmuExe := ConEmuDir . "\ConEmu64.exe"

	Type13 := "Type13"
	,PARAMETERS := 1
	,PARAMETERS2 := 2

	szKeys := []
	,handles := []
	,oldVals := []
	,hKeys := []

	szKeys[PARAMETERS] := "SYSTEM\CurrentControlSet\Services\IBMPMSVC\Parameters\Notification"
	szKeys[PARAMETERS2] := "SYSTEM\CurrentControlSet\Services\IBMPMSVC\Parameters2\Type10\Notification"
	Loop % szKeys.MaxIndex() {
		if (!(handles[A_Index] := DllCall("CreateEvent", "Ptr", 0, "Int", False, "Int", False, "Ptr", 0, "Ptr")))
			ExitApp 1
		RegRead, _, HKEY_LOCAL_MACHINE, % szKeys[A_Index], % A_Index == PARAMETERS2 ? "Type13" : ""
		oldVals[A_Index] := _
		hKeys[A_Index] := 0
	}

	if ((_ := DllCall("OpenEvent", "UInt", 0x00100000, "Int", False, "Str", "WinSta0_DesktopSwitch", "Ptr")))
		handles.Push(_)

	dwHandleCount := handles.MaxIndex()
	,VarSetCapacity(handlesArr, dwHandleCount * A_PtrSize)
	for i, hEvent in handles
		NumPut(hEvent, handlesArr, (i - 1) * A_PtrSize, "Ptr")

	Loop
	{
		Loop % hKeys.MaxIndex() {
			If (!hKeys[A_Index]) {
				If DllCall("advapi32\RegOpenKeyExW", "Ptr", 0x80000002, "Ptr", szKeys.GetAddress(A_Index), "UInt", 0, "UInt", 0x0011, "Ptr*", _) != 0
					Break 2
				If DllCall("advapi32\RegNotifyChangeKeyValue", "Ptr", _, "Int", False, "Int", 0x00000004, "Ptr", handles[A_Index], "Int", 1) != 0
					Break 2
				hKeys[A_Index] := _
			}
		}

		Loop {
			r := DllCall("MsgWaitForMultipleObjectsEx", "UInt", dwHandleCount, "Ptr", &handlesArr, "UInt", -1, "UInt", 0x4FF, "UInt", 0x6)
			Sleep -1
			If (r < dwHandleCount)
				Break
			If (r = -1 || !watchReg)
				Break 2
		}

		r++
		If (r == PARAMETERS || r == PARAMETERS2) {
			If DllCall("advapi32\RegQueryValueExW", "Ptr", hKeys[r], "Ptr", r == PARAMETERS2 ? &Type13 : 0, "Ptr", 0, "Ptr", 0, "UInt*", HKEvent, "UInt*", 4) != 0
			{
				DllCall("advapi32\RegCloseKey", "Ptr", hKeys[r]), hKeys[r] := 0
				RegRead, HKEvent, HKEY_LOCAL_MACHINE, % szKeys[r], % r == PARAMETERS2 ? "Type13" : ""
			}

			If (HKEvent != oldVals[r]) {
				If inScriptSession
				{
					newHKEvent := HKEvent ^ oldVals[r]

					If (r == PARAMETERS) {
						If (newHKEvent = 268435456 && onScriptDesktop) {
							If (DllCall("FindWindowW", "WStr", "VirtualConsoleClass", "Ptr", 0)) {
								Send ^'
							} Else {
								/*
								If (A_IsAdmin) {
									If (DllCall("FindWindowW", "WStr", "Shell_TrayWnd", "Ptr", 0))
										ShellRun(ConEmuExe,, ConEmuDir)
									Else
										WdcRunTaskAsInteractiveUser(ConEmuExe, ConEmuDir)
								} Else {
								*/
									Run %ConEmuExe%, %ConEmuDir%, UseErrorLevel
								;}
							}
						}
					} Else {
						If (newHKEvent == 1048576) {
							MusicControl("Media_Play_Pause", !onScriptDesktop)
						} Else If (newHKEvent == 65536) {
							MusicControl("Media_Next", !onScriptDesktop)
						} Else If (newHKEvent == 524288) {
							MusicControl("Media_Prev", !onScriptDesktop)
						}
					}

					If (newHKEvent == 0) {
						Run *open %A_ScriptFullPath%,, UseErrorLevel
						DllCall("TerminateProcess", "Ptr", -1, "UInt", 1)
					}
				}

				oldVals[r] := HKEvent
			}

			If DllCall("advapi32\RegNotifyChangeKeyValue", "Ptr", hKeys[r], "Int", False, "Int", 0x00000004, "Ptr", handles[r], "Int", 1) != 0
				Break

			Continue
		}

		If (r == PARAMETERS2 + 1) {
			onScriptDesktop := IsDesktopActive()
			Loop % hKeys.MaxIndex()
				DllCall("advapi32\RegCloseKey", "Ptr", hKeys[A_Index]), hKeys[A_Index] := 0
		}
	}

	for _, hKey in hKeys
		DllCall("CloseHandle", "Ptr", hKey)

	for _, hEvent in handles
		DllCall("CloseHandle", "Ptr", hEvent)
	
	ExitApp 1
}

IsDesktopActive()
{
	global scriptDesktopName
	static currentDesktopName
	
	ret := False
	if !VarSetCapacity(currentDesktopName)
		VarSetCapacity(currentDesktopName, 64)

	If hDesk := DllCall("OpenInputDesktop", "UInt", 0, "Int", False, "UInt", 0, "Ptr") {
		ret := GetUserObjectName(hDesk, currentDesktopName) && currentDesktopName == scriptDesktopName
		,DllCall("CloseDesktop", "Ptr", hDesk)
	}
	
	return ret
}

ManualDesktopSessionCheck()
{
	global inScriptSession, scriptSessionID, onScriptDesktop

	inScriptSession := scriptSessionID == DllCall("WTSGetActiveConsoleSessionId", "UInt")
	,onScriptDesktop := IsDesktopActive()
}

WM_WTSSESSION_CHANGEcb(wParam, lParam)
{
	global scriptSessionID, inScriptSession

	if (wParam == 1) ; WTS_CONSOLE_CONNECT
		inScriptSession := scriptSessionID == lParam
}

StartWTSMonitoring()
{
	global WM_WTSSESSION_CHANGE := 0x2B1, scriptSessionID, hModuleWtsapi, scriptDesktopName
	DllCall("ProcessIdToSessionId", "UInt", DllCall("GetCurrentProcessId", "UInt"), "UInt*", scriptSessionID)
	if ((hDesk := DllCall("GetThreadDesktop", "UInt", DllCall("GetCurrentThreadId", "UInt"), "Ptr"))) 
		GetUserObjectName(hDesk, scriptDesktopName)
	ManualDesktopSessionCheck()

	if ((hModuleWtsapi := DllCall("LoadLibrary", "Str", "wtsapi32.dll", "Ptr"))) {
		if (DllCall("wtsapi32\WTSRegisterSessionNotification", "Ptr", A_ScriptHwnd, "UInt", NOTIFY_FOR_ALL_SESSIONS := 1))
			OnMessage(WM_WTSSESSION_CHANGE, "WM_WTSSESSION_CHANGEcb")
		else
			DllCall("FreeLibrary", "Ptr", hModuleWtsapi), hModuleWtsapi := 0
	}
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
		,OnMessage(WM_WTSSESSION_CHANGE, "")
		,DllCall("FreeLibrary", "Ptr", hModuleWtsapi), hModuleWtsapi := 0
	}

	Critical Off
	return 0
}
