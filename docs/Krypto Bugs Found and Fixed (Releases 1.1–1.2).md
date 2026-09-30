# Krypto (PASTA80): Bugs Found and Fixed (Releases 1.1–1.2)

Sep 30, 2026 · @Micky

## Summary

Three bugs were found in the Pascal game while porting it to C and testing it in an emulator, all in its arithmetic, and the PASTA80 developer explained why the first one crashed. All are fixed in Release 1.2 (`Krypto1_2.pas`), which still fits in 48K with the full 2048-byte stack. The C version has its own document: Krypto C Port (z88dk): Bugs Found and Fixed.

| # | Bug | Symptom | Fix | Release |
| --- | --- | --- | --- | --- |
| 1 | −32768 could not be displayed | Garbage on the card or a crash after e.g. 16×16×8×4×4 | Special-case −32768 in `PlotSmallNumber` | 1.1 (`Krypto1_1b.pas`) |
| 2 | Overflowed results shown as numbers | 10×4×21×8×9 = 60,480 shown as −5,056 | `Evaluate` detects overflow; card shows TOO / BIG; attempt ends as WRONG | 1.2 |
| 3 | Illegal divisions accepted | 12÷17 gave 0, 17÷12 gave 1, 12÷0 gave 0 | ENTER refuses them via `SafeDiv`; nope sound + ILLEGAL | 1.2 |
| 4 | PASTA80: `FOR` with a Byte variable and an out-of-range bound | Explains *why* bug 1 crashed | Worked around in Krypto; PASTA80 plans to count loops like Turbo Pascal 3 | PASTA80 after 1.0 |

## Background: 16-bit numbers wrap around

Bugs 1 and 2 come from one fact: a PASTA80 `Integer` is 16 bits, so it can only hold **−32,768 to +32,767**. Anything outside that range silently wraps around, like a car's odometer.

The top bit (bit 15) is the sign bit, a scheme called *two's complement*:

| Bits | Hex | Read as |
| --- | --- | --- |
| 0111 1111 1111 1111 | $7FFF | +32,767 (largest) |
| 1000 0000 0000 0000 | $8000 | −32,768 (smallest) |
| 1111 1111 1111 1111 | $FFFF | −1 |

Counting up past the top wraps to the bottom: 32,766, 32,767, **−32,768**, −32,767 … So 8,192 × 4 = 32,768 is stored as $8000 and read back as −32,768. In general a result is stored modulo 65,536: 60,480 becomes 60,480 − 65,536 = **−5,056**, and 6,375,600 becomes 18,608.

The CPU does not report the overflow and PASTA80 does not check for it, so a wrong value flows on as if it were right.

One value is special. −32,768 has **no positive twin**: +32,768 does not fit, so negating $8000 gives $8000 again. Every other negative number flips sign correctly. That quirk is behind bug 1.

The solver was never affected: from the start it used `SafeAdd`, `SafeSub`, `SafeMul` and `SafeDiv`, which check before calculating and reject any result that would not fit. Only the player's own calculations, in `Evaluate`, used plain `+ - * DIV`.

## Bug 1: the −32768 crash (fixed in 1.1)

**Symptom.** Multiplying 16 × 16 × 8 × 4 × 4 = 32,768 wraps to exactly −32,768. The result card then showed a lone minus sign followed by garbage, or the program crashed.

**Where.** `PlotSmallNumber`, which draws results in the 3×5 small font. Your own deal 10 × 4 × 21 × 8 × 9 (wrapped to −5,056) did *not* crash: only the one value −32,768 triggers it.

**Theory, step by step** (original 1\_1a code, value = −32768):

```pascal
negative := 0;
v := value;              { v = -32768 }
IF v < 0 THEN
BEGIN
  negative := 1;
  v := -v;               { +32768 does not fit: v is still -32768 }
END;

count := 0;
IF v = 0 THEN ...
ELSE
  WHILE v > 0 DO ...     { v is negative: the loop never runs, count stays 0 }

FOR i := count - 1 DOWNTO 0 DO     { i is a Byte: FOR i := -1 DOWNTO 0 }
  PlotSmallDigit(startX, y, digits[i]);
```

