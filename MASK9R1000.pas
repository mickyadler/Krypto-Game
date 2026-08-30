{===============================================================}
{ MASK9R1000 - 1000 RANDOM KRYPTO DEALS                         }
{ Micky Adler - 30-Aug-2026 15:56 Israel time                       }
{                                                               }
{ MASK9 solver with complete 4-line solution reconstruction.     }
{ Uses the real 56-card KRYPTO deck.                             }
{                                                               }
{ 1000 deals - completely automatic.                            }
{ No key presses or pauses.                                     }
{ SCR_CT reset prevents "scroll?" prompting.                    }
{                                                               }
{ Records:                                                       }
{   solved / no solution                                        }
{   solved over 150 frames                                      }
{   average solved frames                                       }
{   slowest solved deal                                         }
{   first NO SOLUTION deal                                      }
{===============================================================}

PROGRAM MASK9R1000;

{$l divmod.asm}

CONST
  DeckSize = 56;
  Tests    = 1000;
  Max2     = 6;
  Max3     = 150;
  HashSize = 32;

TYPE
  TValue2 = ARRAY[1..Max2] OF INTEGER;
  TValue3 = ARRAY[1..Max3] OF INTEGER;

VAR
  Deck : ARRAY[1..DeckSize] OF BYTE;

  Cards : ARRAY[1..5] OF INTEGER;
  Target : INTEGER;

  V2 : ARRAY[1..10] OF TValue2;
  N2 : ARRAY[1..10] OF BYTE;

  V3 : ARRAY[1..10] OF TValue3;
  N3 : ARRAY[1..10] OF BYTE;
  Built3 : ARRAY[1..10] OF BOOLEAN;

  Head : ARRAY[0..31] OF BYTE;
  Link : ARRAY[1..Max3] OF BYTE;

  Need : ARRAY[1..6] OF INTEGER;
  NeedOp : ARRAY[1..6] OF CHAR;
  NeedRev : ARRAY[1..6] OF BOOLEAN;
  NeedCount : BYTE;

  Found : BOOLEAN;
  Overflow3 : BOOLEAN;
  SolveFrames : INTEGER;

  { Complete four-line solution }

  StepA : ARRAY[1..4] OF INTEGER;
  StepB : ARRAY[1..4] OF INTEGER;
  StepR : ARRAY[1..4] OF INTEGER;
  StepOp : ARRAY[1..4] OF CHAR;

  { Winning MASK9 route }

  WinMode : CHAR;

  WinSet3 : BYTE;
  WinX : INTEGER;

  WinPairA : BYTE;
  WinPairB : BYTE;
  WinValA : INTEGER;
  WinValB : INTEGER;

  ReconOK : BOOLEAN;

  { Statistics }

  SolvedCount : INTEGER;
  NoSolutionCount : INTEGER;
  Over150Count : INTEGER;

  MaxSolvedFrames : INTEGER;
  MaxSolvedCase : INTEGER;

  TotalSolvedFrames : INTEGER;
  TotalOverflow : BOOLEAN;

  { Slowest solved deal }

  MaxCards : ARRAY[1..5] OF INTEGER;
  MaxTarget : INTEGER;

  { First NO SOLUTION deal }

  HaveNoSol : BOOLEAN;
  NoSolCards : ARRAY[1..5] OF INTEGER;
  NoSolTarget : INTEGER;
  NoSolFrames : INTEGER;


FUNCTION DivMod(Divisor,Dividend:INTEGER;
                VAR Quotient:INTEGER):INTEGER;
                REGISTER;
                EXTERNAL '__divmod';


{===============================================================}
{ FRAME TIMER                                                   }
{===============================================================}

PROCEDURE GetFrame(VAR Lo,Hi:BYTE);
BEGIN
  Lo := Mem[23672];
  Hi := Mem[23673]
END;


FUNCTION FrameDiff(SLo,SHi,ELo,EHi:BYTE):INTEGER;
VAR
  DL,DH,Borrow : INTEGER;
BEGIN
  DL := ELo-SLo;
  Borrow := 0;

  IF DL < 0 THEN
  BEGIN
    DL := DL+256;
    Borrow := 1
  END;

  DH := EHi-SHi-Borrow;

  IF DH < 0 THEN
    DH := DH+256;

  FrameDiff := DH*256+DL
END;


{===============================================================}
{ SAFE ARITHMETIC                                               }
{===============================================================}

FUNCTION SafeAdd(A,B:INTEGER; VAR R:INTEGER):BOOLEAN;
BEGIN
  SafeAdd := FALSE;

  IF (B > 0) AND (A > 32767-B) THEN EXIT;
  IF (B < 0) AND (A < -32768-B) THEN EXIT;

  R := A+B;
  SafeAdd := TRUE
END;


