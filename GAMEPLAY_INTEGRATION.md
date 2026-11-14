# REBOUND: EVOLUTION — gameplay integration

This branch supplies movement/progression and a reusable Echo Nexus. It does not
replace Ved's world, menus, HUD, camera, or starter main scene. No autoload or
project settings changes are required. Debug ability unlocks default to false.

## Create one manager for the journey

Keep the manager above terrain chunks and biome roots. Keep the same manager
when transitioning environments or replacing the player.

```gdscript
const PROGRESSION = preload("res://scripts/progression_manager.gd")
const NEXUS = preload("res://ui/echo_nexus/echo_nexus.tscn")
var progression: Node
var nexus: Control

func setup_gameplay(player: Node) -> void:
    progression = PROGRESSION.new() # user://echo_progression_v1.json
    add_child(progression)          # loads saved progression in _ready
    progression.bind_player(player)
    var overlay_layer := CanvasLayer.new()
    overlay_layer.layer = 20
    add_child(overlay_layer)
    nexus = NEXUS.instantiate()
    overlay_layer.add_child(nexus)
    nexus.bind_progression(progression)
```

The overlay handles Tab/Esc, pauses the SceneTree, disables the bound player,
and restores the preceding pause/active state when closed. Its Control subtree
runs while paused. Do not set the world/player to PROCESS_MODE_ALWAYS. Keep
other pause/menu owners from changing pause state while the tree is open; use
`opened`/`closed` to coordinate HUD/menu input. Use `open_tree()`/`close_tree()`,
not `show()`/`hide()`. A main-menu Nexus also works without a bound player.

Do not create multiple overlays or managers on every biome transition.
`bind_player(new_player)` disconnects old listeners, restores accumulated style,
and assigns upgrade effects from baselines. Rebinding never multiplies upgrades.
Bind after adding the player to the SceneTree. Do not reload the save every biome.

## World coins and stable IDs

Use `collect_coin(source_id)` for actual world coin objects. `add_coins(amount,
source_id)` is an idempotent generic grant and intentionally does NOT increment
the world-object pickup statistic. Coin Magnet requires ten actual pickups.

An optional procedural coin component is included; Ved can replace its drawing:

```gdscript
const COIN = preload("res://scripts/echo_coin.gd")

func spawn_coin(chunk: Node2D, at: Vector2, chunk_number: int, slot: int) -> void:
    var coin := COIN.new()
    coin.configure(progression, "chunk/%d/coin/%d" % [chunk_number, slot])
    coin.position = at
    chunk.add_child(coin)
```

The component checks ownership, attracts toward an active player when
`coin_magnet_radius > 0`, and awards +5 once. For your own coin component:

```gdscript
func on_player_pickup(source_id: String, coin: Node) -> void:
    if progression.collect_coin(source_id):
        coin.queue_free()
```

On restored chunks, skip objects for which
`has_claimed_source("coin", source_id)` is true. Do not use instance IDs or random
IDs that change on each rebuild. IDs must be nonempty, at most 180 characters,
and contain no `|`. Reward categories are separate; call the intended reward API
consistently for an object.

The save stores only a bounded set of active reward IDs, not terrain, nodes,
physics, or every historical world object. It caps at 2048 and rejects new claims
when full rather than silently allowing duplicate rewards. Use globally increasing
chunk numbers across biomes, with IDs `chunk/<number>/<kind>/<local-id>`. Once
chunks cannot EVER be revisited, call:

```gdscript
progression.retire_chunks_through(oldest_irreversibly_unloaded_chunk)
```

This removes active claims and persists one retirement watermark; all older IDs
remain ineligible. Do not retire chunks still reachable through backtracking or
respawn. Non-chunk IDs remain in the bounded ledger. Named biomes cap at 64 and
major challenge IDs at 128. The world must choose a new world/run identity or a
deliberate development reset before reusing retired numbering.

Pacing suggestion: place the first ten coins and first biome discovery in the
opening 2–3 minutes: 50 pickup coins + 50 discovery coins buys Double Jump. The
manager does not place coins or award an initial biome without a world call.

