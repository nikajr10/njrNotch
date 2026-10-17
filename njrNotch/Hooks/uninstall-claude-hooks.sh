#!/bin/bash
# Removes njrNotch's Claude Code hooks from ~/.claude/settings.json (backs it up first).
exec /bin/bash "$(dirname "$0")/install-claude-hooks.sh" --uninstall
