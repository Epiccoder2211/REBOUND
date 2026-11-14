# REBOUND hackathon: AI coding guidelines

This is a Godot 4.x 2D puzzle-platformer, developed in parallel by two people.

## Golden rule
Make small, testable changes. Do not rewrite the whole project to add a feature. The starter was generated without a Godot runtime available; verify all changes in Godot (F5).

## File ownership while parallel work is underway
- `saatvik-gameplay`: `scripts/player.gd`, `scripts/spring.gd`, `scripts/hazard.gd`, `scripts/moving_platform.gd` (gameplay physics, spring timing, controls).
- `ved-levels-ui`: `scripts/main.gd`, `scripts/goal.gd`, plus any new `assets/` content (level layouts, UI, atmosphere, title/ending).
- Avoid changes to the other person's files. If necessary, discuss the interface first and create a separate integration branch after both PRs merge.

## Compatibility contracts
- `player.gd` must keep `signal died(safe_position: Vector2)`, `die()`, `respawn(at: Vector2)`, `bounce(power: float)`, `safe_position`, and `active`.
- `spring.gd` must stay an `Area2D` that calls `body.bounce(...)` on an eligible player.
- `main.gd` owns level lifecycle, respawning, spawning springs, game state, HUD, and level layout in `make_levels()`.
- Goal must still emit `reached` when player enters.
- Keep `project.godot` and `main.tscn` unchanged unless teammates agree.

## Recommended order
1. Compile the project and verify F5 starts the menu.
2. Verify movement, dying, respawning, and persistent springs in level 1.
3. Adjust physics and level layouts until all four levels are beatable.
4. Add polish (SFX, juice, music, transitions) after the core loop is working.
5. Merge only code that runs; reserve at least 30 minutes for the final export.

No hard-coded passwords, tokens, private credentials, or external paid API dependencies.