## Springs, challenges, Comebacks, and biomes

Give springs stable metadata before adding them. Normal player spring checks
emit `spring_source_bounced(id, perfect)`; the bound manager awards a first
Perfect Rebound on that ID +10 once. Existing `spring_bounced(perfect, combo)`
is unchanged. Springs without metadata keep working but earn no coin reward.

```gdscript
spring.set_meta("source_id", "chunk/12/spring/2")
```

Custom spring mechanisms that call `bounce()` outside the player's spring
checks should call `progression.reward_perfect_rebound(source_id)` after
confirming a Perfect Rebound; this method is also idempotent.

```gdscript
# World success triggers only; never invoke these merely on entering a trial.
progression.complete_challenge("velocity_trial")  # +40, permanent Dash
progression.complete_challenge("impact_trial")    # +40, permanent Slam
progression.complete_challenge("momentum_trial")  # +40, style celebration
progression.complete_challenge("ascension/skybound_1") # +100, large style reward

# Call AFTER the player overcomes the obstacle following a failed attempt.
progression.complete_comeback("chunk/12/comeback/gap_2") # +25, +250 style
progression.enter_biome("pulse_caverns") # +50 once
```

Also accepted: `ascension_challenge` and `momentum/<unique-id>`. Unknown
challenge IDs are rejected. The manager trusts world completion triggers; it
cannot determine whether terrain was crossed. Ved must arm a Comeback on failure
and call completion only at the obstacle's success boundary. Dying awards nothing.
Do not connect death directly to `complete_comeback`.

Trials unlock abilities automatically and cannot be purchased early. Require
`player.dash_unlocked`, `slam_unlocked`, or `double_jump_unlocked` before
generating a mandatory ability-specific route; supply an accessible alternative
until unlocked. Do not require Dash to earn the first Dash unlock.

## Nexus nodes and economy API

| ID | Cost | Requirement/effect |
| --- | ---: | --- |
| basic_movement | 0 | Initially unlocked |
| perfect_rebound | 0 | Initially unlocked |
| double_jump | 100 | One extra jump, -440 px/s; recharge on floor/spring |
| air_dash | 0 | Velocity Trial; Shift, one charge per airtime |
| dash_amplifier | 125 | Air Dash; duration ×1.15, speed unchanged |
| spring_mastery | 75 | One Comeback; timing 120 → 150 ms |
| energy_booster | 125 | Spring Mastery; action energy ×1.25 |
| echo_overdrive | 175 | Energy Booster; E consumes 100 energy, lasts 5 sec |
| ground_slam | 0 | Impact Trial; X, 1250 px/s |
| slam_pulse | 150 | Ground Slam; meaningful impacts emit a 120 px pulse |
| coin_magnet | 60 | Ten actual world coin pickups; 90 px radius |

`get_upgrade_definitions()` returns a fresh dictionary keyed by ID, including
`id`, `name`, `description`, `cost`, `prerequisites`, `branch`, `position`,
`challenge`, and structured `effects`. `get_node_state(id)` returns `locked`,
`available`, or `unlocked`. `get_lock_reason(id)` explains requirements.
Available means eligible, not necessarily affordable.

`try_unlock_node(id) -> bool` enforces eligibility, balance, and single purchase,
applies effects immediately, and saves. `get_coin_balance()` returns currency;
`get_statistics()` returns distance, total earned coins, world pickup count,
Comebacks, highest multiplier, total style, and unlocked node IDs.

Economy rewards are configurable manager properties: `coin_pickup_reward=5`,
`perfect_rebound_reward=10`, `comeback_reward=25`, `challenge_reward=40`,
`biome_reward=50`, `ascension_reward=100`. Configure before receiving triggers.

Manager events:

```gdscript
coins_changed(new_balance: int)
upgrade_purchased(node_id: String)
ability_unlocked(ability_id: String) # "dash" or "slam"
challenge_completed(challenge_id: String)
comeback_achieved(comeback_id: String, coins_awarded: int)
celebration(kind: String, source_id: String)
progression_loaded()
save_failed(message: String)
```

