# Changelog

## 0.1.2

### Ammo (hunters)
- The "By shot" list on the Ammo tab is now a table with two columns: This fight (or Last fight) and All time. Each shot shows how many you used in the fight next to how many you've used ever (since installing Tallymark, until you reset).
- Rows have a soft stripe so a line is easy to follow, and up to 7 shots show. With more, the last row adds up the rest. Hover it to see each one.

### New small window
- Redesigned: a header, two big tiles (shots this fight and ammo left, red when low), a table of your shots with Fight and Total columns, a total row, and steps and distance today at the bottom.
- Pick which shots show: Settings > Small window > Shots to show. Tick the ones you want, or use All and None. A shot shows once you know it or have used it.
- Right-clicking the small window now opens the Small window settings.

## 0.1.1

### Ammo (hunters)
- Started using Tallymark late? Settings > Ammo > "Shots before Tallymark": type how many arrows and bullets you used before installing it, and they're added to your Lifetime total. Typing a new number replaces the old one, so it never counts twice. Per character.
- The "Lifetime" card is now called "All time": every arrow and bullet since you installed Tallymark (plus any you typed in), until you reset.
- The small window and the minimap tooltip show your all-time arrows or bullets too.

### Low ammo warning
- Ammo left turns red (number, card border and bell) in the full window, the small window and the minimap tooltip when you reach your warning amount.
- The warning now starts AT your amount, not just below it: set 200 and it warns at 200. The setting is now called "Warn me at".

## 0.1.0 - first release

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
- Each window has its own size, opacity, position and hide-during-combat choice. The small window stays up in fights unless you turn that on. Lock applies to both.

### Settings
- Open from the gear, the minimap right-click, `/tally settings`, or Options > AddOns > Tallymark.
- Tabs: General, Small window, Ammo, Journey. "Reset settings" puts settings back without touching your stats.
- Reset your stats to zero: journey, ammo, or all. Asks first, and only affects the character you're on.
- Done or the gear goes back to the main window. The X or Escape closes it (back to the small window if you use it).

### Other
- Stats are saved per character. The window shows which character you're looking at.
- Minimap button with quick stats on hover.
- `/tally` and `/tm` commands. `/tally help` lists them all.
- `/tally test` checks what Tallymark can read where you are.
