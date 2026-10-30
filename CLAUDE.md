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

- `scripts/main.gd`: world root; loads a new map each round, spawns player, HUD, touch controls.
- `scripts/world/structure.gd`: breakable structures. Intact pieces are frozen
  `RigidBody3D`s (free for physics); damage unfreezes them and `_settle()` drops
  whatever lost support. Disasters only talk to structures through `quake()`,
  `damage_sphere()` and `apply_field()` via `call_group("structures", ...)`.
  Intact pieces are drawn as MultiMesh batches (plain boxes: one unit cube scaled and
  tinted per instance), so a building is a few draw calls; check `--perf` draw counts
  after adding pieces. Shaders on batched boxes must read the piece size from
  `MODEL_MATRIX` scale, not from `VERTEX`.
- `scripts/world/interior.gd`: rooms per floor (partition with a doorway) and furniture
  against the walls; all ordinary structure pieces.
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
- `scripts/world/debris.gd`: pooled chunks that pieces shatter into (explosions, very
  strong winds, hard landings; glass always). Falling pieces that hit hard call
  `impact()` on structures, so collapses spread.
- `scripts/world/weather.gd`: sky, sun, fog and the sea. Each round picks a time of day
  (`TIMES`: morning, day, golden, night; `--time=` forces one) and each disaster sets a
  `mood` (clear, dust, dusk, overcast, storm, ash) that the weather blends into from the
  warning on; moods are tinted by the time of day. Rain wets the ground (puddles via
  the `wetness` global), storms throw lightning bolts, rain ends in a rainbow, clear
  nights get stars and an aurora, and a lens flare follows the sun.
- `scripts/world/effects.gd`: pooled particle bursts (explosions, dust from breaking
  pieces), reached through `call_group("effects", ...)`.
- `scripts/world/maps.gd`: the small maps (skyscraper, garden house, apartment, neighbourhood).
- `scripts/disasters/`: `disaster.gd` base + one file per disaster, registered in
  `disaster_manager.gd`'s `DISASTERS`. `projectile_pool.gd` is shared by meteors and lava bombs.
- `scripts/player/player.gd`: first-person controller; world effects go through
  `push()`, `set_water()`, `explode_at()`, `take_damage()`, `add_shake()`.
- `scripts/ui/`: HUD and touch controls (shown on phones and with `-- --touch`): floating
  analog stick (auto-sprint at full forward), drag-to-look that ignores impossible jumps
  (browsers renumber fingers), jump/sprint buttons, a settings panel (sensitivity,
  invert; saved in `user://settings.cfg`). Touches also reach GUI as emulated mouse.
  Touch can be tested under `xvfb-run` by feeding `InputEventScreenTouch/Drag` through
  `Input.parse_input_event()` + `Input.flush_buffered_events()` (not in `--headless`).
- Everything is built in code; `scenes/main.tscn` only holds the root script.

## Performance rules

Mobile and web are the targets, so: nothing is instanced during a round (pool it),
intact geometry stays frozen, disasters touch physics on a fixed 0.1 s tick, and
shared meshes/materials/shapes come from caches. Web builds use the Compatibility
(OpenGL) renderer; check visuals there too (`--rendering-method gl_compatibility`).

## Checking changes

If Godot is not installed, get the Linux build (same URL pattern the workflow uses):

```bash
wget -q https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_linux.x86_64.zip
unzip -q Godot_v4.7.2-stable_linux.x86_64.zip && mv Godot_v4.7.2-stable_linux.x86_64 godot
./godot --headless --path . --import                       # parse errors show up here
./godot --headless --path . -- --fast --log --run-for=80   # runs several full rounds
```

Debug options after `--` are documented at the top of `scripts/core/debug_tools.gd`
(`--fast`, `--log`, `--perf`, `--map=<i>`, `--disaster=<i>`, `--time=`, `--shots=<dir>`, `--pos=`,
`--yaw=`, `--pitch=`, `--touch`). Screenshots need a display: `xvfb-run -a` works.
If the download is blocked, push and rely on the workflow's export step instead.
