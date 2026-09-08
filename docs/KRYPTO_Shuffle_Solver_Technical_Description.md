# **KRYPTO for ZX Spectrum 48K Shuffle and Solver — Theory, Program Flow and Code Commentary** 

#### **Technical description of the production MASK9 shuffle/solver** 

Source baseline: ShowCard_68_LOWER_FOCUS_BASELINE_USER.pas KRYPTO Rev. 1.0 — ZX Spectrum 48K / PASTA80 

**Purpose:** This document explains the production shuffle/solver as it exists in the Rev. 1.0 game: what problem it solves, how the algorithm is organized, why it was chosen, how the main procedures work, and which compromises were deliberately made for a 48K Spectrum. 

KRYPTO for ZX Spectrum 48K — Shuffle/Solver Technical Description    | **1** 

## **1. What the shuffle/solver is responsible for** 

The game must not simply deal five playable cards and a target and hope that the puzzle is usable. Before the cards are shown to the player, the program tests the deal. A deal is accepted only if the production solver finds a legal solution quickly enough. If it does not, the deck is shuffled again and another six cards are tried. 

This means the production solver has two jobs at once: 

- Deal validation: reject a deal that cannot be solved by the production search within its allowed time and working-space limits. 

- Hint capture: when a solution is found, save four arithmetic rows so the game can later display the solution after a wrong attempt. 

**Important distinction:** The production routine is best understood as a fast deal-acceptance solver, not as an offline mathematical theorem prover. A timeout is intentionally treated exactly like a bad deal: the player never sees the delay; the game simply reshuffles. 

## **2. KRYPTO rules that shape the algorithm** 

The solver is built around the exact rules used by this Spectrum version of KRYPTO: 

- All five playable cards must be used exactly once. 

- The four operators are +, -, * and /. 

- Negative intermediate results are legal. 

- Zero is legal. 

- Fractional intermediate results are not legal: division is accepted only when the remainder is zero. 

- The player may combine any two currently available values, so arbitrary pairwise grouping is part of the game model. 

The last rule is especially important. A solver that merely tries card permutations with a fixed left-to-right evaluation order can be very fast, but it can miss legal solutions that require parking an intermediate result and combining it later. That limitation was encountered during development, so the production design had to preserve substantially more grouping freedom while remaining small and fast enough for the Spectrum. 

## **3. Why the obvious solver was not suitable** 

A direct recursive reduction solver is conceptually simple: from the current set of values, choose any two, try every legal arithmetic result, replace the pair by the result, and recurse until one value remains. For five cards this is mathematically attractive because it naturally follows the real game. 

On a modern computer that approach is easy to accept. On a 3.5 MHz Z80 inside a 48K game, however, the worst cases are the problem. An unsolvable or awkward deal forces the search to explore a very large fraction of the tree. Earlier complete pair-reduction experiments could take far too long for an operation that happens every time the game shuffles. 

At the opposite extreme, the earlier FAST1-style search was very quick but proved too restrictive: validation found real legal solutions that it missed. The production MASK9 design is therefore a compromise optimized for the actual job: find a usable solution extremely quickly on almost every random deal, save that solution, and discard the rare difficult deal rather than making the player wait. 

KRYPTO for ZX Spectrum 48K — Shuffle/Solver Technical Description    | **2** 

|**Approach**|**Strength**|**Problem in this game**|
|---|---|---|
|Fixed-order / highly pruned search|Very fast and compact|Can miss legal arbitrary-grouping<br>solutions.|
|Full any-two recursive reduction|Natural and exhaustive search<br>model|Worst-case execution time is too<br>high for shufle-time use on a 48K<br>Spectrum.|
|Large subset dynamic<br>programming|Strong reuse of computed subsets|Keeping all values/provenance for<br>many subsets consumes RAM and<br>code; unnecessary for a deal<br>validator.|
|MASK9 production search|Small tables, no recursion, fast<br>matching, direct hint capture|Deliberately optimized for deal<br>acceptance; timeout/overfow<br>cause a reshufle rather than a<br>proof of impossibility.|



## **4. High-level theory of operation** 

The main idea is to compute useful results for small subsets once, then combine those results rather than repeatedly rebuilding the same arithmetic subexpressions. The five playable cards are numbered internally 0..4; card 5 is the target. 

