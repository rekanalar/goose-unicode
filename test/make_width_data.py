#!/usr/bin/env python3
"""Make width_data.goose and width_cases.goose: the tables and the vectors
of the width calls.

The reference is the Rust unicode-width crate. The script builds the per
character width table from the files of the Character Database, checks it
against the crate over the whole code point range, and fails on any
difference. The crate gives -1, printed as "none" here, for a control
character; the package gives -1 there too.

The string widths hold no rule outside the crate, so the script asks the
crate for the width of each text and writes the answers into the suite.
The suite checks the package against them. The texts come from the
characters of the width rules: the presentation sequences, the variation
selectors, the zero width joiner, the regional indicators, the emoji
modifiers, the keycaps, the tag characters, the quotation marks and a few
plain characters.

Usage: make_width_data.py [ucd directory]
"""
import os
import random
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
UCD = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "..", "..", "tmp", "ucd")
ORACLE_BIN = os.path.join(HERE, "oracle", "target", "release", "width")
MAX_CP = 0x110000


def fail(msg):
    print("FAIL: " + msg, file=sys.stderr)
    sys.exit(1)


def read_lines(name):
    path = os.path.join(UCD, name)
    if not os.path.exists(path):
        fail("the file " + name + " is missing in " + UCD)
    with open(path, encoding="utf-8") as f:
        for line in f:
            yield line


def load_prop(name, pattern):
    """The code points of the file whose property matches the pattern."""
    got = set()
    for line in read_lines(name):
        line = line.split("#")[0].strip()
        if not line:
            continue
        fields = line.split(";")
        if len(fields) < 2:
            continue
        if not re.fullmatch(pattern, fields[1].strip()):
            continue
        rng = fields[0].strip()
        if ".." in rng:
            lo, hi = rng.split("..")
            got.update(range(int(lo, 16), int(hi, 16) + 1))
        else:
            got.add(int(rng, 16))
    return got


def load_variation(style):
    """The base code points of one style of emoji-variation-sequences.txt."""
    got = set()
    for line in read_lines("emoji-variation-sequences.txt"):
        line = line.split("#")[0].strip()
        if not line:
            continue
        fields = [f.strip() for f in line.split(";")]
        if len(fields) < 2 or fields[1] != style:
            continue
        base = int(fields[0].split(" ")[0], 16)
        got.add(base)
    return got


def to_ranges(cps):
    """A sorted list of (start, end) pairs."""
    out = []
    for cp in sorted(cps):
        if out and cp == out[-1][1] + 1:
            out[-1][1] = cp
        else:
            out.append([cp, cp])
    return [(lo, hi) for lo, hi in out]


def oracle(mode, lines):
    r = subprocess.run([ORACLE_BIN, mode], input="\n".join(lines) + "\n",
                       capture_output=True, text=True)
    if r.returncode != 0:
        fail("the width oracle failed: " + r.stderr[:500])
    return r.stdout.splitlines()


