# Avalanche Run

An original downhill skiing arcade game for macOS, built with SpriteKit. The
avalanche is coming: ski as far as you can, dodge trees and rocks, hit ramps
for spins and thread gates for speed.

## Play

```bash
./build-app.sh
open "build/Avalanche Run.app"
```

Only the Xcode Command Line Tools are needed (Swift 5.9+, macOS 14+). The
build script compiles the Swift package, wraps it in an `.app` bundle and
ad-hoc signs it.

| Key | Action |
|---|---|
| ← → (A D) | Steer; in the air, spin |
| ↓ (S) | Tuck (faster) |
| ↑ (W) | Brake |
| Space | Jump / start |
| P or Esc | Pause |
| Return or R | Ski again after you're buried |

## Scoring

- 1 point per meter skied.
- Blue gates: +100 and a speed boost when you pass between the flags.
- Spins off a ramp: +250 per full turn, +100 per consecutive clean landing.
  Land crooked and you wipe out.
- Trees and rocks stop you dead for about a second, and the avalanche closes in.
  The gap meter at the top shows how close it is.

Best score is kept in `UserDefaults` (`net.cgallagher.avalancherun`).