Use `celebration` for golden Comeback particles/notifications and achievement
toasts. No presentation is injected into Ved's HUD.

## Player integration and separate rewards

Existing `bounce(power=910.0)`, `die()`, `respawn(at)`, `safe_position`, `active`,
`unlock_ability(name)`, and `died(safe_position)` remain compatible.
Standalone/manual `unlock_ability("dash"/"slam"/"double_jump")` remains available;
permanent gameplay unlocks should go through the manager, which is authoritative
when applying saved upgrades.

Coins persist and purchase nodes. Energy stays 0–100 and resets on death.
Style points accumulate across deaths and saves. Spring-only `bounce_combo` is
preserved separately from `combo_multiplier` (1–8 for all qualifying actions).
The shared action timeout is 3 active seconds. Overdrive boosts ordinary
horizontal speed 12% and movement-action style 50%; it does not alter dash or
slam collision speeds. Death/expiration ends it cleanly; pause freezes it.

Player signals for Ved's animation/audio/effects:

```gdscript
spring_bounced(perfect: bool, combo: int)
dash_started(direction: Vector2)
dash_ended()
slam_started()
slam_landed(position: Vector2, impact_speed: float)
combo_changed(combo: int)
energy_changed(energy: float)
style_points_awarded(points: int, reason: String)
double_jumped()
slam_pulse(position: Vector2, radius: float)
overdrive_changed(enabled: bool)
spring_source_bounced(spring_id: String, perfect: bool)
```

Example: `player.slam_pulse.connect(on_world_pulse)`; implement the handler in
the world to query switches/destructibles within the provided radius. No
destructible objects are included here. Keep procedural nodes unscaled; current
spring geometry assumes the existing 14 px player circle.

## Endless-world death boundary

The default remains `fall_boundary_enabled=true`, `fall_boundary_y=745.0`, so
the finite starter remains playable. During endless-world setup choose one:

```gdscript
player.fall_boundary_enabled = false # world kill zones call player.die()
# OR maintain an absolute world-space boundary below the live terrain:
player.fall_boundary_y = active_chunk_bottom + 300.0
```

Update it on biome/chunk transitions and every replacement player. Ved owns
nearby safe respawns and failure-spring placement; existing main.gd is untouched.
Current distance statistics ignore jumps between samples >=100 px, but a short
teleport may count as movement; use authoritative world distance for the HUD.

## Saves and development

Production: `user://echo_progression_v1.json`; standalone demo:
`user://echo_nexus_demo_v1.json`. Files are versioned JSON, written through a
temporary file with a previous valid backup. Missing/invalid saves start safely;
corrupt primary files recover from valid backups. Unknown versions are not read.
Purchases and rewards save immediately. Style/distance save every five seconds
and on manager removal. Call `save_progression()` before a custom quit flow.
Observe `save_failed` and surface a small notification if disk writes fail.

`load_progression() -> bool`, `save_progression() -> bool` are available.
`development_reset()` is debug-build-only and rewrites the current manager's
save to defaults; never call it on death. The demo's reset affects only its
separate save. No external services or paid dependencies are used.

## Run and manually verify

Open `ui/echo_nexus/echo_nexus_test.tscn`, then use **Run Current Scene (F6)**.
The tree opens immediately. Its dedicated developer keys work while open:

- **0** reset the demo progression; **1** grant 100 demo coins.
- **2** complete Velocity; **3** complete Impact; **4** complete one Comeback.
- **5** discover the test biome; **6** simulate ten unique world pickups.
- **Tab/Esc** close/open; move with A/D, jump with Space, dash Shift, slam X.

These shortcuts belong only to the test scene, not the reusable overlay.

Manual acceptance:
1. Reset. All eleven nodes/colored connections should be visible by scrolling;
   free nodes glow, gated nodes dim, and affordable nodes gain colored borders.