The routine believes the number has zero digits, and the final loop starts at −1. A `Byte` cannot hold −1, so `i` starts at 255 and the loop reads `digits[255]`, `digits[254]` … far past the 6-byte array, plotting random memory as "digits" further and further right until it runs off the screen. The next section has the PASTA80 developer's confirmation of this mechanism.

**The 1.1 fix: two lines.**

```pascal
  v := -v;
END;
IF v < 0 THEN v := 32767;               { only -32768 is still negative here;
                                          32767 gives the digits 3,2,7,6,7 }
... digit loop runs normally, count = 5 ...
IF value = -32768 THEN digits[0] := 8;  { 3276(7) -> 3276(8) }
```

With `count` at 5 the final loop runs from 4 down to 0 as intended, and the card reads −32768.

**What it cost.** The first attempt restructured the routine and pushed the program to 30,802 bytes, over the limit. The two-line version still left it 44 bytes over. The duplicated game-state reset in `RestartGame` and `RunCardCursor` was then moved into one `ResetPlayState` procedure, which saved 123 bytes: 1\_1b came to 30,642 bytes with 78 bytes free.

**Tested** on a forced deal of 16, 16, 8, 4, 4: 1\_1a drew garbage or crashed, and 1\_1b showed −32768.

In 1.2 these two lines were removed: overflow is now caught before it happens (bug 2), so −32768 can no longer reach the display as a number.

## What the PASTA80 developer explained

The PASTA80 author confirmed that bug 1's crash comes from how PASTA80 runs `FOR` loops, and that it differs from Turbo Pascal 3 (TP3), which PASTA80 follows.

**Two ways to run a FOR loop:**

|  | PASTA80 today | Turbo Pascal 3 |
| --- | --- | --- |
| Method | Steps the loop variable and compares it with the final value on every pass | Works out the number of passes once, in 16 bits, then counts that down to zero |
| `FOR i := -1 DOWNTO 0` (i: Byte) | `i` starts at 255, so 256 passes | −1 − 0 + 1 = 0 passes: the body never runs |
| `FOR B := 3 DOWNTO I` with I = −1 | Ran forever before issue #162 was fixed | 3, 2, 1, 0, 255 (5 passes) |
| `FOR B := 0 TO 260` (B: Byte) | — | 261 passes: 0 … 255, then wraps to 0 … 4 |

So under TP3's rule, Krypto's `FOR i := count - 1 DOWNTO 0` with `count = 0` would simply not run, and the card would have shown only the minus sign instead of garbage.

**Issue #162.** Before it was fixed, the loop with a negative *final* value (the author's `3 DOWNTO I` example) ran forever. As a stopgap, PASTA80 now truncates the final value to the loop variable's width, so that loop runs zero times. The test `TestForByteLimit` in `tests/more.pas` documents this; its expected results will change (to 5 and 51 passes) when PASTA80 adopts TP3's counting.

**Planned for after PASTA80 1.0:**

- **Count the passes like TP3**, once, in 16 bits. This is also cheaper than a signed 16-bit comparison on every pass.
- **Constant bounds:** when both bounds are known at compile time, the pass count is too, so the check before the loop disappears, and so does the loop if the count is zero.
- **8-bit count:** when both bounds are 8-bit (Char, Boolean, enums, Byte variables, constants 0–255) there are at most 256 passes. The check per pass shrinks from 8 bytes / 45 T-states (`pop hl / dec hl / push hl / ld a,h / or l / jp z`) to 6 bytes / 35 T-states (`pop bc / dec c / push bc / jp z`).
- The author notes that **`count - 1` does not qualify for the 8-bit form even when `count` is a Byte**, because Byte arithmetic is done in 16 bits. That is exactly Krypto's pattern: it will keep the 16-bit count, so `count = 0` correctly gives zero passes, not 256.

Open questions the author raised: how TP3 handles an Integer loop from −32768 to 32767 (65,536 passes, which does not fit in 16 bits). TP 5.5 most likely rejects `3 DOWNTO -1` with a Byte variable as "Constant out of range".

**What it means for Krypto.** Every `FOR` loop in 1.2 behaves the same under both the current and the planned rule:

