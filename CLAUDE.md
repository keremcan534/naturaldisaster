# Natural Disaster

Original first-person disaster survival game (Roblox-style genre, our own maps and
mechanics), built in **Godot 4.7.2 + GDScript**, mobile first. The user writes in
Turkish; answer in Turkish.

## How the user tests

The user plays on their phone at https://keremcan534.github.io/naturaldisaster/

`.github/workflows/pages.yml` exports the web build and deploys it on **every push,
from any branch** (the site shows whatever was pushed last). So when a change is
done and checked, **commit and push it** without waiting to be asked; then tell
the user the build takes about 3 minutes and that the version label under the
health bar (`<commit> <time>`) shows which build their phone has loaded. If the
phone shows an old label, a refresh fixes it (Pages caches for ~10 minutes).

Check the run with `gh run list --limit 1` / `gh run watch` when `gh` is available.

## Layout

- `scripts/main.gd`: world root; builds the player, HUD, touch controls, AI bots, menus and
  the round loop. Starts in the main menu (live island behind it); OYNA starts a session
  (`DisasterManager.start(keep_map)`), the pause menu (touch menu button, Esc, or a lost
  pointer lock on desktop) can go back (`stop()`). The game never pauses.
- `scripts/ui/menu.gd` (main menu with the player's character standing near the spawn,
  shop, settings, pause), `settings_panel.gd` (shared settings window), `ui.gd` (panel and
  button styles, coin label).
- `scripts/core/settings.gd`: control settings (sensitivity, invert, button size/spots,
  auto-jump), section "touch" of `user://settings.cfg`. `profile.gd`: coins, records, shop
  items (perks the player reads at respawn, outfits), daily gift, in `user://profile.cfg`.
- Scoring (`disaster_manager.gd`): survivors get 100 + half their health + streak and team
  bonuses; `round_scored` shows the scoreboard; the player's points / 5 become coins.
  `scripts/core/progress.gd`: XP and levels, three daily missions (same for everyone each
  day), achievements; `record_round()` gets what happened (kinds survived, height,
  flawless, team) and returns toasts for the HUD. Saved in the "progress" section of
  `user://profile.cfg` (both modules load the file before saving, keep it that way).
  First play shows a tutorial (menu.gd) while the round clock waits.
