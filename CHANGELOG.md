# Changelog

## [1.2.1] - 2026-10-21

The parrot is now an orange-fronted conure, drawn by a community member. Focus sessions keep a countdown over your pet's head, and the characters are PNG sprite sheets you can draw your own from.

### Changed

- The parrot is now an orange-fronted conure, drawn a pixel at a time from photographs by [@diazdesandi](https://github.com/diazdesandi): orange patch over its pale beak, blue-green crown, blue flight feathers and a long tail. It sleeps with its head tucked into its wing, pecks at its food and lets its tail hang when you pick it up. (Thank you!)
- The characters are now PNG sprite sheets in `Art/`, one per pet, so you can draw your own in Aseprite, Piskel or any pixel editor. `Art/README.md` has the layout and colours. (Thanks for the idea!)
- During a focus session your pet keeps a countdown in its speech bubble, so you can see the time left at a glance. It no longer goes quiet while you focus: a song change, an agent update or any other news still shows, then the clock comes back. It stays silent (no meows), and break reminders wait for the session to end.

## [1.2.0] - 2026-10-21

Your pet dances to YouTube, chases a laser dot, poses for your screenshots, celebrates your birthday, says good morning, leaves you gifts, keeps you company while you focus, swings its legs when you carry it and puts on a nightcap after midnight. And the shelf widget counts your days together.

### Added
- Carry your pet about and its legs swing the way you move it: drag it to the right and they swing right, drag it to the left and they swing left, further the faster you go, and hang still again the moment you stop. Held without moving, it just hangs there. Every character does it.
- Your pet dances to whatever is playing, not just Apple Music and Spotify: a YouTube video in Safari, Chrome or another browser, a video, another music player. It starts a couple of seconds after the sound does and stops when you pause. Song names are still only for Apple Music and Spotify. The setting is now called Music.
- A laser pointer to play with. Hold your pet, choose Play, then Laser pointer: a glimmering red dot follows your pointer and your pet stalks it, crouches and leaps at it. It never quite catches it ("Where did it go?"), so it keeps trying for twice as long as the other toys.
- Late nights. From midnight to 5 am your pet wears a floppy blue nightcap, and the first time it sees you at your Mac it says "It's late. Bed soon?", once a night and never during calls. Headphones still go on over it. Switch it off with Late nights in Settings.
- Your pet strikes a pose when you take a screenshot, looks pleased with itself and asks "Did you get my good side?" (or "Cheese!"). It finds new screenshots through Spotlight, so no permission is needed; one copied only to the clipboard goes unnoticed. Switch it off with Screenshots in Settings.
- The shelf widget now shows how long you have been together and how many times you have petted, fed and played with your pet (just the days and pets when it shares a row; hover for all four). Days count from when you first installed Pixpaw; meals and games count from this version.
- Your birthday. Set it under Festivals in Settings and, on the day, confetti falls across the screen, your pet wears a party hat and wishes you a happy birthday. Born on 29 February? It comes on the 28th in other years.
- Good morning. The first time your pet sees you at your Mac on a morning (5 am to noon), it has a long stretch and says good morning, with your first event of the day when Calendar events is on ("Good morning! First up: Standup at 9:30."). Switch it off with Good morning in Settings.
- Stroke your pet. Run the pointer back and forth over it, no click needed, and it purrs and earns a star, just as when you click it.
- Shake it about. Carry your pet and shake it from side to side, and it lands seeing stars: it sits there dizzy for a few seconds, looking this way and that ("Whoa…").
- Treats. Hold your pet and choose Give a treat: a fish biscuit lands a little way off, your pet runs over and gobbles it up. Up to three treats a day earn stars; they don't spoil its dinner.
- A little gift once a day. Some while after you sit down, your pet leaves you a present on the floor: a flower, a fish bone, a ball or a feather. Click it to pick it up for a star.
- Take a photo of your pet. The camera on the shelf (or Take a photo when you hold it) makes a big, crisp portrait of your pet as it is right now, hat and all, with how many days you've been together, and saves it where you choose. Made for sharing.
- Focus sessions. Start one from the timer on the shelf or when you hold your pet (15, 25, 45 or 50 minutes, set under Health). Your pet sits by you without a word, the time left counts down beside the notch, and when it's up it comes over to tell you to take a break.
- Festival hats. On a festival's days your pet dresses for it: a witch hat on Halloween, a Santa hat at Christmas, a party hat at New Year and on your birthday, a bow on Valentine's Day.
- Two more festivals: Loy Krathong, with krathongs floating along the bottom of the screen and lanterns rising, and Chinese New Year, with red lanterns swaying along the top, on their real dates each year.
- Keep the Mac awake while agents work. Turn it on in Settings and, while Claude Code, Codex or another agent reports it is working, your Mac won't go to sleep, so a long run can finish; the screen can still turn off. It lets go the moment no agent is working. Closing a laptop's lid still puts it to sleep.

### Changed
- The character list is in A to Z order, on the shelf and in Settings.
- Settings are grouped into sections: Pet, Moving about, Wardrobe, Friend, Speech bubble, Quiet, Around your Mac, AI agents, Health, Festivals and Notch, instead of one long list of switches.

### Fixed
- Holding your pet to open its menu could leave it stuck in the carried pose. The slightest twitch of the hand while holding picked it up, and the menu then left it hanging in the air. Now only a real move picks it up, and opening the menu puts it back down.
- With the bell turned off, the shelf widget showed a line of code ("Image(provider: …") where the crossed-out bell and "Quiet" should be. It shows the bell again.
- A long agent run no longer drops off the list after half an hour. Agents only report when a run starts, so a working one now counts as working for up to four hours.
- The cat teaser keeps up with your pointer. It trailed behind on a springy string, so a quick flick left it far behind; now it stays right under the pointer however fast you move.

## [1.1.0] - 2026-10-21

New pets, festival decorations, and the cat dances properly again.

### Added
- A bee! Pick it under Character in Settings instead of the cat. It flies anywhere on the screen, hovering with its wings beating, buzzes when it talks, hums when you pet it, and does everything the cat does: eats, plays, dances, wears hats and headphones.
- A parrot! Green with a red face and a hooked orange beak. It perches where the cat would sit, takes off and flies whenever it goes somewhere, squawks when it talks and chirps when you pet it.
- A dinosaur! A little green T-rex with orange spikes down its back. It stomps about where the cat would walk, says "Rawr!" when it talks and rumbles when you pet it.
- A dog! A beagle puppy with a floppy ear and white socks. It trots about where the cat would walk, wags its tail, barks "Woof!" when it talks and pants happily when you pet it.
- A hamster! A round golden ball with pink ears and little pink feet. It scurries about where the cat would walk, squeaks when it talks, chitters when you pet it and stuffs its cheeks when it eats.
- A chicken! A plump white hen with a red comb and an orange beak. It struts about where the cat would walk, pecks at its food, flaps when it's happy, says "Bawk!" when it talks and clucks softly when you pet it.
- Festival decorations. On a festival's days the screen joins in, then clears when the day is over: ghosts drift across it on Halloween (31 Oct), fireworks go up for New Year (31 Dec from 6 pm to 1 Jan), snow falls at Christmas (24 and 25 Dec), water drops for Songkran (13 to 15 Apr) and hearts float up on Valentine's Day (14 Feb). Your pet says hello when one starts. Only on the real dates, never during calls or screen sharing; switch them all off, or any one of them, under Festivals in Settings.
- Switch characters right from the shelf under the notch: the little portrait next to the bell opens a menu of every character.
- The cat wears headphones while yours are connected. When AirPods or other headphones connect, it stops, settles a pixel pair over its ears with a paw and looks pleased; they come off when you disconnect. They take the place of its hat while on, and it dances in them too.

### Fixed
- Calendar access no longer keeps asking. Once Droppy had calendar access, the Allow button could stay in Settings and calendar reminders stayed off; Pixpaw now goes by what Droppy reports.
- The cat dances to your music again. It only bobbed in the short moments it sat still, so with a song playing it mostly kept walking and grooming. Now it stops and dances the moment a song starts or changes in Apple Music or Spotify, keeps dancing for most of the song, and dances bigger: a higher bob, a turn to the beat and a little music note.
- The cat no longer walks off the screen. With "Bottom and on windows" on, it could follow a window that hangs past the edge of the screen, or ride one you drag off, and disappear. It now only walks the part of a window that is on screen, and comes straight back if anything ever takes it past an edge.

## [1.0.0] - 2026-10-20

First release. A pixel cat that lives on your desktop and talks to you.

- Wanders the whole screen, the bottom edge, or the bottom edge and the tops of your windows (riding along when you drag one). Smooth, display-paced movement.
- Grooms, purrs when petted, can be picked up and dropped, naps when you ask, and pounces on files you drag.
- Hold it for a menu: feed it, have it nap, or play with a yarn ball or a feather teaser.
- Gets hungry over four hours and eats from a bowl you put down.
- Speech bubble for Mac notifications, calendar events five minutes ahead, song changes (and it dances), Claude Code and Codex finishing or needing you (with plan usage left), volume and brightness, headphones, battery and downloads.
- Goes quiet during calls and screen sharing, and optionally while mirroring.
- Break reminders every 30 to 90 minutes.
- Happiness stars (up to 30 a day) unlock pixel hats and collars.
- Sounds: a synthesised meow, purr and crunch.
- Six coats, an optional friend cat, and a shelf widget.