- Loops that can run zero times (`1 TO N2[…]`, `1 TO NeedCount`, `1 TO N3`, `cursorIndex + 1 TO 4`) have a start above the end; both rules give zero passes.
- The only loops that could start negative, `count - 1 DOWNTO 0` and `cursorIndex - 1 DOWNTO 0`, are protected: `count` is always at least 1, and the second is guarded by `IF cursorIndex > 0`.
- All other loops have small fixed positive bounds.

When PASTA80 switches to TP3 counting, Krypto should compile to slightly smaller, faster code with no change in behaviour.

## Bug 2: overflowed results shown as numbers (fixed in 1.2)

**Symptom.** Bug 1's fix stopped the crash but still showed wrapped values: 10 × 4 × 21 × 8 × 9 = 60,480 appeared as **−5,056**, which looks as if the Spectrum cannot multiply.

**Why the display can't simply show the right number.** By the time a result reaches `PlotSmallNumber`, the true value is gone: the 16 bits only keep it modulo 65,536. Reading the bits as unsigned would show 60,480 correctly, but then a genuine 3 − 8 = −5 would appear as 65,531. The display cannot tell the two apart, so the fix belongs where the overflow happens, in `Evaluate`.

**Which calculations can overflow.** Only ones covering at least four cards: the largest three-card result is 25 × 24 × 23 = 13,800. Examples: 600 × 600 (two pairs), 13,800 × 3, or 12 × 13 × 14 × 15 = 32,760 followed by + 9.

**Why ending the attempt is correct.** A value beyond ±32,767 combined with the one card left can never reach a target of 1–25: adding, subtracting or multiplying keeps it in the tens of thousands, and even dividing by 25 leaves at least 1,310. So no win is lost by stopping at once. Your own test confirmed this: 14 × 22 × 17 × 7 = 36,652 ended with TOO BIG and WRONG before the last card.

**The design: a marker value.** `Evaluate` now uses the solver's safe functions. They leave their result untouched when they detect overflow, so starting the result at −32768 is enough to mark "too big". No real result can be −32768: four-card results stay above about −13,800.

```pascal
CONST
  TooBigMark = -32768;    { Evaluate's result when a calculation overflows }

FUNCTION Evaluate(a, b, opIdx: Integer): Integer;
VAR
  r: Integer;
BEGIN
  r := TooBigMark;
  IF opIdx = 0 THEN IF SafeAdd(a, b, r) THEN;
  IF opIdx = 1 THEN IF SafeSub(a, b, r) THEN;
  IF opIdx = 2 THEN IF SafeMul(a, b, r) THEN;
  IF opIdx = 3 THEN
    IF b <> 0 THEN
      r := a DIV b;
  Evaluate := r;
END;
```

`IF SafeAdd(…) THEN;` with an empty THEN is how a Boolean function is called for its side effect in PASTA80.

In the ENTER handler, one line makes an overflow final, so the existing WRONG path takes over:

```pascal
IF PendingValue = TooBigMark THEN
  isFinal := 1;     { overflow: this attempt cannot succeed }
```

In `PlotSmallNumber`, the marker is drawn as two words instead of digits:

```pascal
IF value = TooBigMark THEN
BEGIN
  startX := x + 10;
  FOR i := 0 TO 2 DO
  BEGIN
    PlotSmallDigit(startX, y - 3, TooBigGlyph[i]);       { T O O }
    PlotSmallDigit(startX, y + 4, TooBigGlyph[i + 3]);   { B I G }
    startX := startX + SmallCharPitch;
  END;
  EXIT;
END;
```

The small font gained four letters (O reuses the 0 glyph):

```pascal
    7,2,2,2,2,      { T }
    6,5,6,5,6,      { B }
    7,2,2,2,7,      { I }
    7,4,5,5,7       { G }
  TooBigGlyph: array[0..5] of Byte = (11, 0, 0, 12, 13, 14);   { T O O / B I G }
```

**Why the small font and not `Write('TOO')`.** A card is 4 character cells wide and its outer two cells hold the frame. A 3-letter ROM-font word needs 3 cells, so it would erase part of the frame. The 3×5 letters fit between the frame lines, in the same blue style as other results.

**Why a named constant.** PASTA80 compiles the literal `-32768` as "0 minus 32768", calculated at run time on every use. `TooBigMark` is folded at compile time, which saved 24 bytes over three uses.

## Bug 3: illegal divisions accepted (fixed in 1.2)

