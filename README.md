# Avalanche Run

An original downhill skiing arcade game for macOS, built with SpriteKit. The
avalanche is coming: ski as far as you can, dodge trees, rocks and the locals,
hit ramps for spins and grabs, chain tricks into combos, and sign the
high-score board.

## Install

Requires macOS 14 (Sonoma) or later, on Apple silicon or Intel.

1. Download `AvalancheRun-<version>.dmg` from the
   [latest release](https://github.com/git-cgallagher/avalanche-run/releases/latest).
2. Open it and drag **Avalanche Run** onto the **Applications** folder.
3. Eject the disk image and launch Avalanche Run from Applications or Launchpad.

**First launch:** the app is signed but not notarized by Apple (that needs a paid
Apple Developer account), so macOS blocks the first launch with a warning that it
can't verify the app. To allow it:

- Open the app once and dismiss the warning. Then go to **System Settings ▸ Privacy & Security**,
  scroll to the message about Avalanche Run, and click **Open Anyway**.
- Or, from Terminal:

  ```bash
  xattr -dr com.apple.quarantine "/Applications/Avalanche Run.app"
  ```

You only need to do this once per version.

## Build from source

Only the Xcode Command Line Tools are needed (Swift 5.9+); full Xcode isn't required.

```bash
./build-app.sh                  # universal build/Avalanche Run.app (arm64 + x86_64), ad-hoc signed
open "build/Avalanche Run.app"
./make-dmg.sh                   # build/AvalancheRun-<version>.dmg with an Applications shortcut
```

| Key | Action |
|---|---|
| ← → (A D) | Steer; in the air, spin |
| ↓ (S) | Tuck (faster) |
| ↑ (W) | Brake |
| ↓ in the air | Grab (ramp air only) |
| Space | Jump / start |
| P or Esc | Pause |
| M | Cycle sound: music + effects → effects only → muted |
| G | Cycle game speed (title or pause screen) |
| ⌘1 – ⌘4 | Game ▸ Speed menu: Chill, Normal, Fast, Turbo |
| H | High scores (title screen) |
| Return or R | Ski again after you're buried |

## Scoring

- 1 point per meter skied.
- Tricks score at your current **combo multiplier** (×1 up to ×8). Each trick
  adds one to the chain; you have 3 seconds on the ground to land the next one
  (the clock pauses in the air). Crashing loses the combo.

| Trick | Base points |
|---|---|
| Spin off a ramp or jump | 250 per full turn (land within ~45° of straight or you wipe out) |
| Grab (hold ↓ for ¼ s on ramp air) | 100 |
| Big air (a second or more aloft) | 100 |
| Gate (pass between the blue flags, also a speed boost) | 100 |
| Clear (jump over a tree or rock) | 50 |
| Hop a creature | 250 |
| Close call (just miss a creature) | 150 |
| Dodge a snowball mid-air | 100 |

## Prize boxes

Purple gift boxes turn up every 120–220 m. Ski (or jump) through one and the
avalanche either **freezes for 4 seconds** (more time) or gets **shoved back
50 m** (more distance). The gap meter turns ice-blue and counts down while it's
frozen. If the avalanche is already far behind, you always get the freeze, so
the prize is never wasted. Each box is also a 50-point trick for your combo.

## Game speed

Four speeds scale the whole simulation clock (skier, avalanche, creatures and
timers together): **Chill 0.75×, Normal 1×, Fast 1.25×, Turbo 1.5×**. Change it
with G on the title or pause screen, or from the Game menu (⌘1–⌘4). It's
remembered between launches. A HUD tag shows any speed other than Normal.
Physics substeps at 60 Hz or finer, so Turbo can't skip through trees.

## The locals

After 200 m, one creature at a time turns up at random, more often the further
down you get. A red **!** badge at the screen edge says who's coming.

- **Penguin**: belly-slides across the run ahead of you.
- **Polar bear**: charges uphill, homing for a moment before it commits.
- **Yeti**: a horned fuzzball that runs along the edge and lobs three snowballs at where you're headed.
- **Narwhal**: a ripple appears in the snow ahead, and it breaches as you arrive.

Getting hit stops you like a tree does. Jumping over one scores big.

## High scores

Finish in the top 10 and you're asked for a name (up to 12 characters,
Return to save). Runs that weren't at Normal speed are tagged with the
**slowest** speed used during the run, so you can't run Chill and switch to Turbo
in the pause menu to get a Turbo tag. The table is stored locally in `UserDefaults`
(`net.cgallagher.avalancherun`).

## Audio

All music and sound effects are synthesized in code at launch
(`Audio.swift`); the app ships no audio files. The music is a 16-bar loop in A
minor, and a low rumble swells as the avalanche closes in.
