; Roblox Virtual Piano autoplayer, ported to the legacy (v1.0.24) syntax that AHK_X11 understands.
; Original script: auto_piano.ahk (v1.2). Same behaviour, but no functions or expressions:
; the old PlayNextNote() function is now the PlayNextNote: subroutine.
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

PianoMusic =
CurrentPos = 1
DisplayPos = 1
isPlaying = 0
SkipChars = %A_Space%/`n`r

Suspend, On
Return

PlayNextNote:
    Gui, Submit, Nohide
    DisplayMusic = %PianoMusic%
    ; strip newlines, slashes and spaces (a space is written as [ ] so trimming can't eat it)
    RegExReplace, Music, PianoMusic, \n|\r|/|[ ], , all
    StringLen, Len, Music
    StringLen, DisplayLen, DisplayMusic

    If CurrentPos > %Len%
    {
        CurrentPos = 1
        DisplayPos = 1
    }
    If CurrentPos > %Len%
        Return

    ; next note: either a single character or a [chord]
    StringMid, Char, Music, %CurrentPos%, 1
    Keys = %Char%
    If Char = [
    {
        Pos = %CurrentPos%
        Loop
        {
            Pos += 1
            If Pos > %Len%
            {
                Break
            }
            StringMid, C2, Music, %Pos%, 1
            If C2 = ]
            {
                Count = %Pos%
                Count -= %CurrentPos%
                Count += 1
                StringMid, Keys, Music, %CurrentPos%, %Count%
                Break
            }
        }
    }

    StringLen, KeysLen, Keys
    CurrentPos += %KeysLen%

    ; move the display position past skipped characters, then past the note
    Loop
    {
        If DisplayPos > %DisplayLen%
        {
            Break
        }
        StringMid, C3, DisplayMusic, %DisplayPos%, 1
        IfNotInString, SkipChars, %C3%
        {
            Break
        }
        DisplayPos += 1
    }
    DisplayPos += %KeysLen%

    ; trim [ and ] from both ends
    Loop
    {
        StringLeft, C4, Keys, 1
        If C4 <> [
        {
            Break
        }
        StringTrimLeft, Keys, Keys, 1
    }
    Loop
    {
        StringRight, C5, Keys, 1
        If C5 <> ]
        {
            Break
        }
        StringTrimRight, Keys, Keys, 1
    }

    SendRaw, %Keys%

    StringMid, NextNotes, DisplayMusic, %DisplayPos%, 90
    GuiControl,, NextNotes, %NextNotes%
Return

-::
=::
[::
]::
    GoSub, PlayNextNote
Return

TogglePlayStop:
    If isPlaying = 0
    {
        isPlaying = 1
        Suspend, Off
        GuiControl,, TogglePlayStopButton, Stop
    }
    Else
    {
        isPlaying = 0
        Suspend, On
        GuiControl,, TogglePlayStopButton, Play
        CurrentPos = 1
        DisplayPos = 1
        GuiControl,, NextNotes
    }
Return

SheetChanged:
    Gui, Submit, Nohide
    CurrentPos = 1
    DisplayPos = 1
    GuiControl,, NextNotes
Return

GuiClose:
    ExitApp
