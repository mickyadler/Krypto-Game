{ ============================================================
  ShowCard.pas
  Minimal PASTA80 program that loads a ZX-Paintbrush export
  (wep.inc: 32x48 pixel picture, 4x6 attribute cells) and
  draws it to the screen.

  Bitmap: 192 bytes (4 bytes/row x 48 rows, MSB = leftmost px)
  Attribute: 24 bytes (4x6 cells), taken as-is from the export
  - no need to work out ink/paper by hand, ZX-Paintbrush already
  baked the correct attribute byte for every cell.
  ============================================================ }

{$a-}
PROGRAM ShowCard;

CONST
  CardW = 32;  { pixels wide, 4 attribute cells }
  CardH = 48;  { pixels tall, 6 attribute cells }

  { pixel data, straight from wep.inc }
  CardBitmap: array[0..191] of Byte = (
    31,255,255,248,127,255,255,254,248,0,0,31,
    240,0,0,15,224,0,0,7,192,0,0,1,
    192,0,0,1,192,0,0,1,192,0,0,1,
    192,0,0,1,192,0,0,1,192,0,0,1,
    192,0,0,1,192,0,0,1,192,0,0,1,
    192,0,0,1,192,0,0,1,192,0,0,1,
    192,0,0,1,192,0,0,1,192,0,0,1,
    192,0,0,1,192,0,0,1,192,0,0,1,
    192,0,0,1,192,0,0,1,192,0,0,1,
    192,0,0,1,192,0,0,1,192,0,0,1,
    192,0,0,1,192,0,0,1,192,0,0,1,
    192,0,0,1,192,0,0,1,192,0,0,1,
    192,0,0,1,192,0,0,1,192,0,0,1,
    192,0,0,1,192,0,0,1,192,0,0,1,
    192,0,0,3,224,0,0,7,240,0,0,7,
    248,0,0,15,120,0,0,30,63,255,255,252
  );

  { attribute data, straight from wep.inc }
  CardAttr: array[0..23] of Byte = (
    121, 121, 121, 121, 121, 127, 127, 121, 121, 127, 127, 121, 121, 120, 120, 121,
    121, 121, 121, 121, 121, 121, 121, 121

  );

  { CardNumbers is now filled by the Krypto deal logic. }

  { card BACK pixel data, straight from back.inc }
  CardBackBitmap: array[0..191] of Byte = (
    0,0,0,0,0,0,0,0,31,62,62,124,
    46,221,221,186,49,227,227,198,59,247,247,230,
    53,235,235,214,46,221,221,186,46,221,221,186,
    31,62,62,124,31,62,62,124,46,221,221,186,
    53,235,235,214,59,247,247,230,53,235,235,214,
    46,221,221,186,31,62,62,124,31,62,62,124,
    46,221,221,186,53,235,235,214,59,247,247,238,
    53,235,235,214,46,221,221,186,31,62,62,124,
    31,62,62,124,31,62,62,124,46,221,221,186,
    53,235,235,214,59,247,247,230,53,235,235,214,
    46,221,221,186,31,62,62,124,31,62,62,124,
    46,221,221,186,53,235,235,214,59,247,247,230,
    53,235,235,214,46,221,221,186,31,62,62,124,
    31,62,62,124,31,62,62,124,46,221,221,186,
    53,235,235,214,59,247,247,230,49,227,227,198,
    46,221,221,186,31,62,62,124,0,0,0,0
  );

  { card BACK attribute data, straight from back.inc - one
    uniform value for all 24 cells }
  CardBackAttr: array[0..23] of Byte = (
    57,57,57,57,57,57,57,57,57,57,57,57,
    57,57,57,57,57,57,57,57,57,57,57,57
  );

  { which card is shifted, and by how much - used by both the
    front and back row layouts so they line up exactly }
  ShiftedCardIndex = 5;   { 0-based: the 6th card }
  ShiftAmount = 8;        { pixels to shift that card up }

  { shared x-position table for all 6 cards, used everywhere a
    card position is needed (drawing, cursor, etc.) }
  CardXPos: array[0..5] of Integer = (8, 48, 88, 128, 168, 208);

  { layout for the lower "equation" row: two full-size card
    copies (same graphic as the upper row) with an operator
    symbol centred in the gap between them, plus a parking
    slot further right for setting a result aside }
  LowerY = 112;
  LowerSlot1X = 72;
  LowerSlot2X = 144;
  LowerOpX = 120;
  LowerParkX = 200;

  { Krypto logo, from krypto_name.inc, cropped to just the real
    visible artwork band (the original export had a lot of
    blank padding above/below the actual "KRYPTO" text - the
    real content is only 25px tall, so this is cropped to a
    clean 32px / 4-cell-tall band, which fits the original 48px
    gap between the two card rows with room to spare - no need
    to move the lower row at all. }
  KryptoX = 72;
  KryptoY = 64;
  KryptoAttrCols = 13;
  KryptoAttrRows = 4;
  KryptoPixelRows = 32;

  KryptoBitmap: array[0..383] of Byte = (
    0,0,0,0,0,0,0,0,0,0,0,0,
    0,0,0,0,0,0,0,0,0,0,0,0,
    0,0,0,0,0,0,0,0,0,0,0,0,
    0,0,0,0,0,0,0,0,0,0,0,0,
    0,0,0,0,0,0,0,0,0,0,0,0,
    3,253,241,255,207,247,249,255,31,255,207,240,
    7,255,255,255,255,255,255,255,255,255,255,252,
    7,255,255,255,255,255,255,255,255,255,255,254,
    7,143,191,128,124,127,23,3,248,1,252,63,
    7,143,143,0,52,127,20,0,248,1,240,15,
    7,143,159,0,62,62,52,0,120,1,176,7,
    7,143,63,31,31,62,124,60,127,159,227,199,
    7,140,127,31,31,28,126,62,127,159,227,227,
    7,140,255,31,31,28,254,62,127,159,231,227,
    7,128,255,31,31,136,254,62,127,159,231,227,
    7,129,255,31,63,192,254,62,127,159,231,227,
    7,128,255,28,63,193,254,60,123,159,231,227,
    7,0,255,0,127,227,254,0,251,159,231,227,
    7,12,127,0,253,227,238,0,251,159,231,227,
    7,30,63,28,120,227,238,63,247,159,231,227,
    7,30,63,28,120,227,206,63,247,159,231,227,
    7,31,31,30,60,227,206,63,231,15,227,227,
    7,31,31,30,60,227,206,63,199,15,225,199,
    15,31,155,31,28,227,206,60,7,15,240,7,
    15,31,139,31,30,227,206,252,7,14,240,15,
    15,31,187,31,62,227,206,252,7,14,124,31,
    15,255,255,255,254,255,207,252,7,254,127,255,
    15,255,255,255,254,255,207,252,7,254,63,254,
    7,255,255,255,252,127,207,248,3,254,31,252,
    1,248,241,249,240,63,131,240,1,252,7,240,
    0,0,0,0,0,0,0,0,0,0,0,0,
    0,0,0,0,0,0,0,0,0,0,0,0
  );

  KryptoAttr: array[0..51] of Byte = (
    96,96,96,96,96,96,96,96,96,96,96,96,
    96,96,80,80,80,80,80,80,80,80,80,80,
    80,96,96,80,80,80,96,80,96,80,96,80,
    80,80,96,96,96,96,96,96,96,96,96,96,
    96,96,96,96
  );

  { focus arrow: sits at the far left edge, vertically aligned
    with whichever row (upper or lower) currently has focus }
  ArrowCol = 31;
  ArrowRowUpper = 5;
  ArrowRowLower = 18;

{ ============================================================
  KRYPTO game logic imported from KRYPTO02I.
  ============================================================ }
CONST
  DeckSize = 56;
  HandSize = 5;
  DebugFixedDeal = 1;  { set to 0 after first integration test }

TYPE
  TDeck = ARRAY[1..DeckSize] OF BYTE;
  TCardArray = ARRAY[1..HandSize] OF INTEGER;
  TBoolArray = ARRAY[1..HandSize] OF BOOLEAN;
  TSolveArray = ARRAY[1..HandSize] OF INTEGER;
  TSolveOpArray = ARRAY[1..4] OF CHAR;
  TSolveValueArray = ARRAY[1..4] OF INTEGER;
VAR
  Work : TCardArray;
  WorkCount : BYTE;
  Cursor : BYTE;
  Area : BYTE;
  InsertPos : BYTE;

  Deck: TDeck;
  Cards: TCardArray;
  Used: TBoolArray;
  Target: BYTE;
  SolutionFound: BOOLEAN;
  SolutionOps: TSolveOpArray;
  SolutionLeft: TSolveValueArray;
  SolutionRight: TSolveValueArray;
  SolutionResult: TSolveValueArray;
  GameOver: Integer;
  CardNumbers: array[0..5] of Integer;

  { runtime snapshot of every card's actual attribute bytes,
    captured right after the numbers are printed. Indexed as
    CardSavedAttr[cardIndex*24 + cellIndex]. This is how
    SelectCard tells "plain frame cell" from "number cell" -
    by comparing against the known blank CardAttr template -
    without needing to predict where GotoXY actually put the
    text. }
  CardSavedAttr: array[0..143] of Integer;

  { equation-building state, used by RunCardCursor's S/Q/A/=
    handling. Kept as globals (rather than locals) since they
    must persist across the whole play session. }
  UsedCard: array[0..4] of Integer;   { 1 once a card has been placed }
  ChoosingOp: Integer;                { 0 = picking a card, 1 = picking the operator }
  HavePending: Integer;               { 0/1 - whether slot 1 already holds a value }
  PendingValue: Integer;              { slot 1's value (running result) }
  WaitingValue: Integer;              { slot 2's value, valid while ChoosingOp=1 }
  OpIndex: Integer;                   { 0=+ 1=- 2=* 3=/ }
  Focus: Integer;                     { 0 = upper row, 1 = lower row (C toggles) }
  HaveParked: Integer;                { 0/1 - whether the parking slot holds a value }
  ParkedValue: Integer;               { the parking slot's value }
  LowerCursorPos: Integer;            { 0 = slot A, 1 = park slot - which is highlighted }
  LowerSavedAttr: array[0..47] of Integer; { live snapshot: slot A = 0-23, park = 24-47 }

  PROCEDURE CreateDeck;

VAR
N, I : BYTE;

BEGIN

N := 0;

FOR I := 1 TO 6 DO
BEGIN

N := N + 1;
Deck[N] := I;

N := N + 1;
Deck[N] := I;

N := N + 1;
Deck[N] := I

END;


FOR I := 7 TO 10 DO
BEGIN

N := N + 1;
Deck[N] := I;

N := N + 1;
Deck[N] := I;

N := N + 1;
Deck[N] := I;

N := N + 1;
Deck[N] := I

END;


FOR I := 11 TO 17 DO
BEGIN

N := N + 1;
Deck[N] := I;

N := N + 1;
Deck[N] := I

END;


FOR I := 18 TO 25 DO
BEGIN

N := N + 1;
Deck[N] := I

END

END;


{===============================================================}

PROCEDURE Swap(VAR A, B : BYTE);

VAR
T : BYTE;

BEGIN

T := A;
A := B;
B := T

END;


{===============================================================}

PROCEDURE SwapInt(VAR A, B : INTEGER);

VAR
T : INTEGER;

BEGIN

T := A;
A := B;
B := T

END;


{===============================================================}
{ SHUFFLE                                                        }
{===============================================================}

PROCEDURE ShuffleDeck;

VAR
I, J : BYTE;

BEGIN

FOR I := DeckSize DOWNTO 2 DO
BEGIN

J := Random(I) + 1;

Swap(Deck[I], Deck[J])

END

END;


{===============================================================}
{ DEBUG DEAL                                                      }
{===============================================================}

{PROCEDURE DealCards;

BEGIN

Target := 10;

Cards[1] := 17;
Cards[2] := 7;
Cards[3] := 8;
Cards[4] := 10;
Cards[5] := 6;

Used[1] := FALSE;
Used[2] := FALSE;
Used[3] := FALSE;
Used[4] := FALSE;
Used[5] := FALSE;

WorkCount := 0;

Cursor := 1;

Area := 1;

InsertPos := 1

END;
}
PROCEDURE DealCards;

VAR
  I : BYTE;

BEGIN

Target := Deck[1];

FOR I := 1 TO HandSize DO
  Cards[I] := Deck[I + 1];

Used[1] := FALSE;
Used[2] := FALSE;
Used[3] := FALSE;
Used[4] := FALSE;
Used[5] := FALSE;

WorkCount := 0;

Cursor := 1;

Area := 1;

InsertPos := 1

END;

{===============================================================}

{PROCEDURE NewDeal;

BEGIN

{ DEBUG VERSION 

DealCards

END;
}
PROCEDURE NewDeal;

BEGIN

CreateDeck;
ShuffleDeck;
DealCards

END;


{ ============================================================
  Graphical deal bridge.
  CardNumbers[0..4] = playing cards; CardNumbers[5] = target.
  ============================================================ }
PROCEDURE SyncCardNumbers;
VAR
  I: Integer;
BEGIN
  FOR I := 1 TO HandSize DO
    CardNumbers[I - 1] := Cards[I];
  CardNumbers[5] := Target;
END;

PROCEDURE NewGraphicalDeal;
BEGIN
  IF DebugFixedDeal = 1 THEN
  BEGIN
    Target := 7;
    Cards[1] := 17;
    Cards[2] := 12;
    Cards[3] := 13;
    Cards[4] := 14;
    Cards[5] := 8;
    SyncCardNumbers;
  END
  ELSE
  BEGIN
    CreateDeck;
    ShuffleDeck;
    DealCards;
    SyncCardNumbers;
  END;
END;

{------------------------------------------------------------}
PROCEDURE Ink(C:BYTE);
BEGIN
  Write(#16,CHR(C));
END;

{------------------------------------------------------------}
PROCEDURE Paper(C:BYTE);
BEGIN
  Write(#17,CHR(C));
END;

{------------------------------------------------------------}
PROCEDURE Flash(C:BYTE);
BEGIN
  Write(#18,CHR(C));
END;

{------------------------------------------------------------}
PROCEDURE Bright(C:BYTE);
BEGIN
  Write(#19,CHR(C));
END;

{------------------------------------------------------------}
PROCEDURE Inverse(C:BYTE);
BEGIN
  Write(#20,CHR(C));
END;

{------------------------------------------------------------}
PROCEDURE Over(C:BYTE);
BEGIN
  Write(#21,CHR(C));
END;

{ ------------------------------------------------------------
  DigitCount(value)
  Returns how many characters value will print as, including
  the minus sign for negatives (e.g. 7 -> 1, 17 -> 2, -5 -> 2,
  -17 -> 3). Used to right-justify numbers correctly regardless
  of sign - a plain "< 10" check only works for positive values
  and pushes negative single digits one column too far right.
  ------------------------------------------------------------ }
FUNCTION DigitCount(value: Integer): Integer;
VAR
  v, count: Integer;
BEGIN
  count := 0;
  v := value;
  IF v < 0 THEN
  BEGIN
    count := 1;
    v := -v;
  END;
  IF v = 0 THEN
    count := count + 1
  ELSE
    WHILE v > 0 DO
    BEGIN
      count := count + 1;
      v := v DIV 10;
    END;
  DigitCount := count;
END;

{ ------------------------------------------------------------
  NumberColor(n)
  Returns the ink colour for a card value, per the rule:
    1-10  -> black (0)
    11-17 -> red   (2)
    18-25 -> cyan  (5)
  ------------------------------------------------------------ }
FUNCTION NumberColor(n: Integer): Integer;
BEGIN
  IF n <= 10 THEN
    NumberColor := 0
  ELSE IF n <= 17 THEN
    NumberColor := 2
  ELSE
    NumberColor := 5;
END;

{ ------------------------------------------------------------
  ScreenAddr(x, y)
  Computes the ZX Spectrum screen memory address of the byte
  containing pixel (x, y). x must be a multiple of 8 (this
  returns the address of that whole byte, i.e. 8 pixels).

  Screen memory is not simple top-to-bottom row order - the
  192 pixel rows are split into three 64-row thirds, and the
  8 pixel-rows within each character row are interleaved. This
  is the standard bit layout:
    bits: 0 1 0 Y7 Y6 Y2 Y1 Y0 Y5 Y4 Y3 X4 X3 X2 X1 X0
  ------------------------------------------------------------ }
FUNCTION ScreenAddr(x, y: Integer): Integer;
BEGIN
  ScreenAddr := $4000
                + ((y AND $C0) SHL 5)   { third of screen (Y7,Y6) }
                + ((y AND $07) SHL 8)   { pixel row within cell (Y2,Y1,Y0) }
                + ((y AND $38) SHL 2)   { character row (Y5,Y4,Y3) }
                + (x SHR 3);            { byte column }
END;

{ ------------------------------------------------------------
  DrawCard(x, y)
  Draws the card with its top-left pixel at (x, y) by writing
  the exported bytes straight into screen and attribute memory
  - no per-pixel Plot calls needed, since the data is already
  in the exact format the hardware expects.
  x and y must be multiples of 8 so the picture lands cleanly
  on the attribute grid.
  ------------------------------------------------------------ }
PROCEDURE DrawCard(x, y: Integer);
VAR
  row, col, byteIdx: Integer;
  rowAddr: Integer;
  attrRow, attrCol, attrAddr: Integer;
BEGIN
  { blit the bitmap 4 bytes (32px) at a time, one screen row per loop }
  FOR row := 0 TO CardH - 1 DO
  BEGIN
    rowAddr := ScreenAddr(x, y + row);
    FOR col := 0 TO 3 DO   { 4 bytes per row = 32 px / 8 }
    BEGIN
      byteIdx := row * 4 + col;
      Mem[rowAddr + col] := CardBitmap[byteIdx];
    END;
  END;

  { write the attribute cells directly - these were never
    reachable via Plot/FloodFill in the first place }
  FOR attrRow := 0 TO 5 DO      { 6 cell rows }
    FOR attrCol := 0 TO 3 DO    { 4 cell cols }
    BEGIN
      attrAddr := $5800
                  + ((y DIV 8) + attrRow) * 32
                  + ((x DIV 8) + attrCol);
      Mem[attrAddr] := CardAttr[attrRow * 4 + attrCol];
    END;
END;

{ ------------------------------------------------------------
  DrawCardBack(x, y)
  Draws the card BACK with its top-left pixel at (x, y).
  Kept as a separate procedure rather than a parameterised
  version of DrawCard, since it's not confirmed PASTA80 supports
  passing arrays as procedure parameters - duplicating this
  small loop is safer than guessing at that.
  x and y must be multiples of 8.
  ------------------------------------------------------------ }
PROCEDURE DrawCardBack(x, y: Integer);
VAR
  row, col, byteIdx: Integer;
  rowAddr: Integer;
  attrRow, attrCol, attrAddr: Integer;
BEGIN
  FOR row := 0 TO CardH - 1 DO
  BEGIN
    rowAddr := ScreenAddr(x, y + row);
    FOR col := 0 TO 3 DO
    BEGIN
      byteIdx := row * 4 + col;
      Mem[rowAddr + col] := CardBackBitmap[byteIdx];
    END;
  END;

  FOR attrRow := 0 TO 5 DO
    FOR attrCol := 0 TO 3 DO
    BEGIN
      attrAddr := $5800
                  + ((y DIV 8) + attrRow) * 32
                  + ((x DIV 8) + attrCol);
      Mem[attrAddr] := CardBackAttr[attrRow * 4 + attrCol];
    END;
END;

{ ------------------------------------------------------------
  DrawKryptoLogo(x, y)
  Draws the "KRYPTO" logo (from krypto_name.inc, cropped to
  its real 32px-tall content band) with its top-left pixel at
  (x, y). x, y must be multiples of 8.
  ------------------------------------------------------------ }
PROCEDURE DrawKryptoLogo(x, y: Integer);
VAR
  row, col, rowAddr, byteIdx, attrRow, attrCol, attrAddr: Integer;
BEGIN
  FOR row := 0 TO KryptoPixelRows - 1 DO
  BEGIN
    rowAddr := ScreenAddr(x, y + row);
    FOR col := 0 TO 11 DO
    BEGIN
      byteIdx := row * 12 + col;
      Mem[rowAddr + col] := KryptoBitmap[byteIdx];
    END;
  END;

  FOR attrRow := 0 TO KryptoAttrRows - 1 DO
    FOR attrCol := 0 TO KryptoAttrCols - 1 DO
    BEGIN
      attrAddr := $5800
                  + ((y DIV 8) + attrRow) * 32
                  + ((x DIV 8) + attrCol);
      Mem[attrAddr] := KryptoAttr[attrRow * KryptoAttrCols + attrCol];
    END;
END;

{ ------------------------------------------------------------
  DrawCardBacksRow
  Draws all 6 card backs at the same positions DrawCardRow
  uses for the fronts (including the 6th card's upward shift),
  so the flip lines up exactly.
  ------------------------------------------------------------ }
PROCEDURE DrawCardBacksRow;
VAR
  i, x0, y: Integer;
  xs: array[0..5] of Integer;
BEGIN
  xs[0] := 8;  xs[1] := 48;  xs[2] := 88;
  xs[3] := 128; xs[4] := 168; xs[5] := 208;

  FOR i := 0 TO 5 DO
  BEGIN
    x0 := xs[i];
    IF i = ShiftedCardIndex THEN
      y := 16 - ShiftAmount
    ELSE
      y := 16;
    DrawCardBack(x0, y);
  END;
END;

{ ------------------------------------------------------------
  DrawCardRow
  Lays out 6 cards across the top of the screen.
  x positions are 8,48,88,128,168,208 (all multiples of 8, so
  every card's bitmap and attribute cells land cleanly).
  The 6th card is shifted up a full 8 pixels (one whole
  attribute cell) so it lands cleanly on the grid - no seam,
  no bleed into the green background, since the shift stays a
  multiple of 8.
  ------------------------------------------------------------ }
PROCEDURE DrawCardRow;
VAR
  i, x0, y, textCol, textRow: Integer;
  xs: array[0..5] of Integer;
BEGIN
  xs[0] := 8;  xs[1] := 48;  xs[2] := 88;
  xs[3] := 128; xs[4] := 168; xs[5] := 208;

  FOR i := 0 TO 5 DO
  BEGIN
    x0 := xs[i];
    IF i = ShiftedCardIndex THEN
      y := 16 - ShiftAmount
    ELSE
      y := 16;
    DrawCard(x0, y);

    { text-cell position for this card's number, derived from
      its own pixel position - same offset (+2 cols, +3 rows)
      that lined up card 1's "12" correctly }
    textCol := (x0 DIV 8) + 2;
    textRow := (y DIV 8) + 3;

    { right-justify around a 2-character field: shift left as
      the value gets longer (accounting for a possible minus
      sign), so everything lines up on its right edge }
    textCol := textCol + (2 - DigitCount(CardNumbers[i]));

    GotoXY(textCol, textRow);
    Paper(7);
    Ink(NumberColor(CardNumbers[i]));
    Bright(1);
    Write(CardNumbers[i]);
  END;
END;

{ ------------------------------------------------------------
  CardYAt(i)
  Returns the y-position for card index i (0-5), accounting for
  the one shifted card - kept in one place so the cursor code
  always agrees with where the cards are actually drawn.
  ------------------------------------------------------------ }
FUNCTION CardYAt(i: Integer): Integer;
BEGIN
  IF i = ShiftedCardIndex THEN
    CardYAt := 16 - ShiftAmount
  ELSE
    CardYAt := 16;
END;

{ ------------------------------------------------------------
  CaptureCardAttrs
  Reads the ACTUAL attribute byte currently sitting in every
  cell of every card - taken right after DrawCardRow has
  already printed the numbers - and stores it in
  CardSavedAttr. This captures the real, correct state (frame
  colour and number colour alike) with no assumptions about
  where GotoXY actually placed the text.
  Call this once, after DrawCardRow, before RunCardCursor.
  ------------------------------------------------------------ }
PROCEDURE CaptureCardAttrs;
VAR
  i, x, y, attrRow, attrCol, attrAddr, idx: Integer;
BEGIN
  FOR i := 0 TO 5 DO
  BEGIN
    x := CardXPos[i];
    y := CardYAt(i);
    FOR attrRow := 0 TO 5 DO
      FOR attrCol := 0 TO 3 DO
      BEGIN
        attrAddr := $5800
                    + ((y DIV 8) + attrRow) * 32
                    + ((x DIV 8) + attrCol);
        idx := attrRow * 4 + attrCol;
        CardSavedAttr[i * 24 + idx] := Mem[attrAddr];
      END;
  END;
END;

{ ------------------------------------------------------------
  SelectCard(cardIndex, selected)
  Highlights card number cardIndex (0-5) by darkening its
  plain frame cells to black ink (a "shadow" effect), while
  leaving the number's own cell untouched - detected at
  runtime by comparing each cell's saved value against the
  known blank CardAttr template: if they match, it's a plain
  frame cell (safe to darken); if they differ, Print must have
  written something different there (the number), so it's left
  exactly as saved.
  selected=1 to highlight, 0 to restore the saved colours.
  ------------------------------------------------------------ }
PROCEDURE SelectCard(cardIndex, selected: Integer);
VAR
  x, y, attrRow, attrCol, attrAddr, idx, savedVal: Integer;
BEGIN
  { once a card is used, it stays permanently black-and-white -
    select/deselect must never touch it, or deselecting would
    restore its original colours and undo MarkCardUsed }
  IF UsedCard[cardIndex] = 0 THEN
  BEGIN
    x := CardXPos[cardIndex];
    y := CardYAt(cardIndex);

    FOR attrRow := 0 TO 5 DO
      FOR attrCol := 0 TO 3 DO
      BEGIN
        attrAddr := $5800
                    + ((y DIV 8) + attrRow) * 32
                    + ((x DIV 8) + attrCol);
        idx := attrRow * 4 + attrCol;
        savedVal := CardSavedAttr[cardIndex * 24 + idx];

        IF selected = 0 THEN
          { deselect: always restore exactly what was saved,
            correct regardless of whether it's a frame or number
            cell }
          Mem[attrAddr] := savedVal
        ELSE
        BEGIN
          IF savedVal = CardAttr[idx] THEN
            { unchanged from the blank template - a plain frame
              cell, safe to darken }
            Mem[attrAddr] := savedVal AND $F8
          ELSE
            { differs from the template - Print touched this
              cell (the number), leave its real colour alone }
            Mem[attrAddr] := savedVal;
        END;
      END;
  END;
END;

{ ------------------------------------------------------------
  LowerSlotX(slotID)
  Maps a lower-slot ID (0 = A, 1 = park) to its screen x
  position.
  ------------------------------------------------------------ }
FUNCTION LowerSlotX(slotID: Integer): Integer;
BEGIN
  IF slotID = 0 THEN
    LowerSlotX := LowerSlot1X
  ELSE
    LowerSlotX := LowerParkX;
END;

{ ------------------------------------------------------------
  CaptureLowerSlot(slotID)
  Reads back the actual current attribute bytes of lower slot
  slotID (0=A, 1=park) into LowerSavedAttr. Call this right
  after every DrawLowerCard/ClearLowerCard that targets slot A
  or the park slot, so ShadowLowerSlot always has an accurate,
  up-to-date picture of what's really on screen - the same
  read-back approach CaptureCardAttrs uses for the upper cards.
  ------------------------------------------------------------ }
PROCEDURE CaptureLowerSlot(slotID: Integer);
VAR
  x, y, attrRow, attrCol, attrAddr, idx: Integer;
BEGIN
  x := LowerSlotX(slotID);
  y := LowerY;
  FOR attrRow := 0 TO 5 DO
    FOR attrCol := 0 TO 3 DO
    BEGIN
      attrAddr := $5800
                  + ((y DIV 8) + attrRow) * 32
                  + ((x DIV 8) + attrCol);
      idx := attrRow * 4 + attrCol;
      LowerSavedAttr[slotID * 24 + idx] := Mem[attrAddr];
    END;
END;

{ ------------------------------------------------------------
  ShadowLowerSlot(slotID, selected)
  Same darken-the-frame highlight as SelectCard, applied to a
  lower slot (0=A, 1=park) using its own saved snapshot. Works
  correctly even on an empty slot (nothing visible changes,
  since empty cells never match the CardAttr template anyway).
  ------------------------------------------------------------ }
PROCEDURE ShadowLowerSlot(slotID, selected: Integer);
VAR
  x, y, attrRow, attrCol, attrAddr, idx, savedVal: Integer;
BEGIN
  x := LowerSlotX(slotID);
  y := LowerY;
  FOR attrRow := 0 TO 5 DO
    FOR attrCol := 0 TO 3 DO
    BEGIN
      attrAddr := $5800
                  + ((y DIV 8) + attrRow) * 32
                  + ((x DIV 8) + attrCol);
      idx := attrRow * 4 + attrCol;
      savedVal := LowerSavedAttr[slotID * 24 + idx];

      IF selected = 0 THEN
        Mem[attrAddr] := savedVal
      ELSE
      BEGIN
        IF savedVal = CardAttr[idx] THEN
          Mem[attrAddr] := savedVal AND $F8
        ELSE
          Mem[attrAddr] := savedVal;
      END;
    END;
END;

{ ------------------------------------------------------------
  OpChar(idx)
  Maps an operator index (0-3) to its display character.
  ------------------------------------------------------------ }
FUNCTION OpChar(idx: Integer): Char;
BEGIN
  IF idx = 0 THEN OpChar := '+';
  IF idx = 1 THEN OpChar := '-';
  IF idx = 2 THEN OpChar := '*';
  IF idx = 3 THEN OpChar := '/';
END;

{ ------------------------------------------------------------
  Evaluate(a, b, opIdx)
  Applies operator opIdx to a and b. Division truncates to an
  integer and is guarded against b=0 (shouldn't happen in
  practice, since card values are always 1-25, but kept safe).
  ------------------------------------------------------------ }
FUNCTION Evaluate(a, b, opIdx: Integer): Integer;
BEGIN
  IF opIdx = 0 THEN Evaluate := a + b;
  IF opIdx = 1 THEN Evaluate := a - b;
  IF opIdx = 2 THEN Evaluate := a * b;
  IF opIdx = 3 THEN
    IF b <> 0 THEN
      Evaluate := a DIV b
    ELSE
      Evaluate := 0;
END;

{ ------------------------------------------------------------
  DrawLowerCard(x, y, value)
  Draws a full copy of the same card graphic used up top (via
  DrawCard) at the lower position, then stamps the value on it
  using the exact same text-position formula DrawCardRow uses -
  so numbers fit inside the frame correctly, the same way they
  already do on the upper row.
  ------------------------------------------------------------ }
PROCEDURE DrawLowerCard(x, y, value: Integer);
VAR
  textCol, textRow: Integer;
BEGIN
  DrawCard(x, y);

  textCol := (x DIV 8) + 2;
  textRow := (y DIV 8) + 3;
  textCol := textCol + (2 - DigitCount(value));

  GotoXY(textCol, textRow);
  Paper(7);
  Ink(NumberColor(value));
  Bright(1);
  Write(value);
END;

{ ------------------------------------------------------------
  ClearLowerCard(x, y)
  Erases a full 32x48 lower card back to plain background -
  both the pixel bitmap and the attribute cells. The background
  attribute is read live from cell (0,0) - a corner never drawn
  on by any card - rather than a hardcoded guess, so this always
  matches the real background exactly regardless of whatever
  Paper/Ink/Bright state was active when the screen was first
  cleared.
  ------------------------------------------------------------ }
PROCEDURE ClearLowerCard(x, y: Integer);
VAR
  row, col, rowAddr, attrRow, attrCol, attrAddr, bgAttr: Integer;
BEGIN
  bgAttr := Mem[$5800];

  FOR row := 0 TO CardH - 1 DO
  BEGIN
    rowAddr := ScreenAddr(x, y + row);
    FOR col := 0 TO 3 DO
      Mem[rowAddr + col] := 0;
  END;

  FOR attrRow := 0 TO 5 DO
    FOR attrCol := 0 TO 3 DO
    BEGIN
      attrAddr := $5800
                  + ((y DIV 8) + attrRow) * 32
                  + ((x DIV 8) + attrCol);
      Mem[attrAddr] := bgAttr;
    END;
END;

{ ------------------------------------------------------------
  DrawLowerOperator / ClearLowerOperator
  Prints (or blanks) the operator symbol centred in the gap
  between the two lower cards.
  ------------------------------------------------------------ }
PROCEDURE DrawLowerOperator(x, y, idx: Integer);
VAR
  textCol, textRow: Integer;
BEGIN
  textCol := x DIV 8;
  textRow := (y DIV 8) + 3;
  GotoXY(textCol, textRow);
  Paper(4);
  Ink(6);
  Bright(1);
  Write(OpChar(idx));
END;

PROCEDURE ClearLowerOperator(x, y: Integer);
VAR
  textCol, textRow, attrAddr, bgAttr, row, rAddr: Integer;
BEGIN
  textCol := x DIV 8;
  textRow := (y DIV 8) + 3;
  bgAttr := Mem[$5800];

  attrAddr := $5800 + textRow * 32 + textCol;
  Mem[attrAddr] := bgAttr;

  { clear the character cell's 8 pixel rows directly, rather
    than printing a space - that way there's no dependency on
    whatever Ink/Paper/Bright state Write would otherwise use }
  FOR row := textRow * 8 TO textRow * 8 + 7 DO
  BEGIN
    rAddr := ScreenAddr(textCol * 8, row);
    Mem[rAddr] := 0;
  END;
END;

{ ------------------------------------------------------------
  MarkCardUsed(cardIndex)
  Turns a card fully black-and-white (forces black ink on every
  cell, including the number) to show it's been used. This is
  permanent - unlike SelectCard's shadow, it's never restored.
  ------------------------------------------------------------ }
PROCEDURE MarkCardUsed(cardIndex: Integer);
VAR
  x, y, attrRow, attrCol, attrAddr, idx, savedVal: Integer;
BEGIN
  x := CardXPos[cardIndex];
  y := CardYAt(cardIndex);
  FOR attrRow := 0 TO 5 DO
    FOR attrCol := 0 TO 3 DO
    BEGIN
      attrAddr := $5800
                  + ((y DIV 8) + attrRow) * 32
                  + ((x DIV 8) + attrCol);
      idx := attrRow * 4 + attrCol;
      savedVal := CardSavedAttr[cardIndex * 24 + idx];
      Mem[attrAddr] := savedVal AND $F8;
    END;
END;

{ ------------------------------------------------------------
  DrawFocusArrow
  Shows a small arrow at the left edge of the screen, aligned
  with whichever row (upper or lower) currently has focus - so
  pressing C always gives a visible confirmation of which half
  is active. Clears both possible positions first, then draws
  the current one.
  ------------------------------------------------------------ }
PROCEDURE DrawFocusArrow;
BEGIN
  GotoXY(ArrowCol, ArrowRowUpper);
  Paper(4);
  Ink(4);
  Bright(1);
  Write('  ');

  GotoXY(ArrowCol, ArrowRowLower);
  Paper(4);
  Ink(4);
  Bright(1);
  Write('  ');

  IF Focus = 0 THEN
  BEGIN
    GotoXY(ArrowCol, ArrowRowUpper);
    Paper(4);
    Ink(0);
    Bright(1);
    Write('<<');
  END
  ELSE
  BEGIN
    GotoXY(ArrowCol, ArrowRowLower);
    Paper(4);
    Ink(0);
    Bright(1);
    Write('<<');
  END;
END;

{ ============================================================
  Compact KRYPTO solver.

  There is deliberately NO memo table here.  The old linear memo
  table became slower as it grew, because every recursive state had
  to scan the table.  With only five cards a direct pair-reduction
  search is small enough and is much cheaper in memory.

  + and X are commutative, so only A+B and A*B are tried.
  - and : are tried in both directions.
  Division must be exact.
  Negative and zero intermediate values are allowed.
  ============================================================ }

PROCEDURE CopySolveArray(VAR Source : TSolveArray;
                         VAR Dest : TSolveArray;
                         Count : BYTE);
VAR
  I : BYTE;
BEGIN
  FOR I := 1 TO Count DO
    Dest[I] := Source[I]
END;

PROCEDURE SaveSolution(Level : BYTE;
                       A, B, R : INTEGER;
                       Op : CHAR);
BEGIN
  SolutionLeft[Level] := A;
  SolutionRight[Level] := B;
  SolutionResult[Level] := R;
  SolutionOps[Level] := Op
END;

{ Safe integer arithmetic.  A failed operation is simply skipped. }
FUNCTION SafeOp(A, B : INTEGER; Op : CHAR;
                VAR R : INTEGER) : BOOLEAN;
BEGIN
  SafeOp := FALSE;

  IF Op = '+' THEN
  BEGIN
    IF (B > 0) AND (A > 32767 - B) THEN
      EXIT;
    IF (B < 0) AND (A < -32768 - B) THEN
      EXIT;
    R := A + B;
    SafeOp := TRUE
  END

  ELSE IF Op = '-' THEN
  BEGIN
    IF (B > 0) AND (A < -32768 + B) THEN
      EXIT;
    IF (B < 0) AND (A > 32767 + B) THEN
      EXIT;
    R := A - B;
    SafeOp := TRUE
  END

  ELSE IF Op = 'X' THEN
  BEGIN
    IF A = 0 THEN
    BEGIN
      R := 0;
      SafeOp := TRUE;
      EXIT
    END;

    IF B = 0 THEN
    BEGIN
      R := 0;
      SafeOp := TRUE;
      EXIT
    END;

    IF A > 0 THEN
    BEGIN
      IF B > 0 THEN
      BEGIN
        IF A > 32767 DIV B THEN EXIT
      END
      ELSE
      BEGIN
        IF B < -32768 DIV A THEN EXIT
      END
    END
    ELSE
    BEGIN
      IF B > 0 THEN
      BEGIN
        IF A < -32768 DIV B THEN EXIT
      END
      ELSE
      BEGIN
        { Both negative.  Use -A only when A is not the
          minimum INTEGER value. }
        IF A = -32768 THEN
          EXIT;

        IF B = -32768 THEN
          EXIT;

        IF (-A) > 32767 DIV (-B) THEN
          EXIT
      END
    END;

    R := A * B;
    SafeOp := TRUE
  END

  ELSE IF Op = ':' THEN
  BEGIN
    IF B = 0 THEN EXIT;
    IF (A MOD B) <> 0 THEN EXIT;
    R := A DIV B;
    SafeOp := TRUE
  END
END;

PROCEDURE Solve(VAR Numbers : TSolveArray;
                Count : BYTE;
                Level : BYTE);
VAR
  I, J, K : BYTE;
  A, B, R : INTEGER;
  Next : TSolveArray;
BEGIN
  IF SolutionFound THEN
    EXIT;

  IF Count = 1 THEN
  BEGIN
    IF Numbers[1] = Target THEN
      SolutionFound := TRUE;
    EXIT
  END;

  FOR I := 1 TO Count - 1 DO
  BEGIN
    FOR J := I + 1 TO Count DO
    BEGIN
      A := Numbers[I];
      B := Numbers[J];

      { Addition }
      IF SafeOp(A, B, '+', R) THEN
      BEGIN
        CopySolveArray(Numbers, Next, Count);
        Next[I] := R;
        FOR K := J TO Count - 1 DO
          Next[K] := Next[K + 1];
        SaveSolution(Level, A, B, R, '+');
        Solve(Next, Count - 1, Level + 1);
        IF SolutionFound THEN EXIT
      END;

      { Multiplication }
      IF SafeOp(A, B, 'X', R) THEN
      BEGIN
        CopySolveArray(Numbers, Next, Count);
        Next[I] := R;
        FOR K := J TO Count - 1 DO
          Next[K] := Next[K + 1];
        SaveSolution(Level, A, B, R, 'X');
        Solve(Next, Count - 1, Level + 1);
        IF SolutionFound THEN EXIT
      END;

      { A-B }
      IF SafeOp(A, B, '-', R) THEN
      BEGIN
        CopySolveArray(Numbers, Next, Count);
        Next[I] := R;
        FOR K := J TO Count - 1 DO
          Next[K] := Next[K + 1];
        SaveSolution(Level, A, B, R, '-');
        Solve(Next, Count - 1, Level + 1);
        IF SolutionFound THEN EXIT
      END;

      { B-A }
      IF SafeOp(B, A, '-', R) THEN
      BEGIN
        CopySolveArray(Numbers, Next, Count);
        Next[I] := R;
        FOR K := J TO Count - 1 DO
          Next[K] := Next[K + 1];
        SaveSolution(Level, B, A, R, '-');
        Solve(Next, Count - 1, Level + 1);
        IF SolutionFound THEN EXIT
      END;

      { A/B }
      IF SafeOp(A, B, ':', R) THEN
      BEGIN
        CopySolveArray(Numbers, Next, Count);
        Next[I] := R;
        FOR K := J TO Count - 1 DO
          Next[K] := Next[K + 1];
        SaveSolution(Level, A, B, R, ':');
        Solve(Next, Count - 1, Level + 1);
        IF SolutionFound THEN EXIT
      END;

      { B/A }
      IF SafeOp(B, A, ':', R) THEN
      BEGIN
        CopySolveArray(Numbers, Next, Count);
        Next[I] := R;
        FOR K := J TO Count - 1 DO
          Next[K] := Next[K + 1];
        SaveSolution(Level, B, A, R, ':');
        Solve(Next, Count - 1, Level + 1);
        IF SolutionFound THEN EXIT
      END
    END
  END
END;

{ ------------------------------------------------------------
  OperationValid
  Exact integer division is required, as in KRYPTO02I.
  ------------------------------------------------------------ }
FUNCTION OperationValid(a, b, opIdx: Integer): Boolean;
BEGIN
  OperationValid := TRUE;
  IF opIdx = 3 THEN
    IF (b = 0) OR ((a MOD b) <> 0) THEN
      OperationValid := FALSE;
END;

{ ------------------------------------------------------------
  ShowFinalResult
  ------------------------------------------------------------ }
PROCEDURE ShowFinalResult;
BEGIN
  GotoXY(2, 21);
  Paper(4);
  Ink(0);
  Bright(1);
  IF PendingValue = Target THEN
  BEGIN
    Write('*** CORRECT! *** TARGET = ', Target);
    GameOver := 1;
  END
  ELSE
  BEGIN
    Write('--- WRONG --- RESULT = ', PendingValue);
    GotoXY(2, 22);
    Write('TARGET = ', Target);
    GameOver := 1;
  END;
END;

{ ------------------------------------------------------------
  ShowGraphicalSolution
  ------------------------------------------------------------ }
PROCEDURE ShowGraphicalSolution;
VAR
  Numbers: TSolveArray;
  I: BYTE;
  Col: Integer;
BEGIN
  SolutionFound := FALSE;
  FOR I := 1 TO HandSize DO
    Numbers[I] := Cards[I];

  GotoXY(2, 21);
  Paper(4);
  Ink(0);
  Bright(1);
  Write('SEARCHING...');
  Solve(Numbers, HandSize, 1);

  GotoXY(2, 21);
  Write('                         ');

  IF NOT SolutionFound THEN
  BEGIN
    GotoXY(2, 21);
    Write('NO SOLUTION FOUND');
    EXIT;
  END;

  GotoXY(2, 21);
  Write('SOLUTION:');
  FOR I := 1 TO HandSize - 1 DO
  BEGIN
    Col := 12 + (I - 1) * 10;
    GotoXY(Col, 21);
    Write(SolutionLeft[I], ' ');
    IF SolutionOps[I] = 'X' THEN
      Write('X ')
    ELSE IF SolutionOps[I] = ':' THEN
      Write(': ')
    ELSE
      Write(SolutionOps[I], ' ');
    Write(SolutionRight[I], '=', SolutionResult[I]);
  END;
END;

{ ------------------------------------------------------------
  RunCardCursor
  Lets the player move a selection highlight across cards 1-5
  (the shifted 6th card is excluded) using O (left) and P
  (right), upper or lower case.
  Runs forever - call after the cards are already face-up.
  ------------------------------------------------------------ }
PROCEDURE RunCardCursor;
VAR
  cursorIndex, newIndex, i, value, temp, search, found: Integer;
  k: Char;
BEGIN
  cursorIndex := 0;
  GameOver := 0;
  ChoosingOp := 0;
  HavePending := 0;
  HaveParked := 0;
  Focus := 0;
  LowerCursorPos := 0;
  FOR i := 0 TO 4 DO
    UsedCard[i] := 0;

  SelectCard(cursorIndex, 1);
  CaptureLowerSlot(0);
  CaptureLowerSlot(1);
  ShadowLowerSlot(0, 1);
  DrawFocusArrow;

  REPEAT
    k := ReadKey;

    IF (k = 'h') OR (k = 'H') THEN
      ShowGraphicalSolution;

    { C toggles which row O/P currently controls: the upper
      cards, or the lower row's cursor/park mechanism }
    IF (k = 'c') OR (k = 'C') THEN
    BEGIN
      IF Focus = 0 THEN
        Focus := 1
      ELSE
        Focus := 0;
      DrawFocusArrow;
    END;

    IF Focus = 0 THEN
    BEGIN
      { --- upper row: O/P always navigate here (skipping used
        cards), regardless of what's happening below. Only S
        (placing a new card) requires the pending operator to
        already be resolved - there's nowhere for a 4th value
        to go while ChoosingOp=1. --- }
      newIndex := cursorIndex;

      IF (k = 'o') OR (k = 'O') THEN
        IF cursorIndex > 0 THEN
        BEGIN
          found := 0;
          FOR search := cursorIndex - 1 DOWNTO 0 DO
            IF found = 0 THEN
              IF UsedCard[search] = 0 THEN
              BEGIN
                newIndex := search;
                found := 1;
              END;
        END;

      IF (k = 'p') OR (k = 'P') THEN
      BEGIN
        found := 0;
        FOR search := cursorIndex + 1 TO 4 DO
          IF found = 0 THEN
            IF UsedCard[search] = 0 THEN
            BEGIN
              newIndex := search;
              found := 1;
            END;
      END;

      IF newIndex <> cursorIndex THEN
      BEGIN
        SelectCard(cursorIndex, 0);
        cursorIndex := newIndex;
        SelectCard(cursorIndex, 1);
      END;

      IF (k = 's') OR (k = 'S') THEN
        IF ChoosingOp = 0 THEN
          IF UsedCard[cursorIndex] = 0 THEN
          BEGIN
            UsedCard[cursorIndex] := 1;
            MarkCardUsed(cursorIndex);
            value := CardNumbers[cursorIndex];

            IF HavePending = 0 THEN
            BEGIN
              PendingValue := value;
              HavePending := 1;
              DrawLowerCard(LowerSlot1X, LowerY, PendingValue);
              CaptureLowerSlot(0);
            END
            ELSE
            BEGIN
              WaitingValue := value;
              DrawLowerCard(LowerSlot2X, LowerY, WaitingValue);
              OpIndex := 0;
              DrawLowerOperator(LowerOpX, LowerY, OpIndex);
              ChoosingOp := 1;
            END;
          END;
    END
    ELSE
    BEGIN
      { --- lower row --- }
      IF ChoosingOp = 1 THEN
      BEGIN
        { picking the operator: O/P swap the two active operands,
          Q/A cycle the operator, = evaluates }
        IF (k = 'o') OR (k = 'O') OR (k = 'p') OR (k = 'P') THEN
        BEGIN
          temp := PendingValue;
          PendingValue := WaitingValue;
          WaitingValue := temp;
          DrawLowerCard(LowerSlot1X, LowerY, PendingValue);
          DrawLowerCard(LowerSlot2X, LowerY, WaitingValue);
        END;

        IF (k = 'q') OR (k = 'Q') THEN
        BEGIN
          OpIndex := OpIndex + 1;
          IF OpIndex > 3 THEN
            OpIndex := 0;
          DrawLowerOperator(LowerOpX, LowerY, OpIndex);
        END;

        IF (k = 'a') OR (k = 'A') THEN
        BEGIN
          IF OpIndex = 0 THEN
            OpIndex := 3
          ELSE
            OpIndex := OpIndex - 1;
          DrawLowerOperator(LowerOpX, LowerY, OpIndex);
        END;

        IF k = '=' THEN
        BEGIN
          IF OperationValid(PendingValue, WaitingValue, OpIndex) THEN
          BEGIN
            PendingValue := Evaluate(PendingValue, WaitingValue, OpIndex);
            ClearLowerOperator(LowerOpX, LowerY);
            ClearLowerCard(LowerSlot2X, LowerY);
            DrawLowerCard(LowerSlot1X, LowerY, PendingValue);
            CaptureLowerSlot(0);
            ChoosingOp := 0;

            IF (UsedCard[0] = 1) AND (UsedCard[1] = 1) AND
               (UsedCard[2] = 1) AND (UsedCard[3] = 1) AND
               (UsedCard[4] = 1) AND (HavePending = 1) AND
               (HaveParked = 0) THEN
              ShowFinalResult;
          END
          ELSE
          BEGIN
            GotoXY(2, 21);
            Paper(4);
            Ink(0);
            Bright(1);
            Write('INVALID DIVISION - MUST BE EXACT');
          END;
        END;
      END
      ELSE
      BEGIN
        { no operator pending: O/P move a highlight between slot
          A and the park slot (purely visual - the actual action
          below is decided by what's really in A and Park, not
          by the cursor). S then does one of three things:
            A filled, Park empty  -> park A (A -> Park)
            A filled, Park filled -> recall INTO B, pairing the
              parked value alongside the current A value and
              starting operator selection
            A empty, Park filled  -> recall into A }
        IF (k = 'o') OR (k = 'O') THEN
          IF LowerCursorPos = 1 THEN
          BEGIN
            ShadowLowerSlot(LowerCursorPos, 0);
            LowerCursorPos := 0;
            ShadowLowerSlot(LowerCursorPos, 1);
          END;

        IF (k = 'p') OR (k = 'P') THEN
          IF LowerCursorPos = 0 THEN
          BEGIN
            ShadowLowerSlot(LowerCursorPos, 0);
            LowerCursorPos := 1;
            ShadowLowerSlot(LowerCursorPos, 1);
          END;

        IF (k = 's') OR (k = 'S') THEN
        BEGIN
          IF HavePending = 1 THEN
            IF HaveParked = 0 THEN
            BEGIN
              ParkedValue := PendingValue;
              HaveParked := 1;
              HavePending := 0;
              ClearLowerCard(LowerSlot1X, LowerY);
              CaptureLowerSlot(0);
              DrawLowerCard(LowerParkX, LowerY, ParkedValue);
              CaptureLowerSlot(1);
            END
            ELSE
            BEGIN
              WaitingValue := ParkedValue;
              HaveParked := 0;
              ClearLowerCard(LowerParkX, LowerY);
              CaptureLowerSlot(1);
              DrawLowerCard(LowerSlot2X, LowerY, WaitingValue);
              OpIndex := 0;
              DrawLowerOperator(LowerOpX, LowerY, OpIndex);
              ChoosingOp := 1;
            END
          ELSE
            IF HaveParked = 1 THEN
            BEGIN
              PendingValue := ParkedValue;
              HavePending := 1;
              HaveParked := 0;
              ClearLowerCard(LowerParkX, LowerY);
              CaptureLowerSlot(1);
              DrawLowerCard(LowerSlot1X, LowerY, PendingValue);
              CaptureLowerSlot(0);
            END;

          ShadowLowerSlot(LowerCursorPos, 1);
        END;
      END;
    END;
    CheckBreak;
  UNTIL GameOver = 1;
END;

{ ------------------------------------------------------------
  Main program: green background, 6 card backs shown first;
  on any keypress, flip them over to show the fronts with
  their numbers.
  ------------------------------------------------------------ }
BEGIN
  Randomize;
  NewGraphicalDeal;

  Paper(4);  { green paper for the whole screen }
  Ink(4);    { green ink by default }
  Bright(1); { bright green background, matching the cards/logo's own bright attributes }
  ClrScr;
  DrawKryptoLogo(KryptoX, KryptoY);

  DrawCardBacksRow;

  GotoXY(2, 22);
  Paper(4);
  Ink(0);
  Bright(1);
  Write('Press any key...');
  ReadKey;

  { redraw the whole screen fresh for the flip - this also
    clears the "press any key" prompt (and the logo, which
    ClrScr wipes just like everything else - so it has to be
    put back immediately after) }
  Paper(4);
  Ink(0);
  Bright(1);
  ClrScr;
  DrawKryptoLogo(KryptoX, KryptoY);
  DrawCardRow;

  CaptureCardAttrs;
  RunCardCursor;
END.
