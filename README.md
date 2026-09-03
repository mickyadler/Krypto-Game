# KRYPTO for the ZX Spectrum 48K

A version of the classic **KRYPTO mathematical card game** for the **ZX
Spectrum 48K**, written in Pascal using the **PASTA80** compiler.

## The Game

KRYPTO is a mathematical card game in which five number cards and one
target card are dealt.

The objective is to use **all five number cards exactly once**, together
with addition `+`, subtraction `-`, multiplication `*`, and division
`/`, to obtain the value shown on the target card.

In this version, intermediate negative values are allowed, but division
must produce an exact integer result; fractional intermediate values are
not permitted.

The ZX Spectrum version uses graphical cards and an interactive work
area where cards can be selected, combined, and intermediate results
temporarily parked while the player constructs a solution.

------------------------------------------------------------------------

## The Two Main Challenges

Although KRYPTO looks like a relatively small game, two technical
problems became particularly important when implementing it on a 48K ZX
Spectrum.

### 1. Finding a Solvable Shuffle Quickly

A random deal is not necessarily solvable.

Therefore, before presenting a new game to the player, the program runs
a solver to determine whether the five dealt cards can produce the
target.

A straightforward exhaustive search is much too slow on a 3.5 MHz Z80.
Early versions of the solver could take many seconds, or even minutes,
on difficult or unsolvable combinations.

A considerable part of the development effort therefore went into
designing and testing a much faster solver.

The final solver uses a compact subset/pair/triple search strategy and
aggressive elimination of redundant work. A time limit is also used: if
a particular deal takes too long to prove, the program simply reshuffles
and tries another deal.

The result is that, during normal play, the solver and any necessary
reshuffling are effectively invisible to the player.

This was one of the most difficult parts of the project.

### 2. Fitting Everything into 48K

The second major problem is memory.

The game contains graphical card data, card drawing routines, the
complete game engine, the KRYPTO solver, solution reconstruction for
hints, sound effects, menus and user interface, working tables required
by the solver, and the Pascal runtime and stack.

PASTA80 generates native Z80 machine code, so compiled program size
quickly became an important constraint.

A great deal of work therefore went into reducing code size without
making the solver slower or compromising its correctness.

Examples include sharing graphics routines, replacing repeated code with
compact tables, reducing unnecessary procedure wrappers, storing the
KRYPTO deck as initialized data, and substantially reducing the size of
the sound-effect engine.

The project deliberately reserves only a 2K stack so that more of the
Spectrum's memory remains available for program code.

------------------------------------------------------------------------

## PASTA80 Build Directives

Near the beginning of the source are these directives:

``` pascal
{$l divmod.asm}
{$m 2048}
{$l BeepFX2.asm} { machine code to be used to play sound effects.}
```

They are important parts of the program.

### `{$l divmod.asm}`

`divmod.asm` is a small Z80 assembly routine used by the solver for
integer division.

The solver performs a very large number of arithmetic tests. For a
division to be legal in this version of KRYPTO, the division must have
**zero remainder**.

The assembly `DivMod` routine calculates the quotient and remainder
together, avoiding unnecessary duplicated division work. This is
particularly valuable inside the performance-critical solver.

### `{$m 2048}`

This tells PASTA80 to reserve a **2048-byte stack**.

PASTA80 normally reserves a larger stack. This program does not use
recursion and was designed to operate safely with the smaller stack.

On a 48K Spectrum, those extra bytes are extremely valuable. Reducing
the stack from 4K to 2K gives the compiled game considerably more room
while still leaving an adequate stack for this program.

### `{$l BeepFX2.asm}`

`BeepFX2.asm` contains the Z80 machine-code sound-effect player and the
sound effects used by the game.

An earlier version contained many effects that KRYPTO never used.
Because memory is precious, the sound library was reduced to contain
only the effects actually required by the game.

This change alone recovered a surprisingly significant amount of memory.

------------------------------------------------------------------------

## Development

The project was developed through extensive testing on the ZX Spectrum
48K environment, with particular attention to solver correctness, solver
execution time, and compiled code size.

Many solvable and deliberately unsolvable KRYPTO combinations were used
to verify the solver. Random deals from the real KRYPTO deck
distribution were also tested to determine whether the solver was fast
enough for use during an actual shuffle.

The guiding principle became:

> The player does not need to know that a solver is running.\
> If a deal cannot be verified quickly enough, discard it and deal
> another one.

This proved very effective in practice.

------------------------------------------------------------------------

## Credits

### Joerg Pleumann

A **very special thank you to Joerg Pleumann**, creator of **PASTA80**.

His compiler made it possible to write a substantial Pascal program for
the ZX Spectrum while still producing native Z80 code suitable for a 48K
machine.

Joerg also provided invaluable technical advice during development,
including information about PASTA80's memory and stack behaviour,
code-size considerations, division routines, and suggestions for
reducing the size of the final program.

His help and willingness to answer detailed questions about the compiler
contributed significantly to this project.

### AI Assistance

Development was also assisted by:

-   **ChatGPT (OpenAI)** --- programming assistance, solver design and
    testing, debugging, optimization, game design, and development
    discussions.
-   **Claude (Anthropic)** --- Helped developing the graphical interface, additional code analysis and optimization
    suggestions.

Both were used as development tools; all generated and suggested code
was compiled, tested, measured, and revised on the actual target
environment.

------------------------------------------------------------------------

## Target System

-   **Computer:** Sinclair ZX Spectrum 48K
-   **Language:** Pascal
-   **Compiler:** PASTA80
-   **CPU:** Z80
-   **Memory:** 48K
