#SingleInstance Force
#Persistent

Gui, +AlwaysOnTop
Gui, Add, Text,, ============Roblox Virtual Piano In-Game Styled Autoplayer (v 1.2)============
Gui, Add, Text,, -----------------------------------------------PASTE SHEETS HERE------------------------------------------------
Gui, Add, Edit, R10 w400 vPianoMusic gSheetChanged
Gui, Add, Text,, Keybinds: - (Minus), = (Equals), [ (Left Bracket), ] (Right Bracket)
Gui, Add, Text,, Click the "Play" button to activate the keybinds. Click "Stop" to deactivate.
Gui, Add, Text,, Press the keybinds to begin autoplaying. You'll need to play by rhythm.
Gui, Add, Text,, Based on the old AutoHotkey Roblox Piano Autoplayer (the one with F4 and F8)
Gui, Add, Text,, (This also works in Virtual Pianos outside of Roblox Virtual Piano games.)
Gui, Add, Text,, Modifications done by: Crimsxn K1ra
Gui, Add, Text,, ------------------------------------------------------------Progress------------------------------------------------------------
Gui, Add, Edit, ReadOnly w400 vNextNotes
Gui, Add, Button, vTogglePlayStopButton gTogglePlayStop, Play
Gui, Show

PianoMusic := ""
CurrentPos := 1
DisplayPos := 1
KeyPressStartTime := 0
KeyDelay := 0.1
isPlaying := false

Suspend, On

PlayNextNote()
{
    global PianoMusic, CurrentPos, DisplayPos, KeyDelay, KeyPressStartTime
    Gui, Submit, Nohide
    DisplayMusic := PianoMusic
    PianoMusic := RegExReplace(PianoMusic, "`n|`r|/| ")

    if (CurrentPos > StrLen(PianoMusic))
    {
        CurrentPos := 1
        DisplayPos := 1
    }

    if (CurrentPos <= StrLen(PianoMusic) && A_TickCount - KeyPressStartTime < 3000)
    {
        if (RegExMatch(PianoMusic, "U)(\[.*]|.)", Keys, CurrentPos))
        {
            CurrentPos += StrLen(Keys)

            while (DisplayPos <= StrLen(DisplayMusic) && InStr(" `n`r/", SubStr(DisplayMusic, DisplayPos, 1)))
                DisplayPos++

            DisplayPos += StrLen(Keys)

            Keys := Trim(Keys, "[]")
            SendInput, {Raw}%Keys%

            NextNotes := SubStr(DisplayMusic, DisplayPos, 90)
            GuiControl,, NextNotes, %NextNotes%
            
            Sleep, %KeyDelay%
        }
    }
}

-::
=::
[::
]::
    KeyPressStartTime := A_TickCount
    PlayNextNote()
    KeyPressStartTime := 0
return

TogglePlayStop:
    isPlaying := !isPlaying
    if (isPlaying)
    {
        Suspend, Off
        GuiControl,, TogglePlayStopButton, Stop
    }
    else
    {
        Suspend, On
        GuiControl,, TogglePlayStopButton, Play
        CurrentPos := 1
        DisplayPos := 1
        GuiControl,, NextNotes
    }
return

SheetChanged:
    Gui, Submit, Nohide
    CurrentPos := 1
    DisplayPos := 1
    GuiControl,, NextNotes
return

GuiClose:
    ExitApp
