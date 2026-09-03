# KRYPTO — User Manual

## What is Krypto?

Krypto is a mental-math puzzle. You're dealt **six cards**: five playable cards and one **target card**. Your job is to combine the five playable cards — using addition, subtraction, multiplication, and division, in any order and combination — so the final result equals the target card's number.

Every deal in this game is **guaranteed to have a solution** — the game shuffles behind the scenes until it finds a solvable deal before showing you the cards, so you can always find a way through.

---

## Getting Started

When the game begins, you'll see six cards lying face down with a `KRYPTO` banner above them, and a prompt reading `Press any key...`.

Press any key to flip the cards face up. You'll see:

- **Five playable cards** on the left, each showing a number from 1–25.
- **One target card** on the far right, sitting slightly higher than the others — this is the number you're trying to reach. It can never be selected or used directly; it's your goal, not a piece to play.

The leftmost playable card starts **selected**, shown with a red frame around it.

---

## Controls

The bottom two lines of the screen always show a **live key legend** — it updates automatically to list only the keys that actually do something at your current stage, so you never have to guess what's available.

| Key | Action |
|---|---|
| **O** | Move selection left (upper row) / swap operands (lower row) |
| **P** | Move selection right (upper row) / swap operands (lower row) |
| **C** | Switch focus between the card row (top) and the working area (bottom) |
| **S** | Pick up the selected card / park or recall a value (see below) |
| **Q** | Cycle the operator forward: `+` → `−` → `×` → `÷` |
| **A** | Cycle the operator backward |
| **=** | Calculate the result |
| **D** | Restart the current deal — available as soon as you've picked up your first card |
| **R** | Reshuffle for a brand new deal — available at any time, mid-puzzle or not |
| **E** | Exit — available at any time |

Letters work in either upper or lower case.

A **solid vertical line** on the left edge of the screen tells you which half of the screen your controls currently affect:
- **Blue**, upper half — you're controlling the card row.
- **Red**, lower half — you're controlling the working area below.

Press **C** to switch between them at any time.

---

## How to Play

### 1. Pick up a card

With focus on the card row (blue line), use **O** / **P** to move the red selection frame across your five cards, then press **S** to pick one up. It drops into the working area at the bottom of the screen, and the card above turns **black and white** to show it's been used.

### 2. Pick a second card

Move to another unused card and press **S** again. It appears in a second slot next to the first, with an operator symbol (starting with `+`) shown between them.

### 3. Switch focus and choose your operator

Press **C** to switch focus down to the working area (the line on the left turns **red**). **Q** and **A** only respond while you're focused here — pressing them with the blue line showing (focus still on the card row) does nothing.

With focus on the working area, press **Q** or **A** to cycle through `+`, `−`, `×`, `÷` until you see the one you want.

> **Tip:** while still focused on the working area, press **O** or **P** to swap which card is on the left and which is on the right — useful for subtraction and division, where order matters.

### 4. Calculate

Still with focus on the working area (red line), press **=**. The two cards combine into a single result, shown in the left slot. A large `=` symbol appears next to it as a reminder that this value is locked in — it disappears as soon as you take any other action.

- If you still have cards left to use, the result appears in a **small font, bright blue/magenta** — this marks it as a mid-calculation value rather than an original card.
- If that was your **last card**, the result appears large, in the same bright color — this is your final answer, automatically checked against the target.

### 5. Keep combining

Pick up another card the same way, pair it with your running result, choose an operator, and press **=** again. Repeat until all five cards are used.

---

## The Parking Area

To the right of your two working slots is a dimmed grey box — the **parking area**. This lets you set a value aside temporarily so you can work on something else first.

With focus on the working area (**C** to switch, red line):

- Press **S** to send your current result into parking.
- Press **S** again later to bring it back — it returns into whichever slot is open, ready to pair with your next card.

This is essential for problems where you need to compute two things separately before combining them — for example, working out `(13 + 14 + 8)` on its own, then separately `(17 − 12)`, before finally dividing one by the other.

---

## Winning and Losing

Once your final result appears, the game checks it against the target card automatically. After showing the outcome, it will prompt `Press any key...` — press one to continue to your options:

- **`*** CORRECT ***`** — you solved it! You'll then be offered:
  - **D** — replay this exact same deal (handy for trying a different route to the same answer).
  - **R** — reshuffle for a brand new deal.
  - **E** — quit.
- **`*** WRONG ***`** — the result didn't match. You'll then be offered:
  - **V** — view a worked solution for this exact deal.
  - **D** — restart this same deal from scratch and try again.
  - **R** — reshuffle for a brand new deal.
  - **E** — quit.

---

## Reading the Cards

Each card's number is colored by size, as a quick visual guide:

| Range | Color |
|---|---|
| 1–10 | Black |
| 11–17 | Red |
| 18–25 | Cyan |

This coloring only applies to your five original playable cards — calculated results are always shown in bright blue/magenta, so you can tell at a glance whether a number is an original card or something you've computed.

---

## Quick Reference

Not sure what a key does right now? Check the bottom of the screen — the legend there always shows exactly what's currently active.

1. **O/P** — move / swap
2. **C** — switch top ↔ bottom
3. **S** — pick up a card, or park/recall a value
4. **Q/A** — choose operator
5. **=** — calculate
6. **D** — restart this deal (once you've picked up a card)
7. **R** — reshuffle for a new deal, any time
8. **E** — quit, any time

Good luck, and happy solving!