2. Select Double Jump with no coins: Unlock disabled. Press 1, select it, click
   Unlock: balance decreases exactly 100, label becomes Unlocked immediately.
3. Close the tree. Jump, release Space, press again: one weaker extra jump and
   cyan burst. Third press fails. Land or bounce: extra jump recharges.
4. Reset; Shift/X must do nothing. Press 2/3: their nodes unlock, grant +40 each,
   and Shift/X work after closing. Repeat the shortcuts: no further rewards.
5. Walk across coins. Magnet remains gated until ten actual pickup events;
   generic grants do not qualify. Purchase it and approach a remaining coin.
6. Press 4 once; purchase Spring Mastery, then Energy Booster and Overdrive
   after funding with 1. Perfect timing widens; E at full energy gives a golden
   aura for five active seconds and consumes the energy. Repeating E cannot
   restart it without refilling. Buy Slam Pulse and observe world event hooks.
7. Pause via Nexus while airborne, including during dash/slam/Overdrive. Wait;
   close while holding Space/Shift/X/E. Movement resumes without firing a new
   ability until its input is released and pressed again.
8. Die: coins, purchases, and style survive; temporary combo/energy/Overdrive
   reset. Verify normal movement, variable jump, coyote time, jump buffering,
   Perfect Rebound → Dash → Slam, spring priority, and wall collisions.
9. Buy a node and complete trials, stop the demo, then run F6 again: balance,
   nodes, milestones, and reward deduplication persist. Production save remains
   separate. Reset with 0 only when intentionally testing a new demo journey.

Automated checks (prefer a temporary project copy to avoid generated import files):

```sh
godot --headless --path . --script res://tests/progression_checks.gd
godot --headless --path . --script res://tests/gameplay_checks.gd --fixed-fps 60
```

The progression checks use a unique test save, never the production save.
`REBOUND_TEST_DIR` may point at a writable temporary directory. Headless tests
verify logic/Controls/pausing; visual layout, audio integration, and controller
feel still require Play-button testing.

## Safest merge sequence

No branch/history operations were performed by this implementation. Review and
commit only the gameplay files listed with the delivery. Have Ved finish his
world changes independently. Review both PRs, merge them in the agreed order,
then use a separate integration branch to attach the manager/overlay and world
triggers. Preserve Ved's main.gd/project.godot changes; do not blanket-replace
those files. Re-run both automated suites and the manual checklist after the
merge, then test a fresh export and reserve time before submission.

## Final presentation package

Run `ui/menus/polish_demo.tscn` with **F6 / Run Current Scene** for the complete
presentation host: Main Menu → test arena → Pause Menu, Nexus, Personalization,
and How to Play. The original `ui/echo_nexus/echo_nexus_test.tscn` remains available
and still opens directly into the Nexus. Both share the separate demo save
`user://echo_nexus_demo_v1.json`; production progression is untouched.

The existing developer keys remain: **0** resets the demo, **1** grants 100,
**2/3** complete Velocity/Impact, **4** completes a Comeback, **5** discovers a
biome, **6** simulates ten unique pickups. **C** opens Personalization during
gameplay; **Esc** opens Pause in the polished host. These shortcuts are confined
to test scenes. `demo_save_path` can override the demo save for automated tests.

The Nexus now uses circular luminous nodes, a larger central core, dotted curved
prerequisite paths, traveling unlock sparks, and a deterministic cosmic
background. Costs, prerequisites, branch identities, and manager definitions
are unchanged. `POSITIONS` in the UI owns the constellation layout independently
of the progression definition coordinates. Scroll to reach the outer branches.
Keyboard focus and hover illuminate nodes; purchases produce a brief ring flash.

### Personalization integration

Add the component alongside the Nexus under your overlay CanvasLayer:

```gdscript
const PERSONALIZATION = preload("res://ui/personalization/personalization.tscn")
var personalization: Control

func setup_personalization(layer: CanvasLayer) -> void:
	personalization = PERSONALIZATION.instantiate()
	layer.add_child(personalization)
	personalization.bind_progression(progression)
	# C opens it by default. A menu button may call open_tree() instead.
```

