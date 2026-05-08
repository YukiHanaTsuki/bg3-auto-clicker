#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent

; 全局变量
global pos1 := "", pos2 := "", nextPos := 1, running := false
global cfgKeyPos1 := "F1", cfgKeyPos2 := "F2", cfgKeyToggle := "F3", cfgInterval := 400
global SettingsGui := 0, gStatusText := ""
global IniFile := A_ScriptDir "\ClickerSettings.ini"

; 只读编辑框引用
global gEdPos1 := 0, gEdPos2 := 0, gEdToggle := 0

; 捕获相关变量
global capTargetEdit := "", capHotkey := "", capRow := "", capText := "", capBtnCancel := ""
global capOldIMC := 0, capOldOpenStatus := 0

; ==================== 设置文件处理 ====================
LoadSettings() {
    global cfgKeyPos1, cfgKeyPos2, cfgKeyToggle, cfgInterval
    cfgKeyPos1 := IniRead(IniFile, "Settings", "KeyPos1", "F1")
    cfgKeyPos2 := IniRead(IniFile, "Settings", "KeyPos2", "F2")
    cfgKeyToggle := IniRead(IniFile, "Settings", "KeyToggle", "F3")
    cfgInterval := IniRead(IniFile, "Settings", "Interval", 400)
}

SaveSettings() {
    global cfgKeyPos1, cfgKeyPos2, cfgKeyToggle, cfgInterval
    IniWrite(cfgKeyPos1, IniFile, "Settings", "KeyPos1")
    IniWrite(cfgKeyPos2, IniFile, "Settings", "KeyPos2")
    IniWrite(cfgKeyToggle, IniFile, "Settings", "KeyToggle")
    IniWrite(cfgInterval, IniFile, "Settings", "Interval")
}

; ==================== 核心功能 ====================
RecordPos1(*) {
    MouseGetPos(&x, &y)
    global pos1 := x "," y
    ToolTip("✅ 位置1已记录: " pos1)
    SetTimer(() => ToolTip(), -1500)
}

RecordPos2(*) {
    MouseGetPos(&x, &y)
    global pos2 := x "," y
    ToolTip("✅ 位置2已记录: " pos2)
    SetTimer(() => ToolTip(), -1500)
}

ToggleClick(*) {
    global pos1, pos2, running, nextPos, cfgInterval, cfgKeyToggle
    if (pos1 = "" or pos2 = "") {
        MsgBox("请先用记录键记录两个位置！", "提示", "Icon!")
        return
    }
    running := !running
    if (running) {
        nextPos := 1
        SetTimer(ClickLoop, cfgInterval)
        ToolTip("▶ 交替点击中... (按 " cfgKeyToggle " 停止)")
    } else {
        SetTimer(ClickLoop, 0)
        ToolTip("⏸ 已停止")
        SetTimer(() => ToolTip(), -1500)
    }
}

ClickLoop() {
    global pos1, pos2, nextPos
    if (nextPos = 1) {
        coords := StrSplit(pos1, ",")
        try MouseClick("Left", Integer(coords[1]), Integer(coords[2]))
        nextPos := 2
    } else {
        coords := StrSplit(pos2, ",")
        try MouseClick("Left", Integer(coords[1]), Integer(coords[2]))
        nextPos := 1
    }
}

; ==================== 热键绑定管理 ====================
BindHotkeys(keyPos1, keyPos2, keyToggle) {
    static old1 := "", old2 := "", old3 := ""
    if (old1 != "" and old1 != keyPos1)
        Hotkey(old1, "Off")
    if (old2 != "" and old2 != keyPos2)
        Hotkey(old2, "Off")
    if (old3 != "" and old3 != keyToggle)
        Hotkey(old3, "Off")
    try {
        Hotkey(keyPos1, RecordPos1, "On")
        old1 := keyPos1
    } catch as e {
        MsgBox("热键 " keyPos1 " 无效: " e.Message, "错误", "Icon!")
        return false
    }
    try {
        Hotkey(keyPos2, RecordPos2, "On")
        old2 := keyPos2
    } catch as e {
        MsgBox("热键 " keyPos2 " 无效: " e.Message, "错误", "Icon!")
        return false
    }
    try {
        Hotkey(keyToggle, ToggleClick, "On")
        old3 := keyToggle
    } catch as e {
        MsgBox("热键 " keyToggle " 无效: " e.Message, "错误", "Icon!")
        return false
    }
    return true
}

