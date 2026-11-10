#!/usr/bin/env python3
"""Compare the width of ordered pairs and triples: the Rust crate against
the package.

The random texts of diff_width.py rarely form the ordered pairs that the
script ligature rules need. This script walks every ordered pair and every
ordered triple of a small script alphabet.

Usage: diff_pairs.py [cjk]   (cjk: the East Asian context form)
"""
import itertools
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
RS = os.path.join(HERE, "oracle", "target", "release", "width")
CJK = "cjk" in sys.argv[1:]
MODE_ORACLE = "cstr" if CJK else "str"
FN = "string_width_cjk" if CJK else "string_width"

# The characters of the script ligature rules, the transparent marks and
# a few plain ones.
ALPHA = [
    0x644, 0x6B5, 0x6B6, 0x6B7, 0x6B8, 0x76A, 0x8A6, 0x8C7,   # lam
    0x622, 0x623, 0x625, 0x627, 0x671, 0x675, 0x873,          # alef
    0x5D0, 0x5DC, 0x200D,                                       # hebrew
    0x1780, 0x1783, 0x1789, 0x17A0, 0x17A2, 0x17AF, 0x17D2,   # khmer
    0x1A10, 0x1A15, 0x1A17,                                    # buginese
    0x2D31, 0x2D65, 0x2D6F, 0x2D7F,                           # tifinagh
    0xA4F8, 0xA4FB, 0xA4FC, 0xA4FD,                           # lisu
    0x10C03, 0x10C32,                                          # old turkic
    0x16D63, 0x16D67, 0x16D68, 0x16D69,                        # kirat rai
    0x34F, 0x17B4, 0x180B, 0x180F, 0xE0100, 0xFE0F, 0xFE0E,    # marks
    0x338, 0x3C, 0x3D, 0x3E, 0x301, 0x64B, 0xFE00, 0xFE02, 0x201C, 0xA1,  # solidus, ambiguous
    0x41, 0x20,                                                # plain
]


def main():
    texts = []
    for a, b in itertools.product(ALPHA, repeat=2):
        texts.append([a, b])
    for a, b, c in itertools.product(ALPHA[:24] + ALPHA[-12:], repeat=3):
        texts.append([a, b, c])

    bodies = [" ".join("%X" % cp for cp in t) for t in texts]
    r = subprocess.run([RS, MODE_ORACLE], input="\n".join(bodies) + "\n",
                       capture_output=True, text=True)
    if r.returncode != 0:
        print("FAIL: the oracle failed: " + r.stderr[:400], file=sys.stderr)
        sys.exit(1)
    want = [int(x) for x in r.stdout.split()]

    scratch = os.path.join(ROOT, "..", "..", "tmp", "diff_pairs.goose")
    with open(scratch, "w") as f:
        f.write("// Scratch program for the width compare.\n")
        f.write("import std;\n")
        f.write("import unicode from \"../packages/goose-unicode\";\n")
        f.write("fn tw(cps: const i64[:]) -> i64 {\n")
        f.write("    var b: u8[>..] = [];\n")
        f.write("    for k in 0..cps.len { unicode::utf8_encode(b, cps[k]); }\n")
        f.write("    let code, w = unicode::" + FN + "(b[..]);\n")
        f.write("    return w;\n}\n")
        f.write("fn main() {\n")
        for b in bodies:
            nums = ", ".join(str(int(x, 16)) for x in b.split(" "))
            f.write("    print(tw([%s]), \"\\n\");\n" % nums)
        f.write("    return 0;\n}\n")
    r = subprocess.run(["goose", "run", scratch], cwd=ROOT,
                       capture_output=True, text=True)
    if r.returncode != 0:
        print("FAIL: the package did not run: " + r.stderr[-600:], file=sys.stderr)
        sys.exit(1)
    got = [int(x) for x in r.stdout.split()]

    bad = 0
    for t, w, g in zip(texts, want, got):
        if w != g:
            bad += 1
            if bad <= 40:
                print("U+%s: crate %d, package %d" % (
                    " U+".join("%04X" % c for c in t), w, g))
    print("differing texts: %d of %d" % (bad, len(texts)))


main()
