# Changelog

## 0.1.0 (in progress, Beta)

- Step 1: addon skeleton. Loads, saves settings (schema 1), `/tally` toggles an empty window, `/tally help` lists commands.
- Step 2: journey tracking. Distance by travel type (on foot, mounted, flight paths, swimming, ghost), estimated steps (lifetime, today, this session). Skips teleports, zoning and places where position is hidden. `/tally debug journey` shows the last moves and totals.
- Step 3: arrow and bullet tracking for hunters. Counts shots live per fight, per dungeon and lifetime, split by arrows and bullets, with a per-shot breakdown. Reads ammo left and checks it against the shot count after each fight. Keeps the last 50 fights. `/tally debug arrows` shows it all.
- Step 4: the Shadow window. Tabs for Ammo (hunters), Journey and History. Big live number, Dungeon, Lifetime and Bullets/Arrows left cards, low ammo box (under 200), bars by shot and by travel type, recent fights list, lock button.
- Step 5: `/tally test`. Shows client build, whether position and ammo can be read here, the last 10 casts with how much ammo went down after each, and which spells used ammo this session (flags any that disagree with the shot list).
- Fonts: Space Grotesk Bold for the name and big numbers, Inter for everything else (SIL Open Font License, included in Media/Fonts). Falls back to the game font if a file fails to load.
- License: All Rights Reserved (LICENSE file, README notice, TOC X-License line, LICENSE.txt shipped inside the addon folder).
- Seal logo (ring, arrowhead with tally marks) replaces the placeholder.
- Minimap button in the standard gold ring, with the seal arrowhead. Left-click shows or hides the window, right-click locks it, drag to move, hover for steps today and ammo left. `/tally minimap` hides or shows it.
- `/tm` works the same as `/tally`.
- Window matches the design: rounded corners, gear and close buttons, label next to the big number, bell on the ammo card, "Time to restock." message.
- "By shot" bars show this fight while in combat, and the last fight after it ends.
- Shots are found by spell ID, so counting works in every game language, not just English. `/tally test` shows how many shot IDs were found; `/tally test shots` lists each one with its name in your language.
- Settings window. Opens from the gear, minimap right-click, `/tally settings`, or Options > AddOns > Tallymark. General: lock window, window size (70%-130%), hide during combat, show minimap button. Ammo warning: on/off, warn below N (default 200), pop-up alert, test button. Journey: miles or kilometers, step length. Reset to default.
- Low ammo pop-up: a gold alert near the top of the screen when ammo drops below the warning amount, and once after login if already low. Fades out after a few seconds.
- Gear button now opens settings (it used to lock the window). Minimap right-click opens settings too.
- Settings now open inside the main window instead of a second window. The gear switches between stats and settings; the tabs become General, Ammo warning, Journey; the footer shows Reset to default and Done. Window size applies when you let go of the slider.
- Low ammo pop-up is smaller, sits at the very top of the screen, and fades after about 3 seconds instead of 6. If you drop low during a fight, it waits until the fight ends so it never covers your view.
