#!/bin/bash
# Claude Code status line: the model, context used and plan usage left, and
# a copy of the usage for Pixpaw to mention when Claude finishes.
exec python3 "$(cd "$(dirname "$0")" && pwd)/usage.py" statusline
