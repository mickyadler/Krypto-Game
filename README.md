# Krypto-Game

This project is an implementation of the famous 70's card puzzle game (https://en.wikipedia.org/wiki/Krypto_(game)).
The game is developed in two separate sessions, an engines program that does a. random shuflling of the cards according to the rules. b. calculate a solution, if there is non shuffle again. c. Present a solution on screen. The second session is the man-machine interface that uses graphics, sound and animation.

The project is being developed in Pascal using PASTA80 with the assistance of ChatGpt and Claude AI with much assistance from Joerg Pleumann PASTA80 developer.
MASK9R1000.pas is the final solver, it takes an average of 1 second to solve, there are a few cases  that take longer including the unsolvable ones. For the game we will cut them off and reshuffle. 
What this says about a 3-second cutoff
If we stop at 150 frames and reshuffle, then in this run:
972 of 1000 deals would have been accepted within 3 seconds.
The rejected deals would have been the 27 slow-but-solvable deals plus the one unsolvable deal.
So the immediate acceptance probability is approximately:
97.2%
That's excellent for the game. On average, only about 1 in 36 shuffles would need another shuffle.
And because a reshuffle gives another independent-looking deal, the chance of needing two consecutive reshuffles would be roughly:
2.8% × 2.8% ≈ 0.08% or around 1 in 1,275 games.