FUNCTION SafeSub(A,B:INTEGER; VAR R:INTEGER):BOOLEAN;
BEGIN
  SafeSub := FALSE;

  IF (B < 0) AND (A > 32767+B) THEN EXIT;
  IF (B > 0) AND (A < -32768+B) THEN EXIT;

  R := A-B;
  SafeSub := TRUE
END;


FUNCTION SafeMul(A,B:INTEGER; VAR R:INTEGER):BOOLEAN;
BEGIN
  SafeMul := FALSE;

  IF A = 0 THEN
  BEGIN
    R := 0;
    SafeMul := TRUE;
    EXIT
  END;

  IF B = 0 THEN
  BEGIN
    R := 0;
    SafeMul := TRUE;
    EXIT
  END;

  IF A = -32768 THEN
  BEGIN
    IF B = 1 THEN
    BEGIN
      R := -32768;
      SafeMul := TRUE
    END;
    EXIT
  END;

  IF B = -32768 THEN
  BEGIN
    IF A = 1 THEN
    BEGIN
      R := -32768;
      SafeMul := TRUE
    END;
    EXIT
  END;

  IF ABS(A) > 32767 DIV ABS(B) THEN EXIT;

  R := A*B;
  SafeMul := TRUE
END;


FUNCTION SafeDiv(A,B:INTEGER; VAR R:INTEGER):BOOLEAN;
VAR
  Q,Rem : INTEGER;
BEGIN
  SafeDiv := FALSE;

  IF B = 0 THEN EXIT;
  IF (A = -32768) AND (B = -1) THEN EXIT;

  Rem := DivMod(B,A,Q);

  IF Rem <> 0 THEN EXIT;

  R := Q;
  SafeDiv := TRUE
END;


{===============================================================}
{ REAL KRYPTO DECK                                              }
{===============================================================}

PROCEDURE CreateDeck;
VAR
  N,I : BYTE;
BEGIN
  N := 0;

  FOR I := 1 TO 6 DO
  BEGIN
    N:=N+1;
    Deck[N]:=I;

    N:=N+1;
    Deck[N]:=I;

    N:=N+1;
    Deck[N]:=I
  END;

  FOR I := 7 TO 10 DO
  BEGIN
    N:=N+1;
    Deck[N]:=I;

    N:=N+1;
    Deck[N]:=I;

    N:=N+1;
    Deck[N]:=I;

    N:=N+1;
    Deck[N]:=I
  END;

  FOR I := 11 TO 17 DO
  BEGIN
    N:=N+1;
    Deck[N]:=I;

    N:=N+1;
    Deck[N]:=I
  END;

  FOR I := 18 TO 25 DO
  BEGIN
    N:=N+1;
    Deck[N]:=I
  END
END;


PROCEDURE Swap(VAR A,B:BYTE);
VAR
  T : BYTE;
BEGIN
  T:=A;
  A:=B;
  B:=T
END;


PROCEDURE ShuffleDeck;
VAR
  I,J : BYTE;
BEGIN
  FOR I:=DeckSize DOWNTO 2 DO
  BEGIN
    J:=Random(I)+1;
    Swap(Deck[I],Deck[J])
  END
END;


PROCEDURE Deal;
VAR
  I : BYTE;
BEGIN
  CreateDeck;
  ShuffleDeck;

  FOR I:=1 TO 5 DO
    Cards[I]:=Deck[I];

  Target:=Deck[6]
END;


{===============================================================}
{ TWO-CARD SETS                                                 }
{===============================================================}

PROCEDURE Add2(SetNo:BYTE; R:INTEGER);
VAR
  K : BYTE;
BEGIN
  FOR K:=1 TO N2[SetNo] DO
    IF V2[SetNo,K]=R THEN EXIT;

  IF N2[SetNo]<Max2 THEN
  BEGIN
    N2[SetNo]:=N2[SetNo]+1;
    V2[SetNo,N2[SetNo]]:=R
  END
END;


PROCEDURE Make2(SetNo:BYTE; A,B:INTEGER);
VAR
  R : INTEGER;
BEGIN
  N2[SetNo]:=0;

  IF SafeAdd(A,B,R) THEN Add2(SetNo,R);
  IF SafeSub(A,B,R) THEN Add2(SetNo,R);
  IF SafeSub(B,A,R) THEN Add2(SetNo,R);
  IF SafeMul(A,B,R) THEN Add2(SetNo,R);
  IF SafeDiv(A,B,R) THEN Add2(SetNo,R);
  IF SafeDiv(B,A,R) THEN Add2(SetNo,R)
END;


PROCEDURE Build2;
BEGIN
  Make2(1,Cards[1],Cards[2]);
  Make2(2,Cards[1],Cards[3]);
  Make2(3,Cards[1],Cards[4]);
  Make2(4,Cards[1],Cards[5]);

  Make2(5,Cards[2],Cards[3]);
  Make2(6,Cards[2],Cards[4]);
  Make2(7,Cards[2],Cards[5]);

  Make2(8,Cards[3],Cards[4]);
  Make2(9,Cards[3],Cards[5]);

  Make2(10,Cards[4],Cards[5])
