# Tallymark

**Every step. Every shot.**

A World of Warcraft: Forever addon by Buyaka. It works like a fitness tracker for your character.

- Journey: distance traveled and estimated steps, split by how you moved.
- Ammo (hunters): arrows or bullets used per fight, per dungeon and lifetime, plus ammo left.
- Low ammo warning on the window and as a short pop-up, at the amount you choose.
- A full window with Ammo, Journey and History tabs, or a small window to keep on screen.

Status: 0.1.1. See [CHANGELOG](CHANGELOG.md).

> **All Rights Reserved.** Copyright (c) 2026 Buyaka.
> You may download Tallymark and use it in game. You may not copy, change,
> reuse, re-upload or redistribute any part of it without written permission.
> The source is visible only because Blizzard requires addon code to be readable.
> See [LICENSE](LICENSE).

## Commands

- `/tally` or `/tm` show or hide the window (or click the minimap button)
- `/tally minimap` show or hide the minimap button
- `/tally settings` open settings (or click the gear, or right-click the minimap button or the small window)
- `/tally help` list all commands
- `/tally status` show version and saved settings
- `/tally reset` move both windows back to where they started
- `/tally test` check what Tallymark can read here (try in and out of combat, and in a dungeon)
- `/tally test shots` list every tracked shot with its name in your game language
- `/tally debug journey` show the last moves and your journey totals
- `/tally debug arrows` hunters: show ammo, fights and the last shots

## Fonts

Inter and Space Grotesk are included under the SIL Open Font License 1.1
(see `Tallymark/Media/Fonts/OFL-*.txt`). They are not covered by the Tallymark license.

## Author scripts

`scripts/install.bat` (Windows) and `scripts/install.sh` (Mac/Linux) copy the addon
into the game folder for the author's own testing.
