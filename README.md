# Krypto

A version of the classic **KRYPTO** mathematical card game for the **ZX Spectrum 48K**, written in Pascal using the [PASTA80](https://github.com/pleumann/pasta80) compiler.
---

## The Game

Five number cards and one target card are dealt. The objective: use all five number cards exactly once, together with `+ − × ÷`, to reach the value on the target card.

Intermediate negative values are allowed — but every division must produce an **exact integer result**; fractional intermediate values are not permitted.

Every deal is guaranteed solvable: the game runs its solver behind the scenes before showing you a hand, reshuffling automatically until it finds one it can prove.

---

## Features

- **Guaranteed-solvable deals**, verified invisibly before dealing.
- **Live, context-aware key legend** at the bottom of the screen — always shows exactly which keys do something right now.
- **Full working-area UI** — pick up cards, choose an operator, chain results, and use a dedicated parking slot to juggle multi-step calculations (e.g. computing `(13+14+8)` and `(17−12)` separately before combining them).
- **Visual feedback throughout** — colour-coded card values, a used-card indicator, a live focus indicator, and distinct styling for raw cards vs. intermediate vs. final results.
- **Wrong-answer support** — view a full worked solution, restart the same deal, or reshuffle.
- Sound effects, and runs entirely within the **48K RAM budget** of an original Spectrum.

## How to Play

You're dealt six cards: five playable, and one target (shown slightly raised, on the right — your goal number, never selectable). Pick up two cards, choose an operator, press `=` to combine them, then keep combining your running result with the remaining cards until all five are used.

Full rules and a step-by-step walkthrough are in [`MANUAL.md`](MANUAL.md).

### Controls

| Key | Action |
|---|---|
| `O` / `P` | Move card selection (top row) · Swap operands (bottom row) |
| `C` | Switch focus between the card row and the working area |
| `S` | Pick up the selected card · Park or recall a value |
| `Q` / `A` | Cycle the operator: `+` → `−` → `×` → `÷` |
| `=` | Calculate the result |
| `D` | Restart the current deal (once you've picked up a card) |
| `R` | Reshuffle for a new deal — any time |
| `E` | Exit — any time |

A vertical line on the left edge shows which half of the screen is active: **blue** (top) for the card row, **red** (bottom) for the working area — `Q`, `A`, `=`, and the `O`/`P` swap only respond while the working area is focused.

---

## Engineering Notes

Krypto looks small, but two problems made it a real challenge on a 3.5 MHz Z80 with 48K of RAM.

**Finding a solvable shuffle, fast.** A random deal isn't necessarily solvable, and a naive exhaustive search was far too slow — early versions could take seconds or minutes on hard deals. The final solver uses a compact subset/pair/triple search with aggressive elimination of redundant work, plus a time limit: if a deal can't be proven quickly, it's discarded and another is dealt. In practice, the solver and any reshuffling are invisible to the player.

> The player does not need to know that a solver is running. If a deal can't be verified quickly enough, discard it and deal another one.

**Fitting everything into 48K.** Card graphics, drawing routines, the full game engine, the solver, hint reconstruction, sound, UI, and the Pascal runtime all had to fit together. Significant effort went into shrinking compiled size without slowing the solver or risking correctness — shared drawing routines instead of duplicated ones, compact lookup tables in place of repeated code, fewer procedure wrappers, the card deck stored as compact initialized data, and a sound-effect library trimmed down to only the effects the game actually uses.

### Build directives

```pascal
{$l divmod.asm}   { Z80 assembly: combined divide+remainder, used heavily by the solver }
{$m 2048}         { 2K stack instead of PASTA80's default 4K - frees RAM for code }
{$l BeepFX2.asm}  { machine-code sound player, trimmed to only this game's effects }
```

---

## Building

```sh
pasta --zx48 --opt --dep --tap Krypto.pas
```

Produces a `.tap` (or your configured PASTA80 output) targeting the 48K Spectrum. *(Adjust to match your local PASTA80 setup/version.)*

## Running

Load the build in your emulator of choice (developed/tested with [Spectaculator](https://www.spectaculator.com/)), or transfer to real hardware via the usual `.tap` DivMMC route.

---

## Credits

- Game design & development: **Micky** ([@mickyadler](https://github.com/mickyadler))
- **Joerg Pleumann**, creator of [PASTA80](https://github.com/pleumann/pasta80) — whose compiler made a Pascal program of this size possible on a 48K Spectrum, and whose technical advice on memory, stack behaviour, and code size directly shaped this project.
- **AI assistance**: ChatGPT (OpenAI) — solver design and testing, debugging, optimization, game design; Claude (Anthropic) — graphical interface development, code analysis and optimization suggestions.
- All generated and suggested code was compiled, tested, measured, and revised on the real target platform.

### Target System

| | |
|---|---|
| Computer | Sinclair ZX Spectrum 48K |
| Language | Pascal |
| Compiler | PASTA80 |
| CPU | Z80 |
| Memory | 48K |

## License

This project is licensed under the MIT License — see [LICENSE](LICENSE) for details.
