# KRYPTO for ZX Spectrum 48K Baseline Version History 

_Development record – prepared September 2026_ 

## **Purpose** 

This document records the important versions that became working baselines during development of KRYPTO for the ZX Spectrum 48K. It is intended as a future memory aid: what each baseline established, why it replaced the previous one, and which experiments were deliberately rejected. 

## **1. Solver baselines** 

### **FAST1 – first proven fast baseline** 

**What changed:** The early five-card solver established that a practical solver could run on a 48K Spectrum. It passed the original 17 benchmark tests and became the reference for speed. 

**Why it became a baseline:** It was kept because difficult unsolvable cases were around six seconds rather than minutes. However, later validation showed that its search model was incomplete for the actual graphical game. 

### **FAST1.6 – frozen FAST1 baseline** 

**What changed:** A sequence of modest FAST1.1–FAST1.6 optimizations improved timing without changing the basic architecture. FAST1.6 became the frozen fast baseline; worst benchmark timings were roughly 3–4 seconds. 

**Why it became a baseline:** A new 100-case validation set exposed two legal solutions FAST1.6 missed: 14,18,23,24,25 -> 15 and 10,17,20,21,23 -> 1. This proved that a merely fast left-to-right/restricted search could not be the final production solver because the game permits arbitrary pairwise grouping. 

### **FAST2.1 – correctness/reduction proof** 

**What changed:** FAST2 changed to the true game model: repeatedly combine any two currently available values. FAST2.1 added reduction rules and demonstrated that the previously missed cases could be found correctly. 

**Why it became a baseline:** This was an important correctness baseline, but the complete reduction search could still be much too slow on hard or unsolvable deals, so it was not suitable as the production shuffle validator. 

### **MASK9 – production solver architecture** 

**What changed:** MASK9 introduced the compact subset/pair/triple search used by the game: precomputed two-card values, three-card values with a small hash structure, inverse target search, duplicate elimination, and saved reconstruction information. 

**Why it became a baseline:** It became the production solver because it balanced completeness for the game's required grouping patterns, speed, and memory. Earlier MASK2/3/5/6/7/8 and several recursion/cache experiments were rejected because they were slower, larger, or less reliable. 

### **MASK9 with 150-frame cutoff – production deal policy** 

**What changed:** The solver was integrated into the shuffle loop with a 150 Spectrum-frame cutoff (about three seconds). If a deal is not proved quickly, the game simply reshuffles. A 1000-deal run accepted 972 deals within the cutoff (97.2%); only 2.8% required another shuffle. 

**Why it became a baseline:** This turned solver worst-case time into a controlled gameplay cost. Long realplay testing later showed that solver/reshuffle delay was effectively unnoticeable to the player. 

### **MASK9 solution reconstruction fix – current frozen solver** 

**What changed:** A displayed-solution bug was found with 10,20,9,8,16 -> 6. The arithmetic search was correct, but Card3 overwrote the operator code for the outer row while reconstructing an inner V3 row. The fix preserves it as OuterCode before decoding the inner operation. 

**Why it became a baseline:** This was frozen only after an independent 1000-solved-deal validator replayed every displayed four-row solution as a multiset reduction and reported ALL 1000 SAVED SOLUTIONS OK (1020 deals attempted). This is the current trusted solver baseline. 

## **2. Graphical game and memory baselines** 

### **ShowCard / MASK9 integration** 

**What changed:** The production solver was joined to the graphical card game: six 32x48 cards, raised target card, colour ranges, work area, parking, used-card monochrome display, dealing/flip animation, and solution capture. 

**Why it became a baseline:** This established the real game architecture rather than a solver test harness. 

### **ShowCard45 – first return to a 2K-stack-compatible memory boundary** 

**What changed:** After several size reductions, ShowCard45 compiled to about 30,720 bytes ($F7FF), crossing back under the important 2K-stack boundary. 

**Why it became a baseline:** The project could again retain {$m 2048}, the preferred stack size, instead of depending on a 1K stack. 

### **Trimmed BeepFX baseline** 

**What changed:** The sound library was reduced to only the effects actually used by KRYPTO and the effects were remapped to a compact 0..7 table. This saved about 1,835 bytes. 

**Why it became a baseline:** This was the single largest low-risk space saving and restored substantial headroom while preserving sound. 

### **ShowCard46 – typed deck baseline** 

