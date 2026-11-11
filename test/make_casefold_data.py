#!/usr/bin/env python3
"""Make cf_cases.goose: the suite tables of the NFKC case fold.

The per code point rows come from the NFKC_CF property of
DerivedNormalizationProps.txt. A code point with no row maps to
itself, so the suite replays the listed rows only. The script also
writes strings of several code points with their fold from the ICU 78
library, because mapped characters interact and the composition runs
over the whole text. Each string folds to the same bytes as its NFKC
case fold, so the suite compares them directly.

Usage: make_casefold_data.py [ucd directory]
"""
import os
import random
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ucdlib as u


def parse_nfkc_cf():
    """The rows of the NFKC_CF property: cp -> mapped code points."""
    rows = {}
    for line in u.lines_of("DerivedNormalizationProps.txt"):
        p = [x.strip() for x in line.split(";")]
        if len(p) < 3 or p[1] != "NFKC_CF":
            continue
        rows[u.parse_range(p[0])[0]] = [int(x, 16) for x in p[2].split()]
    if len(rows) < 3000:
        u.fail("only %d NFKC_CF rows" % len(rows))
    return rows


def main():
    u.check_version()
    rows = parse_nfkc_cf()

    # The fixed strings: composition, the long expansions, dropped
    # code points, and pairs that interact. The ICU fold of each one
    # is the wanted result of nfkc_casefold.
    fixed = [
        [0x45, 0x301],          # E plus combining acute composes
        [0xDF],                 # sharp s folds to ss
        [0xAD, 0x41],           # soft hyphen drops out
        [0x130],                # I with dot keeps the combining dot
        [0xFB01],               # fi ligature
        [0x2168],               # roman numeral nine
        [0xFF21, 0x200B],       # fullwidth A and zero width space
        [0x1E9E, 0x308],        # capital sharp s plus a mark
        [0x5A, 0x315, 0x302],   # marks around the skipped one
        [0x3D2, 0x345],         # upsilon hook symbol with a mark
        [0x3392],               # square m2, a long expansion
        [0xFDFA],               # the longest expansion of the fold
    ]

    # Random strings of listed code points, so the replay covers
    # interaction on hostile shaped input too.
    rng = random.Random(20261111)
    listed = sorted(rows)
    rand = []
    for _ in range(400):
        n = rng.randrange(1, 6)
        rand.append([rng.choice(listed) for _ in range(n)])

    texts = fixed + rand
    lines = [" ".join("%X" % c for c in t) for t in texts]
    folds = u.oracle_go("icefold", stdin="\n".join(lines) + "\n")
    if len(folds) != len(lines):
        u.fail("the ICU oracle returned %d folds for %d texts" % (len(folds), len(lines)))
    pool = []
    off = [0]
    for f in folds:
        cps = [int(x, 16) for x in f.split()]
        pool += cps
        off.append(len(pool))

    # The per code point table: only the listed rows.
    cp = sorted(rows)
    for c in cp:
        pool += rows[c]
        off.append(len(pool))

    suite = [
        u.array("CF_FIXED_OFF", off[:len(texts) + 1],
                "The end of each fixed text in CF_POOL."),
        u.array("CF_POOL", pool, "The code points of the fixed folds and of the row folds."),
        u.array("CF_ROW_OFF", off[len(texts):],
                "The end of the fold of each listed row in CF_POOL."),
        u.array("CF_CP", cp, "The code point of each listed row, sorted."),
    ]
    u.write_goose(os.path.join(u.ROOT, "test", "suite", "cf_cases.goose"),
                  "make_casefold_data.py", suite, "suite")
    print("cf_cases.goose: %d rows, %d strings" % (len(cp), len(texts)))


if __name__ == "__main__":
    main()
