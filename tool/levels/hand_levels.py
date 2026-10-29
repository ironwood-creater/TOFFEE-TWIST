#!/usr/bin/env python3
"""Hand-designed tutorial levels 1-30 for Toffee Twist.

Run:  python3 tool/levels/hand_levels.py
It writes assets/levels/level_0001.json ... level_0030.json with placeholder
moves/stars; then `dart run tool/build_levels.dart tune-hand` sets moves and
star scores from 50 bot plays per level (target win rates are in that tool).

Board legend: . cell  # hole  c caramel  C double caramel  1/2/3 crate  n nut
Preset sweets: t toffee  k cupcake  d donut  m macaron  l lollipop  h chocolate
Preset specials: - striped row  | striped column  b Sweet Box  s Toffee Swirl
"""
import json, os, re

ROOT = os.path.join(os.path.dirname(__file__), '..', '..', 'assets', 'levels')

T, K, D, M, L, H = 'toffee', 'cupcake', 'donut', 'macaron', 'lollipop', 'chocolate'
C4 = [T, K, D, M]
C5 = [T, K, D, M, L]
C6 = [T, K, D, M, L, H]

def full(rows, cols):
    return ['.' * cols for _ in range(rows)]

def shape(*rows):
    return list(rows)

def overlay(board, marks):
    """marks: list of (row, col, char)."""
    b = [list(r) for r in board]
    for r, c, ch in marks:
        if b[r][c] == '#':
            continue
        b[r][c] = ch
    return [''.join(r) for r in b]

def rect(r0, c0, r1, c1, ch):
    return [(r, c, ch) for r in range(r0, r1 + 1) for c in range(c0, c1 + 1)]

def blank(rows, cols):
    return ['.' * cols for _ in range(rows)]

def with_rows(base, rows):
    """Replace specific rows of a preset: rows = {index: 'string'}."""
    out = list(base)
    for i, s in rows.items():
        out[i] = s
    return out

def score(n): return {'type': 'score', 'target': n}
def collect(s, n): return {'type': 'collect', 'sweet': s, 'count': n}
def caramel(): return {'type': 'caramel'}
def crates(): return {'type': 'crates'}
def nuts(n, max_on=1): return {'type': 'nuts', 'count': n, 'maxOnBoard': max_on}

def tut(i, title, text): return {'id': i, 'title': title, 'text': text}

CORNERS7 = shape('#.....#', '.......', '.......', '.......', '.......', '.......', '#.....#')
CORNERS8 = shape('#......#', '........', '........', '........', '........', '........', '........', '#......#')
CORNERS9 = shape('#.......#', *(['.........'] * 7), '#.......#')
ROUND9 = shape('##.....##', '#.......#', *(['.........'] * 5), '#.......#', '##.....##')
DIAMOND9 = shape('###...###', '##.....##', '#.......#', '.........', '.........', '.........',
                 '#.......#', '##.....##', '###...###')
HOURGLASS9 = shape('.........', '.........', '#.......#', '##.....##', '###...###',
                   '##.....##', '#.......#', '.........', '.........')
PILLARS9 = shape('.........', '.........', '.........', '..#...#..', '..#...#..', '..#...#..',
                 '.........', '.........', '.........')
PLUS9 = shape('##.....##', '##.....##', *(['.........'] * 5), '##.....##', '##.....##')
HEART9 = shape('#..###..#', '.........', '.........', '.........', '#.......#',
               '##.....##', '###...###', '####.####')
HEX9 = shape('##.....##', '#.......#', '.........', '.........', '.........', '.........',
             '.........', '#.......#', '##.....##')

LEVELS = []

def level(i, board, colors, goals, kind='tutorial', tutorial=None, preset=None, specials=None):
    d = {'id': i, 'kind': kind, 'moves': 30, 'sweets': colors, 'goals': goals,
         'stars': [1000, 2000, 3000], 'board': board}
    if preset: d['preset'] = preset
    if specials: d['presetSpecials'] = specials
    if tutorial: d['tutorial'] = tutorial
    LEVELS.append(d)

# 1 - first matches
level(1, CORNERS7, C4, [score(8000)],
      tutorial=tut('match3', 'Welcome to Toffee Twist!',
                   'Swipe a sweet to swap it with its neighbour. Line up 3 or more of the same sweet to clear them!'),
      preset=with_rows(blank(7, 7), {2: '....d..', 3: '..ddt..'}))
# 2 - collect goal
level(2, full(7, 7), C4, [collect(D, 30)],
      tutorial=tut('collect', 'Level goals', 'Goals are shown at the top. Collect the sweets shown before you run out of moves!'))
