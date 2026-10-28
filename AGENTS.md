# AGENTS.md — avalanche-run

Original macOS arcade game (Swift Package + SpriteKit, no Xcode project, no asset files).

## Layout
- `Sources/AvalancheRun/main.swift`: app shell (window, menu, focus-loss pause) and the snapshot dev aid.
- `Sources/AvalancheRun/GameScene.swift`: all gameplay. Tuning constants are in `Tune`, key codes in `Key`.
- `Sources/AvalancheRun/Art.swift`: `Palette` + vector art. Obstacles are baked to textures once per scene.
- `build-app.sh` → `build/Avalanche Run.app` (gitignored).

## Verifying visually
The agent shell has no screen-recording permission (`screencapture` fails), so the app can screenshot itself:
```bash
AVALANCHE_SNAPSHOT_DIR=/some/dir "build/Avalanche Run.app/Contents/MacOS/AvalancheRun"
```
It starts a run, holds tuck, weaves, and writes `1-title.png` … `5-end.png` over ~16 s. Kill it afterwards.

## Gotchas
- Swift 6.2 toolchain: top-level code in `main.swift` must be wrapped in `MainActor.assumeIsolated`.
- The snapshot run brings the window to the front, so a Return typed elsewhere can restart the game mid-script.
- Originality rule: this is its own game. Don't add mechanics, characters or art copied from any existing skiing game.
