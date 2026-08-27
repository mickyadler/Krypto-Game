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

PROGRAM ShowCard;

TYPE
  { shared array shapes, so one blit/fill routine can serve
    every 32x48 card (front, back, or a lower-row copy) instead
    of each having its own duplicated loop }
  TCardBitmap = array[0..191] of Byte;
  TCardAttr = array[0..23] of Byte;

CONST
  CardW = 32;  { pixels wide, 4 attribute cells }
  CardH = 48;  { pixels tall, 6 attribute cells }

  { pixel data, straight from wep.inc }
  CardBitmap: TCardBitmap = (
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
  CardAttr: TCardAttr = (
    121, 121, 121, 121, 121, 127, 127, 121, 121, 127, 127, 121, 121, 120, 120, 121,
    121, 121, 121, 121, 121, 121, 121, 121

  );

  { debug values for the 6 cards, in the order they're drawn
    (left to right). Range is 1-25:
      1-10  -> black
      11-17 -> red
      18-25 -> blue/cyan }
  CardNumbers: array[0..5] of Integer = (17, 12, 13, 14, 8, 7);

  { card BACK pixel data, straight from back.inc }
  CardBackBitmap: TCardBitmap = (
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
  CardBackAttr: TCardAttr = (
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
  LowerParkX = 200;

  { the operator symbol is now a ~20px vector drawing, not a
    single text character, so it needs its own cell-aligned
    clear zone (5x4 cells, covering the full gap between the
    two cards) and a fixed centre point to draw around }
  OpZoneX = 104;   { LowerSlot1X + CardW }
  OpZoneY = 120;   { vertically centred within the card row }
  OpZoneWBytes = 5;  { 40px / 8 }
  OpZoneHCells = 4;  { 32px / 8 }
  OpCenterX = 124;
  OpCenterY = 136;
  OpColor = 0;      { black - clearer against bright green than yellow was }

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
  ArrowCol = 1;   { GotoXY's leftmost valid column - column 0 crashes }
  TopRow = 1;
  MidRow = 13;
  BottomRow = 22;

VAR
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
  PendingIsResult: Integer;           { 0/1 - is slot A's value a raw card or a computed result }
  WaitingIsResult: Integer;           { 0/1 - same, for slot B }
  ParkedIsResult: Integer;            { 0/1 - same, for the parking slot }
  GameOver: Integer;                  { 0/1 - set once the final result is shown }
  EqualsShowing: Integer;             { 0/1 - whether the = symbol is currently up }
  
  cursorIndex: Integer;               { moved here from RunCardCursor's local VAR
                                         so RestartGame can reset it too }

  {------------------------------------------------------------}
{ SetAttr(paper, ink, bright)
  Combines what was previously three separate calls (Paper/
  Ink/Bright) into one - every call site in this program always
  set all three together anyway. Ink/Paper are redundant with
  PASTA80's own TextColor/TextBackground, used directly here;
  Bright still goes through its own control code since PASTA80
  has no built-in for it. }
PROCEDURE SetAttr(paper, ink, bright: Byte);
BEGIN
  TextBackground(paper);
  TextColor(ink);
  Write(#19, CHR(bright));
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
    Inc(count)
  ELSE
    WHILE v > 0 DO
    BEGIN
      Inc(count);
      v := v DIV 10;
    END;
  DigitCount := count;
END;

{ ------------------------------------------------------------
  PrintBigNumber(x, y, value, inkColor)
  Prints value in the ROM 8x8 font, right-justified within the
  card at (x, y), in the given ink colour. Shared by the upper
  cards, a freshly placed lower-row card, and the final result -
  the only thing that ever differed between those three was the
  ink colour, so one routine replaces three near-duplicate
  blocks.
  ------------------------------------------------------------ }
PROCEDURE PrintBigNumber(x, y, value, inkColor: Integer);
VAR
  textCol, textRow: Integer;
BEGIN
  textCol := (x DIV 8) + 2;
  textRow := (y DIV 8) + 3;
  textCol := textCol + (2 - DigitCount(value));

  GotoXY(textCol, textRow);
  SetAttr(7, inkColor, 1);
  Write(value);
END;

{ ------------------------------------------------------------
  SmallFont
  A compact 3x5-pixel digit font (0-9, plus a minus sign at
  index 10) for the lower-row numbers, used instead of the ROM
  8x8 font so results never overflow the card's own 32px width
  - even the extreme case (-32768, Integer's own range boundary)
  is only 6 characters, which at a 4px pitch is 23px wide, well
  inside the card. Each glyph is 5 rows; each row's low 3 bits
  select which of the 3 columns are lit (bit2=left, bit1=middle,
  bit0=right).
  ------------------------------------------------------------ }
CONST
  SmallFont: array[0..54] of Byte = (
    7,5,5,5,7,      { 0 }
    2,6,2,2,7,      { 1 }
    7,1,7,4,7,      { 2 }
    7,1,7,1,7,      { 3 }
    5,5,7,1,1,      { 4 }
    7,4,7,1,7,      { 5 }
    7,4,7,5,7,      { 6 }
    7,1,2,2,2,      { 7 }
    7,5,7,5,7,      { 8 }
    7,5,7,1,7,      { 9 }
    0,0,7,0,0       { - }
  );
  SmallCharPitch = 4;   { px between glyph starts }
  SmallCharRows = 5;    { glyph height in px }

{ ------------------------------------------------------------
  PlotSmallDigit(x, y, glyphIndex)
  Plots one SmallFont glyph (0-9, or 10 for minus) with its
  top-left pixel at (x, y).
  ------------------------------------------------------------ }
PROCEDURE PlotSmallDigit(x, y, glyphIndex: Integer);
VAR
  row, col, rowBits: Integer;
BEGIN
  FOR row := 0 TO SmallCharRows - 1 DO
  BEGIN
    rowBits := SmallFont[glyphIndex * SmallCharRows + row];
    FOR col := 0 TO 2 DO
      IF (rowBits AND (4 SHR col)) <> 0 THEN
        Plot(x + col, y + row);
  END;
END;

{ ------------------------------------------------------------
  PlotSmallNumber(x, y, value)
  Plots value using the small font, horizontally centred within
  a CardW-wide field starting at x. Handles negative values with
  a leading minus glyph.
  ------------------------------------------------------------ }
PROCEDURE PlotSmallNumber(x, y, value: Integer);
VAR
  totalWidth, startX, v, negative, count, i: Integer;
  digits: array[0..5] of Integer;
BEGIN
  totalWidth := DigitCount(value) * SmallCharPitch - 1;
  startX := x + (CardW - totalWidth) DIV 2;

  negative := 0;
  v := value;
  IF v < 0 THEN
  BEGIN
    negative := 1;
    v := -v;
  END;

  count := 0;
  IF v = 0 THEN
  BEGIN
    digits[0] := 0;
    count := 1;
  END
  ELSE
    WHILE v > 0 DO
    BEGIN
      digits[count] := v MOD 10;
      Inc(count);
      v := v DIV 10;
    END;

  IF negative = 1 THEN
  BEGIN
    PlotSmallDigit(startX, y, 10);
    startX := startX + SmallCharPitch;
  END;

  FOR i := count - 1 DOWNTO 0 DO
  BEGIN
    PlotSmallDigit(startX, y, digits[i]);
    startX := startX + SmallCharPitch;
  END;
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
  BlitCard(x, y, bitmap, attr)
  Draws any 32x48 card (front, back, or a lower-row copy) with
  its top-left pixel at (x, y), using whichever bitmap/attr
  data is passed in. Writes the exported bytes straight into
  screen and attribute memory - no per-pixel Plot calls needed,
  since the data is already in the exact format the hardware
  expects. x and y must be multiples of 8.
  ------------------------------------------------------------ }
PROCEDURE BlitCard(x, y: Integer; VAR bitmap: TCardBitmap; VAR attr: TCardAttr);
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
      Mem[rowAddr + col] := bitmap[byteIdx];
    END;
  END;

  FOR attrRow := 0 TO 5 DO
    FOR attrCol := 0 TO 3 DO
    BEGIN
      attrAddr := $5800
                  + ((y DIV 8) + attrRow) * 32
                  + ((x DIV 8) + attrCol);
      Mem[attrAddr] := attr[attrRow * 4 + attrCol];
    END;
END;

{ ------------------------------------------------------------
  DrawCard(x, y) / DrawCardBack(x, y)
  Thin wrappers around BlitCard for the front/back card art.
  ------------------------------------------------------------ }
PROCEDURE DrawCard(x, y: Integer);
BEGIN
  BlitCard(x, y, CardBitmap, CardAttr);
END;

PROCEDURE DrawCardBack(x, y: Integer);
BEGIN
  BlitCard(x, y, CardBackBitmap, CardBackAttr);
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
    DrawCard(x0, y);
    PrintBigNumber(x0, y, CardNumbers[i], NumberColor(CardNumbers[i]));
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
  DrawCard) at the lower position, then stamps a raw card value
  on it using the ROM 8x8 font with the usual tier colouring -
  exactly like the upper cards, since a raw card is never bigger
  than 25 and never negative. Used whenever a card is placed,
  swapped, parked, or recalled without having been combined via
  an operator yet.
  ------------------------------------------------------------ }
PROCEDURE DrawLowerCard(x, y, value: Integer);
BEGIN
  DrawCard(x, y);
  PrintBigNumber(x, y, value, NumberColor(value));
END;

{ ------------------------------------------------------------
  DrawLowerResult(x, y, value)
  Draws an intermediate result (after = with cards still
  remaining to combine) in the small pixel font, always bright
  blue (magenta) - distinct from a raw card value both in size and
  colour, since it can be negative or 3+ digits.
  ------------------------------------------------------------ }
PROCEDURE DrawLowerResult(x, y, value: Integer);
BEGIN
  DrawCard(x, y);
  SetAttr(7, 1, 1);
  PlotSmallNumber(x, y + 21, value);
END;

{ ------------------------------------------------------------
  DrawFinalResult(x, y, value)
  Draws the final result - reached once all 5 cards have been
  used and nothing is left parked - in the ROM 8x8 font, bright
  blue(magenta), per the game design (the final answer is meant to be
  compared against a 1-25 target card).
  ------------------------------------------------------------ }
PROCEDURE DrawFinalResult(x, y, value: Integer);
BEGIN
  DrawCard(x, y);
  PrintBigNumber(x, y, value, 3);
END;

{ ------------------------------------------------------------
  FillCardArea(x, y, fillAttr)
  Fills a 32x48 lower-card-sized area with blank pixels and a
  single attribute value - the shared core behind both clearing
  a lower slot back to plain background and drawing the park
  slot's dim marker block.
  ------------------------------------------------------------ }
PROCEDURE FillCardArea(x, y, fillAttr: Integer);
VAR
  row, col, rowAddr, attrRow, attrCol, attrAddr: Integer;
BEGIN
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
      Mem[attrAddr] := fillAttr;
    END;
END;

{ ------------------------------------------------------------
  ClearLowerCard(x, y)
  Erases a full 32x48 lower card back to plain background. The
  background attribute is read live from cell (0,0) - a corner
  never drawn on by any card - rather than a hardcoded guess,
  so this always matches the real background exactly regardless
  of whatever Paper/Ink/Bright state was active when the screen
  was first cleared.
  ------------------------------------------------------------ }
PROCEDURE ClearLowerCard(x, y: Integer);
VAR
  bgAttr: Integer;
BEGIN
  bgAttr := Mem[$5800];
  FillCardArea(x, y, bgAttr);
END;

{ ------------------------------------------------------------
  DrawParkBlock(x, y)
  Fills the parking slot with a solid dim (Bright 0) block -
  visually distinct from the bright cards and bright background
  everywhere else, so it's always obvious where to send a
  result to park it. This is drawn once at game start and
  redrawn every time the slot empties (instead of clearing back
  to plain background), so the marker stays visible throughout
  the whole game.
  ------------------------------------------------------------ }
PROCEDURE DrawParkBlock(x, y: Integer);
CONST
  ParkBlockAttr = 32;   { Bright 0, Paper Green(4), Ink Black(0) }
BEGIN
  FillCardArea(x, y, ParkBlockAttr);
END;

{ ------------------------------------------------------------
  ClearOperatorZone
  Blanks the full 40x32 area the operator symbol can occupy -
  needed because the symbol is now a ~20px vector drawing that
  can span several attribute cells, not a single text
  character.
  ------------------------------------------------------------ }
PROCEDURE ClearOperatorZone;
VAR
  row, col, rowAddr, attrRow, attrCol, attrAddr, bgAttr: Integer;
BEGIN
  bgAttr := Mem[$5800];

  FOR row := 0 TO (OpZoneHCells * 8) - 1 DO
  BEGIN
    rowAddr := ScreenAddr(OpZoneX, OpZoneY + row);
    FOR col := 0 TO OpZoneWBytes - 1 DO
      Mem[rowAddr + col] := 0;
  END;

  FOR attrRow := 0 TO OpZoneHCells - 1 DO
    FOR attrCol := 0 TO OpZoneWBytes - 1 DO
    BEGIN
      attrAddr := $5800
                  + ((OpZoneY DIV 8) + attrRow) * 32
                  + ((OpZoneX DIV 8) + attrCol);
      Mem[attrAddr] := bgAttr;
    END;
END;

{ ------------------------------------------------------------
  DrawOperatorSymbol(idx)
  Draws a bold ~20px vector symbol for the current operator
  (0=+ 1=- 2=x 3=div), centred in the gap between the two lower
  cards. Each stroke is drawn twice, offset by 1px, for extra
  weight at this size. Built from Plot/Draw line segments
  rather than stored bitmap data, since that's effectively free
  compared to exporting custom pixel art for four symbols.
  ------------------------------------------------------------ }
PROCEDURE DrawOperatorSymbol(idx: Integer);
BEGIN
  ClearOperatorZone;
  SetAttr(4, OpColor, 1);

  IF idx = 0 THEN
  BEGIN
    { + }
    Plot(OpCenterX, OpCenterY - 10);
    Draw(0, 20);
    Plot(OpCenterX + 1, OpCenterY - 10);
    Draw(0, 20);
    Plot(OpCenterX - 10, OpCenterY);
    Draw(20, 0);
    Plot(OpCenterX - 10, OpCenterY + 1);
    Draw(20, 0);
  END;

  IF idx = 1 THEN
  BEGIN
    { - }
    Plot(OpCenterX - 10, OpCenterY);
    Draw(20, 0);
    Plot(OpCenterX - 10, OpCenterY + 1);
    Draw(20, 0);
  END;

  IF idx = 2 THEN
  BEGIN
    { x (multiply) }
    Plot(OpCenterX - 10, OpCenterY - 10);
    Draw(20, 20);
    Plot(OpCenterX - 9, OpCenterY - 10);
    Draw(20, 20);
    Plot(OpCenterX - 10, OpCenterY + 10);
    Draw(20, -20);
    Plot(OpCenterX - 9, OpCenterY + 10);
    Draw(20, -20);
  END;

  IF idx = 3 THEN
  BEGIN
    { division sign: bar with a dot above and below }
    Plot(OpCenterX - 8, OpCenterY);
    Draw(16, 0);
    Plot(OpCenterX - 8, OpCenterY + 1);
    Draw(16, 0);
    Plot(OpCenterX - 1, OpCenterY - 6);
    Draw(2, 0);
    Plot(OpCenterX - 1, OpCenterY - 5);
    Draw(2, 0);
    Plot(OpCenterX - 1, OpCenterY + 5);
    Draw(2, 0);
    Plot(OpCenterX - 1, OpCenterY + 6);
    Draw(2, 0);
  END;
END;

{ ------------------------------------------------------------
  DrawEqualsSymbol
  Draws a bold "=" in the same spot/style as the operator
  symbols, shown after pressing = to mark the result as
  settled. Stays up until the next card is placed, at which
  point DrawOperatorSymbol's own ClearOperatorZone call
  naturally replaces it - no separate cleanup needed.
  ------------------------------------------------------------ }
PROCEDURE DrawEqualsSymbol;
BEGIN
  ClearOperatorZone;
  SetAttr(4, OpColor, 1);
  Plot(OpCenterX - 10, OpCenterY - 5);
  Draw(20, 0);
  Plot(OpCenterX - 10, OpCenterY - 4);
  Draw(20, 0);
  Plot(OpCenterX - 10, OpCenterY + 4);
  Draw(20, 0);
  Plot(OpCenterX - 10, OpCenterY + 5);
  Draw(20, 0);
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
  Shows a solid vertical line (Spectrum character 138) down the
  screen's leftmost column, indicating which half currently has
  focus: blue, top to middle, for the upper row; red, middle to
  bottom, for the lower row. Only one is ever shown at a time -
  clears the full column first, then draws whichever half
  applies. Only ever sets ink (TextColor) - paper is left
  exactly as it already is, never touched via TextBackground. A
  blank space has no visible pixels, so clearing needs no colour
  handling at all.
  ------------------------------------------------------------ }
PROCEDURE DrawFocusArrow;
VAR
  row: Integer;
BEGIN
  TextBackground(4);
{  TextColor(ink);}
  Write(#19, CHR(1));
  FOR row := TopRow TO BottomRow DO
  BEGIN
    GotoXY(ArrowCol, row);
    Write(' ');
  END;

  IF Focus = 0 THEN
  BEGIN
    TextColor(1);
    FOR row := TopRow TO MidRow-1 DO
    BEGIN
      GotoXY(ArrowCol, row);
      Write(CHR(138));
    END;
  END
  ELSE
  BEGIN
    TextColor(2);
    FOR row := MidRow TO BottomRow DO
      BEGIN
      GotoXY(ArrowCol, row);
      Write(CHR(138));
    END;
  END;
END;

{ ------------------------------------------------------------
  AllCardsUsed
  Returns 1 if all 5 playable upper cards have been used, 0
  otherwise. Used to detect the final result: once every card
  is used and nothing is left parked, whatever value remains
  in slot A is the answer.
  ------------------------------------------------------------ }
FUNCTION AllCardsUsed: Integer;
VAR
  i, allUsed: Integer;
BEGIN
  allUsed := 1;
  FOR i := 0 TO 4 DO
    IF UsedCard[i] = 0 THEN
      allUsed := 0;
  AllCardsUsed := allUsed;
END;

{ ------------------------------------------------------------
  DrawSlotValue(x, y, value, isResult)
  Redraws a lower slot in whichever style matches its current
  nature - big font/tier colour for a raw card, small font/
  blue (magenta) for an intermediate result. Used wherever a value
  moves between slots (swap, recall) without changing what kind
  of value it is.
  ------------------------------------------------------------ }
PROCEDURE DrawSlotValue(x, y, value, isResult: Integer);
BEGIN
  IF isResult = 1 THEN
    DrawLowerResult(x, y, value)
  ELSE
    DrawLowerCard(x, y, value);
END;

{ ------------------------------------------------------------
  RestartGame
  Resets everything back to the state right after the initial
  deal: redraws all 6 upper cards fresh (undoing any black/used
  marking), re-captures their attribute snapshot, clears the
  whole lower area (both slots, the operator/equals symbol, and
  resets the park marker), and resets every piece of game state.
  Triggered by X at any point during play.
  ------------------------------------------------------------ }
PROCEDURE RestartGame;
VAR
  i: Integer;
BEGIN
  DrawCardRow;
  CaptureCardAttrs;

  ClearLowerCard(LowerSlot1X, LowerY);
  ClearLowerCard(LowerSlot2X, LowerY);
  ClearOperatorZone;
  DrawParkBlock(LowerParkX, LowerY);

  cursorIndex := 0;
  ChoosingOp := 0;
  HavePending := 0;
  HaveParked := 0;
  PendingIsResult := 0;
  WaitingIsResult := 0;
  ParkedIsResult := 0;
  EqualsShowing := 0;
  GameOver := 0;
  Focus := 0;
  FOR i := 0 TO 4 DO
    UsedCard[i] := 0;

  SelectCard(cursorIndex, 1);
  DrawFocusArrow;
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
  newIndex, i, value, temp, search, found, isFinal: Integer;
  k: Char;
BEGIN
  cursorIndex := 0;
  ChoosingOp := 0;
  HavePending := 0;
  HaveParked := 0;
  PendingIsResult := 0;
  WaitingIsResult := 0;
  ParkedIsResult := 0;
  GameOver := 0;
  EqualsShowing := 0;
  Focus := 0;
  FOR i := 0 TO 4 DO
    UsedCard[i] := 0;

  SelectCard(cursorIndex, 1);
  DrawParkBlock(LowerParkX, LowerY);
  DrawFocusArrow;

  REPEAT
    k := UpCase(ReadKey);

    { the = symbol is only meaningful right after evaluating -
      any other action key means it no longer applies, so clear
      it before that key's own handling runs }
    IF EqualsShowing = 1 THEN
    BEGIN
      found := 0;
      IF k = 'S' THEN found := 1;
      IF k = 'O' THEN found := 1;
      IF k = 'P' THEN found := 1;
      IF k = 'C' THEN found := 1;
      IF k = 'Q' THEN found := 1;
      IF k = 'A' THEN found := 1;
      IF k = 'X' THEN RestartGame;
     
      IF found = 1 THEN
      BEGIN
        ClearOperatorZone;
        EqualsShowing := 0;
      END;
    END;

    { C toggles which row O/P currently controls: the upper
      cards, or the lower row's park/recall mechanism }
    IF k = 'C' THEN
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

      IF k = 'O' THEN
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

      IF k = 'P' THEN
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

      IF k = 'S' THEN
        IF ChoosingOp = 0 THEN
          IF UsedCard[cursorIndex] = 0 THEN
          BEGIN
            UsedCard[cursorIndex] := 1;
            MarkCardUsed(cursorIndex);
            value := CardNumbers[cursorIndex];

            IF HavePending = 0 THEN
            BEGIN
              PendingValue := value;
              PendingIsResult := 0;
              HavePending := 1;
              DrawLowerCard(LowerSlot1X, LowerY, PendingValue);
            END
            ELSE
            BEGIN
              WaitingValue := value;
              WaitingIsResult := 0;
              DrawLowerCard(LowerSlot2X, LowerY, WaitingValue);
              OpIndex := 0;
              DrawOperatorSymbol(OpIndex);
              ChoosingOp := 1;
            END;
          END;
    END
    ELSE
    BEGIN
      { --- lower row --- }
      IF ChoosingOp = 1 THEN
      BEGIN
        { picking the operator: O/P swap the two active operands
          (and which one is a raw card vs a result travels with
          them), Q/A cycle the operator, = evaluates }
        IF (k = 'O') OR (k = 'P') THEN
        BEGIN
          temp := PendingValue;
          PendingValue := WaitingValue;
          WaitingValue := temp;
          temp := PendingIsResult;
          PendingIsResult := WaitingIsResult;
          WaitingIsResult := temp;
          DrawSlotValue(LowerSlot1X, LowerY, PendingValue, PendingIsResult);
          DrawSlotValue(LowerSlot2X, LowerY, WaitingValue, WaitingIsResult);
        END;

        IF k = 'Q' THEN
        BEGIN
          Inc(OpIndex);
          IF OpIndex > 3 THEN
            OpIndex := 0;
          DrawOperatorSymbol(OpIndex);
        END;

        IF k = 'A' THEN
        BEGIN
          IF OpIndex = 0 THEN
            OpIndex := 3
          ELSE
            Dec(OpIndex);
          DrawOperatorSymbol(OpIndex);
        END;

        IF k = '=' THEN
        BEGIN
          PendingValue := Evaluate(PendingValue, WaitingValue, OpIndex);
          PendingIsResult := 1;
          DrawEqualsSymbol;
          EqualsShowing := 1;
          ClearLowerCard(LowerSlot2X, LowerY);
          ChoosingOp := 0;

          isFinal := 0;
          IF AllCardsUsed = 1 THEN
            IF HaveParked = 0 THEN
              isFinal := 1;

          IF isFinal = 1 THEN
          BEGIN
            { every card used and nothing left parked - this is
              the final result, per the game design }
            DrawFinalResult(LowerSlot1X, LowerY, PendingValue);

            GotoXY(9, 22);
            SetAttr(4, 6, 1);
            IF PendingValue = CardNumbers[5] THEN
              Write('*** CORRECT ***')
            ELSE
              Write('*** WRONG ***');

            GameOver := 1;
          END
          ELSE
            DrawLowerResult(LowerSlot1X, LowerY, PendingValue);
        END;
      END
      ELSE
      BEGIN
        { no operator pending: O/P do nothing here now - S alone
          drives all three cases from state, no cursor needed:
            A filled, Park empty  -> park A (A -> Park)
            A filled, Park filled -> recall INTO B, pairing the
              parked value alongside the current A value and
              starting operator selection
            A empty, Park filled  -> recall into A
          The isResult flag travels with the value in every
          case, so a parked result still shows small/blue (magenta),
          and a parked raw card still shows big/tier-coloured. }
        IF k = 'S' THEN
        BEGIN
          IF HavePending = 1 THEN
            IF HaveParked = 0 THEN
            BEGIN
              ParkedValue := PendingValue;
              ParkedIsResult := PendingIsResult;
              HaveParked := 1;
              HavePending := 0;
              ClearLowerCard(LowerSlot1X, LowerY);
              DrawSlotValue(LowerParkX, LowerY, ParkedValue, ParkedIsResult);
            END
            ELSE
            BEGIN
              WaitingValue := ParkedValue;
              WaitingIsResult := ParkedIsResult;
              HaveParked := 0;
              DrawParkBlock(LowerParkX, LowerY);
              DrawSlotValue(LowerSlot2X, LowerY, WaitingValue, WaitingIsResult);
              OpIndex := 0;
              DrawOperatorSymbol(OpIndex);
              ChoosingOp := 1;
            END
          ELSE
            IF HaveParked = 1 THEN
            BEGIN
              PendingValue := ParkedValue;
              PendingIsResult := ParkedIsResult;
              HavePending := 1;
              HaveParked := 0;
              DrawParkBlock(LowerParkX, LowerY);
              DrawSlotValue(LowerSlot1X, LowerY, PendingValue, PendingIsResult);
            END;
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
  SetAttr(4, 4, 1); { bright green background, matching the cards/logo's own bright attributes }
  ClrScr;
  DrawKryptoLogo(KryptoX, KryptoY);

  DrawCardBacksRow;

  GotoXY(2, 22);
  SetAttr(4, 0, 1);
  Write('Press any key...');
  ReadKey;

  { redraw the whole screen fresh for the flip - this also
    clears the "press any key" prompt (and the logo, which
    ClrScr wipes just like everything else - so it has to be
    put back immediately after) }
  SetAttr(4, 0, 1);
  ClrScr;
  DrawKryptoLogo(KryptoX, KryptoY);
  DrawCardRow;

  CaptureCardAttrs;
  RunCardCursor;
END.
