# REBOUND — The Art of Falling Forward

An original Godot 4.x 2D puzzle-platformer. It has four increasingly difficult stages, procedural neon visuals and original looping music, moving platforms, hazards, large gates with the next stage visible beyond them, a menu, a pause state, and run statistics.

## Open in Godot

1. Extract this entire folder somewhere you can save files (e.g. Desktop/REBOUND).
2. Launch Godot 4.x.
3. Click **Import** and select **project.godot** inside the extracted folder.
4. Click **Import & Edit**.
5. Press **F6** if `main.tscn` is open, or **F5** to run the project. Press Space or Enter on the title screen.

## Controls
- A/D or Left/Right: move
- Space: jump / proceed from menus
- Escape: pause/resume
- Your first fall gives you one power-up: Skybound.
- Press P once to use Skybound. It cannot be used again, and no other power-ups are available.
- Jump through the large gate to continue directly onto the next stage.

## Important scripts
- `scripts/main.gd`: levels, UI, menus, platforms, one-time power-up, music, and progression
- `scripts/player.gd`: physics, input, coyote time, bouncing
- `scripts/spring.gd`: glowing spring that launches player
- `scripts/goal.gd`: gold level exit
- `scripts/hazard.gd`: red-pink danger areas
- `scripts/moving_platform.gd`: oscillating platform

## Developer tips
- To adjust level geometry, edit `make_levels()` in `scripts/main.gd`. Each platform uses `Rect2(x, y, width, height)`.
- The player is deliberately just a glowing ball, which is easy to replace with your own sprite.
- Tune `JUMP_FORCE`, `MOVE_SPEED`, `GRAVITY` in `player.gd` and the spring's `body.bounce(930.0)` in `spring.gd`.
- Connect Godot to Visual Studio Code by selecting it as the External Editor in Godot Editor Settings. Use Codex in VS Code to help edit the whole project.
- This starter is generated source, not a tested engine export: test locally in Godot immediately and share any errors for fixes.

## Hackathon plan
1. Test movement and respawn.
2. Test spring spawn/launch in Level 1.
3. Adjust distances so every level is enjoyable and beatable.
4. Add splash particles, background art, audio, and smooth transitions.
5. Playtest and export at least 30 minutes before submission.

The central theme is: **Your mistakes become tools for progress.**
