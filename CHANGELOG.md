# Changelog

## 0.1.0 (in progress, Beta)

- Step 1: addon skeleton. Loads, saves settings (schema 1), `/tally` toggles an empty window, `/tally help` lists commands.
- Step 2: journey tracking. Distance by travel type (on foot, mounted, flight paths, swimming, ghost), estimated steps (lifetime, today, this session). Skips teleports, zoning and places where position is hidden. `/tally debug journey` shows the last moves and totals.
- Step 3: arrow and bullet tracking for hunters. Counts shots live per fight, per dungeon and lifetime, split by arrows and bullets, with a per-shot breakdown. Reads ammo left and checks it against the shot count after each fight. Keeps the last 50 fights. `/tally debug arrows` shows it all.
