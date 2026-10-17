#!/bin/bash
# Puts back the status line you had before njrNotch (backs up settings.json first).
exec /bin/bash "$(dirname "$0")/install-statusline.sh" --uninstall
