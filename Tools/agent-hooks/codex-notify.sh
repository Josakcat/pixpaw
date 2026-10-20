#!/bin/bash
# Codex `notify`: Codex runs this with the event JSON as the last argument.
# Tells Pixpaw first (it returns at once), then hands the same event to the
# command Codex had before, if there was one, so it keeps working:
# PIXPAW_CODEX_NEXT names it, and by default it is Codex Computer Use's
# notifier when that is installed.
here="$(cd "$(dirname "$0")" && pwd)"
payload="${@: -1}"
"$here/pixpaw-agent.sh" --codex "$payload"
next="${PIXPAW_CODEX_NEXT:-$HOME/.codex/computer-use/Codex Computer Use.app/Contents/SharedSupport/SkyComputerUseClient.app/Contents/MacOS/SkyComputerUseClient}"
if [ -x "$next" ]; then
  exec "$next" turn-ended "$payload"
fi
exit 0
