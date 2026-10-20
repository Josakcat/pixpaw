# Pixpaw 🐾

A pixel cat that lives on your desktop and talks to you. A Droplet for
[Droppy](https://getdroppy.app), built with
[DroppyKit](https://getdroppy.app/docs/droppykit).

![Pixpaw on the desktop](Assets/Screenshot-1.png)

## What it does

**Lives on your desktop**
- Walks the bottom edge, the whole screen, or hops onto the tops of your
  windows, and rides along when you drag one. Movement follows the display's
  refresh, so it glides.
- Grooms, purrs when petted, pounces on files you drag, and dangles like a
  real cat when you pick it up.
- Hold it for half a second for its menu: Feed, Nap, Play (a yarn ball or a
  feather teaser) and Wardrobe.
- Six coats, and an optional friend cat that sits with it and plays tag.

**Talks in a speech bubble**
- Mac notifications, and calendar events five minutes ahead.
- Song changes in Apple Music and Spotify (and it dances while they play).
- Claude Code and Codex finishing or needing you, with the plan usage left.
- Volume and brightness, headphones connecting, the battery, downloads.
- Goes quiet during calls and screen sharing, and optionally while mirroring.

**Little extras**
- Happiness stars (petting, meals, play, catches; up to 30 a day) unlock
  pixel hats and collars.
- Break reminders every 30 to 90 minutes: stretch, drink water, rest your eyes.
- A hunger meter and a food bowl.
- A synthesised meow, purr and crunch; no sound files.
- A shelf widget with its mood, stars, coats and quick controls.

| | |
|---|---|
| ![Playtime](Assets/Screenshot-2.png) | ![Wardrobe](Assets/Screenshot-3.png) |
| ![Alerts](Assets/Screenshot-4.png) | |

Everything runs on your Mac. Notification text is shown and forgotten;
nothing is stored or sent anywhere.

## Building

You need macOS 14 or later, Xcode with Swift 6.2 or later, the
[DroppyKit](https://gitlab.com/droppyformac1/droppykit) SDK on your `PATH`,
and [Droppy](https://getdroppy.app) or the free
[Droppy Playground](https://getdroppy.app/download/playground).

```bash
droppykit build      # .build/Pixpaw.droplet
droppykit validate   # the checks the Droplet Store runs
droppykit run        # open it in the DroppyKit harness
```

Then drop `.build/Pixpaw.droplet` on Droppy Playground's Store page, or on
Droppy's Settings → Store → Local droplets.

## Coding agents

The cat says when a coding agent starts, finishes or needs you. Agents report
through `Tools/agent-hooks/pixpaw-agent.sh <name> <working|done|waiting|error> [text]`,
which opens `droppy-playground://droplet/pixpaw/agent?…` in the background
(set `PIXPAW_SCHEME=droppy` for Droppy itself).

- **Claude Code**: hooks in `~/.claude/settings.json`: `UserPromptSubmit` →
  `pixpaw-agent.sh Claude working`, `Stop` → `… done`, `Notification` →
  `… waiting`. For the usage left, set `Tools/agent-hooks/claude-statusline.sh`
  as the `statusLine` command: Claude Code only hands its rate limits to a
  status line, which saves them for the Stop hook to read.
- **Codex**: `notify = ["/path/to/Tools/agent-hooks/codex-notify.sh"]` in
  `~/.codex/config.toml`. It passes the event on to `PIXPAW_CODEX_NEXT`, or to
  Codex Computer Use's notifier when that is installed, so an existing
  `notify` keeps working.
- **Cursor**: `beforeSubmitPrompt` → working, `stop` → done.

## Links for scripts and Shortcuts

`droppy://droplet/pixpaw/<action>` (or `droppy-playground://…`): `show`, `hide`,
`come`, `nap`, `feed`, `play?toy=yarn|teaser|stop`, `wear?hat=…&collar=…`,
`quiet?on=1|0`, `say?text=…`, `agent?name=…&state=…&text=…&usage=…`,
`roam?mode=anywhere|floor|windows`.

## Art

All sprites are text grids in `Tools/sprites.py`, which also previews them
(`python3 Tools/sprites.py preview out.png`, `… wear out.png`) and writes
`Sources/Pixpaw/CatSprites.generated.swift` (`python3 Tools/sprites.py swift`).
`Tools/store-art.swift` draws the screenshots and the creator avatar from
the same sprites.

The droplet's Store icon is designed by Droppy; `Pixpaw.icon` here is only
for local builds.

## Licence

MIT. See [LICENSE](LICENSE).