It uses the same `open_tree()`/`close_tree()`, `opened`/`closed`, and
`hotkey_enabled` interface as Nexus. Opening pauses safely; closing guards
held jump/ability inputs. Both register in `echo_modal` and refuse to open on
top of another visible package modal. Close the current modal before navigating
to another one. Disable component hotkeys while a parent menu owns navigation.

Each cosmetic belongs to one independent slot. Defaults are free and owned:

| Slot | Cosmetic IDs | Purchase prices |
| --- | --- | --- |
| Skin | skin_echo, skin_solar, skin_void, skin_pulse | 0, 80, 90, 90 |
| Trail | trail_cyan, trail_gold, trail_nebula | 0, 65, 75 |
| Glow | glow_standard, glow_royal, glow_prism | 0, 60, 85 |

The menu previews selections locally. Purchase acquires ownership; a separate
Equip click applies it. Previewing never spends currency or changes the player.
The same procedural renderer is used by previews and the real player.

New manager methods:

```gdscript
progression.get_cosmetic_definitions() # fresh dictionary: name/slot/cost/color/description
progression.purchase_cosmetic("skin_solar") # bool, rejects duplicate/unaffordable IDs
progression.equip_cosmetic("skin_solar")    # bool, rejects unowned/already-equipped IDs
progression.get_owned_cosmetics()           # Array of IDs
progression.get_equipped_cosmetics()        # Dictionary: skin/trail/glow -> ID
progression.get_cosmetic_appearance()       # presentation snapshot
```

`cosmetic_purchased(id)` and `cosmetic_equipped(id)` are new manager signals.
Purchases share the existing wallet and atomic save path. Cosmetics are separate
from `_unlocked` power nodes and never enter ability prerequisites or stats.
`player.apply_cosmetics(appearance)` only assigns a drawing snapshot; equipping
does not reapply abilities, reset charges, alter velocity, or touch collision.
`bind_player(new_player)` automatically restores both power upgrades and equipped
cosmetics. Repeated binding/equipping cannot stack effects.

The version-1 JSON gains optional `owned_cosmetics` and `equipped_cosmetics`
fields. Older saves with neither field retain all existing progression and get
the free defaults. Invalid IDs, wrong slots, and unowned equipped items fall back
to defaults. Valid-backup recovery still applies. Reset clears cosmetics together
with progression. Do not replace an existing production save with a demo save.

### Menu integration

Reusable scenes are:

- `ui/menus/main_menu.tscn`
- `ui/menus/pause_menu.tscn`
- `ui/menus/how_to_play.tscn`
- `ui/personalization/personalization.tscn`
- `ui/echo_nexus/echo_nexus.tscn`

Add each under a CanvasLayer and `bind_progression(progression)` after adding.
Menus are hidden until `open_tree()`. They reuse tested pause ownership and emit
navigation requests rather than modifying Ved's world or loading scenes:

```gdscript
menu.journey_requested.connect(start_journey)
menu.nexus_requested.connect(open_nexus_from_menu)
menu.personalization_requested.connect(open_personalization_from_menu)
menu.help_requested.connect(open_controls)
menu.restart_requested.connect(restart_at_safe_location)
menu.quit_to_menu_requested.connect(return_to_main_menu)
menu.quit_requested.connect(quit_game)
```

Connect only signals relevant to that scene. Resume/How-to-Play Return close
their own panel; Start/Restart/Quit requests need host handlers. The standalone
demo implements all these handlers. Its `_push()`/`_pop()` is a short reference
for closing a parent before opening a child, then restoring the parent on Return.
Do not open multiple package modals concurrently or have separate menu owners
change `SceneTree.paused` behind one another. In Ved's presentation, keep these
components optional; attach their requests to his existing menu coordinator.

All menus share `presentation_theme.gd` and `cosmic_background.gd`. No external
fonts, textures, autoloads, or project settings are required. Final art may
replace the procedural drawing without changing progression or cosmetic IDs.