MASK9 works in three layers: 

1. Build every distinct legal result for each of the ten two-card subsets. These are the V2 tables. 

2. Build one selected three-card subset at a time into a reusable V3 scratch table. A triple is formed by combining one V2 result with the remaining card of that triple. 

3. For the remaining four-card part, combine either one card with a triple (1+3) or two pairs (2+2). Instead of then trying a fifth operation against the target, precompute the values that the four-card result would have to equal for the final card to reach the target. 

This transforms much of the search into table generation plus equality matching. It also allows the same V3 table to be built, searched in two complementary orientations, and immediately discarded. 

|**Stage**|**Main routine**|**Output / decision**|
|---|---|---|
|Shufle|ShufleDeck / DealCards|Five playable values plus target.|
|Initialize|ResetSolver|Clear found/abort/overfow state.|
|Pair layer|Build2|10 V2 sets, each containing unique<br>legal pair results and compact<br>provenance.|
|Search|SearchTarget|Build selected V3 sets; test 1+3|



KRYPTO for ZX Spectrum 48K — Shuffle/Solver Technical Description    | **3** 

|**Stage**|**Main routine**|**Output / decision**|
|---|---|---|
|||and 2+2 four-card forms.|
|Final inversion|PrepareNeed + MatchNeed|Turn the fnal-card operation into a<br>small list of required four-card<br>values.|
|Success|SavePair / SaveRow / SaveFinal|Four displayable hint rows are<br>saved; SolverFound becomes true.|
|Failure/timeout|SolverAbort or SolverOverfow|The deal is discarded and shufled<br>again.|



## **5. Shuffle flow** 

PROCEDURE ShuffleUntilSolved; BEGIN REPEAT DealCards; SolveCurrentDeal UNTIL SolverFound END; 

This tiny procedure is the key to the user experience. The game does not need to display “unsolvable” or “search failed” during shuffle. Any unsuccessful attempt simply causes another deal. 

PROCEDURE DealCards; VAR I: Byte; BEGIN ShuffleDeck; FOR I := 0 TO 5 DO CardNumbers[I] := Deck[I+1] END; 

The deck is a writable typed constant containing the real 56-card KRYPTO distribution. ShuffleDeck performs an in-place Fisher–Yates-style shuffle: for I from 56 down to 2, it swaps Deck[I] with a uniformly selected position 1..I. The first six shuffled entries become the deal. 

## **6. Starting and timing a solve** 

PROCEDURE SolveCurrentDeal; BEGIN ResetSolver; SolveStartLo := Mem[23672]; SolveStartHi := Mem[23673]; Build2; SearchTarget END; 

KRYPTO for ZX Spectrum 48K — Shuffle/Solver Technical Description    | **4** 

The low two bytes of the Spectrum FRAMES system variable are sampled at the beginning of the search. SolverTimeUp later subtracts that value from the current frame count, including the low-byte borrow, and sets SolverAbort once the elapsed count reaches SolveLimit. 

<mark>SolveLimit = 150;   { approximately 3 seconds at 50 Hz }</mark> 

The 150-frame limit is a design parameter, not a correctness theorem. If a valid deal happens to require more search than the limit allows, the production game is allowed to reject it and reshuffle. This is exactly why the solver can be optimized for perceived shuffle speed rather than worst-case exhaustive completion. 

## **7. Safe arithmetic and why divmod.asm is used** 

PASTA80 uses 16-bit signed Integer values. The solver therefore must not allow a temporary arithmetic overflow to wrap around and masquerade as a valid KRYPTO result. SafeAdd, SafeSub and SafeMul test the range before committing the operation. SafeDiv rejects division by zero, rejects the -32768 / -1 overflow case, and requires an exact remainder of zero. 

FUNCTION SafeDiv(A,B:Integer; VAR R:Integer):Boolean; VAR Q,Rem: Integer; BEGIN SafeDiv := False; IF B = 0 THEN EXIT; IF (A = -32768) AND (B = -1) THEN EXIT; Rem := DivMod(B,A,Q); IF Rem <> 0 THEN EXIT; R := Q; SafeDiv := True END; 