**The Krypto rule.** Division must come out exact, and you can never divide *by* zero. Dividing zero is fine: 0 ÷ 12 = 0. The Instructions screen already said "No fractions".

**Symptom.** The player's `Evaluate` used Pascal's `DIV`, which truncates, plus a fallback for a zero divisor:

```pascal
IF opIdx = 3 THEN
  IF b <> 0 THEN
    Evaluate := a DIV b     { 12 DIV 17 = 0, 17 DIV 12 = 1 }
  ELSE
    Evaluate := 0;          { 12 / 0 quietly became 0 }
```

| Move | 1.1 | 1.2 |
| --- | --- | --- |
| 12 ÷ 17 | 0 | refused |
| 17 ÷ 12 | 1 | refused |
| 6 ÷ 24 | 0 | refused |
| 12 ÷ 0 | 0 | refused |
| 24 ÷ 6 | 4 | 4 |
| 0 ÷ 12 | 0 | 0 |

The important distinction: the `ELSE Evaluate := 0` line was not what handled 0 ÷ 12 (that goes through `a DIV b` and correctly gives 0). It handled the illegal 12 ÷ 0 and treated it as a valid result. A zero divisor must be rejected by the legality check, not turned into a value. A player could even have used that to reach a target.

**The solver was already right.** It uses `SafeDiv`, which rejects exactly the illegal cases:

```pascal
FUNCTION SafeDiv(A,B:Integer; VAR R:Integer):Boolean;
...
  SafeDiv := False;
  IF B = 0 THEN EXIT;                      { divisor 0: illegal }
  IF (A = -32768) AND (B = -1) THEN EXIT;  { would overflow }
  Rem := DivMod(B,A,Q);
  IF Rem <> 0 THEN EXIT;                   { fraction: illegal }
  R := Q;                                  { 0 / 12 = 0 passes }
  SafeDiv := True
```

**The fix: refuse the move, using the same function.** When the player presses ENTER with ÷ selected, the game calls `SafeDiv` first. If it fails, the move is refused: the nope sound plays, ILLEGAL appears in red on the command line, and nothing else changes. The player can pick another operator with Q/A or swap the cards with O/P (turning 12 ÷ 0 into 0 ÷ 12, which is allowed).

```pascal
IF k = CHR(13) THEN
  IF OpIndex = 3 THEN
    IF NOT SafeDiv(PendingValue, WaitingValue, temp) THEN
    BEGIN
      Channel(1);
      GotoXY(13, 1);
      SetAttr(4, 2, 1, 0);
      Write('ILLEGAL');
      Channel(2);
      IllegalShown := 1;
      SoundEffect(2);
      k := #0;          { swallow this ENTER }
    END;
```

The message is cleared by the next key, whatever it is. It is only ever shown while choosing the operator (menu 4), so that menu is the one redrawn:

```pascal
k := UpCase(ReadKey);
IF IllegalShown = 1 THEN
BEGIN
  IllegalShown := 0;
  DrawCommandMenu(4);
END;
```

`IllegalShown` is a new global Byte, reset in `ResetPlayState`. Because ENTER can no longer pass a zero divisor, `Evaluate` dropped its `ELSE r := 0` line; `IF b <> 0` stays only as a safety net.

**Result:** one rule in one function. The player and the solver now use the same `SafeDiv`, so they can never disagree about what is a legal division.

The nested `IF` statements (rather than `AND`) follow the PASTA80 note that complex Boolean expressions may not parse reliably.

## How ENTER is handled in 1.2

&#91;embedded content: ENTER handling in Release 1.2 · 2 new checks, 4 outcomes\]

A division is checked by `SafeDiv` before anything is calculated, and every other result is checked for overflow by the safe functions inside `Evaluate`; only a legal, in-range result reaches the usual final-step and target checks.

## Fitting it into 48K

The program loads at $8000 and the 2048-byte stack starts at $F800, so the program can use at most **30,720 bytes**. 1\_1b left only 78 of them free, less than the new features needed, so space had to be found without changing gameplay.

**Measuring.** PASTA80 was built from source (Free Pascal + sjasmplus) so every change could be measured byte for byte, and each procedure's size compared in the assembler listing. None of the PASTA80 versions on GitHub matched your 30,642-byte 1\_1b exactly; the closest (27 August 2026) gives 30,663, so the figures below are from that build. Your compiler produces about 21 bytes less for the same source.

