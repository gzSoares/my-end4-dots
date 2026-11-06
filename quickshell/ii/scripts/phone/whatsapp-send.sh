#!/usr/bin/env bash
# Opens a WhatsApp Web chat and, when asked, sends the message waiting in it.
#
# Usage: whatsapp-send.sh URL AUTO_SEND DELAY [WINDOW_ADDRESS]
#   URL            https://web.whatsapp.com/send?phone=...&text=...
#   AUTO_SEND      1 to press Enter once the chat has loaded, 0 to leave the
#                  message in the box
#   DELAY          seconds to give WhatsApp Web to load the chat before Enter
#   WINDOW_ADDRESS the Hyprland window already showing WhatsApp, if any: it is
#                  brought forward and sent to the link, instead of the
#                  browser opening one more tab (WhatsApp Web then complains
#                  it is open somewhere else)
#
# Every keystroke is only sent while the WhatsApp window is the focused one,
# so a slow machine or a changed focus never types into something else.

url="$1"; auto="${2:-0}"; delay="${3:-6}"; addr="${4:-}"

# The focused window is WhatsApp: its title begins with it, after an optional
# "(3) " unread count
whatsapp_focused() {
    hyprctl activewindow -j 2>/dev/null \
        | jq -e '(.title // "") | test("^(\\([0-9]+\\) )?WhatsApp")' >/dev/null 2>&1
}

wait_focused() {  # seconds
    local tries=$(( ${1} * 10 )) i
    for ((i = 0; i < tries; i++)); do
        whatsapp_focused && return 0
        sleep 0.1
    done
    return 1
}

open_new() { xdg-open "$url" >/dev/null 2>&1; }

if [[ -n "$addr" ]] && command -v wtype >/dev/null && command -v wl-copy >/dev/null; then
    hyprctl dispatch "hl.dsp.focus({window = \"address:${addr}\"})" >/dev/null 2>&1
    if wait_focused 3; then
        # Paste rather than type: typed characters raced the address bar
        printf %s "$url" | wl-copy
        sleep 0.3; wtype -M ctrl -k l -m ctrl
        sleep 0.3; wtype -M ctrl -k v -m ctrl
        sleep 0.2; wtype -k Return
    else
        open_new
    fi
else
    open_new
fi

[[ "$auto" == 1 ]] || exit 0
command -v wtype >/dev/null || exit 0

# The page reloads for the new chat: give it time, then make sure it is the
# window in front before pressing Enter in its message box
sleep "$delay"
wait_focused 8 || exit 0
wtype -k Return