### Coins and reward notification hooks

The coin API/placement contract is unchanged. Bobbing affects drawing only;
pickup/magnet distances and the physics collider stay fixed. Coins now spin and
shimmer, highlight magnet attraction, and retain a 0.32-second sparkle burst
after successful collection. Their collision monitoring disables on collection
and the reward guard is set immediately. The short-lived visual cannot award
again, and automatically frees itself. New coin signal:

```gdscript
coin.picked_up.connect(on_coin_visual_pickup) # (position: Vector2, amount: int)
```

The manager emits `reward_received(amount: int, reason: String)` after a positive
credit. Reasons include `Echo Coins`, `Perfect Rebound`, `Comeback`, `Trial
complete`, `Ascension`, `Biome discovered`, and generic `reward`. This complements
`coins_changed`, which is still the authoritative HUD balance signal. Duplicate
sources emit no new reward notice. Cosmetic spending emits balance changes,
not positive reward notices.

An optional `ui/shared/reward_notifications.gd` Control binds via
`bind_progression(progression)`. Add it under a HUD CanvasLayer. It shows at most
three small notices and merges coin pickups arriving within 0.4 seconds. Its
default top-right position is a sample; Ved should position or replace it to fit
his HUD. It ignores mouse input and does not pause or capture gameplay.

Player visual changes are drawing-only: layered breathing glow, rotating rim
highlights, palette-specific accents, distinct trail styles, dash elongation,
slam stretch/chevrons, Double Jump sparks, Perfect Rebound gold, and a segmented
Overdrive orbit. Physics constants and movement transition logic are preserved.

### Final manual polish checklist

These require interactive rendering; headless success does not establish visual
quality, readability, or game feel. Start the polished demo at 1280×800, then
also resize to the intended submission resolution.

1. Main Menu: verify title/hero layout, focus and hover states; Start enters the
   arena, How to Play returns correctly, and Quit exits after saving.
2. Open Nexus: inspect all 11 circular nodes by scrolling; verify branch colors,
   dotted prerequisites, central core emphasis, selection, labels, and details.
3. Reset with 0, grant with 1, purchase Double Jump: verify the exact debit,
   immediate button state, and unlock ring. No second purchase is possible.
4. Close and verify one extra midair jump, its burst, blocked third jump, and
   floor/spring recharge. Compare tap/held ordinary jumps and coyote/buffering.
5. Complete Velocity with 2 and Impact with 3: verify existing Dash/Slam and
   spring interruption. Repeat the completion keys: no duplicate coin rewards.
6. Watch coin balance during actual pickups, Comeback (4), and biome discovery
   (5). Notices should remain small and merge coin streaks without obscuring
   Ved's eventual HUD layout.
7. Open Personalization via C or Main/Pause menu. Preview all skins, trails, and
   accents; confirm previewing neither spends coins nor changes the live player.
8. Buy a cosmetic with enough coins: exact cost deducted, then Equip available.
   Equip it: status updates and the actual player changes after closing.
9. Switch to previously owned options without spending again. Unaffordable,
   duplicate, and unowned equip attempts must remain blocked.
10. Stop and rerun F6: currency, power nodes, owned cosmetics, and equipped skin/
    trail/glow survive. An old progression save should retain powers and use
    default cosmetics. Reset only the separate demo when deliberately testing.
11. Dash with each trail and inspect the real orb with each glow. Skins must
    remain readable against the floor and at high speed; collision must feel
    identical across all appearances.
12. Pause with Esc during movement; open a child menu and return. Resume should
    restore the prior motion; no held jump/dash/slam input should fire anew.
13. Use Restart and Quit to Menu from Pause. Verify safe spawn, coin/upgrade/
    cosmetic preservation, and correct menu focus without a stuck pause.
14. Chain Perfect Rebound → Dash → Slam. Gold rebound, cyan/custom trail,
    downward silhouette, and impact effects should remain distinguishable.
