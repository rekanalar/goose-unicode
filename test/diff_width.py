#!/usr/bin/env python3
"""Compare the width of many texts: the Rust crate against the package.

The script writes a list of texts as hex code points, asks the Rust
oracle for the width of each, and asks the package for the width of each
by running one Goose program over the same list. It prints the texts
that differ.

Usage: diff_width.py [count]
"""
import os
import random
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
RS = os.path.join(HERE, "oracle", "target", "release", "width")
CJK = "cjk" in sys.argv[1:]
MODE_ORACLE = "cstr" if CJK else "str"
FN = "string_width_cjk" if CJK else "string_width"

# The characters of the rules that the crate applies.
ALPHABET = []
# The emoji presentation bases and the text style bases.
ALPHABET += list(range(0x1F300, 0x1F600))
ALPHABET += list(range(0x1F600, 0x1F700))
ALPHABET += list(range(0x1F900, 0x1FB00))
ALPHABET += list(range(0x2600, 0x27C0))
ALPHABET += list(range(0x2B00, 0x2C00))
ALPHABET += [0x2764, 0x00A9, 0x00AE, 0x203C, 0x2049, 0x2122, 0x2139, 0x3030,
             0x303D, 0x3297, 0x3299, 0x0023, 0x002A, 0x0030, 0x0031, 0x0032]
# The variation selectors, the joiner and the keycap.
ALPHABET += list(range(0xFE00, 0xFE10))
ALPHABET += list(range(0xE0100, 0xE0120))
ALPHABET += [0x200D, 0x20E3]
# The quotation marks and the digits.
ALPHABET += [0x2018, 0x2019, 0x201C, 0x201D, 0x30, 0x31, 0x32, 0x39, 0x23, 0x2A]
# The regional indicators and the emoji modifiers.
ALPHABET += list(range(0x1F1E6, 0x1F200))
ALPHABET += list(range(0x1F3FB, 0x1F400))
# The tag characters.
ALPHABET += list(range(0xE0020, 0xE0080))
# The scripts of the ligature rules.
ALPHABET += [0x644, 0x6B5, 0x6B6, 0x6B7, 0x6B8, 0x76A, 0x8A6, 0x8C7,
             0x622, 0x623, 0x625, 0x627, 0x5D0, 0x5DC, 0x200D,
             0x1780, 0x17D2, 0x17A4, 0x1A10, 0x1A15, 0x1A17,
             0x2D31, 0x2D65, 0x2D6F, 0x2D7F, 0xA4FC, 0xA4FD, 0xA4F8,
             0x10C03, 0x10C32, 0x16D63, 0x16D67, 0x16D68, 0x16D69]
# A small alphabet of the ligature characters, for dense texts.
SCRIPT = [0x644, 0x6B5, 0x76A, 0x8C7, 0x622, 0x627, 0x64B, 0x670, 0x200D,
          0xFE0F, 0xFE0E, 0xFE01, 0x5D0, 0x5DC, 0x1780, 0x1783, 0x17D2, 0x17B4,
          0x1A10, 0x1A15, 0x1A17, 0x2D31, 0x2D65, 0x2D6F, 0x2D7F, 0xA4FC,
          0xA4FD, 0xA4F8, 0xA4FB, 0x10C03, 0x10C32, 0x16D63, 0x16D67, 0x16D68,
          0x16D69, 0x34F, 0x180B, 0xE0100, 0x41]
# The marks that are transparent.
ALPHABET += [0x34F, 0x17B4, 0x17B5, 0x180B, 0x180C, 0x180D, 0x180F]
# Some plain characters.
ALPHABET += [0x41, 0x61, 0x20, 0x0A, 0x0D, 0x4E2D, 0x3000]


def main():
    args = [a for a in sys.argv[1:] if a != "cjk"]
    count = int(args[0]) if args else 20000
    rnd = random.Random(20261110)
    texts = []
    for _ in range(count):
        n = rnd.randint(1, 8)
        pool = SCRIPT if rnd.random() < 0.5 else ALPHABET
        texts.append([rnd.choice(pool) for _ in range(n)])

    bodies = [" ".join("%X" % cp for cp in t) for t in texts]
    r = subprocess.run([RS, MODE_ORACLE], input="\n".join(bodies) + "\n",
                       capture_output=True, text=True)
    if r.returncode != 0:
        print("FAIL: the oracle failed: " + r.stderr[:400], file=sys.stderr)
        sys.exit(1)
    want = [int(x) for x in r.stdout.split()]

    # The package, over the same list.
    # The scratch program sits in the scratch directory of the management
    # repository. It imports the package by its path.
    scratch = os.path.join(ROOT, "..", "..", "tmp", "diff_width.goose")
    with open(scratch, "w") as f:
        f.write("// Scratch program for the width compare.\n")
        f.write("import std;\nimport unicode from \"../packages/goose-unicode\";\n")
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
    r = subprocess.run(["goose", "run", scratch],
                       cwd=ROOT, capture_output=True, text=True)
    if r.returncode != 0:
        print("FAIL: the package did not run: " + r.stderr[-600:], file=sys.stderr)
        sys.exit(1)
    got = [int(x) for x in r.stdout.split()]

    bad = 0
    seen = set()
    for t, w, g in zip(texts, want, got):
        if w != g:
            key = tuple(t)
            if key in seen:
                continue
            seen.add(key)
            bad += 1
            if bad <= 40:
                print("U+%s: crate %d, package %d" % (
                    " U+".join("%04X" % c for c in t), w, g))
    print("differing texts: %d of %d" % (bad, len(texts)))


main()
