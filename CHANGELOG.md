# Changelog

## Release 1.2 — 30 September 2026

Source: `game resources/Krypto1_2.pas` · Tape: `Krypto1_2.tap`

### Fixed

- **Results too large for the Spectrum's 16-bit numbers are no longer shown as
  wrong numbers.** The game stores numbers as 16-bit integers (−32,768 to
  32,767). Large calculations used to wrap around silently, so
  10 × 4 × 21 × 8 × 9 = 60,480 was shown as **−5,056**. Any calculation that
  goes beyond the limit now shows **TOO / BIG** on the card and ends the
  attempt as WRONG, followed by the solution as usual.

  Ending the attempt straight away is safe: an overflow needs at least four
  cards, and a number beyond ±32,767 can never be brought back to a target of
  1–25 with the one card left.

- **Illegal divisions are refused, as the Krypto rules require.**
  Division must be exact, and you can never divide *by* zero
  (dividing zero is fine: 0 ÷ 12 = 0). Previously the game truncated and
  guessed:

  | Move | Before | Now |
  |---|---|---|
  | 12 ÷ 17 | 0 | refused |
  | 17 ÷ 12 | 1 | refused |
  | 12 ÷ 0 | 0 | refused |
  | 24 ÷ 6 | 4 | 4 |
  | 0 ÷ 12 | 0 | 0 |

  A refused division plays the "nope" sound and shows **ILLEGAL** on the
  command line until the next key. Change the operator with Q/A, or swap the
  two cards with O/P. The check is the same `SafeDiv` function the solver
  uses, so the player and the solver now follow exactly the same rules.

### Changed (internal)

- `Evaluate` now uses the solver's `SafeAdd`, `SafeSub` and `SafeMul`. On
  overflow it returns a marker value (`TooBigMark` = −32768), which no real
  result can produce, and `PlotSmallNumber` draws it as TOO / BIG. This
  replaces the 1.1 −32768 display fix, which can no longer be reached.
- The "R D E" end-of-attempt menu, previously written out twice (after
  CORRECT and after WRONG / G), is now a single `EndMenu` procedure.
- `DigitCount` removed: `PrintBigNumber` only ever prints 1–25, so a simple
  `< 10` test is enough.
- The operator symbol stroke tables are stored as `Byte` instead of
  `Integer`, halving their size; the symbols are drawn pixel-for-pixel as
  before.
- Together these savings more than pay for the new features: the program
  fits in 48K with the full 2048-byte stack and more free memory than 1.1.

Controls, screens, sounds and the solver are otherwise unchanged.

## Release 1.1 — 29 September 2026

Source: `game resources/Krypto1_1b.pas` · Tape: `Krypto1_1b.tap`

### Fixed

- **Crash or corrupted display when a result is exactly −32768.**
  Player calculations wrap on overflow, so some multiplications land exactly
  on −32768 (for example 16 × 16 × 8 × 4 × 4). `PlotSmallNumber` could not
  negate that value, which left its digit count at 0 and broke its drawing
  loop. The value is now drawn correctly.

### Changed (internal)

- The game-state reset, previously duplicated in `RestartGame` and
  `RunCardCursor`, is now a single `ResetPlayState` procedure. This saved
  123 bytes, which paid for the fix.

## Release 1.0

- First release.
