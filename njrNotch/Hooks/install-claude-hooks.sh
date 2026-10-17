#!/bin/bash
# Adds njrNotch's Claude Code hooks to ~/.claude/settings.json. Safe to re-run.
#
# - Backs up settings.json first (settings.json.njrnotch-backup-<time>-<pid>).
# - Only adds or removes njrNotch's own entries; your other hooks are left exactly as they are.
# - Each hook is a native `http` hook that POSTs the event to njrNotch on 127.0.0.1.
#   If njrNotch isn't running, the POST fails instantly and Claude Code carries on.
#
#   ./install-claude-hooks.sh               install / update
#   ./install-claude-hooks.sh --uninstall   remove (same as ./uninstall-claude-hooks.sh)
set -euo pipefail
umask 077   # backups and rewritten settings are readable by you only

SETTINGS="$HOME/.claude/settings.json"
URL="http://127.0.0.1:47823/claude"   # must match ClaudeCodeAdapter.hookURL

mkdir -p "$(dirname "$SETTINGS")"
if [ -f "$SETTINGS" ]; then
  BACKUP="$SETTINGS.njrnotch-backup-$(date +%Y%m%d-%H%M%S)-$$"
  cp "$SETTINGS" "$BACKUP"
  echo "Backed up settings to $BACKUP"
fi

/usr/bin/python3 - "$SETTINGS" "$URL" "${1:-}" <<'PY'
import json, os, sys, tempfile

path, url, flag = sys.argv[1:4]
uninstall = flag == "--uninstall"

settings = {}
if os.path.exists(path) and os.path.getsize(path):
    with open(path, encoding="utf-8") as f:
        settings = json.load(f)  # invalid JSON stops here, before anything is written

# PermissionRequest waits up to 10 minutes so you can answer from the notch.
# The notch answers instantly when "Answer permission requests in the notch" is off.
timeouts = {"PermissionRequest": 600}
events = ["SessionStart", "UserPromptSubmit", "PreToolUse", "PostToolUse",
          "PermissionRequest", "Stop", "StopFailure", "SessionEnd"]

hooks = settings.get("hooks", {})
for event in events:
    groups = []
    for group in hooks.get(event, []):
        # Remove only njrNotch's handler; keep the user's handlers in the same group.
        kept = [h for h in group.get("hooks", []) if h.get("url") != url]
        if kept:
            groups.append({**group, "hooks": kept})
    if not uninstall:
        groups.append({"hooks": [{"type": "http", "url": url, "timeout": timeouts.get(event, 5)}]})
    if groups:
        hooks[event] = groups
    else:
        hooks.pop(event, None)

if hooks:
    settings["hooks"] = hooks
else:
    settings.pop("hooks", None)

# Write to a temp file and rename, so settings.json is never left half-written.
fd, tmp = tempfile.mkstemp(dir=os.path.dirname(path))
with os.fdopen(fd, "w", encoding="utf-8") as f:
    json.dump(settings, f, indent=2, ensure_ascii=False)  # keep non-ASCII text as written
    f.write("\n")
os.replace(tmp, path)

print(("Removed" if uninstall else "Installed") + f" njrNotch hooks in {path}")
allowed = settings.get("allowedHttpHookUrls")
if not uninstall and allowed is not None and url not in allowed:
    print(f"Warning: allowedHttpHookUrls is set; add {url} to it or the hooks won't run.")
PY
