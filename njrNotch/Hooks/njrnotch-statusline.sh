#!/bin/sh
# njrNotch status line. Claude Code pipes its status JSON in on every update
# (https://code.claude.com/docs/en/statusline). This saves it to ~/.claude/njrnotch-usage.json
# for the notch's usage bars, then runs the status line you had before (if any) with the same
# input, so your terminal looks exactly as it did. Installed by install-statusline.sh.

input=$(cat; echo x)   # the x keeps trailing newlines, so your status line gets the exact input
input=${input%x}
out="$HOME/.claude/njrnotch-usage.json"
# Write then rename, so the app never reads half a file.
printf '%s' "$input" > "$out.$$" && mv -f "$out.$$" "$out"

previous="$HOME/.claude/njrnotch-statusline-previous.sh"
[ -f "$previous" ] || exit 0
# Claude Code runs status line commands with `sh -c`; do the same.
printf '%s' "$input" | /bin/sh -c "$(cat "$previous")"
