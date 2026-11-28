#!/bin/sh
# AHK_X12 installer: puts the app in ~/.local/bin and makes double-clicking .ahk files run them.
# Usage: sh install.sh          (downloads the latest build)
#        AHK_X12_LOCAL=/path/to/ahk_x12 sh install.sh   (use a binary you already have)
# Remove again with: sh install.sh --uninstall
set -e
BIN="$HOME/.local/bin"
APPS="$HOME/.local/share/applications"
MIME="$HOME/.local/share/mime"
URL="https://github.com/1to10fr/AHK_X12/releases/download/x12-latest/ahk_x12"

if [ "$1" = "--uninstall" ]; then
	rm -f "$BIN/ahk_x12" "$BIN/ahk_x12-open" "$APPS/ahk_x12.desktop" "$MIME/packages/ahk_x12.xml"
	update-mime-database "$MIME" 2>/dev/null || true
	update-desktop-database "$APPS" 2>/dev/null || true
	echo "AHK_X12 removed."
	exit 0
fi

mkdir -p "$BIN" "$APPS" "$MIME/packages"

if [ -n "$AHK_X12_LOCAL" ]; then
	cp "$AHK_X12_LOCAL" "$BIN/ahk_x12"
elif command -v curl >/dev/null 2>&1; then
	curl -fL --progress-bar -o "$BIN/ahk_x12" "$URL"
elif command -v wget >/dev/null 2>&1; then
	wget -O "$BIN/ahk_x12" "$URL"
else
	echo "Need curl or wget to download AHK_X12." >&2
	exit 1
fi
chmod +x "$BIN/ahk_x12"

# Launcher used on double-click: explains the Wayland problem instead of failing silently
cat > "$BIN/ahk_x12-open" <<'LAUNCHER'
#!/bin/sh
if [ "$XDG_SESSION_TYPE" = "wayland" ]; then
	msg="AHK_X12 only works in an X11 session, and you are on Wayland. Log out and choose 'Xorg' (or 'on Xorg') from the gear icon on the login screen, then try again."
	zenity --error --title "AHK_X12" --text "$msg" 2>/dev/null || notify-send "AHK_X12" "$msg" 2>/dev/null || echo "$msg" >&2
	exit 1
fi
# Kill any other running copy of this same script (they fight over the hotkeys and cause BadAccess errors)
for pid in $(pgrep -x ahk_x12 2>/dev/null); do
	[ "$pid" = "$$" ] && continue
	if [ "$(tr '\0' ' ' < /proc/$pid/cmdline 2>/dev/null | sed 's/ *$//' | sed 's/^[^ ]* //')" = "$*" ]; then kill -9 "$pid" 2>/dev/null; fi
done
sleep 0.3
LOGDIR="$HOME/.cache/ahk_x12"; mkdir -p "$LOGDIR"; LOG="$LOGDIR/last.log"
"$HOME/.local/bin/ahk_x12" "$@" >"$LOG" 2>&1
code=$?
if [ "$code" -ne 0 ]; then
	{ echo "--- exit code $code ---"; dmesg 2>/dev/null | tail -3; } >>"$LOG" 2>&1
	msg="AHK_X12 stopped unexpectedly (exit code $code). Details were saved to $LOG - please send that file."
	zenity --error --title "AHK_X12" --text "$msg" 2>/dev/null || notify-send "AHK_X12" "$msg" 2>/dev/null
fi
exit "$code"
LAUNCHER
chmod +x "$BIN/ahk_x12-open"

cat > "$MIME/packages/ahk_x12.xml" <<'XML'
<?xml version="1.0" encoding="UTF-8"?>
<mime-info xmlns="http://www.freedesktop.org/standards/shared-mime-info">
  <mime-type type="text/x-autohotkey">
    <comment>AutoHotkey script</comment>
    <glob pattern="*.ahk"/>
    <sub-class-of type="text/plain"/>
  </mime-type>
</mime-info>
XML

cat > "$APPS/ahk_x12.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=AHK_X12
Comment=Run AutoHotkey scripts
Exec=$BIN/ahk_x12-open %f
Terminal=false
MimeType=text/x-autohotkey;
Categories=Utility;
DESKTOP

update-mime-database "$MIME" 2>/dev/null || true
update-desktop-database "$APPS" 2>/dev/null || true
xdg-mime default ahk_x12.desktop text/x-autohotkey 2>/dev/null || true

echo
echo "AHK_X12 installed. Double-click any .ahk file to run it."
echo "To edit a script, right-click it and choose 'Open With' > your text editor."
echo "Make sure you are logged in with an X11 (Xorg) session."