# 3 - two goals
level(3, full(8, 7), C4, [collect(K, 45), collect(M, 45)])
# 4 - striped toffee
level(4, full(8, 8), C4, [collect(T, 60)],
      tutorial=tut('striped', 'Striped Toffee', 'Match 4 in a line to make a Striped Toffee. Match it again to clear a whole row or column!'),
      preset=with_rows(blank(8, 8), {4: '..ttkt..', 5: '....t...'}))
# 5 - fifth sweet
level(5, CORNERS8, C5, [score(8000), collect(L, 25)])
# 6 - sweet box
level(6, full(8, 8), C4, [collect(D, 60)],
      tutorial=tut('box', 'Sweet Box', 'Match sweets in an L or T shape to make a Sweet Box. It explodes twice!'),
      preset=with_rows(blank(8, 8), {2: '....d...', 3: '..ddm...', 4: '....d...', 5: '....d...'}))
# 7 - three collect goals on a rounded board
level(7, ROUND9, C5, [collect(T, 25), collect(K, 25), collect(M, 25)])
# 8 - toffee swirl
level(8, full(8, 8), C5, [score(12000)],
      tutorial=tut('swirl', 'Toffee Swirl', 'Match 5 in a line to make a Toffee Swirl. Swap it with any sweet to clear every sweet of that kind!'),
      preset=with_rows(blank(8, 8), {3: '...l....', 4: '.lltll..'}))
# 9 - combos
level(9, CORNERS8, C5, [collect(L, 35), collect(D, 35)],
      tutorial=tut('combo', 'Super combos', 'Swap two special sweets together for a giant combo. Try it with these two Striped Toffees!'),
      preset=with_rows(blank(8, 8), {4: '...tk...'}),
      specials=with_rows(blank(8, 8), {4: '...-|...'}))
# 10 - caramel
level(10, full(8, 8), C4, [caramel(), collect(T, 25)],
      tutorial=tut('caramel', 'Caramel tiles', 'Caramel hides under some sweets. Make matches on top of it to clear it!'),
      kind='tutorial')
LEVELS[-1]['board'] = overlay(full(8, 8), rect(1, 1, 6, 6, 'c'))
# 11 - caramel cross + collect
level(11, overlay(CORNERS9, rect(4, 0, 4, 8, 'c') + rect(0, 4, 8, 4, 'c') + rect(3, 3, 5, 5, 'c')), C5,
      [caramel(), collect(M, 25)])
# 12 - boosters
level(12, full(9, 9), C5, [collect(T, 40), collect(D, 40)],
      tutorial=tut('boosters', 'Boosters', 'Stuck? Tap the Rolling Pin to smash one piece, or Free Swap to swap any two neighbours. They use no moves!'))
# 13 - crates
level(13, overlay(full(8, 8), rect(3, 1, 3, 6, '1') + rect(5, 1, 5, 6, '1')), C5, [crates(), collect(K, 20)],
      tutorial=tut('crate', 'Wooden crates', 'Crates block the way. Make matches right next to them to break them!'))
# 14 - crate corners + collect
level(14, overlay(ROUND9, rect(2, 1, 3, 2, '1') + rect(2, 6, 3, 7, '1') + rect(6, 3, 6, 5, '1')), C5,
      [crates(), collect(K, 35)])
# 15 - caramel and crates
level(15, overlay(overlay(full(9, 9), rect(0, 0, 0, 8, 'c') + rect(8, 0, 8, 8, 'c') + rect(0, 0, 8, 0, 'c') + rect(0, 8, 8, 8, 'c')),
                  rect(4, 3, 4, 5, '1')), C5, [caramel(), crates()])
# 16 - golden nuts
level(16, overlay(full(8, 8), [(0, 2, 'n'), (0, 5, 'n')]), C5, [nuts(2, 2)],
      tutorial=tut('nut', 'Golden nuts', 'Bring the golden nuts down to the bottom row. Clear the sweets underneath them!'))
# 17 - nuts + collect
level(17, overlay(CORNERS9, [(1, 2, 'n'), (1, 6, 'n')]), C5, [nuts(2, 2), collect(L, 18)])
# 18 - board shapes
level(18, DIAMOND9, C5, [collect(D, 35), collect(M, 35)],
      tutorial=tut('shape', 'All shapes and sizes', 'Boards come in many shapes. Sweets fall straight through the gaps to fill empty cells.'))