END;


{===============================================================}
{ HASHED THREE-CARD SETS                                        }
{===============================================================}

FUNCTION Hash32(R:INTEGER):BYTE;
VAR
  H : INTEGER;
BEGIN
  H:=R MOD HashSize;

  IF H<0 THEN
    H:=H+HashSize;

  Hash32:=H
END;


PROCEDURE ClearHash;
VAR
  H : BYTE;
BEGIN
  FOR H:=0 TO 31 DO
    Head[H]:=0
END;


PROCEDURE Add3(SetNo:BYTE; R:INTEGER);
VAR
  H,K,NewK : BYTE;
BEGIN
  H:=Hash32(R);
  K:=Head[H];

  WHILE K<>0 DO
  BEGIN
    IF V3[SetNo,K]=R THEN EXIT;
    K:=Link[K]
  END;

  IF N3[SetNo]<Max3 THEN
  BEGIN
    NewK:=N3[SetNo]+1;
    N3[SetNo]:=NewK;

    V3[SetNo,NewK]:=R;

    Link[NewK]:=Head[H];
    Head[H]:=NewK
  END
  ELSE
    Overflow3:=TRUE
END;


PROCEDURE AddCardTo2(Set3,Set2:BYTE; C:INTEGER);
VAR
  K : BYTE;
  X,R : INTEGER;
BEGIN
  FOR K:=1 TO N2[Set2] DO
  BEGIN
    X:=V2[Set2,K];

    IF SafeAdd(C,X,R) THEN Add3(Set3,R);
    IF SafeSub(C,X,R) THEN Add3(Set3,R);
    IF SafeSub(X,C,R) THEN Add3(Set3,R);
    IF SafeMul(C,X,R) THEN Add3(Set3,R);
    IF SafeDiv(C,X,R) THEN Add3(Set3,R);
    IF SafeDiv(X,C,R) THEN Add3(Set3,R)
  END
END;


PROCEDURE Ensure3(SetNo:BYTE);
BEGIN
  IF Built3[SetNo] THEN EXIT;

  N3[SetNo]:=0;
  ClearHash;

  IF SetNo=1 THEN
  BEGIN
    AddCardTo2(1,5,Cards[1]);
    AddCardTo2(1,2,Cards[2]);
    AddCardTo2(1,1,Cards[3])
  END;

  IF SetNo=2 THEN
  BEGIN
    AddCardTo2(2,6,Cards[1]);
    AddCardTo2(2,3,Cards[2]);
    AddCardTo2(2,1,Cards[4])
  END;

  IF SetNo=3 THEN
  BEGIN
    AddCardTo2(3,7,Cards[1]);
    AddCardTo2(3,4,Cards[2]);
    AddCardTo2(3,1,Cards[5])
  END;

  IF SetNo=4 THEN
  BEGIN
    AddCardTo2(4,8,Cards[1]);
    AddCardTo2(4,3,Cards[3]);
    AddCardTo2(4,2,Cards[4])
  END;

  IF SetNo=5 THEN
  BEGIN
    AddCardTo2(5,9,Cards[1]);
    AddCardTo2(5,4,Cards[3]);
    AddCardTo2(5,2,Cards[5])
  END;

  IF SetNo=6 THEN
  BEGIN
    AddCardTo2(6,10,Cards[1]);
    AddCardTo2(6,4,Cards[4]);
    AddCardTo2(6,3,Cards[5])
  END;

  IF SetNo=7 THEN
  BEGIN
    AddCardTo2(7,8,Cards[2]);
    AddCardTo2(7,6,Cards[3]);
    AddCardTo2(7,5,Cards[4])
  END;

  IF SetNo=8 THEN
  BEGIN
    AddCardTo2(8,9,Cards[2]);
    AddCardTo2(8,7,Cards[3]);
    AddCardTo2(8,5,Cards[5])
  END;

  IF SetNo=9 THEN
  BEGIN
    AddCardTo2(9,10,Cards[2]);
    AddCardTo2(9,7,Cards[4]);
    AddCardTo2(9,6,Cards[5])
  END;

  IF SetNo=10 THEN
  BEGIN
    AddCardTo2(10,10,Cards[3]);
    AddCardTo2(10,9,Cards[4]);
    AddCardTo2(10,8,Cards[5])
  END;

  Built3[SetNo]:=TRUE
END;


{===============================================================}
{ FINAL TARGET INVERSE                                          }
{===============================================================}

PROCEDURE AddNeed(V:INTEGER; Op:CHAR; Rev:BOOLEAN);
VAR
  K : BYTE;
BEGIN
  FOR K:=1 TO NeedCount DO
    IF Need[K]=V THEN EXIT;

  IF NeedCount<6 THEN
  BEGIN
    NeedCount:=NeedCount+1;
    Need[NeedCount]:=V;
    NeedOp[NeedCount]:=Op;
    NeedRev[NeedCount]:=Rev
  END
