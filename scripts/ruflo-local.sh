#!/bin/sh
set -eu
cd "$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
export RUFLO_DAEMON_AUTOSTART=0
export RUFLO_FUNNEL=0
# Use the existing installed CLI; never download via npx or reuse a global MCP.
if command -v ruflo >/dev/null 2>&1; then
  exec ruflo "$@"
fi
echo 'Ruflo is not installed on PATH.' >&2
exit 1
