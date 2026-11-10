#!/usr/bin/env python3
"""Compare the root collation of four references on random pairs.

The script builds random pairs of code points from the whole range and
asks each reference for the sign of its root collator. The references
are the ICU 78 library, the collate package of Go x/text, the Intl
object of Node, and the icu_collator crate of Rust. The script prints
how often the references disagree and gives examples. A disagreement
of two references is a fact of the references. The package follows the
conformance file, so the README names each disagreement that stays.

Usage: diff_coll.py [pairs]
"""
import os
import random
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ORACLE = os.path.join(HERE, "oracle")


def build_pairs(count):
    """The pairs: random code points of the whole range. A lone
    surrogate stays out, because no reference can encode one."""
    rng = random.Random(20261110)
    pairs = []
    while len(pairs) < count:
        a = rng.randrange(0x110000)
        b = rng.randrange(0x110000)
        if 0xD800 <= a <= 0xDFFF or 0xD800 <= b <= 0xDFFF:
            continue
        pairs.append((a, b))
    return pairs


def signs_of(lines, argv, cwd):
    """The signs of one reference: it reads the pairs on stdin."""
    text = "\n".join(lines) + "\n"
    out = subprocess.run(argv, input=text.encode(), cwd=cwd,
                         capture_output=True, check=True).stdout.decode()
    signs = out.split()
    if len(signs) != len(lines):
        sys.exit("the oracle returned %d signs for %d pairs"
                 % (len(signs), len(lines)))
    return [int(s) for s in signs]


def main():
    count = 50000
    if len(sys.argv) > 1:
        count = int(sys.argv[1])
    pairs = build_pairs(count)
    lines = ["%X|%X" % p for p in pairs]
    refs = [
        ("icu", signs_of(lines, ["go", "run", "main.go", "icecoll"], ORACLE)),
        ("go", signs_of(lines, ["go", "run", "main.go", "gocoll"], ORACLE)),
        ("node", signs_of(lines, ["node", "collate.mjs"], ORACLE)),
        ("rust", signs_of(lines, [os.path.join(ORACLE, "target", "release", "collate")], ORACLE)),
    ]
    names = [n for n, _ in refs]
    total = 0
    for i in range(len(refs)):
        for j in range(i + 1, len(refs)):
            na, sa = refs[i]
            nb, sb = refs[j]
            bad = [(pairs[k], sa[k], sb[k]) for k in range(count) if sa[k] != sb[k]]
            print("%s vs %s: %d of %d differ" % (na, nb, len(bad), count))
            for (a, b), x, y in bad[:10]:
                print("  %04X %04X: %s %s" % (a, b, x, y))
            total += len(bad)
    if total == 0:
        print("all four references agree on %d random pairs" % count)


if __name__ == "__main__":
    main()
