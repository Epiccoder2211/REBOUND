# REBOUND — two-person GitHub workflow

## Initial setup (project owner)
1. Install GitHub Desktop, Godot 4.x and VS Code with Godot Tools + OpenAI Codex extensions.
2. In GitHub Desktop, File > New Repository, name it REBOUND, choose a parent local folder, Create Repository.
3. Copy the CONTENTS of this folder into the newly-created REBOUND repository. Confirm `project.godot` is at REBOUND/project.godot.
4. Godot: Import `project.godot`, run with F5. Verify errors before expanding.
5. GitHub Desktop: Changes > Summary "Initial Godot 4 starter" > Commit to main > Publish repository.
6. GitHub website: Repo > Settings > Collaborators > Add people > invite teammate by username; wait for acceptance.

## Teammate setup
1. Accept collaborator invitation.
2. GitHub Desktop > File > Clone Repository > select REBOUND > choose local path > Clone.
3. Import the cloned `project.godot` in Godot 4.x. In VS Code, File > Open Folder > cloned REBOUND folder.
4. Keep Godot running while using VS Code's Godot Tools language features.

## Parallel branches
Project owner (gameplay): Current Branch > New Branch > `saatvik-gameplay` from `main` > Publish Branch.
Teammate (levels/UI): Current Branch > New Branch > `ved-levels-ui` from `main` > Publish Branch.

Game developer edits only `scripts/player.gd`, `scripts/spring.gd`, `scripts/hazard.gd`, `scripts/moving_platform.gd`.
Levels/UI developer edits only `scripts/main.gd`, `scripts/goal.gd`, and new assets. Avoid cross-edits.

## Everyday loop
1. Edit in VS Code (review any AI-generated diff before accepting).
2. Test in Godot (F5); fix errors.
3. GitHub Desktop Changes: concise Summary > Commit to your branch > Push origin.
4. When a feature is ready, Branch > Create Pull Request (or GitHub's Compare & pull request) targeting `main`.
5. Review that the PR contains only your files; merge into `main`.
6. Other teammate: GitHub Desktop > Current Branch > main > Fetch origin > Pull origin to get updates; then return to their feature branch as appropriate.
7. After both PRs merge, use one integration branch/one owner for any cross-file edits. Test and merge final branch into main.

## If a merge conflict happens
Do not blindly accept all changes or overwrite a teammate's file. Stop, inspect the conflict together in GitHub Desktop/VS Code, preserve both intended features, then test in Godot.

## Codex prompts

### Gameplay branch
"Read AGENTS.md. On branch saatvik-gameplay, examine player.gd, spring.gd, hazard.gd, and moving_platform.gd. First find parser errors and movement bugs; make only small changes to these files. Keep all signals and methods used by main.gd compatible. Improve jumping, safe grounded position, bounce reliability, and clear feedback. Ask before changing scripts/main.gd. After each change, tell me how to test it with F5 in Godot 4."

### Levels / UI branch
"Read AGENTS.md. On branch ved-levels-ui, improve visuals, HUD, title and victory screens, and layout/balance of all four levels. Work primarily in scripts/main.gd, scripts/goal.gd, and assets/. Do not change player.gd or spring.gd. Maintain the existing spring-and-respawn interface. Make small GDScript changes, explain each one, and give specific F5 test steps."

## Submit
Commit everything, verify `main` is current, test from a fresh clone if possible, export a working build, and submit before the deadline.