The source directive {$l divmod.asm} links a small Z80 routine that returns quotient and remainder together. This matters because legality of division depends on the remainder. Doing one machine-code division that supplies both values is cheaper than performing a quotient calculation and a separate remainder test in Pascal inside a hot search loop. 

**Calling convention:** The external routine is declared DivMod(Divisor, Dividend, Quotient). Therefore A DIV B is tested with DivMod(B, A, Q). The reversed argument order is intentional. 

## **8. The V2 pair tables** 

With five playable cards there are exactly ten unordered two-card subsets. Build2 assigns them fixed set numbers: 

|**V2 set**|**Card indexes**|
|---|---|
|1|0,1|
|2|0,2|
|3|0,3|
|4|0,4|



KRYPTO for ZX Spectrum 48K — Shuffle/Solver Technical Description    | **5** 

|**V2 set**|**Card indexes**|
|---|---|
|5|1,2|
|6|1,3|
|7|1,4|
|8|2,3|
|9|2,4|
|10|3,4|



Make2 tries six possibilities: A+B, A-B, B-A, A*B, A/B and B/A. Addition and multiplication need only one orientation because they are commutative. Add2 removes duplicate numeric results before storing them. 

IF SafeAdd(A,B,R) THEN Add2(SetNo,R,0); IF SafeSub(A,B,R) THEN Add2(SetNo,R,1); IF SafeSub(B,A,R) THEN Add2(SetNo,R,129); IF SafeMul(A,B,R) THEN Add2(SetNo,R,2); IF SafeDiv(A,B,R) THEN Add2(SetNo,R,3); IF SafeDiv(B,A,R) THEN Add2(SetNo,R,131) 

Max2 is 6 because two input values can produce at most those six operator/orientation outcomes before duplicates are removed. V2Code stores enough information to reconstruct the chosen operation. Codes 0..3 mean +, -, * and /. Adding 128 means the operands were reversed. For example 129 means “second operand minus first”; 131 means “second operand divided by first”. 

## **9. The V3 triple scratch table** 

There are ten three-card subsets as well, but the program deliberately does not keep ten permanent triple tables. That would cost too much RAM. Instead V3[1..150] is one scratch table: Build3 creates one triple subset, SearchTarget uses it immediately, and the next Build3 overwrites it. 

|**V3 set**|**Card indexes**|
|---|---|
|1|0,1,2|
|2|0,1,3|
|3|0,1,4|
|4|0,2,3|
|5|0,2,4|
|6|0,3,4|
|7|1,2,3|



KRYPTO for ZX Spectrum 48K — Shuffle/Solver Technical Description    | **6** 

|**V3 set**|**Card indexes**|
|---|---|
|8|1,2,4|
|9|1,3,4|
|10|2,3,4|



Each triple can be formed in three pair-plus-card ways. Rather than ten separate blocks of code, Build3PairSet and Build3CardNo are compact recipe tables. Build3 runs exactly three AddCardTo2 calls for the selected triple. 

PROCEDURE Build3(SetNo:Byte); VAR I,Base: Byte; BEGIN N3 := 0; ClearHash; Base := (SetNo-1)*3; FOR I := 1 TO 3 DO AddCardTo2(Build3PairSet[Base+I],Build3CardNo[Base+I]) END; 

## **10. Duplicate elimination in V3: a tiny hash table** 

A triple can reach the same numeric value by many different expressions. Storing every duplicate would make the scratch table grow rapidly and waste search time. Add3 therefore uses a 32-bucket chained hash table to detect whether a value is already present. 

Head[0..31] stores the first entry in each bucket; Link[1..150] creates an index chain through entries that hash to the same bucket. Hash32 is simply value MOD 32, adjusted so negative values still map to 0..31. A collision is resolved by comparing the actual V3 value before deciding that an entry is a duplicate. 

This is a good Spectrum compromise: 32 bytes for Head plus 150 bytes for Link avoids a much slower linear scan through as many as 150 triple values. If N3 reaches Max3=150, SolverOverflow is set and that deal is abandoned rather than allocating more RAM. 

## **11. Compact provenance: saving a hint without a reconstruction engine** 

The shuffle solver must do more than answer yes/no: if the player later asks for the solution, the game needs the arithmetic steps. A conventional dynamic-programming solver might attach a full expression tree or string to every stored value. That would be far too expensive here. 

Instead, the solver stores only compact provenance for the value that eventually wins: 