**What changed:** CreateDeck was removed and the 56-card KRYPTO deck became initialized typed data. Compiled size dropped by about 569 bytes. 

**Why it became a baseline:** The deck is fixed data, so generating it procedurally was unnecessary code. 

### **ShowCard47 – table-driven Build3** 

**What changed:** Ten repeated Build3 IF blocks were replaced by compact table data and a small loop, saving about 425 bytes. 

**Why it became a baseline:** It preserved solver behavior while reducing duplicated code. 

### **ShowCard48 – table-driven symbol drawing** 

**What changed:** DrawOperatorSymbol and DrawEqualsSymbol were consolidated into table-driven symbol drawing, saving about 416 bytes. 

**Why it became a baseline:** It removed duplicated graphics code without changing gameplay. 

### **Rev. 1.0 functional baseline** 

**What changed:** The main menu, instructions, About screen, focus indicators, final sound mapping, correct/wrong flow, restart/reshuffle/main-menu behavior and 2K stack were all integrated. The game was considered functionally complete. 

**Why it became a baseline:** At this point optimization was deliberately frozen unless memory became necessary; gameplay stability became the priority. 

## **3. Final control-flow baselines** 

### **Undo experiment – rejected** 

**What changed:** Several increasingly compact U/Undo versions were implemented and tested; the smallest fitted comfortably. 

**Why it became a baseline:** Undo was abandoned for a design reason rather than a technical failure: repeatedly undoing mistakes made it less likely that the player would ever reach WRONG and see the game's solution. 

### **Krypto1_0_GIVE_UP_COMPACT – accepted Give Up baseline** 

**What changed:** Undo was replaced by G = Give Up / solution. G becomes available only after the first calculation. Pressing G abandons the attempt, displays the saved solution, and then offers R, D, E. A wrong final answer also displays the solution automatically. V was removed. 

**Why it became a baseline:** This better matched the intended game flow and used a compact shared SolutionEndMenu instead of duplicated menus. 

### **Krypto1_0_GIVE_UP_ENTER2 – ENTER control baseline** 

**What changed:** The calculation command changed from '=' to the ENTER key, shown in the UI as ENT. The built-in instructions were updated accordingly. 

**Why it became a baseline:** This separates the player's calculate command from the large graphical '=' symbol that appears beside a locked result. 

### **Krypto1_0_GIVE_UP_ENTER3_FIX_SOLUTION – current code baseline** 

**What changed:** ENTER behavior was retained and the Card3 OuterCode solution-reconstruction fix was applied. 

**Why it became a baseline:** After the 1000-solution reconstruction validation, this became the current trusted gameplay/solver source baseline. Only small UI presentation changes, such as positioning/colour of G in the command legend, should be made without reopening the solver. 

## **4. Current control model** 

O/P move the upper selection or swap lower operands; S selects/moves a card or parks/recalls a value; C changes focus area; Q/A changes the operator; ENTER (shown as ENT) calculates; D redoes the same deal; R reshuffles; E returns to the main menu; G gives up and shows the saved solution after the first calculation. 

The mathematical '=' remains a graphical result indicator. It is not the calculation key. 

## **5. Important lessons preserved by the baselines** 

- Correct game modelling mattered more than raw speed: arbitrary pairwise expression trees are legal. 

- Correctness had to include solution reconstruction, not merely finding the target value. 

- A bounded production solver plus reshuffle is better gameplay engineering than exhaustive proof on every deal. 

- On PASTA80, algorithmic simplification and removal of duplicated code produced larger gains than risky micro-optimization. 

- The 2K stack ({$m 2048}) is part of the preferred production configuration. 

- Once a version is proven, changes should be isolated and tested one at a time. 

## **6. Files worth preserving** 

- Krypto1_0_GIVE_UP_ENTER3_FIX_SOLUTION.pas – current validated game/solver baseline. 

- Krypto_Solution_Validator_1000.pas – independent saved-solution reconstruction validator. 

- BeepFX2_KRYPTO_Rev1.asm – cleaned/commented eight-effect sound library. 

- Krypto_User_Manual_FINAL_CHECKED.md – checked user manual. 

- README_FINAL_CHECKED.md – checked project README. 

_This history records the development checkpoints known from the project conversations. Intermediate experimental filenames that never became accepted baselines are intentionally summarized rather than exhaustively listed._ 