def main():
    if not os.path.exists(ORACLE_BIN):
        fail("the width oracle is missing; build test/oracle with cargo build --release --offline")

    # ---- the data of the Character Database --------------------------
    di = load_prop("DerivedCoreProperties.txt", "Default_Ignorable_Code_Point")
    extend = load_prop("DerivedCoreProperties.txt", "Grapheme_Extend")
    hangul_vt = load_prop("HangulSyllableType.txt", "[VT]")
    prepend = load_prop("GraphemeBreakProperty.txt", "Prepend")
    pcm = load_prop("PropList.txt", "Prepended_Concatenation_Mark")
    emoji_pres = load_prop("emoji-data.txt", "Emoji_Presentation")
    mod_base = load_prop("emoji-data.txt", "Emoji_Modifier_Base")
    eaw_wf = load_prop("EastAsianWidth.txt", "[WF]")
    marks = load_prop(os.path.join("extracted", "DerivedGeneralCategory.txt"), "(?:Mn|Mc|Me)")
    emoji_style = load_variation("emoji style")
    text_style = load_variation("text style")

    zero = di | extend | hangul_vt | (prepend - pcm) | {0x0605, 0x070F, 0x0890, 0x0891, 0x08E2, 0xA8FA}
    zero.discard(0x115F)
    zero.discard(0x2D7F)
    # The combining marks that the standard calls ignorable, plus the zero
    # width joiner. They never break a joiner sequence.
    ligature = (di & marks) | {0x200D}
    # The text presentation sequences of the ideographic supplement keep
    # the width of their base.
    text_pres = (text_style & emoji_pres) - set(range(0x1F200, 0x1F300))

    def table_width(cp):
        # The rule order of the crate: the Khmer sign first, then the zero
        # width set, then the wide set.
        if cp == 0x17D8:
            return 3
        if cp in zero:
            return 0
        # The regional indicators count as one alone, the crate says so.
        if 0x1F1E6 <= cp <= 0x1F1FF:
            return 1
        if cp == 0x17A4 or cp in emoji_pres or cp in eaw_wf:
            return 2
        return 1

    def char_width(cp):
        if cp < 0 or cp >= MAX_CP:
            return -1
        if 0xD800 <= cp <= 0xDFFF:
            return -1
        if cp < 0x20 or 0x7F <= cp <= 0x9F:
            return -1
        return table_width(cp)

    # ---- the runs of the width table ---------------------------------
    starts = []
    vals = []
    for cp in range(MAX_CP):
        w = table_width(cp)
        if not vals or vals[-1] != w:
            starts.append(cp)
            vals.append(w)

    # ---- the check against the crate, over the whole range ----------
    lines = []
    for cp in range(MAX_CP):
        lines.append("%X" % cp)
    got = oracle("char", lines)
    if len(got) != MAX_CP:
        fail("the oracle gave %d lines for %d code points" % (len(got), MAX_CP))
    diffs = 0
    for cp in range(MAX_CP):
        want = char_width(cp)
        if int(got[cp]) != want:
            if diffs < 20:
                print("U+%X: crate %s, table %d" % (cp, got[cp], want), file=sys.stderr)
            diffs += 1
    if diffs:
        fail("%d code points disagree with the crate" % diffs)

    # ---- the string cases --------------------------------------------
    cases = [
        [0x41],                                   # A, one column
        [0x4E2D],                                 # CJK, two columns
        [0x17D8],                                 # three columns
        [0x0A], [0x0D], [0x0D, 0x0A], [0x41, 0x0D, 0x0A, 0x42],
        [0x09], [0x1F600], [0x2764], [0x2764, 0xFE0F], [0x2764, 0xFE0E],
        [0xA9], [0xA9, 0xFE0F], [0xAE, 0xFE0F], [0x23, 0xFE0F], [0x31, 0xFE0F],
        [0x31, 0xFE0F, 0x20E3],                   # keycap
        [0x1F468, 0x200D, 0x1F469, 0x200D, 0x1F466],   # family
        [0x261D, 0x1F3FB],                        # modifier on a narrow base
        [0x1F44D, 0x1F3FD],                       # modifier on a wide base
        [0x1F1E9, 0x1F1EA],                       # flag
        [0x1F1E9, 0x1F1EA, 0x1F1EB],
        [0x1F1E9, 0x200D, 0x1F1EA],
        [0x201C, 0xFE00], [0x201C, 0xFE01], [0x2018, 0xFE02], [0x2019, 0xFE01],
        [0x203C, 0xFE0E], [0x2049, 0xFE0F],
        [0x1F202, 0xFE0E],                        # ideographic text style keeps 2
        [0x1F3F4, 0xE0067, 0xE0062, 0xE0073, 0xE0063, 0xE0074, 0xE007F],   # subdivision flag
        [0x1F3F4, 0x200D, 0x1F3F4],
        [0x2329, 0xFE0E], [0x21A9, 0xFE0F], [0x25FD], [0x25FE, 0xFE0E],
        [0x200D], [0x200D, 0x200D], [0x1F9D1, 0x200D, 0x2764, 0xFE0F, 0x200D, 0x1F48B, 0x200D, 0x1F468],
    ]
    alphabet = sorted(emoji_style | text_style | {0xFE0F, 0xFE0E, 0xFE01, 0xFE00, 0xFE02,
        0x200D, 0x20E3, 0x2018, 0x2019, 0x201C, 0x201D, 0xE0020, 0xE0032, 0xE0061,
        0xE0067, 0xE007F, 0x1F3F4, 0x1F600, 0x1F44D, 0x2764, 0x4E2D, 0x61, 0x20,
        0x0A, 0x0D, 0x30, 0x23, 0x2A})
    alphabet += list(range(0x1F1E6, 0x1F200))
    alphabet += list(range(0x1F3FB, 0x1F400))
    rnd = random.Random(20261110)
    for _ in range(50000):
        n = rnd.randint(1, 12)
        cases.append([rnd.choice(alphabet) for _ in range(n)])

    bodies = [" ".join("%X" % cp for cp in text) for text in cases]
    widths = []
    for i in range(0, len(bodies), 10000):
        widths.extend(oracle("str", bodies[i:i + 10000]))
    if len(widths) != len(cases):
        fail("the oracle gave %d widths for %d cases" % (len(widths), len(cases)))

    # ---- the output ---------------------------------------------------
    def write_rows(f, name, size, values, note):
        f.write("// %s\n" % note)
        f.write("const %s: i64[%d] = [\n" % (name, size))
        for i in range(0, len(values), 24):
            f.write("    " + ", ".join(str(v) for v in values[i:i + 24]) + ",\n")
        f.write("];\n\n")

    with open(os.path.join(ROOT, "width_data.goose"), "w", encoding="utf-8") as f:
        f.write("// Unicode 17.0.0 width data for the unicode package.\n")
        f.write("// Made by test/make_width_data.py. Do not edit by hand.\n")
        f.write("//\n")
        f.write("// CW_START and CW_VAL hold the width of every code point\n")
        f.write("// in terminal columns. The other tables hold the code points of\n")
        f.write("// the sequence rules of the width, as sorted ranges.\n")
        f.write("// The numbers come from the Unicode Character Database, which the\n")
        f.write("// Unicode License covers, and from the Rust unicode-width crate,\n")
        f.write("// which the MIT and Apache-2.0 licenses cover. See test/NOTICE.\n")
        f.write("namespace unicode;\n\n")
        write_rows(f, "CW_START", len(starts), starts,
                   "The first code point of each run of equal width.")
        write_rows(f, "CW_VAL", len(vals), vals,
                   "The width of each run, in columns.")
        for name, note, cps in (
            ("CW_EP", "The code points with the Emoji_Presentation property.", emoji_pres),
            ("CW_EPS", "The bases of the emoji presentation sequences.", emoji_style),
            ("CW_TPS", "The bases of the non ideographic text presentation sequences.", text_pres),
            ("CW_EMB", "The bases of the emoji modifier sequences.", mod_base),
            ("CW_LT", "The ignorable marks and the zero width joiner.", ligature),
        ):
            ranges = to_ranges(cps)
            write_rows(f, name + "_START", len(ranges), [r[0] for r in ranges],
                       note + " First code point of each range.")
            write_rows(f, name + "_END", len(ranges), [r[1] for r in ranges],
                       note + " Last code point of each range.")
        print("width table: %d runs, checked %d code points against the crate" % (len(starts), MAX_CP))

    pool = []
    off = []
    exp = []
    for text, w in zip(cases, widths):
        off.append(len(pool))
        pool.append(len(text))
        pool.extend(text)
        exp.append(int(w))
    off.append(len(pool))
    with open(os.path.join(HERE, "suite", "width_cases.goose"), "w", encoding="utf-8") as f:
        f.write("// Reference cases for the test suites, string widths.\n")
        f.write("// Made by test/make_width_data.py. Do not edit by hand.\n")
        f.write("// The expected widths come from the Rust unicode-width crate.\n")
        f.write("namespace suite;\n\n")
        write_rows(f, "W_OFF", len(off), off,
                   "Start of each case in W_POOL. One more entry ends the last.")
        write_rows(f, "W_POOL", len(pool), pool,
                   "For each case: the count of code points, the code points.")
        write_rows(f, "W_EXP", len(exp), exp, "The expected width of each case.")
    print("width cases: %d texts of %d characters, %d distinct widths" % (
        len(cases), len(pool) - len(cases), len(set(exp))))


main()