# 19 - double caramel
level(19, overlay(overlay(full(9, 9), rect(1, 1, 7, 7, 'c')), rect(3, 3, 5, 5, 'C')), C5, [caramel()],
      tutorial=tut('caramel2', 'Dark caramel', 'Dark caramel has two layers - it needs two matches on top to clear.'))
# 20 - first tough level
level(20, overlay(overlay(HOURGLASS9, rect(0, 0, 1, 8, 'c') + rect(7, 0, 8, 8, 'c')), rect(4, 3, 4, 5, '3')),
      C5, [caramel(), crates()], kind='hard')
# 21 - relief
level(21, full(8, 8), C4, [score(30000)], kind='relief')
# 22 - sturdy crates
level(22, overlay(PILLARS9, [(2, 2, '2'), (2, 6, '2'), (6, 2, '2'), (6, 6, '2'), (4, 4, '3')]), C5,
      [crates(), collect(T, 30)],
      tutorial=tut('crate3', 'Sturdy crates', 'Some crates need 2 or 3 hits. Each nearby match knocks off one brace.'))
# 23 - nuts on a shaped board
level(23, overlay(PILLARS9, [(0, 1, 'n'), (0, 7, 'n')]), C5, [nuts(2, 2)])
# 24 - swirl combos
level(24, full(9, 9), C5, [score(18000), collect(K, 45)],
      tutorial=tut('combo2', 'Swirl power', 'Swap a Toffee Swirl with a Striped Toffee: every sweet of that kind turns striped and fires!'),
      preset=with_rows(blank(9, 9), {4: '....k....'}),
      specials=with_rows(blank(9, 9), {4: '...s-....'}))
# 25 - six sweets
level(25, HEX9, C6, [score(6000)],
      tutorial=tut('six', 'Six sweets', 'All six sweets are here now, so matches are harder to find. Make specials whenever you can!'))
# 26 - double caramel + nuts
level(26, overlay(overlay(CORNERS9, rect(5, 1, 7, 7, 'c')), rect(6, 3, 7, 5, 'C') + [(0, 4, 'n')]), C5,
      [caramel(), nuts(2, 1)])
# 27 - heart with crates and caramel
level(27, overlay(overlay(HEART9, rect(1, 1, 3, 7, 'c')), [(4, 3, '1'), (4, 5, '1'), (5, 4, '2')]), C5,
      [caramel(), crates(), collect(D, 30)])
# 28 - nuts and crates
level(28, overlay(PLUS9, [(3, 0, '1'), (3, 8, '1'), (5, 0, '1'), (5, 8, '1'), (0, 3, 'n'), (0, 5, 'n')]), C5,
      [nuts(3, 2), crates()])
# 29 - caramel everywhere with six sweets
level(29, overlay(ROUND9, rect(0, 0, 8, 8, 'c')), C5, [caramel()])
# 30 - end-of-tutorial challenge
level(30, overlay(overlay(overlay(full(9, 9), rect(6, 0, 8, 8, 'c')), rect(7, 2, 8, 6, 'C')),
                  [(3, 1, '2'), (3, 7, '2'), (3, 4, '3'), (0, 4, 'n')]), C5,
      [caramel(), crates(), nuts(2, 1)], kind='hard')


def pretty(d):
    text = json.dumps(d, indent=2)
    # board / preset rows: one per line, already the case; compact the stars list
    text = re.sub(r'\[\n\s+(\d+),\n\s+(\d+),\n\s+(\d+)\n\s+\]', r'[\1, \2, \3]', text)
    text = re.sub(r'"sweets": \[\n([^\]]*)\]',
                  lambda m: '"sweets": [' + ', '.join(x.strip().rstrip(',') for x in m.group(1).split('\n') if x.strip()) + ']',
                  text)
    return text + '\n'


def main():
    for d in LEVELS:
        rows = len(d['board'])
        cols = len(d['board'][0])
        assert all(len(r) == cols for r in d['board']), d['id']
        for layer in ('preset', 'presetSpecials'):
            if layer in d:
                assert len(d[layer]) == rows and all(len(r) == cols for r in d[layer]), (d['id'], layer)
        path = os.path.join(ROOT, 'level_%04d.json' % d['id'])
        # Keep tuned moves/stars when the file already exists.
        if os.path.exists(path):
            old = json.load(open(path))
            d['moves'] = old.get('moves', d['moves'])
            d['stars'] = old.get('stars', d['stars'])
        with open(path, 'w') as f:
            f.write(pretty(d))
    print('wrote %d levels' % len(LEVELS))


if __name__ == '__main__':
    main()
