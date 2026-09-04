"""Real 52-card poker primitives: cards, a 5-card hand evaluator, and
range-notation parsing shared with the Flutter app's data. Used by
`cfr_solver/games/flop_subgame.py` to solve a real (not toy) heads-up
postflop spot — everything in this package is genuinely new complexity
compared to the 3-6 card decks in `games/kuhn.py` / `games/leduc.py`.
"""