15. Inspect hovering/spinning coins, magnet acceleration, one pickup burst per
    object, and automatic effect cleanup. No large obstructive pickup overlays.
16. Verify Overdrive's gold orbit and expiration/death cleanup. Cosmetic colors
	must not hide the special state. Check menu transitions do not advance it.
17. Review all screens for clipping, contrast, coherent spacing/type, keyboard
	navigation, and clarity at export resolution. Final audio and world-art
	integration remain Ved's presentation work.

Additional automated suite:

```sh
godot --headless --path . --script res://tests/polish_checks.gd
```

This tests cosmetics, old saves, no gameplay mutation, bounded notifications,
pickup cleanup, and actual demo navigation. It uses unique temporary save paths
and does not reset the normal demo or production save.

## Cinematic entry, profiles, XP, and journey summaries

Preferred demo entry: `ui/menus/cinematic_entry.tscn` → **Run Current Scene (F6)**.
This uses `ResourceLoader.load_threaded_request` to prepare the actual polished
arena scene. Progress comes from Godot; no minimum wait or fabricated percentage
is used. Failure displays an error and an exit button. Direct
`ui/menus/polish_demo.tscn` remains useful for fast iteration.

First-time demo saves now request a local nickname. `set_display_name(text)`
trims whitespace, removes control characters, accepts Unicode, caps at 24
characters, rejects empty input, and saves. No account/network dependency exists.
Personalization → **Edit Name** changes it. Returning players skip onboarding.
`display_name`, `lifetime_xp`, `reduced_motion`, and `personal_bests` are manager
properties; `profile_changed` and `xp_changed(total, level)` are UI hooks.
`get_player_level()` derives level from cumulative XP; `xp_threshold(level)`
returns the threshold. Do not independently modify coins, energy, or style to
represent XP. Settings exposes persistent reduced motion; decorative star/orb/
Nexus animation pauses while essential movement feedback remains readable.

The version-1 save now has optional profile/XP/records/history/settings fields.
Old purchases and cosmetics stay intact. Missing fields use defaults. Recent
run history is capped at ten sanitized metric dictionaries, and milestone gifts
are reconstructed from XP on load. There is no external inference or telemetry.

### Run lifecycle for Ved

```gdscript
# One start per actual journey, not on every death or biome transition.
progression.start_run() # false if already running

# Report forward route progress in world pixels from the run's starting point.
# Supply a verified monotonic route coordinate; never add absolute frame movement.
progression.report_run_distance(verified_forward_distance)

# Existing calls also award XP exactly once through their existing unique IDs:
progression.complete_challenge("velocity_trial") # +40 XP
progression.complete_comeback("chunk/42/comeback/gap") # +30 XP
progression.enter_biome("skybound") # +50 XP
progression.complete_challenge("ascension/skybound_1") # +100 XP

# End once on explicit journey completion/abandonment, not each respawn.
var summary: Dictionary = progression.end_run() # empty on duplicate call
```

`run_completed(summary)` delivers distance, active duration, coins/XP earned,
actual jumps/rebounds/dashes/slams/falls, best combo, style earned, completed
challenges, Comebacks, record labels, milestone gifts, and offline insights.
The manager subscribes once to player signals and disconnects on replacement;
`jumped()` is new, while all existing signals remain. Pauses do not advance run
duration. World challenge/coin/biome/Comeback events use the existing deduplication
rules. Do not report player events a second time from the world.

Distance is deliberately NOT inferred from the old cumulative movement statistic.
Ved must reject teleports/respawn displacements and backtracking in his route
measurement. The standalone arena demonstrates a forward-X maximum. Reaching
at least 1000 px beyond the previous distance best gives +75 XP; improving combo
to at least ×3 gives +50 once per new record. Completion XP is 5 per 500 px,
capped at 25, requires 20 active seconds and at least one newly completed
challenge/Comeback. Idle runs, repeated deaths, and empty summaries give no XP.
`xp_rewards` exposes configurable milestone/record award values. Only internal
validated completion paths call `_grant_xp`; do not connect it to raw movement.