- V2Code records how each pair value was made. 

- V3Info1 packs PairSet-1 into bits 3..7 and PairIdx-1 into bits 0..2. 

- V3Info2 packs the remaining CardNo into bits 0..2, operator into bits 3..4, and a reversed-operands flag into bit 5. 

- When a winning V3 entry is found, these bytes are decoded immediately and converted into four simple solution rows. 

KRYPTO for ZX Spectrum 48K — Shuffle/Solver Technical Description    | **7** 

The final hint itself is only four arrays of four entries: SolA, SolB, SolR and SolOp. The source comment notes that the finished hint costs 28 bytes. ShowSavedSolution later prints those four rows directly. 

## **12. PrepareNeed: invert the final operation before searching** 

PrepareNeed is one of the most important speed ideas in the production solver. Suppose F is the card that will be consumed in the final arithmetic step, T is the target, and R is the result made from the other four cards. Instead of repeatedly evaluating “R op F” for every candidate R, PrepareNeed computes the small set of R values that could possibly reach T. 

|**Final equation**|**Required four-card value R**|
|---|---|
|R + F = T|R = T - F|
|R - F = T|R = T + F|
|F - R = T|R = F - T|
|R * F = T|R = T / F, only when exact|
|R / F = T|R = T * F|
|F / R = T|R = F / T, only when exact|



AddNeed removes duplicate required values. Need therefore contains at most six integers, with NeedCode preserving which final operation would be used. MatchNeed becomes a very small linear equality check. 

## **13. Building a four-card result: the two structural cases** 

Once a final card F has been chosen conceptually, the other four cards must be reduced to one R. Any binary expression over four leaves has a top split of either 1+3 or 2+2. MASK9 searches both structures. 

### **13.1 One card + one triple (Card3)** 

Card3 takes every value X in the current V3 table and combines it with an outer card C. TryResult tries the six legal arithmetic outcomes of C and X. For every result it asks MatchNeed whether that four-card result is one of the values required by the final card. 

If a match occurs, the code decodes the winning triple provenance, saves the pair step, saves the pair+card triple step, saves the outer-card+triple step, and finally saves the target-producing step. SolverFound is then set immediately. 

### **13.2 Two pairs (PairPair)** 

PairPair takes one value from each of two disjoint V2 sets. TryResult combines the two pair results and again checks the resulting four-card value against Need. On success it saves both pair rows, their combination, and the final target row. 

KRYPTO for ZX Spectrum 48K — Shuffle/Solver Technical Description    | **8** 

## **14. TryResult: the common hot path** 

TryResult centralizes the six arithmetic combinations for two intermediate values. It returns as soon as one legal result matches Need. This keeps the 1+3 and 2+2 search paths consistent and avoids duplicating the operator logic. 

IF SafeAdd(A,B,R) THEN ... IF SafeSub(A,B,R) THEN ... IF SafeSub(B,A,R) THEN ... IF SafeMul(A,B,R) THEN ... IF SafeDiv(A,B,R) THEN ... IF SafeDiv(B,A,R) THEN ... 

The order is intentional from a performance standpoint: a success stops the whole search. The solver is interested in one valid solution, not in enumerating every possible solution. 

## **15. SearchTarget: coverage with deliberate V3 reuse** 

SearchTarget is the hand-arranged schedule that determines which triple is built and which complementary cards are tested around it. The comments describe this as retaining the “first-use order from MASK9”. The important memory-saving idea is that each newly built triple is tested in both useful complement orientations before it is discarded. 

RunSet(7,0,4,4,0); RunSet(4,1,4,4,1); RunSet(2,2,4,4,2); RunSet(1,3,4,4,3); ... PrepareNeed(CardNumbers[4]); PairPair(1,8,4); PairPair(2,6,4); PairPair(3,5,4); 

For example, V3 set 7 represents cards 1,2,3. RunSet(7,0,4,4,0) builds that triple once. It first combines the triple with card 0 and treats card 4 as the final card; then it reuses exactly the same V3 table by combining the triple with card 4 and treating card 0 as the final card. No second triple build is required. 

After the relevant 1+3 forms for a final card have been searched, SearchTarget also tests the three possible 2+2 partitions of the other four cards with PairPair. The sequence is arranged so a successful deal exits as early as possible, while V3 memory remains constant. 

