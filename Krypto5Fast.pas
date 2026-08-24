program Krypto5Fast;

type
  CardArray = array[1..5] of integer;
  ValueArray = array[1..16] of integer;
  OpArray = array[1..16] of integer;

var
  Cards : CardArray;
  Target : integer;

  Values : ValueArray;
  Op1List : OpArray;
  Op2List : OpArray;

  Ops : array[1..4] of integer;

  CountTriples : integer;
  CountResults : integer;
  CountBack : integer;

  Found : boolean;

  I, J, K, D, E : integer;
  N : integer;


function ApplyOp(X, Y, Op : integer; var R : integer) : boolean;
begin
  ApplyOp := true;

  if Op = 0 then
    R := X + Y;

  if Op = 1 then
    R := X - Y;

  if Op = 2 then
    R := X * Y;

  if Op = 3 then
    begin
      if Y = 0 then
        ApplyOp := false
      else
        if (X mod Y) <> 0 then
          ApplyOp := false
        else
          R := X div Y
    end
end;


function OpChar(Op : integer) : char;
begin
  if Op = 0 then OpChar := '+';
  if Op = 1 then OpChar := '-';
  if Op = 2 then OpChar := 'X';
  if Op = 3 then OpChar := ':'
end;


procedure PrintSolution;
begin
  write('  SOLUTION: ');

  write(Cards[I]);
  write(' ',OpChar(Ops[1]),' ');
  write(Cards[J]);
  write(' ',OpChar(Ops[2]),' ');
  write(Cards[K]);
  write(' ',OpChar(Ops[3]),' ');
  write(Cards[D]);
  write(' ',OpChar(Ops[4]),' ');
  writeln(Cards[E])
end;


procedure MakeThreeResults;
var
  O1, O2 : integer;
  V1, V2 : integer;
  OK : boolean;
begin
  N := 0;

  O1 := 0;

  while O1 <= 3 do
    begin
      OK := ApplyOp(Cards[I],Cards[J],O1,V1);

      if OK then
        begin
          O2 := 0;

          while O2 <= 3 do
            begin
              OK := ApplyOp(V1,Cards[K],O2,V2);

              if OK then
                begin
                  N := N + 1;

                  Values[N] := V2;
                  Op1List[N] := O1;
                  Op2List[N] := O2;

                  CountResults := CountResults + 1
                end;

              O2 := O2 + 1
            end
        end;

      O1 := O1 + 1
    end
end;


procedure CheckRequired(V : integer; O3, O4 : integer);
var
  P : integer;
begin
  if Found then
    exit;

  P := 1;

  while P <= N do
    begin
      if Values[P] = V then
        begin
          Ops[1] := Op1List[P];
          Ops[2] := Op2List[P];
          Ops[3] := O3;
          Ops[4] := O4;

          Found := true;

          PrintSolution;

          exit
        end;

      P := P + 1
    end
end;


procedure BackwardCheck;
var
  O3, O4 : integer;
  V3, V2 : integer;
  OK : boolean;
begin

  O4 := 0;

  while (O4 <= 3) and not Found do
    begin

      OK := false;

      { Work backwards through:
          V3 op4 E = Target
      }

      if O4 = 0 then
        begin
          V3 := Target - Cards[E];
          OK := true
        end;

      if O4 = 1 then
        begin
          V3 := Target + Cards[E];
          OK := true
        end;

      if O4 = 2 then
        begin
          if Cards[E] <> 0 then
            if (Target mod Cards[E]) = 0 then
              begin
                V3 := Target div Cards[E];
                OK := true
              end
        end;

      if O4 = 3 then
        begin
          if Cards[E] <> 0 then
            begin
              V3 := Target * Cards[E];
              OK := true
            end
        end;

      if OK then
        begin
          O3 := 0;

          while (O3 <= 3) and not Found do
            begin

              OK := false;

              { Work backwards through:
                  V2 op3 D = V3
              }

              if O3 = 0 then
                begin
                  V2 := V3 - Cards[D];
                  OK := true
                end;

              if O3 = 1 then
                begin
                  V2 := V3 + Cards[D];
                  OK := true
                end;

              if O3 = 2 then
                begin
                  if Cards[D] <> 0 then
                    if (V3 mod Cards[D]) = 0 then
                      begin
                        V2 := V3 div Cards[D];
                        OK := true
                      end
                end;

              if O3 = 3 then
                begin
                  if Cards[D] <> 0 then
                    begin
                      V2 := V3 * Cards[D];
                      OK := true
                    end
                end;

              if OK then
                begin
                  CountBack := CountBack + 1;

                  CheckRequired(V2,O3,O4)
                end;

              O3 := O3 + 1
            end
        end;

      O4 := O4 + 1
    end
end;


procedure Search;
var
  T : integer;
begin
  Found := false;

  CountTriples := 0;
  CountResults := 0;
  CountBack := 0;

  I := 1;

  while (I <= 5) and not Found do
    begin

      J := 1;

      while (J <= 5) and not Found do
        begin

          if J <> I then
            begin

              K := 1;

              while (K <= 5) and not Found do
                begin

                  if (K <> I) and (K <> J) then
                    begin

                      CountTriples := CountTriples + 1;

                      MakeThreeResults;

                      { Find the two unused cards. }

                      D := 1;

                      while (D <= 5) and
                            ((D = I) or (D = J) or (D = K)) do
                        D := D + 1;

                      E := D + 1;

                      while (E <= 5) and
                            ((E = I) or (E = J) or (E = K)) do
                        E := E + 1;

                      { First order: D E }

                      BackwardCheck;

                      { Second order: E D }

                      if not Found then
                        begin
                          T := D;
                          D := E;
                          E := T;

                          BackwardCheck
                        end
                    end;

                  K := K + 1
                end
            end;

          J := J + 1
        end;

      I := I + 1
    end
end;


begin
  writeln('KRYPTO 5-CARD FAST TEST');
  writeln;

  write('CARD 1: ');
  readln(Cards[1]);

  write('CARD 2: ');
  readln(Cards[2]);

  write('CARD 3: ');
  readln(Cards[3]);

  write('CARD 4: ');
  readln(Cards[4]);

  write('CARD 5: ');
  readln(Cards[5]);

  write('TARGET: ');
  readln(Target);

  writeln;
  writeln('CHECKING...');
  writeln;

  Search;

  if not Found then
    writeln('NO SOLUTION');

  writeln;
  writeln('3-CARD ORDERS: ',CountTriples);
  writeln('3-CARD RESULTS: ',CountResults);
  writeln('BACKWARD CASES: ',CountBack);

  writeln;
  writeln('DONE');

  readln
end.