END;


PROCEDURE PrepareNeed(F:INTEGER);
VAR
  R,Q,Rem : INTEGER;
BEGIN
  NeedCount:=0;

  IF SafeSub(Target,F,R) THEN
    AddNeed(R,'+',FALSE);

  IF SafeAdd(Target,F,R) THEN
    AddNeed(R,'-',FALSE);

  IF SafeSub(F,Target,R) THEN
    AddNeed(R,'-',TRUE);

  IF F<>0 THEN
  BEGIN
    Rem:=DivMod(F,Target,Q);

    IF Rem=0 THEN
      AddNeed(Q,'*',FALSE)
  END;

  IF SafeMul(Target,F,R) THEN
    AddNeed(R,'/',FALSE);

  IF Target<>0 THEN
  BEGIN
    Rem:=DivMod(Target,F,Q);

    IF Rem=0 THEN
      AddNeed(Q,'/',TRUE)
  END
END;


{===============================================================}
{ TEST FINAL CANDIDATE                                          }
{===============================================================}

PROCEDURE TestCandidate(R,F:INTEGER);
VAR
  K : BYTE;
BEGIN
  FOR K:=1 TO NeedCount DO
    IF R=Need[K] THEN
    BEGIN
      Found:=TRUE;

      StepR[4]:=Target;
      StepOp[4]:=NeedOp[K];

      IF NeedRev[K] THEN
      BEGIN
        StepA[4]:=F;
        StepB[4]:=R
      END
      ELSE
      BEGIN
        StepA[4]:=R;
        StepB[4]:=F
      END;

      EXIT
    END
END;


{===============================================================}
{ SAVE THIRD STEP                                               }
{===============================================================}

PROCEDURE SaveStep3(A,B,R:INTEGER; Op:CHAR);
BEGIN
  StepA[3]:=A;
  StepB[3]:=B;
  StepR[3]:=R;
  StepOp[3]:=Op
END;


{===============================================================}
{ MASK9 1+3 SEARCH                                              }
{===============================================================}

PROCEDURE Card3(Set3:BYTE; C,Fifth:INTEGER);
VAR
  K : BYTE;
  X,R : INTEGER;
BEGIN
  FOR K:=1 TO N3[Set3] DO
  BEGIN
    IF Found THEN EXIT;

    X:=V3[Set3,K];

    IF SafeAdd(C,X,R) THEN
    BEGIN
      TestCandidate(R,Fifth);

      IF Found THEN
      BEGIN
        WinMode:='1';
        WinSet3:=Set3;
        WinX:=X;
        SaveStep3(C,X,R,'+');
        EXIT
      END
    END;

    IF SafeSub(C,X,R) THEN
    BEGIN
      TestCandidate(R,Fifth);

      IF Found THEN
      BEGIN
        WinMode:='1';
        WinSet3:=Set3;
        WinX:=X;
        SaveStep3(C,X,R,'-');
        EXIT
      END
    END;

    IF SafeSub(X,C,R) THEN
    BEGIN
      TestCandidate(R,Fifth);

      IF Found THEN
      BEGIN
        WinMode:='1';
        WinSet3:=Set3;
        WinX:=X;
        SaveStep3(X,C,R,'-');
        EXIT
      END
    END;

    IF SafeMul(C,X,R) THEN
    BEGIN
      TestCandidate(R,Fifth);

      IF Found THEN
      BEGIN
        WinMode:='1';
        WinSet3:=Set3;
        WinX:=X;
        SaveStep3(C,X,R,'*');
        EXIT
      END
    END;

    IF SafeDiv(C,X,R) THEN
    BEGIN
      TestCandidate(R,Fifth);

      IF Found THEN
      BEGIN
        WinMode:='1';
        WinSet3:=Set3;
        WinX:=X;
        SaveStep3(C,X,R,'/');
        EXIT
      END
    END;

    IF SafeDiv(X,C,R) THEN
    BEGIN
      TestCandidate(R,Fifth);

      IF Found THEN
      BEGIN
        WinMode:='1';
        WinSet3:=Set3;
        WinX:=X;
        SaveStep3(X,C,R,'/');
        EXIT
      END
    END
  END
END;


PROCEDURE RunCard3(Set3:BYTE; C,Fifth:INTEGER);
BEGIN
  IF Found THEN EXIT;

  Ensure3(Set3);

  IF Overflow3 THEN EXIT;

  Card3(Set3,C,Fifth)
END;


{===============================================================}
{ MASK9 2+2 SEARCH                                              }
{===============================================================}

PROCEDURE PairPair(ASet,BSet:BYTE; Fifth:INTEGER);
VAR
  I,J : BYTE;
  A,B,R : INTEGER;