## **16. Worked example: 14, 18, 23, 24, 25 → 15** 

This previously important validation case is useful because it shows why arbitrary grouping matters and also maps cleanly onto the production search. One valid solution is: 

23 - 18 = 5 25 / 5  = 5 14 - 5  = 9 24 - 9  = 15 

Viewed from MASK9’s final-inversion perspective, choose 24 as the final card F and target T=15. PrepareNeed includes the case F - R = T, therefore it calculates R = F - T = 9. The job of the four-card search is now simply to find 9 from 14,18,23,25. 

A triple can make 5 from 18,23,25: first 23-18=5, then 25/5=5. Card3 then combines outer card 14 with that triple result to make 9. MatchNeed sees that 9 is exactly the required value. The four arithmetic rows are saved immediately, and SolverFound ends the search. 

KRYPTO for ZX Spectrum 48K — Shuffle/Solver Technical Description    | **9** 

## **17. What happens on an unsolvable or slow deal** 

There are three normal ways a candidate deal can fail to become the visible game: 

- SearchTarget finishes without SolverFound. 

- SolverTimeUp reaches the 150-frame limit and sets SolverAbort. 

- The single V3 table exceeds Max3=150 unique values and sets SolverOverflow. 

All three outcomes are operationally equivalent at shuffle time. ShuffleUntilSolved deals again. This is a major design simplification: the game does not need a large, slow fallback proof engine because rejecting a random deal has almost no cost to the player. 

In testing with real deck shuffles, this policy worked well: the great majority of deals were accepted within the cutoff, and the player did not perceive a meaningful delay. That practical result is more important for the finished game than maximizing the percentage of random deals retained. 

## **18. Why this design fits PASTA80 and the 48K Spectrum** 

Several choices that may look unusual on a modern machine are direct consequences of the target environment: 

|**Choice**|**Reason**|
|---|---|
|No recursion in production solver|Keeps stack demand predictable and avoids<br>recursive call overhead in a program already using<br>{$m 2048}.|
|V2 fxed arrays and one V3 scratch array|Fixed RAM use; avoids allocating/storing all subset<br>result tables simultaneously.|
|Byte indexes and packed provenance|Saves RAM and often code space where values never<br>exceed 255.|
|Max3=150 hard limit|Caps scratch memory and worst-case work; overfow<br>simply means reshufle.|
|32-bucket hash|Small memory cost for much faster duplicate<br>rejection than a full V3 linear scan.|
|Direct solution capture|Avoids a later expression-tree reconstruction engine.|
|150-frame cutof|Optimizes perceived user experience rather than<br>mathematical completion time.|
|divmod.asm|Moves exact quotient/remainder work into compact<br>Z80 machine code in a hot arithmetic path.|



KRYPTO for ZX Spectrum 48K — Shuffle/Solver Technical Description    | **10** 

## **19. Code map — procedure by** **<u>procedure</u>** 

|**Routine**|**Role**|
|---|---|
|ShufleDeck|Randomizes the 56-card deck in place.|
|DealCards|Copies the frst six shufled cards into CardNumbers.|
|SolverTimeUp|Checks elapsed Spectrum frames and latches<br>SolverAbort.|
|SafeAdd / SafeSub / SafeMul / SafeDiv|Perform legal 16-bit arithmetic without overfow;<br>SafeDiv also enforces exact integer division.|
|Make2 / Add2|Generate and deduplicate all legal values for one<br>card pair; save pair provenance.|
|Build2|Build all ten pair sets.|
|Hash32 / ClearHash / Add3|Deduplicate the current triple table using a tiny<br>chained hash.|
|AddCardTo2|Combine one pair set with the third card to generate<br>triple values.|
|Build3|Build one of the ten triple subsets into the reusable<br>V3 scratch table.|
|AddNeed / PrepareNeed / MatchNeed|Invert the fnal operation and maintain the small list<br>of required four-card values.|
|SaveRow / SavePair / SaveFinal|Convert compact provenance into the four hint rows.|
|TryResult|Try the six legal outcomes of two values and stop on a<br>Need match.|
|Card3|Search four-card 1+3 partitions.|
|RunSet|Build a triple once and test it in two complement<br>orientations.|
|PairPair|Search four-card 2+2 partitions.|
|SearchTarget|Schedule all production search cases and exit early<br>on success/abort/overfow.|
|ResetSolver / SolveCurrentDeal|Initialize one solve and run Build2 + SearchTarget.|
|ShufleUntilSolved|Repeat deal/solve until one acceptable solved deal is|



