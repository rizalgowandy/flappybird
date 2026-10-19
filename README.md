# Flappy Bird

A Flappy Bird clone built with **Godot 4.7** (GL Compatibility renderer).

![Flappy Bird](assets/sprites/bird1.png)

## Features

- Classic one-tap flapping gameplay
- Procedural pipe spawning with a reachable-gap generator (gaps never jump further than the bird can climb)
- Home / Ready / Playing / Game Over state machine
- Persisted best score (`user://flappy.cfg`)
- Fullscreen toggle
- Headless autoplay test that drives the real game scene

## Controls

| Action | Keys |
| --- | --- |
| Flap / Start / Restart | `Space`, `Up`, `W`, `Enter`, left mouse click |
| Toggle fullscreen | `F11` |

## Running from the editor

1. Install [Godot 4.7](https://godotengine.org/download).
2. Open `project.godot`.
3. Press **F5** to play.

## Building a Linux release

The project ships a `Linux` export preset that produces a single self-contained
executable (the PCK is embedded in the binary):

```bash
godot --headless --export-release "Linux" build/linux/flappybird.x86_64
chmod +x build/linux/flappybird.x86_64
./build/linux/flappybird.x86_64
```

## Releases

Pushing a tag matching `v*` triggers the
[release workflow](.github/workflows/release.yml), which exports the Linux
build and attaches it to a GitHub Release:

```bash
git tag v0.1.0
git push origin v0.1.0
```

You can also run the workflow manually from the **Actions** tab (it will build
and upload the artifact without creating a release). Download published builds
from the [Releases](https://github.com/rizalgowandy/flappybird/releases) page.

## Testing

A headless autoplay test drives the real `scenes/main.tscn` with a predictive
autopilot. It exits `0` when the target score is reached and `1` when the time
budget expires.

```bash
godot --headless --path . --fixed-fps 60 res://test/autoplay.tscn -- --target 30 --minutes 2
```

## Project structure

```
assets/sprites/   Sprite textures (bird frames, pipes, background, ground)
scenes/           main.tscn, bird.tscn, pipe.tscn
scripts/          bird.gd, game.gd, ground.gd, pipe.gd
test/             autoplay.tscn / autoplay.gd (headless self-test)
export_presets.cfg  Export configuration (Linux)
```

## License

This is a learning/demo project. Flappy Bird is a trademark of its respective
owner; this is an independent clone.