; ==================== 捕获功能 ====================
StartCapture(editCtrl) {
    global capTargetEdit, capRow, capHotkey, capText, capBtnCancel, gStatusText, SettingsGui
    global capOldIMC, capOldOpenStatus, gEdPos1, gEdPos2, gEdToggle
    global cfgKeyPos1, cfgKeyPos2, cfgKeyToggle

    if (capTargetEdit != "")
        CapCancel()
    capTargetEdit := editCtrl

    Hotkey(cfgKeyPos1, "Off"), Hotkey(cfgKeyPos2, "Off"), Hotkey(cfgKeyToggle, "Off"), Hotkey("Esc", "Off")

    if (SettingsGui) {
        hIMC := DllCall("imm32\ImmGetContext", "ptr", SettingsGui.Hwnd, "ptr")
        if (hIMC) {
            capOldIMC := hIMC
            capOldOpenStatus := DllCall("imm32\ImmGetOpenStatus", "ptr", hIMC)
            if (capOldOpenStatus)
                DllCall("imm32\ImmSetOpenStatus", "ptr", hIMC, "int", 0)
        }
    }

    gEdPos1.Opt("-TabStop"), gEdPos2.Opt("-TabStop"), gEdToggle.Opt("-TabStop")

    capRow.Visible := true, capText.Visible := true, capHotkey.Visible := true, capBtnCancel.Visible := true
    capHotkey.Value := "", Sleep(10), capHotkey.Focus()
    gStatusText.Value := "请按下要设置的按键..."
}

CapAutoConfirm(*) {
    global capHotkey, capTargetEdit, gStatusText
    if (capTargetEdit = "")
        return
    rawKey := capHotkey.Value
    if (rawKey = "")
        return
    keyName := rawKey
    if (SubStr(rawKey, 1, 2) = "vk") {
        keyName := GetKeyName(rawKey)
        if (keyName = "")
            keyName := rawKey
    }
    if (keyName ~= "i)^(Ctrl|Shift|Alt|LWin|RWin)$")
        return
    keyName := StrUpper(keyName)
    capTargetEdit.Value := keyName
    gStatusText.Value := "✅ 按键已设置为: " keyName
    CapCancel()
}

CapCancel(*) {
    global capTargetEdit, capRow, capText, capHotkey, capBtnCancel, capOldIMC, capOldOpenStatus
    global gEdPos1, gEdPos2, gEdToggle, cfgKeyPos1, cfgKeyPos2, cfgKeyToggle

    capRow.Visible := false, capText.Visible := false, capHotkey.Visible := false, capBtnCancel.Visible := false
    capTargetEdit := ""

    if (capOldIMC) {
        if (capOldOpenStatus)
            DllCall("imm32\ImmSetOpenStatus", "ptr", capOldIMC, "int", 1)
        DllCall("imm32\ImmReleaseContext", "ptr", capOldIMC)
        capOldIMC := 0
    }

    gEdPos1.Opt("+TabStop"), gEdPos2.Opt("+TabStop"), gEdToggle.Opt("+TabStop")

    Hotkey(cfgKeyPos1, RecordPos1, "On"), Hotkey(cfgKeyPos2, RecordPos2, "On")
    Hotkey(cfgKeyToggle, ToggleClick, "On"), Hotkey("Esc", (*) => ExitApp(), "On")
}

