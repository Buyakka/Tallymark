# Changelog

## 0.1.0 (Beta) - first release

### Journey
- Distance traveled and estimated steps, for today, this session and lifetime.
- Distance split by how you moved: on foot, mounted, flight paths, swimming and as a ghost.
- Teleports, hearthstones, zoning and places where your position is hidden are skipped.
- Miles or kilometers, and an adjustable step length.

### Ammo (hunters)
- Arrows and bullets used per fight, per dungeon run and lifetime, with a breakdown by shot.
- Shows your arrows or bullets left. Labels follow what you have equipped.
- Shots are found by spell ID, so counting works in every game language.
- Keeps your last 50 fights (place, shots, time) and last 20 dungeon runs.

### Low ammo warning
- One "Warn me below" amount (default 200).
- On the window: the ammo card turns gold, with a bell and a "Time to restock" box.
- Pop-up alert in the middle of the screen, also during a fight. Stays 1 to 10 seconds (default 3). Clicks go through it.
- Each warning can be turned on or off.

### Windows
- Full window with Ammo, Journey and History tabs.
- Small window: a compact card with steps, distance and ammo to keep on screen. Click it for the full window, right-click for settings.
- Each window has its own size, opacity and position. Lock and hide-during-combat apply to both.

### Settings
- Open from the gear, the minimap right-click, `/tally settings`, or Options > AddOns > Tallymark.
- Tabs: General, Small window, Ammo, Journey. Reset to default.

### Other
- Minimap button with quick stats on hover.
- `/tally` and `/tm` commands. `/tally help` lists them all.
- `/tally test` checks what Tallymark can read where you are.
