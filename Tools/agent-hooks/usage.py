#!/usr/bin/env python3
"""Plan usage left for Pixpaw to mention when an agent finishes.

  usage.py statusline        Claude Code status line: reads the session JSON on
                             stdin, saves its rate_limits, prints a short line.
  usage.py claude-left       Prints e.g. "5h 77% · week 59% left" from what the
                             status line saved last, or nothing.
  usage.py codex-left        The same from the newest Codex session log.

Only the percentages and reset times are kept, in
~/Library/Caches/Pixpaw/claude-usage.json. Nothing leaves the Mac.
"""
import glob
import json
import os
import sys
import time

CACHE = os.path.expanduser("~/Library/Caches/Pixpaw/claude-usage.json")


def left(used):
    return max(0, min(100, round(100 - float(used))))


def phrase(five_hour_used, week_used):
    parts = []
    if five_hour_used is not None:
        parts.append(f"5h {left(five_hour_used)}%")
    if week_used is not None:
        parts.append(f"week {left(week_used)}%")
    return (" · ".join(parts) + " left") if parts else ""


def statusline():
    try:
        data = json.load(sys.stdin)
    except Exception:
        data = {}
    limits = data.get("rate_limits") or {}
    keep = {}
    for window in ("five_hour", "seven_day"):
        w = limits.get(window) or {}
        if w.get("used_percentage") is not None:
            keep[window] = {"used": w["used_percentage"], "resets_at": w.get("resets_at")}
    if keep:
        os.makedirs(os.path.dirname(CACHE), exist_ok=True)
        tmp = CACHE + ".tmp"
        with open(tmp, "w") as f:
            json.dump({"saved_at": time.time(), **keep}, f)
        os.replace(tmp, CACHE)

    model = ((data.get("model") or {}).get("display_name")) or "Claude"
    context = (data.get("context_window") or {}).get("used_percentage")
    bits = [model]
    if context is not None:
        bits.append(f"ctx {round(float(context))}%")
    usage = phrase((keep.get("five_hour") or {}).get("used"), (keep.get("seven_day") or {}).get("used"))
    if usage:
        bits.append(usage)
    print(" · ".join(bits))


def claude_left():
    try:
        with open(CACHE) as f:
            data = json.load(f)
    except Exception:
        return
    now = time.time()

    def used(window):
        w = data.get(window) or {}
        resets = w.get("resets_at")
        # A window that has reset since it was saved is back to full.
        if resets and float(resets) < now:
            return 0
        return w.get("used")

    text = phrase(used("five_hour"), used("seven_day"))
    if text:
        print(text)


def codex_left():
    files = glob.glob(os.path.expanduser("~/.codex/sessions/**/*.jsonl"), recursive=True)
    if not files:
        return
    newest = max(files, key=os.path.getmtime)
    if time.time() - os.path.getmtime(newest) > 3600:
        return
    limits = None
    with open(newest, errors="ignore") as f:
        for line in f:
            if '"rate_limits"' not in line:
                continue
            try:
                found = json.loads(line)
            except Exception:
                continue
            stack = [found]
            while stack:
                item = stack.pop()
                if isinstance(item, dict):
                    if isinstance(item.get("rate_limits"), dict):
                        limits = item["rate_limits"]
                    stack.extend(item.values())
                elif isinstance(item, list):
                    stack.extend(item)
    if not limits:
        return
    primary = (limits.get("primary") or {}).get("used_percent")
    secondary = (limits.get("secondary") or {}).get("used_percent")
    text = phrase(primary, secondary)
    if text:
        print(text)


if __name__ == "__main__":
    command = sys.argv[1] if len(sys.argv) > 1 else ""
    {"statusline": statusline, "claude-left": claude_left, "codex-left": codex_left}.get(command, lambda: None)()