; ==================== 设置窗口 ====================
ShowSettings(*) {
    global SettingsGui, cfgKeyPos1, cfgKeyPos2, cfgKeyToggle, cfgInterval, gStatusText
    global capRow, capHotkey, capText, capBtnCancel, gEdPos1, gEdPos2, gEdToggle

    if (SettingsGui) {
        try SettingsGui.Show("NA")
        return
    }

    SettingsGui := Gui("+AlwaysOnTop +ToolWindow", "连点器设置")
    SettingsGui.SetFont("s10", "Microsoft YaHei")

    SettingsGui.Add("Text", "section", "记录位置1的按键:")
    gEdPos1 := SettingsGui.Add("Edit", "x+m yp-3 w80 ReadOnly", cfgKeyPos1)
    btnCap1 := SettingsGui.Add("Button", "x+m yp-3 w60", "捕获")
    btnCap1.OnEvent("Click", (*) => StartCapture(gEdPos1))

    SettingsGui.Add("Text", "xs", "记录位置2的按键:")
    gEdPos2 := SettingsGui.Add("Edit", "x+m yp-3 w80 ReadOnly", cfgKeyPos2)
    btnCap2 := SettingsGui.Add("Button", "x+m yp-3 w60", "捕获")
    btnCap2.OnEvent("Click", (*) => StartCapture(gEdPos2))

    SettingsGui.Add("Text", "xs", "开始/停止按键:")
    gEdToggle := SettingsGui.Add("Edit", "x+m yp-3 w80 ReadOnly", cfgKeyToggle)
    btnCap3 := SettingsGui.Add("Button", "x+m yp-3 w60", "捕获")
    btnCap3.OnEvent("Click", (*) => StartCapture(gEdToggle))

    SettingsGui.Add("Text", "xs", "点击间隔(毫秒):")
    edInterval := SettingsGui.Add("Edit", "x+m yp-3 w80", cfgInterval)

    SettingsGui.Add("Text", "xs w300", "点击「捕获」后按下按键自动填入")

    capRow := SettingsGui.Add("GroupBox", "xs w300 h70", "按键捕获")
    capText := SettingsGui.Add("Text", "xp+10 yp+20", "请按下按键(会自动填入):")
    capHotkey := SettingsGui.Add("Hotkey", "x+m yp-3 w120")
    capHotkey.OnEvent("Change", CapAutoConfirm)
    capBtnCancel := SettingsGui.Add("Button", "x+m yp w60", "取消")
    capBtnCancel.OnEvent("Click", CapCancel)

    capRow.Visible := false, capText.Visible := false, capHotkey.Visible := false, capBtnCancel.Visible := false

    gStatusText := SettingsGui.Add("Text", "xs w300 cBlue", "")

    btnApply := SettingsGui.Add("Button", "xs w170", "应用并更新热键")
    btnApply.OnEvent("Click", ApplySettings)

    SettingsGui.OnEvent("Close", (*) => (
        CapCancel(), SettingsGui.Destroy(), SettingsGui := 0
    ))
    SettingsGui.Show()

    ApplySettings(*) {
        global SettingsGui, cfgKeyPos1, cfgKeyPos2, cfgKeyToggle, cfgInterval, running, gStatusText
        newPos1 := gEdPos1.Value, newPos2 := gEdPos2.Value, newToggle := gEdToggle.Value, newInterval := edInterval.Value

        if (!IsInteger(newInterval) or newInterval < 1) {
            gStatusText.Value := "❌ 间隔必须是正整数（毫秒）"
            return
        }

        if (BindHotkeys(newPos1, newPos2, newToggle)) {
            cfgKeyPos1 := newPos1, cfgKeyPos2 := newPos2, cfgKeyToggle := newToggle, cfgInterval := Integer(newInterval)
            SaveSettings()
            if (running) {
                SetTimer(ClickLoop, 0)
                SetTimer(ClickLoop, cfgInterval)
            }
            gStatusText.Value := "✅ 设置已应用，窗口即将关闭"
            Sleep(400)
            SettingsGui.Destroy(), SettingsGui := 0
        } else {
            gStatusText.Value := "❌ 热键设置失败，请检查按键格式"
        }
    }
}

; ==================== 初始化 ====================
LoadSettings()
BindHotkeys(cfgKeyPos1, cfgKeyPos2, cfgKeyToggle)

tray := A_TrayMenu
tray.Delete()
tray.Add("打开设置", ShowSettings)
tray.Add("退出", (*) => ExitApp())
tray.Default := "打开设置"

Hotkey("Esc", (*) => ExitApp(), "On")