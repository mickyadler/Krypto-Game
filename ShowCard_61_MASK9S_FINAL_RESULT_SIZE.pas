{ ============================================================
  ShowCard_61 - final result size depends on correct/wrong
  ChatGPT - 03-Sep-2026
  ShowCard_40_MASK9S_ROWPATTERN.pas
  Code-size audit test 2 by ChatGPT - 02-Sep-2026 12:55 Israel time

  Based on ShowCard_13.pas
  Minimal PASTA80 program that loads a ZX-Paintbrush export
  (wep.inc: 32x48 pixel picture, 4x6 attribute cells) and
  draws it to the screen.

  Bitmap: 192 bytes (4 bytes/row x 48 rows, MSB = leftmost px)
  Attribute: 24 bytes (4x6 cells), taken as-is from the export
  - no need to work out ink/paper by hand, ZX-Paintbrush already
  baked the correct attribute byte for every cell.
  ============================================================ }

PROGRAM ShowCard;
{ Build3 table size test - ChatGPT - 02-Sep-2026 19:52 Israel time }

{$l divmod.asm}
{$m 2048}
{$l BeepFX2.asm} { machine code to be used to play sound effects.}



TYPE
  { shared array shapes, so one blit/fill routine can serve
    every 32x48 card (front, back, or a lower-row copy) instead
    of each having its own duplicated loop }
  TCardPatterns = array[0..43] of Byte;
  TCardRows = array[0..47] of Byte;
  TCardAttr = array[0..23] of Byte;