- Modes (`DisasterManager.MODES`, picked with the menu's MOD button, `Settings.game_mode`):
  Klasik, Kaos (double every round), Zor (all Kıyamet), Sadece Su, Son Kalan (the fallen stay
  out until one is left). `scripts/core/events.gd`: the week's event (from the week number)
  favors some disasters, doubles coins for surviving them and sells an event outfit.
  Results open a map vote (`vote_started`, HUD buttons or keys 1-3; bots vote too) and
  `load_next_map(choice)` takes the winner. `scripts/world/rescue_heli.gd` (group "rescue")
  sometimes flies to the highest refuge roof mid-disaster; reaching its ladder calls
  `rescue()` on players/bots (no more damage that round, bonus points).
- Player extras: crouch, mantling ledges, items bought in the shop (`items`, parachute /
  bandage / hook, keys 1-3), helping hurt bots (stand next to them), F makes the nearest bots
  `follow()`, G waves, P takes a photo (`scripts/core/photo.gd`: a download on the web),
  gamepad, optional gyro aim (`scripts/core/gyro.gd`, browser device motion).
- `scripts/player/bot.gd`: AI teammates in the "player" group (disasters treat them like
  the player; anything called on "player" must exist on bots too). They react a moment
  after the warning: tsunami → up a building (`Maps.refuges`: `Structure.climb_path`
  through the door and up the ramps, or a ladder), quake → open ground (`Maps.buildings`),
  meteors → inside, tornado → away from `danger_center()`, volcano → the +Z side, fire →
  open ground, lightning/hail/acid/sand → inside. They shout lines (`SHOUTS`) in a bubble.
  `--botlog` prints what they do. Each has a personality (korkak / cesur / şakacı) and a
  skill drawn from the bot level setting; they shout for help when hurt and cheer after a
  round. `avatar.gd` + `shaders/avatar.gdshader`: blocky
  character in one draw call (limbs swing in the shader); also the player's shadow.
- `scripts/world/structure.gd`: breakable structures. Intact pieces are frozen
  `RigidBody3D`s (free for physics); damage unfreezes them and `_settle()` drops
  whatever lost support. Disasters only talk to structures through `quake()`,
  `damage_sphere()` and `apply_field()` via `call_group("structures", ...)`.
  Intact pieces are drawn as MultiMesh batches (plain boxes: one unit cube scaled and
  tinted per instance), so a building is a few draw calls; check `--perf` draw counts
  after adding pieces. Shaders on batched boxes must read the piece size from
  `MODEL_MATRIX` scale, not from `VERTEX`.
- Fire: `Structure.ignite(center, radius)` sets pieces burning; each structure spreads
  it on its own 0.5 s tick through the piece links (up easily, sideways, down slowly),
  chars pieces (instance color, or the building shader's `INSTANCE_CUSTOM.r` with glowing
  embers) and drops burnt ones. `collect_fire()` lists burning spots, `extinguish()`
  puts all out; `Structure.fires` counts them. `scripts/world/flames.gd` draws flames
  (one MultiMesh, `shaders/flame.gdshader`), smoke and light, and burns anyone close.
  The fire disaster, meteors and lava bombs (`ignite_chance`) start fires.
- Building stairs (`Structure._add_ramp`): every floor's ramp runs along the back row
  from a 1 m landing to the fourth column, stacked one storey apart; the second row is
  the walkway back to the next ramp's foot, and furniture keeps clear of both. When
  changing buildings, check a player can walk from the front door up to the roof.
- `scripts/world/interior.gd`: rooms per floor (partition with a doorway) and furniture
  against the walls (homes, or lobby + desks for offices); `place()` is reused by the
  mall's shops. All ordinary structure pieces.
- `scripts/world/mall.gd`: the mall map's building: atrium with skylight, columns,
  escalator ramps (`Structure.add_incline`), glass railings, shops, food court, fountain,
  arcade, cinema, roof car park.
- Pieces can carry a meta the player reacts to: `"bounce"` (trampolines, launch speed)
  and `"ladder"` (climb while pushing forward). Slabs only hold two cells sideways from
  what supports them: when adding open floors, check every structure with `_settle()`
  right after building (nothing may drop at rest).
- `scripts/world/look.gd`: the visual style; procedural textures (generated once, no
  image files) and cached materials. Structures get theirs through `Look.surface(color)`;
  `Look.GLASS_KEY` pieces get see-through glass (window shader), `CAR_GLASS_KEY` plain
  dark glass. Wall pieces are rotated so local +Z faces outward: the building shader
  paints them outside/inside, and gives slabs a plank floor and a ceiling.
- `shaders/`: `sky_common.gdshaderinc` (the sky as a function of direction; the sky,
  water and glass all use it, so reflections show the real clouds and sun), ground
  (road markings, contact shadows), water include (`SEA` Gerstner swells + shore foam,
  `TSUNAMI` breaking wave, pools with a tiled floor), window, building, grass, leaves,
  lava, flowers. Weather values shared by shaders are global uniforms declared in
  `project.godot` `[shader_globals]` (sky/sun/cloud colors, night/stars/aurora/rainbow,
  wetness, wind, wave height, island size, player position for grass).
- `scripts/world/debris.gd`: pooled chunks that pieces shatter into (most breaks: forces,
  quakes, hard landings; glass always), drawn as two MultiMeshes (solid, glass) whose
  instances follow the bodies, and on their own physics layer (5) so they don't collide
  with each other. Loose structure pieces have no mesh of their own either: they stay in
  their batch and `Structure._process` moves the instance while the body moves. Falling
  pieces that hit hard call `impact()` on structures, so collapses spread, and
  `rumble()` the player's view; big drops roll out a dust cloud (`effects.cloud`).
  Tsunamis may split buildings in two (`Structure.cleave`), acid eats them
  (`dissolve`), sinkholes drop them (`sink`), ash crushes roofs (`overload`).
  Pieces tagged "explosive" (red barrels) blow up and "power" poles spark
  (`scripts/world/hazards.gd`).
- Physics interpolation is on in the project but off from the world root down; it is
  switched back on for things moved in physics steps (structures, debris, bots,
  projectiles, the tornado, the ship), which draw with `get_global_transform_interpolated()`
  and call `reset_physics_interpolation()` after teleports. Nodes moved in `_process`
  stay off. `scripts/core/warmup.gd` draws every effect's material once behind the menu
  so web shader compiles don't freeze a round. Settings has a performance readout.
- Chaos: disasters are tuned to bring weak houses down (tsunami rips out ground floors,
  quakes collapse them); building `strength` decides who survives (skyscraper 2.6,
  mall 2.4, apartment 2.0 stand; houses ~1 fall). Every map also gets weak clutter
  (crates, barrels, bins, benches, lamps along roads, cones) that flies first.
  `Structure.awake` counts moving loose pieces; past the quality level's `chaos` budget
  new breaks crumble to dust instead, and the debris pool is sized from it too. Jolt is
  set to fewer solver steps and earlier sleep (project.godot) to keep this cheap.
- `scripts/world/weather.gd`: sky, sun, fog and the sea. Each round picks a time of day
  (`TIMES`: morning, day, golden, night; `--time=` forces one) and each disaster sets a
  `mood` (clear, dust, dusk, overcast, storm, ash) that the weather blends into from the
  warning on; moods are tinted by the time of day. Rain wets the ground (puddles via
  the `wetness` global), storms throw lightning bolts, rain ends in a rainbow, clear
  nights get stars and an aurora, and a lens flare follows the sun.
- `scripts/world/ambience.gd`: ships sailing around the island and seagulls
  (`shaders/birds.gdshader`, moved entirely in the shader).
- `scripts/core/sound.gd`: all audio is generated in code at startup (no files), one sound
  per frame in the menu. `call_group("sound", "play", name, pos)` for one-shots (siren,
  boom, crash, splash, click, coin) and `"loop", name, level, pitch` every frame/tick to
  keep a loop (rumble, wind, fire, surf, rain) going; it fades when the calls stop.
  `"music", "calm"/"tense"` crossfades the generated music (built a slice per frame).
- `scripts/world/effects.gd`: pooled particle bursts (explosions, dust from breaking
  pieces), reached through `call_group("effects", ...)`.
- `scripts/world/maps.gd`: the maps (skyscraper with offices, a helipad and a cafe, garden
  house with a playground, apartment with a corner shop, neighbourhood, mall, port with
  gantry cranes, container stacks, a lighthouse and a moored ship); trampolines, slides
  and ladders up some buildings. Ladders become bot refuges through `_add_ladder_refuge`.
- `scripts/world/maps_extra.gd`: 13 more maps (school, hospital, stadium, village, camp,
  castle, city with a gas station, airport, funfair, river with a bridge and swimmable
  water via `water_zone.gd`, desert town, ski resort, oil rig) built with maps.gd's
  helpers passed in as `M`; towers with ladders (`_tower`) and concrete bunkers become
  bot refuges; `elevator.gd` lifts jam in quakes. Frames like the big wheel raise
  their structure's `span_limit`.
- Omens (`DisasterManager._omens`): the sea draws back before a tsunami
  (`weather.drain_sea`), the gulls flee before a quake or an eruption (`ambience.scatter`).
- Severity: every disaster rolls Şiddetli / Felaket / Kıyamet (`power` 1.15 / 1.4 / 1.7,
  catastrophic ones commoner as a session goes on); there are no easy rounds.
- `scripts/disasters/`: `disaster.gd` base + one file per disaster, registered in
  `disaster_manager.gd`'s `DISASTERS`. `projectile_pool.gd` is shared by meteors and lava bombs.
  A disaster can set `safe_height` (how high bots climb), a longer `warning_time` and
  `danger_center()`. `tsunami.gd` takes its wave size from vars; `mega_tsunami.gd` raises
  them and surfs a cargo ship (`scripts/world/ship.gd`, one mesh) down the wave: it plows
  through weak houses, stops at the first strong building, runs aground and stays
  (`world.keep_on_map`). The tornado is shader layers on lathe meshes
  (`shaders/tornado*.gdshader`: core and sheath, wall cloud, dust moved in the shader).
  `sky_hazard.gd` is the base for hail, acid rain and sandstorm: `exposed()` (nothing
  overhead, a ray straight up) decides who gets hurt. `lightning_storm.gd` marks each
  strike with a glowing ring first and calls `weather.strike_at()`; `flood.gd` is a
  tsunami with no wave whose water just rises. The manager sometimes runs a second
  disaster from `COMBO_PARTNERS` alongside the main one (double disaster).
- `ROADMAP.md`: the backlog of everything planned or imagined, in Turkish, with what is
  done; keep it up to date when adding features.
- `scripts/player/player.gd`: first-person controller at human scale (1.75 m, 0.3 m
  radius, 4.5/7 m/s, ~1.3 m jump, horizontal 90° FOV); world effects go through
  `push()`, `set_water()`, `explode_at()`, `take_damage()`, `add_shake()` (ground shaking:
  sways footing) and `rumble()` (view only). The head is top-level and placed every frame
  between the last two physics positions (`Engine.get_physics_interpolation_fraction()`),
  so move it with `teleport()`/`set_view()`, not by setting transforms. Dead players
  watch a bot. Touch screens get auto-jump over knee-high things.
- `scripts/ui/`: HUD (FPS / quality readout, warning card on `disaster_warned`, who-fell
  feed, red flash when hurt, toasts, an arrow toward `DisasterManager.danger_for()`,
  i.e. each disaster's `danger_point()`) and touch controls (shown on phones
  and with `-- --touch`), laid out like PUBG Mobile: floating analog stick in the lower
  left (full forward sprints; dragged up onto the lock and released, it auto-runs),
  drag-to-look everywhere else (every finger tracked by index from press to release; the
  view turns only by the newest look finger's own movement, so a second finger never
  makes it jump; never drop fast swipes: on slow frames one event carries a big step), a big
  jump button under the right thumb with small buttons around it (crouch toggle, owned
  items with counts; "Takip" and "Selam" next to the menu button), a menu button (sensitivity, invert, button size,
  "Tuşları yerleştir" to drag the stick/jump spots, graphics quality; all saved in
  `user://settings.cfg`, keep other sections when saving). Touches also reach GUI as
  emulated mouse.
  Touch can be tested under `xvfb-run` by feeding `InputEventScreenTouch/Drag` through
  `Input.parse_input_event()` + `Input.flush_buffered_events()` (not in `--headless`).
- Everything is built in code; `scenes/main.tscn` only holds the root script.

## Performance rules

Mobile and web are the targets, so: nothing is instanced during a round (pool it),
intact geometry stays frozen, disasters touch physics on a fixed 0.1 s tick, and
shared meshes/materials/shapes come from caches. Web builds use the Compatibility
(OpenGL) renderer; check visuals there too (`--rendering-method gl_compatibility`).
The web page (`export_presets.cfg` head include) shows uncaught JS errors and a lost
WebGL context in a red box, so the user can screenshot them.

`scripts/core/quality.gd` has three levels (Düşük/Orta/Yüksek) plus auto mode, which
measures FPS and moves between them; phones start on Düşük. Levels change MSAA,
shadows, glow, grass count and draw distance (grass is chunked so far chunks are not
drawn), rain, the lens flare, and the `quality` shader global that shaders check to
skip expensive parts. Never lower the render resolution: the user does not want a
pixelated picture. New expensive shader work needs a cheap path under `quality`.
Software rendering under xvfb is slow but its FPS (`--perf`) still compares costs.

## Checking changes

If Godot is not installed, get the Linux build (same URL pattern the workflow uses):

```bash
wget -q https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_linux.x86_64.zip
unzip -q Godot_v4.7.2-stable_linux.x86_64.zip && mv Godot_v4.7.2-stable_linux.x86_64 godot
./godot --headless --path . --import                       # parse errors show up here
./godot --headless --path . -- --fast --log --run-for=80   # runs several full rounds
```

Debug options after `--` are documented at the top of `scripts/core/debug_tools.gd`
(`--fast`, `--log`, `--perf`, `--quality=<0-2>`, `--map=<i>`, `--disaster=<i>`, `--time=`, `--shots=<dir>`, `--pos=`,
`--yaw=`, `--pitch=`, `--touch`, `--play` skips the menu, `--botlog`, `--mode=<i>`, `--rescue`; `--perf` also prints
the number of burning pieces). Screenshots need a display: `xvfb-run -a` works.
If the download is blocked, push and rely on the workflow's export step instead.