BEGIN
  FOR I:=1 TO N2[ASet] DO
    FOR J:=1 TO N2[BSet] DO
    BEGIN
      IF Found THEN EXIT;

      A:=V2[ASet,I];
      B:=V2[BSet,J];

      IF SafeAdd(A,B,R) THEN
      BEGIN
        TestCandidate(R,Fifth);

        IF Found THEN
        BEGIN
          WinMode:='2';
          WinPairA:=ASet;
          WinPairB:=BSet;
          WinValA:=A;
          WinValB:=B;
          SaveStep3(A,B,R,'+');
          EXIT
        END
      END;

      IF SafeSub(A,B,R) THEN
      BEGIN
        TestCandidate(R,Fifth);

        IF Found THEN
        BEGIN
          WinMode:='2';
          WinPairA:=ASet;
          WinPairB:=BSet;
          WinValA:=A;
          WinValB:=B;
          SaveStep3(A,B,R,'-');
          EXIT
        END
      END;

      IF SafeSub(B,A,R) THEN
      BEGIN
        TestCandidate(R,Fifth);

        IF Found THEN
        BEGIN
          WinMode:='2';
          WinPairA:=ASet;
          WinPairB:=BSet;
          WinValA:=A;
          WinValB:=B;
          SaveStep3(B,A,R,'-');
          EXIT
        END
      END;

      IF SafeMul(A,B,R) THEN
      BEGIN
        TestCandidate(R,Fifth);

        IF Found THEN
        BEGIN
          WinMode:='2';
          WinPairA:=ASet;
          WinPairB:=BSet;
          WinValA:=A;
          WinValB:=B;
          SaveStep3(A,B,R,'*');
          EXIT
        END
      END;

      IF SafeDiv(A,B,R) THEN
      BEGIN
        TestCandidate(R,Fifth);

        IF Found THEN
        BEGIN
          WinMode:='2';
          WinPairA:=ASet;
          WinPairB:=BSet;
          WinValA:=A;
          WinValB:=B;
          SaveStep3(A,B,R,'/');
          EXIT
        END
      END;

      IF SafeDiv(B,A,R) THEN
      BEGIN
        TestCandidate(R,Fifth);

        IF Found THEN
        BEGIN
          WinMode:='2';
          WinPairA:=ASet;
          WinPairB:=BSet;
          WinValA:=A;
          WinValB:=B;
          SaveStep3(B,A,R,'/');
          EXIT
        END
      END
    END
END;


{===============================================================}
{ MASK9 SEARCH ORDER                                            }
{===============================================================}

PROCEDURE SearchTarget;
BEGIN
  Found:=FALSE;

  PrepareNeed(Cards[5]);

  RunCard3(7,Cards[1],Cards[5]);
  RunCard3(4,Cards[2],Cards[5]);
  RunCard3(2,Cards[3],Cards[5]);
  RunCard3(1,Cards[4],Cards[5]);

  IF Found OR Overflow3 THEN EXIT;

  PairPair(1,8,Cards[5]);
  PairPair(2,6,Cards[5]);
  PairPair(3,5,Cards[5]);

  IF Found THEN EXIT;


  PrepareNeed(Cards[4]);

  RunCard3(8,Cards[1],Cards[4]);
  RunCard3(5,Cards[2],Cards[4]);
  RunCard3(3,Cards[3],Cards[4]);
  RunCard3(1,Cards[5],Cards[4]);

  IF Found OR Overflow3 THEN EXIT;

  PairPair(1,9,Cards[4]);
  PairPair(2,7,Cards[4]);
  PairPair(4,5,Cards[4]);

  IF Found THEN EXIT;


  PrepareNeed(Cards[3]);

  RunCard3(9,Cards[1],Cards[3]);
  RunCard3(6,Cards[2],Cards[3]);
  RunCard3(3,Cards[4],Cards[3]);
  RunCard3(2,Cards[5],Cards[3]);

  IF Found OR Overflow3 THEN EXIT;

  PairPair(1,10,Cards[3]);
  PairPair(3,7,Cards[3]);
  PairPair(4,6,Cards[3]);

  IF Found THEN EXIT;


  PrepareNeed(Cards[2]);

  RunCard3(10,Cards[1],Cards[2]);
  RunCard3(6,Cards[3],Cards[2]);
  RunCard3(5,Cards[4],Cards[2]);
  RunCard3(4,Cards[5],Cards[2]);

  IF Found OR Overflow3 THEN EXIT;

  PairPair(2,10,Cards[2]);
  PairPair(3,9,Cards[2]);
  PairPair(4,8,Cards[2]);

  IF Found THEN EXIT;


  PrepareNeed(Cards[1]);

  RunCard3(10,Cards[2],Cards[1]);
  RunCard3(9,Cards[3],Cards[1]);
  RunCard3(8,Cards[4],Cards[1]);
  RunCard3(7,Cards[5],Cards[1]);

  IF Found OR Overflow3 THEN EXIT;

  PairPair(5,10,Cards[1]);
  PairPair(6,9,Cards[1]);
  PairPair(7,8,Cards[1])
END;