KRYPTO for ZX Spectrum 48K — Shuffle/Solver Technical Description    | **11** 

|**Routine**|**Role**<br>found.|
|---|---|



## **20. Design trade-offs and limitations** 

The production solver is intentionally not designed around the requirement “prove every random deal solvable or unsolvable before returning”. Its requirement is “produce a solved playable deal quickly”. That difference is fundamental. 

The cutoff means that “not accepted” does not necessarily mean “mathematically unsolvable”. It can mean that the search did not find a solution before the time budget expired. Likewise, Max3 is a bounded production resource. These are acceptable compromises because the input is a random shuffle and a replacement deal is free from the player’s point of view. 

The architecture also focuses on four-card results that can be matched through one final original card. It is therefore better described as the production MASK9 search architecture than as a general-purpose exhaustive enumerator of every possible five-leaf expression tree. Its suitability rests on its observed coverage, its ability to catch the previously troublesome validation cases, and—most importantly—the fact that reshuffling converts the residual hard cases into a user-invisible event. 

**Engineering principle:** For this game, correctness means never present a deal unless the solver has a legal saved solution. It does not require proving that every rejected deal is truly unsolvable. 

## **21. Why the shuffle feels immediate in the finished game** 

The final user experience comes from several optimizations working together rather than from one “magic” trick: small-subset reuse, duplicate suppression, inverse-target matching, early exit after the first solution, one scratch triple table, direct provenance, machine-code exact division, and a hard time budget with automatic reshuffle. 

The result is that the expensive question has been changed. The program no longer asks, “Can I completely classify this particular deal regardless of cost?” It asks, “Can I find and save one legal solution to this deal within a short budget?” If yes, play it. If no, silently try another shuffle. On the Spectrum this is the right question. 

## **Appendix A. Core constants and memory structures** 

DeckSize = 56; Max2 = 6; Max3 = 150; HashSize = 32; SolveLimit = 150; 

|**Structure**<br>V2[1..10,1..6]|**Purpose**<br>Unique results for each two-card subset.|
|---|---|



KRYPTO for ZX Spectrum 48K — Shuffle/Solver Technical Description    | **12** 

|**Structure**|**Purpose**|
|---|---|
|N2[1..10]|Number of stored results in each V2 set.|
|V2Code|Compact pair-operation provenance.|
|V3[1..150]|One reusable triple-result scratch table.|
|Head[0..31], Link[1..150]|Hash chains for V3 duplicate detection.|
|V3Info1, V3Info2|Packed provenance for each current V3 result.|
|Need[1..6], NeedCode[1..6]|Required four-card values for the selected fnal card.|
|SolA/SolB/SolR/SolOp|Four arithmetic rows retained for the player hint.|



## **Appendix B. Compact operation-code convention** 

|**Code**|**Meaning**|
|---|---|
|0|A + B|
|1|A - B|
|2|A * B|
|3|A / B|
|129|B - A (128 + subtraction code)|
|131|B / A (128 + division code)|



SaveRow interprets any code >=128 by swapping the operands before storing the human-readable solution row and subtracting 128 from the operator code. 

KRYPTO for ZX Spectrum 48K — Shuffle/Solver Technical Description    | **13** 

## **Appendix C. Production flow in one view** 

ShuffleUntilSolved | +-- DealCards |     +-- ShuffleDeck | +-- SolveCurrentDeal +-- ResetSolver +-- start frame timer +-- Build2 +-- SearchTarget | +-- RunSet -> Build3 -> PrepareNeed -> Card3 |                         (1 + 3 search) | +-- PrepareNeed -> PairPair (2 + 2 search) | +-- success -> save four rows -> SolverFound +-- timeout/overflow/no hit -> reject this deal If SolverFound = False: loop back and shuffle again. If SolverFound = True : show the deal to the player. 

#### **End of technical description** 

KRYPTO for ZX Spectrum 48K — Shuffle/Solver Technical Description    | **14** 