CONST
  CardW = 32;  { pixels wide, 4 attribute cells }
  CardH = 48;  { pixels tall, 6 attribute cells }

  { MASK9 production solver }
  DeckSize = 56;
  Max2 = 6;
  Max3 = 150;
  HashSize = 32;
  SolveLimit = 150;   { approximately 3 seconds at 50 Hz }

  { The deck multiset never changes; ShuffleDeck only permutes it.
    Keeping it as a writable typed constant removes CreateDeck. }
  Deck: array[1..DeckSize] of Byte = (
    1,1,1,2,2,2,3,3,3,4,4,4,5,5,
    5,6,6,6,7,7,7,7,8,8,8,8,9,9,
    9,9,10,10,10,10,11,11,12,12,13,13,14,14,
    15,15,16,16,17,17,18,19,20,21,22,23,24,25
  );

  { pixel data, straight from wep.inc }
  CardPattern: TCardPatterns = (
    31,255,255,248,127,255,255,254,248,0,0,
    31,240,0,0,15,224,0,0,7,192,0,
    0,1,192,0,0,3,240,0,0,7,248,
    0,0,15,120,0,0,30,63,255,255,252
  );

  CardRows: TCardRows = (
    0,1,2,3,4,5,5,5,5,5,5,5,
    5,5,5,5,5,5,5,5,5,5,5,5,
    5,5,5,5,5,5,5,5,5,5,5,5,
    5,5,5,5,5,5,6,4,7,8,9,10
  );

  { attribute data, straight from wep.inc }
  CardAttr: TCardAttr = (
    121, 121, 121, 121, 121, 127, 127, 121, 121, 127, 127, 121, 121, 120, 120, 121,
    121, 121, 121, 121, 121, 121, 121, 121

  );

  { card BACK pixel data, straight from back.inc }
  CardBackPattern: TCardPatterns = (
    0,0,0,0,31,62,62,124,46,221,221,
    186,49,227,227,198,59,247,247,230,53,235,
    235,214,59,247,247,238,0,0,0,0,0,
    0,0,0,0,0,0,0,0,0,0,0
  );

  CardBackRows: TCardRows = (
    0,0,1,2,3,4,5,2,2,1,1,2,
    5,4,5,2,1,1,2,5,6,5,2,1,
    1,1,2,5,4,5,2,1,1,2,5,4,
    5,2,1,1,1,2,5,4,3,2,1,0
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
  CardXPos: array[0..5] of Byte = (8, 48, 88, 128, 168, 208);

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
  KryptoPixelRows = 25;

  KryptoBitmap: array[0..299] of Byte = (
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
    1,248,241,249,240,63,131,240,1,252,7,240
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

  { Compact solver provenance lookup.  PairSet 1..10 maps to
    the two original playable-card indexes used by that V2 set. }
  PairCardA: array[1..10] of Byte = (0,0,0,0,1,1,1,2,2,3);
  PairCardB: array[1..10] of Byte = (1,2,3,4,2,3,4,3,4,4);
  SolOpChar: array[0..3] of Char = ('+','-','*','/');


  { Build3 recipe: three (V2 set, remaining card) combinations
    for each of the ten 3-card subsets.  This replaces ten
    separate IF blocks in Build3 with one compact table + loop. }
  Build3PairSet: array[1..30] of Byte = (
    5,2,1, 6,3,1, 7,4,1, 8,3,2, 9,4,2,
    10,4,3, 8,6,5, 9,7,5, 10,7,6, 10,9,8
  );
  Build3CardNo: array[1..30] of Byte = (
    0,1,2, 0,1,3, 0,1,4, 0,2,3, 0,2,4,
    0,3,4, 1,2,3, 1,2,4, 1,3,4, 2,3,4
  );

VAR
  { current deal: five playable cards plus target at index 5 }
  CardNumbers: array[0..5] of Byte;

  { MASK9 subset tables.
    V3 is deliberately ONE 150-value scratch table.  Each 3-card
    subset is built, searched in both possible outer/fifth-card
    orientations, then discarded.  This removes the old ten V3
    tables and their Built3/N3 bookkeeping. }
  V2: array[1..10,1..Max2] of Integer;
  N2: array[1..10] of Byte;
  V2Code: array[1..10,1..Max2] of Byte;

  V3: array[1..Max3] of Integer;
  N3: Byte;
  Head: array[0..31] of Byte;
  Link: array[1..Max3] of Byte;

  { Direct provenance for the ONE current V3 scratch table.
    These bytes let a winner be converted immediately to the
    four final rows, with no later reconstruction engine. }
  { Packed V3 provenance: 2 bytes per value instead of 4.
    Info1: bits 3..7 = PairSet-1, bits 0..2 = PairIdx-1
    Info2: bits 0..2 = CardNo, bits 3..4 = Op, bit 5 = reversed }
  V3Info1: array[1..Max3] of Byte;
  V3Info2: array[1..Max3] of Byte;

  Need: array[1..6] of Integer;
  NeedCode: array[1..6] of Byte;
  NeedCount: Byte;

  SolverFound, SolverAbort, SolverOverflow: Boolean;
  SolveStartLo, SolveStartHi: Byte;

  { runtime snapshot of every card's actual attribute bytes,
    captured right after the numbers are printed. Indexed as
    CardSavedAttr[cardIndex*24 + cellIndex]. This is how
    SelectCard tells "plain frame cell" from "number cell" -
    by comparing against the known blank CardAttr template -
    without needing to predict where GotoXY actually put the
    text. }
  CardSavedAttr: array[0..119] of Byte;

  { equation-building state, used by RunCardCursor's S/Q/A/=
    handling. Kept as globals (rather than locals) since they
    must persist across the whole play session. }
  UsedCard: array[0..4] of Byte;   { 1 once a card has been placed }
  ChoosingOp: Byte;                { 0 = picking a card, 1 = picking the operator }
  HavePending: Byte;               { 0/1 - whether slot 1 already holds a value }
  PendingValue: Integer;              { slot 1's value (running result) }
  WaitingValue: Integer;              { slot 2's value, valid while ChoosingOp=1 }
  OpIndex: Byte;                   { 0=+ 1=- 2=* 3=/ }
  Focus: Byte;                     { 0 = upper row, 1 = lower row (C toggles) }
  HaveParked: Byte;                { 0/1 - whether the parking slot holds a value }
  ParkedValue: Integer;               { the parking slot's value }
  PendingIsResult: Byte;           { 0/1 - is slot A's value a raw card or a computed result }
  WaitingIsResult: Byte;           { 0/1 - same, for slot B }
  ParkedIsResult: Byte;            { 0/1 - same, for the parking slot }
  GameOver: Byte;                  { 0/1 - set once the final result is shown }
  EqualsShowing: Byte;             { 0/1 - whether the = symbol is currently up }
  
  cursorIndex: Byte;
  EndKey: Char;
  { The finished hint costs only 28 bytes. }
  SolA: array[1..4] of Integer;
  SolB: array[1..4] of Integer;
  SolR: array[1..4] of Integer;
  SolOp: array[1..4] of Byte;
               { moved here from RunCardCursor's local VAR
                                         so RestartGame can reset it too }

{==============================================================
  EXTERNAL / SOUND
==============================================================}

{ Plays one of 58 predefined sound effects (machine code in BeepFX.asm). }
Procedure SoundEffect(Number: Integer); register; external 'playBasic';

{ Select ZX ROM output channel:
    1 = lower two-line area
    2 = normal upper screen }
PROCEDURE Channel(Ch: Byte); register; inline (
  $7d /
  $cd / $1601 /
  $c9
);

{===============================================================}
{ MASK9 SHUFFLER / SOLVER                                       }
{                                                               }
{ Space-saving production form:                                 }
{   - no solution reconstruction/debug tables                   }
{   - one V3[1..150] scratch table instead of ten               }
{   - each triple set is built once and tested both ways        }
{===============================================================}

FUNCTION DivMod(Divisor,Dividend:INTEGER;
                VAR Quotient:INTEGER):INTEGER;
                REGISTER;
                EXTERNAL '__divmod';

FUNCTION SafeAdd(A,B:Integer; VAR R:Integer):Boolean;
BEGIN
  SafeAdd := False;
  IF (B > 0) AND (A > 32767-B) THEN EXIT;
  IF (B < 0) AND (A < -32768-B) THEN EXIT;
  R := A+B;
  SafeAdd := True
END;

FUNCTION SafeSub(A,B:Integer; VAR R:Integer):Boolean;
BEGIN
  SafeSub := False;
  IF (B < 0) AND (A > 32767+B) THEN EXIT;
  IF (B > 0) AND (A < -32768+B) THEN EXIT;
  R := A-B;
  SafeSub := True
END;

FUNCTION SafeMul(A,B:Integer; VAR R:Integer):Boolean;
BEGIN
  SafeMul := False;
  IF A = 0 THEN
  BEGIN R := 0; SafeMul := True; EXIT END;
  IF B = 0 THEN
  BEGIN R := 0; SafeMul := True; EXIT END;
  IF A = -32768 THEN
  BEGIN
    IF B = 1 THEN BEGIN R := -32768; SafeMul := True END;
    EXIT
  END;
  IF B = -32768 THEN
  BEGIN
    IF A = 1 THEN BEGIN R := -32768; SafeMul := True END;
    EXIT
  END;
  IF ABS(A) > 32767 DIV ABS(B) THEN EXIT;
  R := A*B;
  SafeMul := True
END;

FUNCTION SafeDiv(A,B:Integer; VAR R:Integer):Boolean;
VAR Q,Rem: Integer;
BEGIN
  SafeDiv := False;
  IF B = 0 THEN EXIT;
  IF (A = -32768) AND (B = -1) THEN EXIT;
  Rem := DivMod(B,A,Q);
  IF Rem <> 0 THEN EXIT;
  R := Q;
  SafeDiv := True
END;

PROCEDURE SwapByte(VAR A,B:Byte);
VAR T: Byte;
BEGIN
  T := A; A := B; B := T
END;

PROCEDURE ShuffleDeck;
VAR I,J: Byte;
BEGIN
  FOR I := DeckSize DOWNTO 2 DO
  BEGIN
    J := Random(I)+1;
    SwapByte(Deck[I],Deck[J]);
  END
   
END;

PROCEDURE DealCards;
VAR I: Byte;
BEGIN
  ShuffleDeck;
  FOR I := 0 TO 5 DO CardNumbers[I] := Deck[I+1];
 
END;

FUNCTION SolverTimeUp:Boolean;
VAR Lo,Hi,DL,DH,Borrow,Elapsed: Integer;
BEGIN
  IF SolverAbort THEN
  BEGIN
    SolverTimeUp := True;
    EXIT
  END;
  Lo := Mem[23672];
  Hi := Mem[23673];
  DL := Lo-SolveStartLo;
  Borrow := 0;
  IF DL < 0 THEN
  BEGIN
    DL := DL+256;
    Borrow := 1
  END;
  DH := Hi-SolveStartHi-Borrow;
  IF DH < 0 THEN DH := DH+256;
  Elapsed := DH*256+DL;
  IF Elapsed >= SolveLimit THEN SolverAbort := True;
  SolverTimeUp := SolverAbort
END;

PROCEDURE Add2(SetNo:Byte; R:Integer; Code:Byte);
VAR K: Byte;
BEGIN
  FOR K := 1 TO N2[SetNo] DO
    IF V2[SetNo,K] = R THEN EXIT;
  IF N2[SetNo] < Max2 THEN
  BEGIN
    Inc(N2[SetNo]);
    K := N2[SetNo];
    V2[SetNo,K] := R;
    V2Code[SetNo,K] := Code
  END
END;

PROCEDURE Make2(SetNo:Byte; A,B:Integer);
VAR R: Integer;
BEGIN
  N2[SetNo] := 0;
  IF SafeAdd(A,B,R) THEN Add2(SetNo,R,0);
  IF SafeSub(A,B,R) THEN Add2(SetNo,R,1);
  IF SafeSub(B,A,R) THEN Add2(SetNo,R,129);
  IF SafeMul(A,B,R) THEN Add2(SetNo,R,2);
  IF SafeDiv(A,B,R) THEN Add2(SetNo,R,3);
  IF SafeDiv(B,A,R) THEN Add2(SetNo,R,131)
END;

PROCEDURE Build2;
BEGIN
  Make2(1,CardNumbers[0],CardNumbers[1]);
  Make2(2,CardNumbers[0],CardNumbers[2]);
  Make2(3,CardNumbers[0],CardNumbers[3]);
  Make2(4,CardNumbers[0],CardNumbers[4]);
  Make2(5,CardNumbers[1],CardNumbers[2]);
  Make2(6,CardNumbers[1],CardNumbers[3]);
  Make2(7,CardNumbers[1],CardNumbers[4]);
  Make2(8,CardNumbers[2],CardNumbers[3]);
  Make2(9,CardNumbers[2],CardNumbers[4]);
  Make2(10,CardNumbers[3],CardNumbers[4])
END;

FUNCTION Hash32(R:Integer):Byte;
VAR H: Integer;
BEGIN
  H := R MOD HashSize;
  IF H < 0 THEN H := H+HashSize;
  Hash32 := H
END;

PROCEDURE ClearHash;
VAR H: Byte;
BEGIN
  FOR H := 0 TO 31 DO Head[H] := 0
END;

PROCEDURE Add3(R:Integer; PairSet,PairIdx,CardNo,Code:Byte);
VAR H,K,NewK: Byte;
BEGIN
  H := Hash32(R);
  K := Head[H];
  WHILE K <> 0 DO
  BEGIN
    IF V3[K] = R THEN EXIT;
    K := Link[K]
  END;
  IF N3 < Max3 THEN
  BEGIN
    NewK := N3+1;
    N3 := NewK;
    V3[NewK] := R;
    V3Info1[NewK] := ((PairSet-1) SHL 3) OR (PairIdx-1);
    V3Info2[NewK] := CardNo OR ((Code AND 3) SHL 3);
    IF Code >= 128 THEN V3Info2[NewK] := V3Info2[NewK] OR 32;
    Link[NewK] := Head[H];
    Head[H] := NewK
  END
  ELSE SolverOverflow := True
END;

PROCEDURE AddCardTo2(Set2,CardNo:Byte);
VAR K: Byte; C,X,R: Integer;
BEGIN
  C := CardNumbers[CardNo];
  FOR K := 1 TO N2[Set2] DO
  BEGIN
    X := V2[Set2,K];
    IF SafeAdd(C,X,R) THEN Add3(R,Set2,K,CardNo,0);
    IF SafeSub(C,X,R) THEN Add3(R,Set2,K,CardNo,1);
    IF SafeSub(X,C,R) THEN Add3(R,Set2,K,CardNo,129);
    IF SafeMul(C,X,R) THEN Add3(R,Set2,K,CardNo,2);
    IF SafeDiv(C,X,R) THEN Add3(R,Set2,K,CardNo,3);
    IF SafeDiv(X,C,R) THEN Add3(R,Set2,K,CardNo,131)
  END
END;

PROCEDURE Build3(SetNo:Byte);
VAR I,Base: Byte;
BEGIN
  N3 := 0;
  ClearHash;
  Base := (SetNo-1)*3;
  FOR I := 1 TO 3 DO
    AddCardTo2(Build3PairSet[Base+I],Build3CardNo[Base+I])
END;

PROCEDURE AddNeed(V:Integer; Code:Byte);
VAR K: Byte;
BEGIN
  FOR K := 1 TO NeedCount DO
    IF Need[K] = V THEN EXIT;
  IF NeedCount < 6 THEN
  BEGIN
    Inc(NeedCount);
    Need[NeedCount] := V;
    NeedCode[NeedCount] := Code
  END
END;

PROCEDURE PrepareNeed(F:Integer);
VAR R,Q,Rem: Integer;
BEGIN
  NeedCount := 0;

  { R + F = Target }
  IF SafeSub(CardNumbers[5],F,R) THEN AddNeed(R,0);

  { R - F = Target }
  IF SafeAdd(CardNumbers[5],F,R) THEN AddNeed(R,1);

  { F - R = Target }
  IF SafeSub(F,CardNumbers[5],R) THEN AddNeed(R,129);

  { R * F = Target }
  Rem := DivMod(F,CardNumbers[5],Q);
  IF Rem = 0 THEN AddNeed(Q,2);

  { R / F = Target }
  IF SafeMul(CardNumbers[5],F,R) THEN AddNeed(R,3);

  { F / R = Target }
  Rem := DivMod(CardNumbers[5],F,Q);
  IF Rem = 0 THEN AddNeed(Q,131)
END;

FUNCTION MatchNeed(R:Integer):Byte;
VAR K: Byte;
BEGIN
  MatchNeed := 0;
  FOR K := 1 TO NeedCount DO
    IF R = Need[K] THEN
    BEGIN
      MatchNeed := K;
      EXIT
    END
END;

PROCEDURE SaveRow(RowNo:Byte; A,B,R:Integer; Code:Byte);
BEGIN
  IF Code >= 128 THEN
  BEGIN
    SolA[RowNo] := B;
    SolB[RowNo] := A;
    SolOp[RowNo] := Code-128
  END
  ELSE
  BEGIN
    SolA[RowNo] := A;
    SolB[RowNo] := B;
    SolOp[RowNo] := Code
  END;
  SolR[RowNo] := R
END;

PROCEDURE SavePair(RowNo,SetNo,Idx:Byte);
BEGIN
  SaveRow(RowNo,
          CardNumbers[PairCardA[SetNo]],
          CardNumbers[PairCardB[SetNo]],
          V2[SetNo,Idx],
          V2Code[SetNo,Idx])
END;

PROCEDURE SaveFinal(RowNo:Byte; R4:Integer; FifthCard,NeedNo:Byte);
BEGIN
  SaveRow(RowNo,R4,CardNumbers[FifthCard],
          CardNumbers[5],NeedCode[NeedNo])
END;

FUNCTION TryResult(A,B:Integer; VAR R:Integer;
                   VAR Code,NeedNo:Byte):Boolean;
BEGIN
  TryResult := False;

  IF SafeAdd(A,B,R) THEN
  BEGIN
    NeedNo := MatchNeed(R);
    IF NeedNo <> 0 THEN
    BEGIN Code:=0; TryResult:=True; EXIT END
  END;

  IF SafeSub(A,B,R) THEN
  BEGIN
    NeedNo := MatchNeed(R);
    IF NeedNo <> 0 THEN
    BEGIN Code:=1; TryResult:=True; EXIT END
  END;

  IF SafeSub(B,A,R) THEN
  BEGIN
    NeedNo := MatchNeed(R);
    IF NeedNo <> 0 THEN
    BEGIN Code:=129; TryResult:=True; EXIT END
  END;

  IF SafeMul(A,B,R) THEN
  BEGIN
    NeedNo := MatchNeed(R);
    IF NeedNo <> 0 THEN
    BEGIN Code:=2; TryResult:=True; EXIT END
  END;

  IF SafeDiv(A,B,R) THEN
  BEGIN
    NeedNo := MatchNeed(R);
    IF NeedNo <> 0 THEN
    BEGIN Code:=3; TryResult:=True; EXIT END
  END;

  IF SafeDiv(B,A,R) THEN
  BEGIN
    NeedNo := MatchNeed(R);
    IF NeedNo <> 0 THEN
    BEGIN Code:=131; TryResult:=True; EXIT END
  END
END;

PROCEDURE Card3(OuterCard,FifthCard:Byte);
VAR K,N,Code,PS,PI,CN: Byte;
    C,X,R,PV: Integer;
BEGIN
  C := CardNumbers[OuterCard];
  FOR K := 1 TO N3 DO
  BEGIN
    IF SolverTimeUp THEN EXIT;
    X := V3[K];

    IF TryResult(C,X,R,Code,N) THEN
    BEGIN
      PS := (V3Info1[K] SHR 3)+1;
      PI := (V3Info1[K] AND 7)+1;
      CN := V3Info2[K] AND 7;
      PV := V2[PS,PI];
      Code := (V3Info2[K] SHR 3) AND 3;
      IF (V3Info2[K] AND 32) <> 0 THEN Code := Code+128;

      SavePair(1,PS,PI);
      SaveRow(2,CardNumbers[CN],PV,X,Code);
      SaveRow(3,C,X,R,Code);
      SaveFinal(4,R,FifthCard,N);

      SolverFound := True;
      EXIT
    END
  END
END;

PROCEDURE RunSet(SetNo,OuterA,FifthA,OuterB,FifthB:Byte);
BEGIN
  IF SolverFound OR SolverAbort OR SolverOverflow THEN EXIT;

  Build3(SetNo);
  IF SolverOverflow OR SolverTimeUp THEN EXIT;

  PrepareNeed(CardNumbers[FifthA]);
  Card3(OuterA,FifthA);
  IF SolverFound OR SolverAbort THEN EXIT;

  PrepareNeed(CardNumbers[FifthB]);
  Card3(OuterB,FifthB)
END;

PROCEDURE PairPair(ASet,BSet,FifthCard:Byte);
VAR I,J,N,Code: Byte;
    A,B,R: Integer;
BEGIN
  FOR I := 1 TO N2[ASet] DO
    FOR J := 1 TO N2[BSet] DO
    BEGIN
      IF SolverTimeUp THEN EXIT;
      A := V2[ASet,I];
      B := V2[BSet,J];

      IF TryResult(A,B,R,Code,N) THEN
      BEGIN
        SavePair(1,ASet,I);
        SavePair(2,BSet,J);
        SaveRow(3,A,B,R,Code);
        SaveFinal(4,R,FifthCard,N);

        SolverFound := True;
        EXIT
      END
    END
END;

PROCEDURE SearchTarget;
BEGIN
  { First-use order from MASK9 is retained.  Each newly built
    triple set is immediately tested in BOTH complement
    orientations, allowing V3 to be discarded afterwards. }

  RunSet(7,0,4,4,0);
  RunSet(4,1,4,4,1);
  RunSet(2,2,4,4,2);
  RunSet(1,3,4,4,3);
  IF SolverFound OR SolverAbort OR SolverOverflow THEN EXIT;

  PrepareNeed(CardNumbers[4]);
  PairPair(1,8,4); PairPair(2,6,4); PairPair(3,5,4);
  IF SolverFound OR SolverAbort THEN EXIT;

  RunSet(8,0,3,3,0);
  RunSet(5,1,3,3,1);
  RunSet(3,2,3,3,2);
  IF SolverFound OR SolverAbort OR SolverOverflow THEN EXIT;

  PrepareNeed(CardNumbers[3]);
  PairPair(1,9,3); PairPair(2,7,3); PairPair(4,5,3);
  IF SolverFound OR SolverAbort THEN EXIT;

  RunSet(9,0,2,2,0);
  RunSet(6,1,2,2,1);
  IF SolverFound OR SolverAbort OR SolverOverflow THEN EXIT;

  PrepareNeed(CardNumbers[2]);
  PairPair(1,10,2); PairPair(3,7,2); PairPair(4,6,2);
  IF SolverFound OR SolverAbort THEN EXIT;

  RunSet(10,0,1,1,0);
  IF SolverFound OR SolverAbort OR SolverOverflow THEN EXIT;

  PrepareNeed(CardNumbers[1]);
  PairPair(2,10,1); PairPair(3,9,1); PairPair(4,8,1);
  IF SolverFound OR SolverAbort THEN EXIT;

  PrepareNeed(CardNumbers[0]);
  PairPair(5,10,0); PairPair(6,9,0); PairPair(7,8,0)
END;

PROCEDURE ResetSolver;
BEGIN
  SolverFound := False;
  SolverAbort := False;
  SolverOverflow := False;
  N3 := 0
END;

PROCEDURE SolveCurrentDeal;
BEGIN
  ResetSolver;
  SolveStartLo := Mem[23672];
  SolveStartHi := Mem[23673];
  Build2;
  SearchTarget
END;

PROCEDURE ShuffleUntilSolved;
BEGIN
  REPEAT
    DealCards;
    SolveCurrentDeal
  UNTIL SolverFound
END;

  {------------------------------------------------------------}
{ SetAttr(paper, ink, bright)
  Combines what was previously three separate calls (Paper/
  Ink/Bright) into one - every call site in this program always
  set all three together anyway. Ink/Paper are redundant with
  PASTA80's own TextColor/TextBackground, used directly here;
  Bright still goes through its own control code since PASTA80
  has no built-in for it. }
PROCEDURE SetAttr(paper, ink, bright, flash: Byte);
BEGIN
  TextBackground(paper);
  TextColor(ink);
  Write(#19, CHR(bright));
  Write(#18, Char(flash));

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
  v: Integer;
  count: Byte;
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
  textCol, textRow: Byte;
BEGIN
  textCol := (x DIV 8) + 2;
  textRow := (y DIV 8) + 3;
  textCol := textCol + (2 - DigitCount(value));

  GotoXY(textCol, textRow);
  SetAttr(7, inkColor, 1, 0);
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
  row, col, rowBits: Byte;
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
  v: Integer;
  totalWidth, startX, negative, count, i: Byte;
  digits: array[0..5] of Byte;
BEGIN
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

  { same width DigitCount(value) would have given (digit count
    plus 1 if negative), computed here from the loop above
    instead of a second, separate digit-counting pass }
  totalWidth := (count + negative) * SmallCharPitch - 1;
  startX := x + (CardW - totalWidth) DIV 2;

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
FUNCTION NumberColor(n: Integer): Byte;
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
PROCEDURE BlitCard(x, y: Integer; VAR pattern: TCardPatterns;
                   VAR rows: TCardRows; VAR attr: TCardAttr);
VAR
  row, col, byteIdx: Byte;
  rowAddr: Integer;
  attrRow, attrCol: Byte;
  attrAddr: Integer;
BEGIN
  FOR row := 0 TO CardH - 1 DO
  BEGIN
    rowAddr := ScreenAddr(x, y + row);
    FOR col := 0 TO 3 DO
    BEGIN
      byteIdx := rows[row] * 4 + col;
      Mem[rowAddr + col] := pattern[byteIdx];
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
  DrawCard(x, y)
  Thin wrapper around BlitCard for the front card art.
  ------------------------------------------------------------ }
PROCEDURE DrawCard(x, y: Integer);
BEGIN
  BlitCard(x, y, CardPattern, CardRows, CardAttr);
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
    rowAddr := ScreenAddr(x, y + 5 + row);
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

PROCEDURE DrawCardBacksRow;
VAR
  i: Byte;
BEGIN
  FOR i := 0 TO 5 DO
    BlitCard(CardXPos[i], CardYAt(i), CardBackPattern, CardBackRows, CardBackAttr);
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
  i: Byte;
BEGIN
  FOR i := 0 TO 5 DO
  BEGIN
    SoundEffect(0);
    DrawCard(CardXPos[i], CardYAt(i));
    PrintBigNumber(CardXPos[i], CardYAt(i), CardNumbers[i], NumberColor(CardNumbers[i]));
  END;
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
  i, x, y, attrRow, attrCol, idx: Byte;
  attrAddr: Integer;
BEGIN
  FOR i := 0 TO 4 DO
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
  x, y, attrRow, attrCol, idx, savedVal: Byte;
  attrAddr: Integer;
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
            Mem[attrAddr] := (savedVal AND $F8) OR 2
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
  SetAttr(7, 1, 1, 0);
  PlotSmallNumber(x, y + 21, value);
END;

{ ------------------------------------------------------------
  DrawFinalResult(x, y, value)
  Draws the final result - reached once all 5 cards have been
  used and nothing is left parked - in the ROM 8x8 font, bright
  blue(magenta), per the game design (the final answer is meant to be
  compared against a 1-25 target card).
  ------------------------------------------------------------ }
{ ------------------------------------------------------------
  FillCardArea(x, y, fillAttr)
  Fills a 32x48 lower-card-sized area with blank pixels and a
  single attribute value - the shared core behind both clearing
  a lower slot back to plain background and drawing the park
  slot's dim marker block.
  ------------------------------------------------------------ }
PROCEDURE FillCardArea(x, y, fillAttr: Integer);
VAR
  row, col, attrRow, attrCol: Byte;
  rowAddr, attrAddr: Integer;
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
  bgAttr: Byte;
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
  row, col, attrRow, attrCol, bgAttr: Byte;
  rowAddr, attrAddr: Integer;
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
CONST
  { Stroke tables for +, -, x, division and =.
    Each stroke is Plot(center+X/Y) then Draw(DX,DY). }
  SymbolStart: array[0..4] of Byte = (0,4,6,10,16);
  SymbolCount: array[0..4] of Byte = (4,2,4,6,4);

  StrokeX: array[0..19] of Integer = (
     0, 1,-10,-10,
    -10,-10,
    -10, -9,-10, -9,
     -8, -8, -1, -1, -1, -1,
    -10,-10,-10,-10
  );

  StrokeY: array[0..19] of Integer = (
    -10,-10, 0, 1,
      0,  1,
    -10,-10,10,10,
      0,  1,-6,-5, 5, 6,
     -5, -4, 4, 5
  );

  StrokeDX: array[0..19] of Integer = (
     0, 0,20,20,
    20,20,
    20,20,20,20,
    16,16, 2, 2, 2, 2,
    20,20,20,20
  );

  StrokeDY: array[0..19] of Integer = (
    20,20, 0, 0,
     0, 0,
    20,20,-20,-20,
     0, 0, 0, 0, 0, 0,
     0, 0, 0, 0
  );

{ ------------------------------------------------------------
  DrawSymbol(idx)
  Draws 0=+, 1=-, 2=x, 3=division, 4== from shared stroke data.
  ------------------------------------------------------------ }
PROCEDURE DrawSymbol(idx: Byte);
VAR
  i, first, last: Byte;
BEGIN
  ClearOperatorZone;
  SetAttr(4, OpColor, 1, 0);

  first := SymbolStart[idx];
  last := first + SymbolCount[idx] - 1;
  FOR i := first TO last DO
  BEGIN
    Plot(OpCenterX + StrokeX[i], OpCenterY + StrokeY[i]);
    Draw(StrokeDX[i], StrokeDY[i]);
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
  x, y, attrRow, attrCol, idx, savedVal: Byte;
  attrAddr: Integer;
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
  row: Byte;
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
FUNCTION AllCardsUsed: Byte;
VAR
  i: Byte;
BEGIN
  AllCardsUsed := 0;
  FOR i := 0 TO 4 DO
    IF UsedCard[i] = 0 THEN EXIT;
  AllCardsUsed := 1;
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
  Triggered by D at any point during play.
  ------------------------------------------------------------ }
PROCEDURE ClearCommandLines;
BEGIN
  Channel(1);
  SetAttr(4,0,1,0);
  GotoXY(1,1);
  Write('                              ');
  GotoXY(1,2);
  Write('                              ');
  Channel(2)
END;

PROCEDURE DrawCommandMenu(Mode:Byte);
BEGIN
  Channel(1);
  SetAttr(4,0,1,0);
  GotoXY(1,1);
  Write('                              ');
  GotoXY(1,2);
  Write('                              ');

  { 0 = upper, before first pull
    1 = upper, one lower value present
    2 = upper, two lower values present
    3 = lower, one value / park-recall state
    4 = lower, two values ready to evaluate }
  IF Mode = 0 THEN
  BEGIN
    GotoXY(10,2);
    Write('O/P S C R E')
  END;

  IF Mode = 1 THEN
  BEGIN
    GotoXY(8,2);
    Write('O/P S C R D E')
  END;

  IF Mode = 2 THEN
  BEGIN
    GotoXY(9,2);
    Write('O/P C R D E')
  END;

  IF Mode = 3 THEN
  BEGIN
    GotoXY(10,2);
    Write('S C R D E')
  END;

  IF Mode = 4 THEN
  BEGIN
    GotoXY(7,2);
    Write('= O/P Q/A C R D E')
  END;

  Channel(2)
END;

PROCEDURE RestartGame;
VAR
  i: Byte;
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
  EndKey := #0;
  FOR i := 0 TO 4 DO
    UsedCard[i] := 0;

  SelectCard(cursorIndex, 1);
  DrawFocusArrow;
  DrawCommandMenu(0);
END;


{ ------------------------------------------------------------
  ShowSavedSolution
  Prints the solver's saved 4-row solution to the hint area,
  used when the player asks to see it after a wrong answer.
  ------------------------------------------------------------ }
PROCEDURE ShowSavedSolution;
VAR I:Byte;
BEGIN
  { Remove the complete 32x48 dim parking block first, including
    its unused top and bottom character rows. }
  ClearLowerCard(LowerParkX, LowerY);

  FOR I := 1 TO 4 DO
  BEGIN
    GotoXY(23,15+I);
    SetAttr(4,0,1,0);
    Write('         ');
    GotoXY(23,15+I);
    Write(SolA[I]);
    Write(SolOpChar[SolOp[I]]);
    Write(SolB[I]);
    Write('=');
    Write(SolR[I])
  END
END;

PROCEDURE HideSavedSolution;
VAR I:Byte;
BEGIN
  { Clear the whole visible solution width, including characters
    that extend to the right of the 4-column parking block. }
  FOR I := 1 TO 4 DO
  BEGIN
    GotoXY(23,15+I);
    SetAttr(4,0,1,0);
    Write('         ')
  END;
  DrawParkBlock(LowerParkX, LowerY)
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
  temp: Integer;
  newIndex, i, value, search, found, isFinal, SolutionShowing: Byte;
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
  SolutionShowing := 0;
  FOR i := 0 TO 4 DO
    UsedCard[i] := 0;

  SelectCard(cursorIndex, 1);
  DrawParkBlock(LowerParkX, LowerY);
  DrawFocusArrow;
  DrawCommandMenu(0);

  REPEAT
    k := UpCase(ReadKey);

    { Centralized key sounds - one place only to save code:
      O/P use the card-show sound, S uses the pull-down sound,
      C uses the extra sound prepared in BeepFX2.asm. }
    IF (k = 'O') OR (k = 'P') THEN
      SoundEffect(0)
    ELSE
      IF k = 'S' THEN
        SoundEffect(1)
      ELSE
        IF k = 'C' THEN
          SoundEffect(4);

    { R reshuffles and E exits from normal play. }
    IF (k = 'R') OR (k = 'E') THEN
    BEGIN
      EndKey := k;
      GameOver := 1
    END;

    { D becomes available after the first card has been pulled down.
      RestartGame restores the same deal to its original state. }
    IF k = 'D' THEN
      IF (HavePending = 1) OR (HaveParked = 1) OR (ChoosingOp = 1) THEN
        RestartGame;

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

      IF Focus = 0 THEN
      BEGIN
        IF ChoosingOp = 1 THEN
          DrawCommandMenu(2)
        ELSE
          IF (HavePending = 1) OR (HaveParked = 1) THEN
            DrawCommandMenu(1)
          ELSE
            DrawCommandMenu(0)
      END
      ELSE
      BEGIN
        IF ChoosingOp = 1 THEN
          DrawCommandMenu(4)
        ELSE
          DrawCommandMenu(3)
      END
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
            DrawCommandMenu(1);

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
              DrawSymbol(OpIndex);
              ChoosingOp := 1;
              DrawCommandMenu(2);
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
          DrawSymbol(OpIndex);
          SoundEffect(6);
        END;

        IF k = 'A' THEN
        BEGIN
          IF OpIndex = 0 THEN
            OpIndex := 3
          ELSE
            Dec(OpIndex);
          DrawSymbol(OpIndex);
          SoundEffect(6);
        END;

        IF k = '=' THEN
        BEGIN
          PendingValue := Evaluate(PendingValue, WaitingValue, OpIndex);
          PendingIsResult := 1;
          DrawSymbol(4);
          SoundEffect(2);
          EqualsShowing := 1;
          ClearLowerCard(LowerSlot2X, LowerY);
          ChoosingOp := 0;
          DrawCommandMenu(3);

          isFinal := 0;
          IF AllCardsUsed = 1 THEN
            IF HaveParked = 0 THEN
              isFinal := 1;

          IF isFinal = 1 THEN
          BEGIN
            { Final result:
              correct -> redraw as a normal large card number;
              wrong   -> keep the safe small result display, since
                         it may be negative or too large for the card. }
            GotoXY(9, 21);
            IF PendingValue = CardNumbers[5] THEN
            BEGIN
              DrawCard(LowerSlot1X, LowerY);
              PrintBigNumber(LowerSlot1X, LowerY, PendingValue, 1);
              ClearCommandLines;
              Channel(1);
              GotoXY(9,1);
              SetAttr(4,1,1,1);
              Write('*** CORRECT ***');
              SoundEffect(5);
              GotoXY(9,2);
              SetAttr(4,0,1,0);
              Write('Press any key...');
              Channel(2);

              ReadKey;

              ClearCommandLines;
              Channel(1);
              SetAttr(4,0,1,0);
              GotoXY(12,2);
              Write('R D E');
              Channel(2);

              REPEAT
                k := UpCase(ReadKey);
                IF k = 'D' THEN
                BEGIN
                  RestartGame;
                  EndKey := #0
                END;
                IF (k = 'R') OR (k = 'E') THEN
                BEGIN
                  EndKey := k;
                  GameOver := 1
                END
              UNTIL (k = 'D') OR (GameOver = 1)
            END
            ELSE
            BEGIN
              DrawLowerResult(LowerSlot1X, LowerY, PendingValue);
              ClearCommandLines;
              Channel(1);
              GotoXY(10,1);
              SetAttr(4,2,1,1);
              Write('*** WRONG ***');
              GotoXY(9,2);
              SetAttr(4,0,1,0);
              Write('Press any key...');
              Channel(2);
              SoundEffect(3);

              ReadKey;

              ClearCommandLines;
              Channel(1);
              SetAttr(4,0,1,0);
              GotoXY(11,2);
              Write('V R D E');
              Channel(2);

              REPEAT
                k := UpCase(ReadKey);

                IF (SolutionShowing = 1) AND (k = 'D') THEN
                BEGIN
                  HideSavedSolution;
                  SolutionShowing := 0
                END;

                IF k = 'V' THEN
                BEGIN
                  ShowSavedSolution;
                  SolutionShowing := 1
                END;

                IF k = 'D' THEN
                BEGIN
                  RestartGame;
                  EndKey := #0
                END;
                IF (k = 'R') OR (k = 'E') THEN
                BEGIN
                  EndKey := k;
                  GameOver := 1
                END
              UNTIL (k = 'D') OR (GameOver = 1)
            END;
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
              DrawCommandMenu(3);
            END
            ELSE
            BEGIN
              WaitingValue := ParkedValue;
              WaitingIsResult := ParkedIsResult;
              HaveParked := 0;
              DrawParkBlock(LowerParkX, LowerY);
              DrawSlotValue(LowerSlot2X, LowerY, WaitingValue, WaitingIsResult);
              OpIndex := 0;
              DrawSymbol(OpIndex);
              ChoosingOp := 1;
              DrawCommandMenu(4);
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
              DrawCommandMenu(3);
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
  Randomize;
  REPEAT
    ShuffleUntilSolved;

    SetAttr(4, 0, 1, 0);
    ClrScr;
    DrawKryptoLogo(KryptoX, KryptoY);
    DrawCardBacksRow;
    
    GotoXY(9,20);
    Write('Press any key...');

    ReadKey;

    SetAttr(4, 0, 1, 0);
    ClrScr;
    DrawKryptoLogo(KryptoX, KryptoY);
    DrawCardRow;

    CaptureCardAttrs;
    RunCardCursor;

    IF (EndKey <> 'R') AND (EndKey <> 'E') THEN
    BEGIN
      DrawCommandMenu(0);
      REPEAT
        EndKey := UpCase(ReadKey)
      UNTIL (EndKey = 'R') OR (EndKey = 'E')
    END
  UNTIL EndKey = 'E'
END.
