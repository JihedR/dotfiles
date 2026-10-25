#!/usr/bin/env bash
# Random profiler NOTE for fastfetch, trimmed with "…" to fit the terminal so it
# never wraps into the logo column.
# OFFSET = column where the value starts: logo padding left 7 + logo width 29
# + padding right 10 + key "NOTE  " and separator 8. Keep in sync with config.jsonc.
OFFSET=54

note=$(shuf -n1 "$HOME/.config/fastfetch/notes.txt")
cols=$(stty size </dev/tty 2>/dev/null | cut -d' ' -f2)
room=$(( ${cols:-0} - OFFSET ))

if [[ -n $cols ]] && (( ${#note} > room )); then
    (( room > 1 )) && note="${note:0:room-1}…" || note=''
fi
printf '%s' "$note"
