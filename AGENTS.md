# AGENTS.md — avalanche-run

Original macOS arcade game (Swift Package + SpriteKit, no Xcode project, no asset files).

## Layout
- `Sources/AvalancheRun/main.swift`: app shell (window, menu, focus-loss pause) and the snapshot dev aid.
- `Sources/AvalancheRun/GameScene.swift`: all gameplay. Tuning constants are in `Tune`, key codes in `Key`.
- `Sources/AvalancheRun/Art.swift`: `Palette` + vector art (course and creatures). Sprites are baked to textures once per scene.
- `Sources/AvalancheRun/Creatures.swift`: the four creatures and snowballs, as a `GameScene` extension.
- `Sources/AvalancheRun/Audio.swift`: `Sound` (AVAudioEngine playback) + `Synth` (offline synth for every effect and the music loop).
- `Sources/AvalancheRun/Leaderboard.swift`: top-10 table in UserDefaults.
- `Sources/AvalancheRun/Settings.swift`: `Store.defaults` (where settings and scores persist) + game-speed presets.
- `build-app.sh` → `build/Avalanche Run.app` (gitignored).

## Releasing
1. In a PR, bump `CFBundleShortVersionString` and `CFBundleVersion` in `Info.plist` and add a `## X.Y.Z — date` section to `CHANGELOG.md`.
2. After merging, tag `main` with `vX.Y.Z` and push the tag. `.github/workflows/release.yml` checks that the tag matches `Info.plist`,
   builds the universal app and DMG on macOS, and publishes a GitHub release using that version's CHANGELOG section as its notes.

Builds are ad-hoc signed, not notarized (no Apple Developer account). The README explains the Gatekeeper "Open Anyway" step.
Developer ID signing and notarization would remove that step and need a $99/yr Apple Developer membership plus CI secrets.

## Repo baseline
Public repo with the `~/Code/AGENTS.md` new-public-repo baseline: secret scanning and push protection, Dependabot alerts and
security updates, private vulnerability reporting (`SECURITY.md`), SHA-pinned actions with Dependabot, and the
"main protection" ruleset requiring the `build` check. CI and release run on `macos-15`.

## Verifying visually
The agent shell has no screen-recording permission (`screencapture` fails), so the app can screenshot itself:
```bash
AVALANCHE_SNAPSHOT_DIR=/some/dir "build/Avalanche Run.app/Contents/MacOS/AvalancheRun"
```
It plays silently with a throwaway leaderboard suite, so real scores are untouched. It holds tuck, weaves and jumps, snapshots every 0.7 s,
then brakes until buried, types `CLAUDE` at the name prompt and quits by itself (`90-name.png`, `91-board.png`).
The script presses G twice first, so it runs at Turbo.
Add `AVALANCHE_DEBUG_CREATURES=1` to spawn creatures from the start, cycling yeti → penguin → bear → narwhal,
and `AVALANCHE_DEBUG_PRIZES=1` to drop a prize box 300 pt ahead of the skier every 2 s (the bot weaves too much to find normal ones).

## Gotchas
- **Universal builds without Xcode:** `swift build --arch arm64 --arch x86_64` needs Xcode's xcbuild, so `build-app.sh` builds
  each `--triple` into its own `--scratch-path` and joins them with `lipo`. That works with only the Command Line Tools.
- Swift 6.2 toolchain: top-level code in `main.swift` must be wrapped in `MainActor.assumeIsolated`.
- **Release builds can hang in the type-checker** on math that mixes `CGFloat` with untyped `.random(in:)` literals
  inside `CGPoint(...)`/`min`/`max`. Debug builds were fine and release ran past 6 minutes. Give the random value an explicit type
  (`CGFloat.random(in:)`) and split the expression; the release build then takes about 6 s.
- The snapshot run brings the window to the front, so a Return typed elsewhere can restart the game mid-script.
- Originality rule: this is its own game. Don't add mechanics, characters or art copied from any existing skiing game.
  The yeti is deliberately a horned periwinkle fuzzball that throws snowballs from the sidelines, not a pursuer that eats the skier.