{===============================================================}
{ SMALL RECONSTRUCTION ENGINE                                   }
{===============================================================}

FUNCTION FindOperation(A,B,Wanted:INTEGER;
                       VAR OA,OB:INTEGER;
                       VAR Op:CHAR):BOOLEAN;
VAR
  R : INTEGER;
BEGIN
  FindOperation:=FALSE;

  IF SafeAdd(A,B,R) THEN
    IF R=Wanted THEN
    BEGIN
      OA:=A;
      OB:=B;
      Op:='+';
      FindOperation:=TRUE;
      EXIT
    END;

  IF SafeSub(A,B,R) THEN
    IF R=Wanted THEN
    BEGIN
      OA:=A;
      OB:=B;
      Op:='-';
      FindOperation:=TRUE;
      EXIT
    END;

  IF SafeSub(B,A,R) THEN
    IF R=Wanted THEN
    BEGIN
      OA:=B;
      OB:=A;
      Op:='-';
      FindOperation:=TRUE;
      EXIT
    END;

  IF SafeMul(A,B,R) THEN
    IF R=Wanted THEN
    BEGIN
      OA:=A;
      OB:=B;
      Op:='*';
      FindOperation:=TRUE;
      EXIT
    END;

  IF SafeDiv(A,B,R) THEN
    IF R=Wanted THEN
    BEGIN
      OA:=A;
      OB:=B;
      Op:='/';
      FindOperation:=TRUE;
      EXIT
    END;

  IF SafeDiv(B,A,R) THEN
    IF R=Wanted THEN
    BEGIN
      OA:=B;
      OB:=A;
      Op:='/';
      FindOperation:=TRUE
    END
END;


PROCEDURE PairCards(SetNo:BYTE; VAR A,B:BYTE);
BEGIN
  IF SetNo=1 THEN BEGIN A:=1; B:=2 END;
  IF SetNo=2 THEN BEGIN A:=1; B:=3 END;
  IF SetNo=3 THEN BEGIN A:=1; B:=4 END;
  IF SetNo=4 THEN BEGIN A:=1; B:=5 END;
  IF SetNo=5 THEN BEGIN A:=2; B:=3 END;
  IF SetNo=6 THEN BEGIN A:=2; B:=4 END;
  IF SetNo=7 THEN BEGIN A:=2; B:=5 END;
  IF SetNo=8 THEN BEGIN A:=3; B:=4 END;
  IF SetNo=9 THEN BEGIN A:=3; B:=5 END;
  IF SetNo=10 THEN BEGIN A:=4; B:=5 END
END;


FUNCTION FindPair(SetNo:BYTE;
                  Wanted:INTEGER;
                  StepNo:BYTE):BOOLEAN;
VAR
  A,B : BYTE;
  OA,OB : INTEGER;
  Op : CHAR;
BEGIN
  FindPair:=FALSE;

  PairCards(SetNo,A,B);

  IF FindOperation(Cards[A],Cards[B],
                   Wanted,OA,OB,Op) THEN
  BEGIN
    StepA[StepNo]:=OA;
    StepB[StepNo]:=OB;
    StepR[StepNo]:=Wanted;
    StepOp[StepNo]:=Op;

    FindPair:=TRUE
  END
END;


FUNCTION TryTriple(CardNo,PairSet:BYTE;
                   Wanted:INTEGER):BOOLEAN;
VAR
  K : BYTE;
  P,OA,OB : INTEGER;
  Op : CHAR;
BEGIN
  TryTriple:=FALSE;

  FOR K:=1 TO N2[PairSet] DO
  BEGIN
    P:=V2[PairSet,K];

    IF FindOperation(Cards[CardNo],P,
                     Wanted,OA,OB,Op) THEN
      IF FindPair(PairSet,P,1) THEN
      BEGIN
        StepA[2]:=OA;
        StepB[2]:=OB;
        StepR[2]:=Wanted;
        StepOp[2]:=Op;

        TryTriple:=TRUE;
        EXIT
      END
  END
END;


FUNCTION FindTriple(SetNo:BYTE;
                    Wanted:INTEGER):BOOLEAN;
