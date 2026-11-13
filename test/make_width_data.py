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
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ucdlib

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
    # The two halfwidth sound marks are Grapheme_Extend, yet the crate
    # 0.2.3 gives them width 1. The package follows the crate.
    zero.discard(0xFF9E)
    zero.discard(0xFF9F)
    # The text presentation sequences of the ideographic supplement keep
    # the width of their base.
    text_pres = (text_style & emoji_pres) - set(range(0x1F200, 0x1F300))
    # The code points of the script ligature rules. The joining group of
    # the Alef comes from the Character Database. The Khmer ranges and
    # the marks that do not break a ligature come from the generator of
    # the Rust crate.
    alef = load_prop("DerivedJoiningGroup.txt", "Alef")
    khmer = set()
    for lo, hi in ((0x1780, 0x1782), (0x1784, 0x1787), (0x1789, 0x178C),
                   (0x178E, 0x1793), (0x1795, 0x1798), (0x179B, 0x179D)):
        khmer.update(range(lo, hi + 1))
    khmer |= {0x17A0, 0x17A2, 0x17A7, 0x17AB, 0x17AC, 0x17AF}
    tifinagh = set(range(0x2D31, 0x2D66)) | {0x2D6F}
    lisu = {0xA4FC, 0xA4FD}
    # The marks that do not break a ligature, from the crate.
    joining_t = load_prop("DerivedJoiningType.txt", "T")
    ntz = zero - joining_t
    lig = set()
    for lo, hi in ((0x34F, 0x34F), (0x17B4, 0x17B5), (0x180B, 0x180D),
                   (0x180F, 0x180F), (0x200D, 0x200D), (0xFE00, 0xFE0F),
                   (0xE0100, 0xE01EF)):
        lig.update(range(lo, hi + 1))

    # The East Asian context form. A character of ambiguous width takes 2
    # columns there. The crate widens the ambiguous characters by this rule:
    # the East Asian width A, plus the line break class AI, minus the
    # letters and the modifier symbols, plus U+0387, plus each character
    # that decomposes to an ambiguous base and U+0338.
    eaw_a = load_prop("EastAsianWidth.txt", "A")
    lb_ai = load_prop("LineBreak.txt", "AI")
    letters_sk = load_prop(os.path.join("extracted", "DerivedGeneralCategory.txt"),
                           "(?:Lu|Ll|Lt|Lm|Lo|Sk)")
    amb = set(eaw_a) | lb_ai
    wide_eaw = eaw_wf - lb_ai
    amb -= letters_sk
    amb.add(0x0387)
    ccc = {}
    decomp = {}
    # The crate reads the decomposition with a loose pattern over each line
    # of UnicodeData.txt. When the decomposition field is empty, the pattern
    # takes a later field made of hex digits, such as the numeric value 300
    # of U+1011B. The same pattern here gives the same set as the crate.
    loose = re.compile(r"([0-9A-Z]+);.*?;.*?;.*?;.*?;([0-9A-F ]+);")
    for line in read_lines("UnicodeData.txt"):
        f = line.split(";")
        if len(f) < 6:
            continue
        cp = int(f[0], 16)
        ccc[cp] = int(f[3])
        m = loose.match(line)
        if m:
            decomp[int(m.group(1), 16)] = [int(x, 16) for x in m.group(2).split(" ")]
    pairs = {}
    for line in read_lines("UnicodeData.txt"):
        f = line.split(";")
        if len(f) >= 6 and f[5] and not f[5].startswith("<"):
            parts = f[5].split(" ")
            if len(parts) == 2 and parts[1] == "0338":
                pairs[int(f[0], 16)] = int(parts[0], 16)
    for cp, base in sorted(pairs.items()):
        if base in amb:
            amb.add(cp)
    # The code points that the combining solidus overlay skips: the marks
    # of canonical class above 1, the marks that do not break a ligature,
    # and every character whose decomposition holds only those.
    solidus = {cp for cp, c in ccc.items() if c > 1} | lig
    again = True
    while again:
        again = False
        for cp, d in decomp.items():
            if cp not in solidus and all(x in solidus for x in d):
                solidus.add(cp)
                again = True
    # The characters that carry a state of their own. A wide reading of
    # their ambiguous width does not apply to them.
    special1 = ({0x0A, 0x5DC, 0x1A10, 0x10C03, 0x16D67, 0x16D68} | alef | khmer
                | tifinagh | lisu | set(range(0x1F1E6, 0x1F200)))

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

    # The East Asian width of a character, and the check against the crate.
    def cjk_width(cp):
        w = char_width(cp)
        if w == 1 and cp not in special1 and (cp in amb or cp in wide_eaw):
            return 2
        return w

    ambiguous_wide = {cp for cp in range(MAX_CP)
                      if char_width(cp) == 1 and cjk_width(cp) == 2}
    got = oracle("cchar", lines)
    diffs = 0
    for cp in range(MAX_CP):
        if int(got[cp]) != cjk_width(cp):
            if diffs < 20:
                print("U+%X: crate %s, cjk table %d" % (cp, got[cp], cjk_width(cp)), file=sys.stderr)
            diffs += 1
    if diffs:
        fail("%d code points disagree with the crate in the East Asian form" % diffs)

    # The solidus set: the text "< c U+0338" is 2 columns wider when c is
    # skipped. Check every code point that holds no state of its own.
    probes = [cp for cp in range(MAX_CP)
              if not (0xD800 <= cp <= 0xDFFF) and cp >= 0xA0
              and cp not in special1 and cp != 0x338 and cp != 0x200D
              and not 0xFE00 <= cp <= 0xFE0F and cp not in emoji_pres
              and cp not in mod_base]
    got = oracle("cstr", ["3C %X 338" % cp for cp in probes])
    diffs = 0
    for cp, g in zip(probes, got):
        want = (2 if cp in solidus else 1) + cjk_width(cp)
        if int(g) != want:
            if diffs < 20:
                print("U+%X: crate %s, solidus model %d" % (cp, g, want), file=sys.stderr)
            diffs += 1
    if diffs:
        fail("%d code points disagree with the crate in the solidus set" % diffs)

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
        [0x644, 0x622], [0x6B5, 0x623, 0x64B], [0x644, 0x64B, 0x627],   # lam alef
        [0x5D0, 0x200D, 0x5DC], [0x5D0, 0x5DC],                       # hebrew
        [0x1780, 0x17D2, 0x1781], [0x1780, 0x17D2, 0x17A4],           # khmer coeng
        [0x1A15, 0x1A17, 0x200D, 0x1A10], [0x1A17, 0x1A10],           # buginese
        [0x2D31, 0x2D7F, 0x2D32], [0x2D31, 0x200D, 0x2D32],           # tifinagh
        [0xA4F8, 0xA4FC], [0x10C32, 0x200D, 0x10C03],                 # lisu, turkic
        [0x16D63, 0x16D67], [0x16D69, 0x16D67], [0x16D63, 0x16D68],   # kirat rai
        [0x1F469, 0xE0100, 0x200D, 0x1F600],                          # transparent mark in a joiner run
        [0xA1], [0x3C, 0x338], [0x3D, 0x338, 0x338], [0x3E, 0x338], [0x41, 0x338, 0x3C],
        [0x3C, 0x301, 0x338], [0x3C, 0x34F, 0x338], [0x3C, 0x622, 0x338],
        [0x3C, 0x338, 0x622], [0x338, 0x622, 0x644], [0x622, 0x338, 0x644],
        [0x622, 0x338, 0x64B, 0x644], [0xFE00, 0x201C], [0x201C, 0xFE00],
        [0x201C, 0xFE02], [0x201C, 0xFE01], [0xAE, 0xFE0F], [0x3B1, 0x3B2],
        [0x2460], [0x2500, 0x2501], [0x2264, 0x338], [0x2264],
        [0x200D], [0x200D, 0x200D], [0x1F9D1, 0x200D, 0x2764, 0xFE0F, 0x200D, 0x1F48B, 0x200D, 0x1F468],
    ]
    alphabet = sorted(emoji_style | text_style | {0xFE0F, 0xFE0E, 0xFE01, 0xFE00, 0xFE02,
        0x200D, 0x20E3, 0x2018, 0x2019, 0x201C, 0x201D, 0xE0020, 0xE0032, 0xE0061,
        0xE0067, 0xE007F, 0x1F3F4, 0x1F600, 0x1F44D, 0x2764, 0x4E2D, 0x61, 0x20,
        0x0A, 0x0D, 0x30, 0x23, 0x2A})
    alphabet += list(range(0x1F1E6, 0x1F200))
    alphabet += list(range(0x1F3FB, 0x1F400))
    script = [0x644, 0x6B5, 0x76A, 0x8C7, 0x622, 0x627, 0x64B, 0x670, 0x200D,
              0xFE0F, 0xFE0E, 0xFE01, 0x5D0, 0x5DC, 0x1780, 0x1783, 0x17D2, 0x17B4,
              0x1A10, 0x1A15, 0x1A17, 0x2D31, 0x2D65, 0x2D6F, 0x2D7F, 0xA4FC,
              0xA4FD, 0xA4F8, 0xA4FB, 0x10C03, 0x10C32, 0x16D63, 0x16D67, 0x16D68,
              0x16D69, 0x34F, 0x180B, 0xE0100, 0x41, 0x1F600, 0x1F469,
              0x338, 0x3C, 0x3D, 0x3E, 0xA1, 0x301, 0x64B, 0x201C, 0xFE00, 0xFE02,
              0x2264, 0x3B1]
    rnd = random.Random(20261110)
    for i in range(50000):
        n = rnd.randint(1, 12)
        pool = script if i % 2 else alphabet
        cases.append([rnd.choice(pool) for _ in range(n)])

    bodies = [" ".join("%X" % cp for cp in text) for text in cases]
    widths = []
    for i in range(0, len(bodies), 10000):
        widths.extend(oracle("str", bodies[i:i + 10000]))
    cwidths = []
    for i in range(0, len(bodies), 10000):
        cwidths.extend(oracle("cstr", bodies[i:i + 10000]))
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
        f.write("// Generated by test/make_width_data.py. Do not edit by hand.\n")
        f.write("// Unicode 18.0.0 width data for the unicode package.\n")
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
            ("CW_LT", "The marks that do not break a script ligature.", lig),
            ("CW_ALEF", "The code points of the joining group Alef.", alef),
            ("CW_NTZ", "The zero width code points that are not joining type Transparent.", ntz),
            ("CW_AMB", "The code points that the East Asian context widens from 1 to 2.", ambiguous_wide),
            ("CW_SOL", "The code points that a combining solidus overlay skips.", solidus),
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
    cexp = []
    for text, w, cw in zip(cases, widths, cwidths):
        cexp.append(int(cw))
        off.append(len(pool))
        pool.append(len(text))
        pool.extend(text)
        exp.append(int(w))
    off.append(len(pool))
    with open(os.path.join(HERE, "suite", "width_cases.goose"), "w", encoding="utf-8") as f:
        f.write("// Generated by test/make_width_data.py. Do not edit by hand.\n")
        f.write("// Reference cases for the test suites, string widths.\n")
        f.write("// The expected widths come from the Rust unicode-width crate.\n")
        f.write("namespace suite;\n\n")
        for name, vals, note in (
            ("W_OFF", off, "Start of each case in W_POOL. One more entry ends the last."),
            ("W_POOL", pool, "For each case: the count of code points, the code points."),
            ("W_EXP", exp, "The expected width of each case."),
            ("W_EXPC", cexp, "The expected width of each case in the East Asian context form."),
        ):
            f.write(ucdlib.bytes_array(name, ucdlib.pool_bytes(vals), note) + "\n")
    print("width cases: %d texts of %d characters, %d distinct widths" % (
        len(cases), len(pool) - len(cases), len(set(exp))))


main()