XP levels: 1 at 0, 2 at 100, 3 at 250, 4 at 500, 5 at 900. Higher levels use
`xp_threshold()`'s increasing curve. Gifts are free, exclusive, and equipable:

| Level | Gift ID | Slot |
| --- | --- | --- |
| 2 | glow_spark | Glow |
| 3 | trail_star | Trail |
| 5 | skin_champion | Skin |
| 10 | glow_celestial | Glow |

`milestone_unlocked(level, cosmetic_id)` fires only for new awards. Gift entries
have a `level` requirement and cannot be bought with coins. Personalization shows
that requirement until earned. The base catalog remains intact; totals are now
5 skins, 4 trails, and 5 glows. Ownership and selection use existing cosmetic APIs.

`performance_insights.gd.analyze(run, history, dash_unlocked)` is a reusable
pure offline rules service. It checks measured timing rate, combo performance,
dash use, records, and previous-run distance. It makes no claim to be a live
language model. An empty run receives neutral guidance, not invented achievements.

The demo ends a run on Pause → Restart or Quit to Menu and shows Journey Complete
before returning to Main Menu. The summary animates earned XP and lists gifts,
records, and a maximum of three concise insights. `profile_panel.gd` supports
`profile`, `settings`, and `summary` modes; set mode before adding it, bind the
manager, and use normal modal `open_tree()`/`close_tree()` ownership. A summary
requires its `summary` dictionary before opening. The gameplay API works even
if Ved chooses a different summary UI.

### Resolution support

The demo sets only its own Window's logical resolution to **1700×956**, canvas
items scaling, and expanded aspect. `project.godot` is unchanged. The same pattern
is available to Ved's final host:

```gdscript
get_window().content_scale_size = Vector2i(1700, 956)
get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
get_window().content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
```

Containers/anchors operate in logical coordinates; uniform canvas scaling keeps
Echo circular. Nexus retains scrollable outer branches. Test window sizes
3400×1912, 1920×1080, 1600×900, and 1280×720. Headless tests verify logical
container dimensions at all four, but do not establish visual sharpness or
clipping on a physical display. In the running demo use Remote → root Window →
Size to set each resolution, or launch Godot with `--resolution WIDTHxHEIGHT`.
The arena currently sets a starting 1280×800 window; override it in Remote after
startup for these tests. No global display settings were changed.

### Final profile acceptance

1. Run cinematic entry with a fresh demo save (demo key 0 resets all demo progress;
   restart afterward). Enter a Unicode nickname; blank names should be rejected.
2. Verify Welcome, name, Level 1, and XP bar. Restart: no name prompt and Welcome
   Back. Personalization → Edit Name updates the local profile.
3. Start a journey. Keys 2, 3, and 4 complete two trials and a Comeback: 110 XP,
   Level 2, First Spark gift. Repeat them: no additional XP. Equip the gift.
4. Key 5 discovers the biome. End via Pause → Quit to Menu. Inspect actual run
   totals, insights, XP animation, and gifts. Reopening or ending again must not
   award twice. An empty journey should not show invented records.
5. Restart: profile, XP, gifts, purchased nodes, and cosmetics persist. For higher
   milestone testing use unique Ascension completions in an isolated test save;
   do not expose raw XP grants in production input.
6. Test Settings → Reduced motion, then reopen each menu. Decorative motion
   should settle while mouse navigation and gameplay remain responsive.
7. Test How to Play, Nexus purchases, Personalization, Escape/Tab/C ownership,
   summary return, and held-input suppression after every modal transition.
8. Review appearance interactively at all four resolutions, especially long
   names, summary wrapping, scrollable Nexus paths, and focus/hover contrast.

Run the additional suite with:
`godot --headless --path . --script res://tests/profile_checks.gd`.
Existing gameplay/progression suites remain applicable. The polish suite now
expects the four extra gifts, onboarding-disabled fixture setup, and explicit
journey summaries on Restart/Quit. These are intentional acceptance updates.