BEGIN
  FindTriple:=FALSE;

  IF SetNo=1 THEN
  BEGIN
    IF TryTriple(1,5,Wanted) THEN BEGIN FindTriple:=TRUE; EXIT END;
    IF TryTriple(2,2,Wanted) THEN BEGIN FindTriple:=TRUE; EXIT END;
    IF TryTriple(3,1,Wanted) THEN BEGIN FindTriple:=TRUE; EXIT END
  END;

  IF SetNo=2 THEN
  BEGIN
    IF TryTriple(1,6,Wanted) THEN BEGIN FindTriple:=TRUE; EXIT END;
    IF TryTriple(2,3,Wanted) THEN BEGIN FindTriple:=TRUE; EXIT END;
    IF TryTriple(4,1,Wanted) THEN BEGIN FindTriple:=TRUE; EXIT END
  END;

  IF SetNo=3 THEN
  BEGIN
    IF TryTriple(1,7,Wanted) THEN BEGIN FindTriple:=TRUE; EXIT END;
    IF TryTriple(2,4,Wanted) THEN BEGIN FindTriple:=TRUE; EXIT END;
    IF TryTriple(5,1,Wanted) THEN BEGIN FindTriple:=TRUE; EXIT END
  END;

  IF SetNo=4 THEN
  BEGIN
    IF TryTriple(1,8,Wanted) THEN BEGIN FindTriple:=TRUE; EXIT END;
    IF TryTriple(3,3,Wanted) THEN BEGIN FindTriple:=TRUE; EXIT END;
    IF TryTriple(4,2,Wanted) THEN BEGIN FindTriple:=TRUE; EXIT END
  END;

  IF SetNo=5 THEN
  BEGIN
    IF TryTriple(1,9,Wanted) THEN BEGIN FindTriple:=TRUE; EXIT END;
    IF TryTriple(3,4,Wanted) THEN BEGIN FindTriple:=TRUE; EXIT END;
    IF TryTriple(5,2,Wanted) THEN BEGIN FindTriple:=TRUE; EXIT END
  END;

  IF SetNo=6 THEN
  BEGIN
    IF TryTriple(1,10,Wanted) THEN BEGIN FindTriple:=TRUE; EXIT END;
    IF TryTriple(4,4,Wanted) THEN BEGIN FindTriple:=TRUE; EXIT END;
    IF TryTriple(5,3,Wanted) THEN BEGIN FindTriple:=TRUE; EXIT END
  END;

  IF SetNo=7 THEN
  BEGIN
    IF TryTriple(2,8,Wanted) THEN BEGIN FindTriple:=TRUE; EXIT END;
    IF TryTriple(3,6,Wanted) THEN BEGIN FindTriple:=TRUE; EXIT END;
    IF TryTriple(4,5,Wanted) THEN BEGIN FindTriple:=TRUE; EXIT END
  END;

  IF SetNo=8 THEN
  BEGIN
    IF TryTriple(2,9,Wanted) THEN BEGIN FindTriple:=TRUE; EXIT END;
    IF TryTriple(3,7,Wanted) THEN BEGIN FindTriple:=TRUE; EXIT END;
    IF TryTriple(5,5,Wanted) THEN BEGIN FindTriple:=TRUE; EXIT END
  END;

  IF SetNo=9 THEN
  BEGIN
    IF TryTriple(2,10,Wanted) THEN BEGIN FindTriple:=TRUE; EXIT END;
    IF TryTriple(4,7,Wanted) THEN BEGIN FindTriple:=TRUE; EXIT END;
    IF TryTriple(5,6,Wanted) THEN BEGIN FindTriple:=TRUE; EXIT END
  END;

  IF SetNo=10 THEN
  BEGIN
    IF TryTriple(3,10,Wanted) THEN BEGIN FindTriple:=TRUE; EXIT END;
    IF TryTriple(4,9,Wanted) THEN BEGIN FindTriple:=TRUE; EXIT END;
    IF TryTriple(5,8,Wanted) THEN BEGIN FindTriple:=TRUE; EXIT END
  END
END;


PROCEDURE Reconstruct;
BEGIN
  ReconOK:=FALSE;

  IF WinMode='1' THEN
    ReconOK:=FindTriple(WinSet3,WinX)
  ELSE
  BEGIN
    IF FindPair(WinPairA,WinValA,1) THEN
      IF FindPair(WinPairB,WinValB,2) THEN
        ReconOK:=TRUE
  END
END;


{===============================================================}
{ RESET FOR NEXT DEAL                                           }
{===============================================================}

PROCEDURE ResetSolver;
VAR
  I : BYTE;
BEGIN
  Found:=FALSE;
  Overflow3:=FALSE;
  ReconOK:=FALSE;
  WinMode:='?';

  FOR I:=1 TO 10 DO
  BEGIN
    Built3[I]:=FALSE;
    N3[I]:=0
  END
END;


{===============================================================}
{ DISPLAY ONE CASE                                              }
{===============================================================}

PROCEDURE ShowStep(N:BYTE);
BEGIN
  Write(N);
  Write(': ');
  Write(StepA[N]);
  Write(' ');
  Write(StepOp[N]);
  Write(' ');
  Write(StepB[N]);
  Write(' = ');
  WriteLn(StepR[N])
END;


PROCEDURE ShowCase(TestNo:INTEGER);
VAR
  I : BYTE;
