#!/usr/bin/env python3
"""What an agent's turn did to the project, and the dev server it started.

    workspace.py turn-start <session> [folder]   (a turn begins: where HEAD is)
    workspace.py turn-diff  <session> [folder]   (it's over: "3 files · +84 −12")

The hooks also import dev_ports(command): the local port a command that starts
a dev server will listen on ("npm run dev", "vite --port 4000",
"python3 -m http.server"), so the pet can offer to open it; and
pushed_to(command, folder): for a `git push` to GitHub, the repository and
branch ("owner/app@main"), so the pet can wait for its CI with `gh`.

Only counts leave here: how many files and lines changed, never which or what.
A folder that isn't a Git repository says nothing. Each git call has a short
time limit, so a slow repository never holds the agent up.
"""

import os
import re
import subprocess
import sys

FOLDER = os.path.expanduser("~/Library/Caches/Pixpaw/turns")

# Dev servers and the port each listens on unless told otherwise.
SERVERS = [
    (r"\bvite\b|\bsvelte-kit\s+dev\b", [5173]),
    (r"\bnext\s+(dev|start)\b|\bnuxi?\s+dev\b|\bremix\s+dev\b|\brails\s+s(erver)?\b|\breact-scripts\s+start\b", [3000]),
    (r"\bastro\s+(dev|preview)\b", [4321]),
    (r"\bng\s+serve\b", [4200]),
    (r"\bwebpack(-dev-server|\s+serve)\b|\bhttp-server\b", [8080]),
    (r"\bhttp\.server\b|\buvicorn\b|\bmanage\.py\s+runserver\b|\bmkdocs\s+serve\b", [8000]),
    (r"\bflask\s+run\b", [5000]),
    (r"\bhugo\s+server\b", [1313]),
    (r"\bjekyll\s+serve\b", [4000]),
    (r"\bexpo\s+start\b", [8081]),
    # A project's own script: whichever of the usual ports comes up.
    (r"\b(npm|pnpm|yarn|bun)\s+(run\s+)?(dev|start|serve|preview)\b|\bnpx\s+serve\b", [3000, 5173, 8080, 4321, 4200, 8000]),
]
PORT = r"(?:--port[=\s]+|-p\s+|\bPORT=|localhost:|127\.0\.0\.1:|0\.0\.0\.0:)(\d{2,5})\b"
POSITIONAL = r"\b(?:http\.server|runserver(?:\s+\S*:)?)\s+(\d{2,5})\b"


def dev_ports(command):
    """The ports a dev server started by this command may be on, likeliest
    first, or [] when it doesn't start one."""
    command = str(command or "")
    for pattern, ports in SERVERS:
        if re.search(pattern, command):
            given = re.search(PORT, command) or re.search(POSITIONAL, command)
            if given and 0 < int(given.group(1)) < 65536:
                return [int(given.group(1))]
            return ports
    return []


def pushed_to(command, folder):
    """"owner/repo@branch" when the command pushes this folder's branch to
    GitHub, else ""."""
    command = str(command or "")
    if not re.search(r"\bgit\s+push\b", command) or not folder:
        return ""
    remote = (git(folder, "remote", "get-url", "origin") or "").strip()
    found = re.match(r"^(?:https://(?:[^@/]+@)?github\.com/|git@github\.com:|ssh://git@github\.com/)([\w.-]+)/([\w.-]+?)(?:\.git)?/?$", remote)
    branch = (git(folder, "rev-parse", "--abbrev-ref", "HEAD") or "").strip()
    if not found or not branch or branch == "HEAD":
        return ""
    return f"{found.group(1)}/{found.group(2)}@{branch}"[:140]


def git(folder, *args):
    try:
        done = subprocess.run(["git", "-C", folder, *args], capture_output=True, text=True, timeout=3)
    except Exception:
        return None
    return done.stdout if done.returncode == 0 else None


def untracked(folder):
    listed = git(folder, "ls-files", "--others", "--exclude-standard")
    return len(listed.splitlines()) if listed is not None else 0


def record(session):
    safe = re.sub(r"[^A-Za-z0-9_-]", "", session)[:80] or "default"
    return os.path.join(FOLDER, safe)


def turn_start(session, folder):
    head = (git(folder, "rev-parse", "HEAD") or "").strip()
    if not head:
        return
    os.makedirs(FOLDER, exist_ok=True)
    with open(record(session), "w") as kept:
        kept.write(f"{folder}\n{head}\n{untracked(folder)}\n")


def turn_diff(session, folder):
    try:
        with open(record(session)) as kept:
            was, head, new_before = (kept.read().splitlines() + ["", "", "0"])[:3]
        os.remove(record(session))
    except OSError:
        return ""
    if was != folder or not head:
        return ""
    stat = git(folder, "diff", "--shortstat", head) or ""
    numbers = {k: int(n) for n, k in re.findall(r"(\d+) (file|insertion|deletion)", stat)}
    files, added, removed = numbers.get("file", 0), numbers.get("insertion", 0), numbers.get("deletion", 0)
    created = max(0, untracked(folder) - int(new_before or 0))
    parts = []
    if files:
        parts.append(f"{files} file{'s' if files != 1 else ''} · +{added} −{removed}")
    if created:
        parts.append(f"{created} new file{'s' if created != 1 else ''}")
    return " · ".join(parts)


def main():
    if len(sys.argv) < 3:
        return
    what, session = sys.argv[1], sys.argv[2]
    folder = os.path.realpath(sys.argv[3] if len(sys.argv) > 3 and sys.argv[3] else os.getcwd())
    if what == "turn-start":
        turn_start(session, folder)
    elif what == "turn-diff":
        print(turn_diff(session, folder))


if __name__ == "__main__":
    main()