| Change | Bytes |
| --- | --- |
| Overflow check, `TooBigMark` and TOO / BIG drawing (bug 2) | +270 |
| `TooBigMark` as a named constant instead of the literal `-32768` | −24 |
| `DigitCount` removed: `PrintBigNumber` only prints 1–25, so `IF value < 10 THEN Inc(textCol)` is enough | −189 |
| Operator stroke tables stored as `Byte` instead of `Integer` | −77 |
| Division check with `SafeDiv` and nope sound (bug 3) | +81 |
| "R D E" end menu shared as one `EndMenu` procedure | −190 |
| ILLEGAL message and clearing it | +109 |
| **Net change from 1\_1b** | **−20** |

Result: 1.2 is 30,643 bytes in the reference build, 77 bytes under the limit (about 98 with your compiler), with the full stack kept.

**Notes on the savings:**

- **`DigitCount`** handled negative numbers, but every call of `PrintBigNumber` prints a card (1–25) or a correct final answer, which equals the target. A single `< 10` test does the same job.
- **Stroke tables:** the values run from −20 to 20, so they fit in a Byte after adding a fixed offset: X and Y are stored +10 and DY +20. `DrawSymbol` subtracts them again (the X/Y offsets fold into the centre constants at compile time). All five symbols were checked to be pixel-for-pixel identical.
- **`EndMenu`:** the menu after CORRECT and the one after WRONG / G were near-copies. The only difference was that after WRONG, D also clears the solution text; after CORRECT that area only holds the empty park block, which is redrawn anyway, so one version serves both.
- **Things that did not help:** a single 6-step loop for TOO / BIG (+8 bytes), a hand-drawn bitmap (+212), and the ROM-font version (smallest, but it broke the card frame).

PASTA80 code is verbose: a single `IF x = y THEN z := 1` with globals costs about 30 bytes, because comparisons go through runtime routines. Removing duplicated code pays far more than tweaking expressions.

## How the fixes were tested

Every build was run in a headless ZX Spectrum 48K emulator (a Python Z80 core with the real 48K ROM), driven by a script that presses keys and saves screenshots. Two tricks made the tests reliable:

- **Forced deals.** After the solver has dealt, the test overwrites the five card values in memory (for example 16, 16, 8, 4, 4) before the cards are shown, so a rare deal can be played on demand. The solution screen then still shows the original deal's solution, which is a side effect of the test, not of the game.
- **Reading the screen, not just memory.** For the small-font results the test decodes the drawn pixels back into digits and letters. This caught bug 4: memory held 6,375,600 while the card showed 6375668.

The emulator jumps straight into the program from the copyright screen, so the ROM keyboard is still in keyword (K) mode. The test sets letter (L) mode first, as the BASIC loader does on a real Spectrum.

**Pascal 1.2 results:**

| Test | Result |
| --- | --- |
| 16×16×8×4×4, 10×4×21×8×9, 25×24×23×22×21, (1−25)×24×23×22 | TOO / BIG, WRONG |
| 12×13×14×15 + 9 (addition overflow) | TOO / BIG, WRONG |
| 25×24×23×22 with the 21 still unused | Ends at once: TOO / BIG, WRONG, solution, D restores the deal |
| 12÷17, 17÷12, 6÷24, 7÷0 | Refused, ILLEGAL shown, cards unchanged |
| ILLEGAL, then Q | Message gone, operator changes |
| 24÷6, 0÷7 | 4 and 0, play continues |
| 3+5+2+4+6 = 20 target; a division chain to 6 | CORRECT |
| R, D and E after CORRECT, WRONG and G | All work; D leaves a clean screen |
| The five operator symbols | Pixel-identical to 1\_1b |

You then confirmed on your own build: the zero rule works, and 14 × 22 × 17 × 7 = 36,652 ended with TOO BIG and WRONG before the last card.

## Sources

- [PASTA80 compiler (pleumann/pasta80)](https://github.com/pleumann/pasta80), including issue #162 on FOR loops with Byte variables
- [Krypto-Game repository](https://github.com/mickyadler/Krypto-Game)