BEGIN
  { Keep Spectrum scrolling automatically }

  Mem[23692]:=255;

  Write('CASE ');
  WriteLn(TestNo);

  Write(Cards[1],' ');
  Write(Cards[2],' ');
  Write(Cards[3],' ');
  Write(Cards[4],' ');
  Write(Cards[5],' -> ');
  WriteLn(Target);

  IF Overflow3 THEN
    WriteLn('3-CARD OVERFLOW')
  ELSE
    IF NOT Found THEN
      WriteLn('NO SOLUTION')
    ELSE
    BEGIN
      Reconstruct;

      IF ReconOK THEN
        FOR I:=1 TO 4 DO
          ShowStep(I)
      ELSE
        WriteLn('RECONSTRUCTION FAILED')
    END;

  Write('FRAMES: ');
  WriteLn(SolveFrames);
  WriteLn
END;


{===============================================================}
{ STATISTICS                                                    }
{===============================================================}

PROCEDURE AddStats(TestNo:INTEGER);
VAR
  I : BYTE;
BEGIN
  IF Found THEN
  BEGIN
    SolvedCount:=SolvedCount+1;

    IF SolveFrames>150 THEN
      Over150Count:=Over150Count+1;

    IF SolveFrames>MaxSolvedFrames THEN
    BEGIN
      MaxSolvedFrames:=SolveFrames;
      MaxSolvedCase:=TestNo;

      FOR I:=1 TO 5 DO
        MaxCards[I]:=Cards[I];

      MaxTarget:=Target
    END;

    IF NOT TotalOverflow THEN
    BEGIN
      IF SolveFrames<=32767-TotalSolvedFrames THEN
        TotalSolvedFrames:=TotalSolvedFrames+SolveFrames
      ELSE
        TotalOverflow:=TRUE
    END
  END
  ELSE
  BEGIN
    NoSolutionCount:=NoSolutionCount+1;

    IF NOT HaveNoSol THEN
    BEGIN
      HaveNoSol:=TRUE;

      FOR I:=1 TO 5 DO
        NoSolCards[I]:=Cards[I];

      NoSolTarget:=Target;
      NoSolFrames:=SolveFrames
    END
  END
END;


{===============================================================}
{ FINAL SUMMARY                                                 }
{===============================================================}

PROCEDURE ShowSummary;
VAR
  Avg : INTEGER;
  I : BYTE;
BEGIN
  ClrScr;
  Mem[23692]:=255;

  WriteLn('MASK9R1000 SUMMARY');
  WriteLn('==================');
  WriteLn;

  Write('DEALS: ');
  WriteLn(Tests);

  Write('SOLVED: ');
  WriteLn(SolvedCount);

  Write('NO SOLUTION: ');
  WriteLn(NoSolutionCount);

  Write('SOLVED OVER 150: ');
  WriteLn(Over150Count);

  WriteLn;

  Write('MAX SOLVED FRAMES: ');
  WriteLn(MaxSolvedFrames);

  Write('MAX CASE: ');
  WriteLn(MaxSolvedCase);

  Write('MAX DEAL: ');

  FOR I:=1 TO 5 DO
  BEGIN
    Write(MaxCards[I]);
    Write(' ')
  END;

  Write('-> ');
  WriteLn(MaxTarget);

  WriteLn;

  IF NOT TotalOverflow THEN
  BEGIN
    Write('TOTAL SOLVED FRAMES: ');
    WriteLn(TotalSolvedFrames);

    IF SolvedCount>0 THEN
    BEGIN
      Avg:=TotalSolvedFrames DIV SolvedCount;

      Write('AVG SOLVED FRAMES: ');
      WriteLn(Avg)
    END
  END
  ELSE
    WriteLn('TOTAL FRAMES OVERFLOW');

  WriteLn;

  IF HaveNoSol THEN
  BEGIN
    WriteLn('FIRST NO SOLUTION');

    FOR I:=1 TO 5 DO
    BEGIN
      Write(NoSolCards[I]);
      Write(' ')
    END;

    Write('-> ');
    WriteLn(NoSolTarget);

    Write('NO SOL FRAMES: ');
    WriteLn(NoSolFrames)
  END
  ELSE
    WriteLn('NO UNSOLVABLE DEAL FOUND')
END;


{===============================================================}
{ MAIN                                                          }
{===============================================================}

VAR
  TestNo : INTEGER;
  SL,SH,EL,EH : BYTE;

BEGIN
  Randomize;

  SolvedCount:=0;
  NoSolutionCount:=0;
  Over150Count:=0;

  MaxSolvedFrames:=0;
  MaxSolvedCase:=0;

  TotalSolvedFrames:=0;
  TotalOverflow:=FALSE;

  HaveNoSol:=FALSE;

  ClrScr;

  Mem[23692]:=255;

  WriteLn('MASK9R1000');
  WriteLn('1000 RANDOM DEALS');
  WriteLn('NO PAUSES');
  WriteLn;

  FOR TestNo:=1 TO Tests DO
  BEGIN
    Deal;
    ResetSolver;

    GetFrame(SL,SH);

    Build2;
    SearchTarget;

    GetFrame(EL,EH);

    SolveFrames:=FrameDiff(SL,SH,EL,EH);

    AddStats(TestNo);
    ShowCase(TestNo)
  END;

  ShowSummary
END.