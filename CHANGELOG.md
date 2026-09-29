# Changelog

## Release 1.1b - 30 September 2026

### Fixed
- **Crash or corrupted display when a result is exactly -32768.**
  Player calculations use 16-bit integers and wrap on overflow, so some
  multiplications land exactly on -32768 (for example 16×16×8×4×4).
  `PlotSmallNumber` could not negate that value, which left its digit
  count at 0 and broke its drawing loop. The result is now drawn
  correctly as -32768.

### Changed
- The game-state reset, previously duplicated in `RestartGame` and
  `RunCardCursor`, is now a single `ResetPlayState` procedure. This
  saves 123 bytes, which paid for the fix; the full 2048-byte stack is kept.

No gameplay changes: controls, screens, sounds and the solver are the same.

## Release 1.1a
- First release.