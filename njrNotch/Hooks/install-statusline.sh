#!/bin/bash
# Points Claude Code's status line at njrnotch-statusline.sh, which saves the context window
# (size and tokens used), model and effort to ~/.claude/njrnotch-session.json for the notch. Safe to re-run.
#
# - Backs up settings.json first (settings.json.njrnotch-backup-<time>-<pid>).
# - Keeps your status line working: its command is saved to njrnotch-statusline-previous.sh
#   and njrNotch's script runs it with the same input, so it looks exactly the same.
# - --uninstall puts your old status line back, or removes the setting if you had none.
#
#   ./install-statusline.sh               install / update
#   ./install-statusline.sh --uninstall   remove (same as ./uninstall-statusline.sh)
set -euo pipefail

SETTINGS="$HOME/.claude/settings.json"
SCRIPT="$HOME/.claude/njrnotch-statusline.sh"

mkdir -p "$(dirname "$SETTINGS")"
if [ -f "$SETTINGS" ]; then
  BACKUP="$SETTINGS.njrnotch-backup-$(date +%Y%m%d-%H%M%S)-$$"
  cp "$SETTINGS" "$BACKUP"
  echo "Backed up settings to $BACKUP"
fi
if [ "${1:-}" != "--uninstall" ]; then
  cp "$(dirname "$0")/njrnotch-statusline.sh" "$SCRIPT"
  chmod +x "$SCRIPT"
fi

/usr/bin/python3 - "$SETTINGS" "$SCRIPT" "${1:-}" <<'PY'
import json, os, sys, tempfile

path, script, flag = sys.argv[1:4]
uninstall = flag == "--uninstall"
home = os.path.dirname(path)
previous = os.path.join(home, "njrnotch-statusline-previous.sh")
session = os.path.join(home, "njrnotch-session.json")
legacy = os.path.join(home, "njrnotch-usage.json")  # written by older versions
ours = "~/.claude/njrnotch-statusline.sh"

settings = {}
if os.path.exists(path) and os.path.getsize(path):
    with open(path, encoding="utf-8") as f:
        settings = json.load(f)  # invalid JSON stops here, before anything is written

line = settings.get("statusLine")
line = dict(line) if isinstance(line, dict) else {}
command = line.get("command")
is_ours = isinstance(command, str) and "njrnotch-statusline.sh" in command

def save():
    # Write to a temp file and rename, so settings.json is never left half-written.
    fd, tmp = tempfile.mkstemp(dir=home)
    with os.fdopen(fd, "w", encoding="utf-8") as f:
        json.dump(settings, f, indent=2, ensure_ascii=False)
        f.write("\n")
    os.replace(tmp, path)

if uninstall:
    if is_ours:
        if os.path.exists(previous):
            with open(previous, encoding="utf-8") as f:
                line["command"] = f.read()
            settings["statusLine"] = line
            print("Restored your previous status line.")
        else:
            settings.pop("statusLine", None)
        save()
        print(f"Removed the njrNotch status line from {path}")
    else:
        print("The status line isn't njrNotch's, so settings.json was left as it is.")
    for leftover in (previous, script, session, legacy):
        if os.path.exists(leftover):
            os.remove(leftover)
else:
    if not is_ours:
        # Save yours before switching, so the script can run it and uninstall can restore it.
        if isinstance(command, str) and command.strip():
            with open(previous, "w", encoding="utf-8") as f:
                f.write(command)
            print("Kept your status line: njrNotch runs it, so it looks the same.")
        elif os.path.exists(previous):
            os.remove(previous)  # left over from an older install
        line["type"] = "command"
        line["command"] = ours
        settings["statusLine"] = line
        save()
    print(f"Installed the njrNotch status line in {path}")
    if os.path.exists(legacy):
        os.remove(legacy)
    print("Context window numbers appear in the notch after your next message in Claude Code.")
PY
