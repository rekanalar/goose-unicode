#!/usr/bin/env python3
"""Make props_data.goose: the script, width, class, mirror, numeric and
name tables.

The tables come from the files of the Unicode Character Database 17.0.0.
Each table is checked against a second source: the Go standard library
for the scripts, golang.org/x/text/width for the widths, x/text bidi and
ICU for the classes, ICU for the mirror partners and the numeric values,
and ICU and Python for the names. The script exits with an error on the
first difference. Usage: make_props_data.py [ucd directory]
"""
import os
import re
import struct
import subprocess
import sys
import unicodedata

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ucdlib as u


BIDI_ALIASES = {
    "Left_To_Right": "L", "Right_To_Left": "R", "Arabic_Letter": "AL",
    "European_Number": "EN", "European_Separator": "ES",
    "European_Terminator": "ET", "Arabic_Number": "AN",
    "Common_Separator": "CS", "Nonspacing_Mark": "NSM",
    "Boundary_Neutral": "BN", "Paragraph_Separator": "B",
    "Segment_Separator": "S", "White_Space": "WS", "Other_Neutral": "ON",
    "Left_To_Right_Embedding": "LRE", "Left_To_Right_Override": "LRO",
    "Right_To_Left_Embedding": "RLE", "Right_To_Left_Override": "RLO",
    "Pop_Directional_Format": "PDF", "Left_To_Right_Isolate": "LRI",
    "Right_To_Left_Isolate": "RLI", "First_Strong_Isolate": "FSI",
    "Pop_Directional_Isolate": "PDI",
}


def parse_props(name):
    """Yield (cp range, value) of a property file, plus its defaults."""
    entries = []
    defaults = []
    with open(ucd_path(name), encoding="utf-8") as f:
        for line in f:
            stripped = line.strip()
            if "@missing:" in stripped:
                body = stripped.split("@missing:", 1)[1].split("#")[0]
                rng, val = [x.strip() for x in body.split(";") if x.strip()]
                defaults.append((u.parse_range(rng), BIDI_ALIASES.get(val, val)))
                continue
            line = line.split("#")[0].strip()
            if not line:
                continue
            parts = [x.strip() for x in line.split(";")]
            val = BIDI_ALIASES.get(parts[1], parts[1])
            entries.append((u.parse_range(parts[0]), val))
    return entries, defaults


def value_array(entries, defaults, default_value):
    """A list of 0x110000 values, defaults first, entries last."""
    v = [default_value] * (u.MAX_CP + 1)
    for (lo, hi), val in defaults:
        for cp in range(lo, hi + 1):
            v[cp] = val
    for (lo, hi), val in entries:
        for cp in range(lo, hi + 1):
            v[cp] = val
    return v


def fail(msg):
    u.fail(msg)


ucd_path = u.ucd_path


def main():
    u.check_version()
    rows = u.unicode_data()
    o = Oracle()

    # ---- the script table, checked against the Go standard library ----
    entries, defaults = parse_props("Scripts.txt")
    names = ["Unknown", "Common", "Inherited"]
    idx = {}
    for (lo, hi), val in defaults + entries:
        if val not in idx:
            if val in ("Unknown", "Common", "Inherited"):
                idx[val] = names.index(val)
            else:
                idx[val] = len(names)
                names.append(val)
    script_vals = value_array(entries, defaults, "Unknown")
    runs = u.runs_of([names.index(x) for x in script_vals])
    go_runs = []
    for line in o.go("script"):
        a, b, name = line.split()
        go_runs.append((int(a, 16), int(b, 16), name))
    mine = [(r[0], r[1], names[r[2]]) for r in runs]
    if go_runs != mine:
        for x, y in zip(go_runs, mine):
            if x != y:
                fail("script runs differ: Go %r, table %r" % (x, y))
        fail("script run counts differ: Go %d, table %d" % (len(go_runs), len(mine)))
    script_start = [r[0] for r in runs]
    script_index = [r[2] for r in runs]
    script_names, script_off = pack(names)

    # ---- the width table, checked against x/text ----------------------
    # The file names its defaults in its comments. The unassigned code
    # points of the CJK blocks and of planes 2 and 3 default to Wide.
    entries, defaults = parse_props("EastAsianWidth.txt")
    defaults += [((0x3400, 0x4DBF), "W"), ((0x4E00, 0x9FFF), "W"),
                 ((0xF900, 0xFAFF), "W"), ((0x20000, 0x2FFFF), "W"),
                 ((0x30000, 0x3FFFF), "W")]
    widths = ["N", "Na", "A", "W", "F", "H"]
    width_vals = value_array(entries, defaults, "N")
    runs = u.runs_of([widths.index(x) for x in width_vals])
    go_runs = []
    for line in o.go("width"):
        a, b, k = line.split()
        go_runs.append((int(a, 16), int(b, 16), widths.index(k)))
    if go_runs != runs:
        for x, y in zip(go_runs, runs):
            if x != y:
                fail("width runs differ: Go %r, table %r" % (x, y))
        fail("width run counts differ: Go %d, table %d" % (len(go_runs), len(runs)))
    width_start = [r[0] for r in runs]
    width_end = [r[1] for r in runs]
    width_val = [r[2] for r in runs]

    # ---- the bidirectional class table --------------------------------
    # Checked against ICU over every code point, and against x/text over
    # every assigned code point.
    entries, defaults = parse_props("DerivedBidiClass.txt")
    bidi_names = ["L", "R", "AL", "EN", "ES", "ET", "AN", "CS", "NSM",
                  "BN", "B", "S", "WS", "ON", "LRE", "LRO", "RLE", "RLO",
                  "PDF", "LRI", "RLI", "FSI", "PDI"]
    bidx = {n: i for i, n in enumerate(bidi_names)}
    bidi_vals = value_array(entries, defaults, "L")
    runs = u.runs_of([bidx[x] for x in bidi_vals])
    go_runs = []
    for line in o.go("bidiicu"):
        a, b, name = line.split()
        go_runs.append((int(a, 16), int(b, 16), bidx[name]))
    if go_runs != runs:
        for x, y in zip(go_runs, runs):
            if x != y:
                fail("class runs differ: ICU %r, table %r" % (x, y))
        fail("class run counts differ: ICU %d, table %d" % (len(go_runs), len(runs)))
    assigned = [False] * (u.MAX_CP + 1)
    for cp, f in rows.items():
        assigned[cp] = f[2] != "Cn"
    start = 0
    for line in o.go("bidi"):
        a, b, name = line.split()
        lo, hi = int(a, 16), int(b, 16)
        for cp in (lo, hi):
            if 0xD800 <= cp <= 0xDFFF:
                continue
            if assigned[cp] and bidi_vals[cp] != name:
                fail("class of %04X differs from x/text: %s, %s"
                     % (cp, bidi_vals[cp], name))
    bidi_start = [r[0] for r in runs]
    bidi_end = [r[1] for r in runs]
    bidi_val = [r[2] for r in runs]

    # ---- the mirror table, checked against ICU -------------------------
    flagged = [cp for cp in rows if rows[cp][9] == "Y"]
    partner = {}
    for line in u.lines_of("BidiMirroring.txt"):
        a, b = [int(x, 16) for x in line.split(";")]
        partner[a] = b
    for cp, b in partner.items():
        if cp not in flagged:
            fail("BidiMirroring %04X carries no mirrored flag" % cp)
    mirror_runs = []
    for cp in flagged:
        d = partner.get(cp, cp) - cp
        if mirror_runs and mirror_runs[-1][1] == cp - 1 and mirror_runs[-1][2] == d:
            mirror_runs[-1][1] = cp
        else:
            mirror_runs.append([cp, cp, d])
    icu_partner = {}
    for line in o.go("mirror"):
        a, b = line.split()
        icu_partner[int(a, 16)] = int(b, 16)
    if set(icu_partner) - set(flagged):
        fail("ICU mirrors a code point without a flag")
    for cp in flagged:
        want = partner.get(cp, cp)
        if icu_partner.get(cp, cp) != want:
            fail("mirror partner of %04X differs from ICU" % cp)
    mirror_start = [r[0] for r in mirror_runs]
    mirror_end = [r[1] for r in mirror_runs]
    mirror_delta = [r[2] for r in mirror_runs]

    # ---- the numeric table, checked against ICU and Python -------------
    nums = {}
    for line in u.lines_of("NumericValue.txt"):
        parts = [x.strip() for x in line.split(";")]
        rng, val = parts[0], parts[3]
        lo, hi = u.parse_range(rng)
        if "/" in val:
            a, b = val.split("/")
            num, den = int(a), int(b)
        else:
            num, den = int(val), 1
        for cp in range(lo, hi + 1):
            nums[cp] = (num, den)
    icu_num = {}
    for line in o.go("numeric"):
        a, b = line.split()
        icu_num[int(a, 16)] = float(b)
    if set(nums) != set(icu_num):
        fail("the numeric sets differ: table %d, ICU %d"
             % (len(nums), len(icu_num)))
    py_warn = 0
    for cp, (num, den) in nums.items():
        if struct.pack("<d", num / den) != struct.pack("<d", icu_num[cp]):
            fail("numeric value of %04X differs from ICU" % cp)
        # Python holds Unicode 16.0.0. A value that the standard corrected
        # in 17.0.0 warns instead of fails.
        try:
            py = unicodedata.numeric(chr(cp))
            if struct.pack("<d", py) != struct.pack("<d", num / den):
                py_warn += 1
        except ValueError:
            pass
    num_runs = []
    for cp in sorted(nums):
        if num_runs and num_runs[-1][1] == cp - 1 and nums[cp] == num_runs[-1][2]:
            num_runs[-1][1] = cp
        else:
            num_runs.append([cp, cp, nums[cp]])
    num_start = [r[0] for r in num_runs]
    num_end = [r[1] for r in num_runs]
    num_num = [r[2][0] for r in num_runs]
    num_den = [r[2][1] for r in num_runs]

    # ---- the name table, checked against ICU and Python ----------------
    names = {}
    for cp, f in rows.items():
        if not f[1].startswith("<"):
            names[cp] = f[1]
    jamo = {}
    for line in u.lines_of("Jamo.txt"):
        cp, short = [x.strip() for x in line.split(";")][:2]
        jamo[int(cp, 16)] = short
    L_BASE, V_BASE, T_BASE = 0x1100, 0x1161, 0x11A8
    for base, count, letter in ((L_BASE, 19, "leading"), (V_BASE, 21, "vowel"),
                                (T_BASE, 27, "trailing")):
        for i in range(count):
            if base + i not in jamo:
                fail("Jamo.txt lacks the %s letters" % letter)

    # The families the standard builds from a rule. Each holds the prefix
    # and the hex form of the code point.
    families = []
    for base, count, prefix in (
        (0x3400, 0x4DBF - 0x3400 + 1, "CJK UNIFIED IDEOGRAPH-"),
        (0x4E00, 0x9FFF - 0x4E00 + 1, "CJK UNIFIED IDEOGRAPH-"),
        (0x20000, 0x2A6DF - 0x20000 + 1, "CJK UNIFIED IDEOGRAPH-"),
        (0x2A700, 0x2B73F - 0x2A700 + 1, "CJK UNIFIED IDEOGRAPH-"),
        (0x2B740, 0x2B81D - 0x2B740 + 1, "CJK UNIFIED IDEOGRAPH-"),
        (0x2B820, 0x2CEAD - 0x2B820 + 1, "CJK UNIFIED IDEOGRAPH-"),
        (0x2CEB0, 0x2EBE0 - 0x2CEB0 + 1, "CJK UNIFIED IDEOGRAPH-"),
        (0x2EBF0, 0x2EE5D - 0x2EBF0 + 1, "CJK UNIFIED IDEOGRAPH-"),
        (0x30000, 0x3134A - 0x30000 + 1, "CJK UNIFIED IDEOGRAPH-"),
        (0x31350, 0x323AF - 0x31350 + 1, "CJK UNIFIED IDEOGRAPH-"),
        (0x323B0, 0x33479 - 0x323B0 + 1, "CJK UNIFIED IDEOGRAPH-"),
        (0x17000, 0x187FF - 0x17000 + 1, "TANGUT IDEOGRAPH-"),
        (0x18D00, 0x18D1E - 0x18D00 + 1, "TANGUT IDEOGRAPH-"),
        (0x1B170, 0x1B2FB - 0x1B170 + 1, "NUSHU CHARACTER-"),
        (0x18B00, 0x18CFF - 0x18B00 + 1, "KHITAN SMALL SCRIPT CHARACTER-"),
    ):
        for cp in range(base, base + count):
            if cp in rows:
                names[cp] = prefix + hexname(cp)
    for cp in range(0xAC00, 0xD7A3 + 1):
        s = cp - 0xAC00
        l = (s // 588)
        v = (s % 588) // 28
        t = s % 28
        parts = [jamo[L_BASE + l], jamo[V_BASE + v]]
        if t:
            parts.append(jamo[T_BASE + t - 1])
        names[cp] = "HANGUL SYLLABLE " + "".join(parts)

    icu_names = {}
    for line in o.go("name"):
        cp, name = line.split(" ", 1)
        icu_names[int(cp, 16)] = name
    if icu_names != names:
        only_icu = set(icu_names) - set(names)
        only_mine = set(names) - set(icu_names)
        if only_icu or only_mine:
            fail("the name sets differ: ICU only %d, table only %d, e.g. %r %r"
                 % (len(only_icu), len(only_mine),
                    sorted(only_icu)[:3], sorted(only_mine)[:3]))
        for cp in sorted(names):
            if names[cp] != icu_names.get(cp):
                fail("name of %04X differs: ICU %r, table %r"
                     % (cp, icu_names.get(cp), names[cp]))
    for cp, name in names.items():
        try:
            py = unicodedata.name(chr(cp))
            if py != name:
                fail("name of %04X differs from Python: %r, %r"
                     % (cp, py, name))
        except ValueError:
            pass
    name_cps = sorted(names)
    name_names, name_off = pack([names[cp] for cp in name_cps])

    # The final of a syllable is one of 28 slots. The first slot holds no
    # letter. The 27 consonants of Jamo.txt fill the other slots.
    jamo_l = [jamo[L_BASE + i] for i in range(19)]
    jamo_v = [jamo[V_BASE + i] for i in range(21)]
    jamo_t = [""] + [jamo[T_BASE + i] for i in range(27)]
    jamo_t_p, jamo_t_off = pack(jamo_t)

    # ---- write the source file ------------------------------------------
    parts = [
        u.array("SCRIPT_START", script_start,
                "The first code point of each run of one script."),
        u.array("SCRIPT_INDEX", script_index,
                "The index of the script of each run in SCRIPT_NAMES."),
        u.string("SCRIPT_NAMES", script_names),
        u.array("SCRIPT_OFF", script_off,
                "The start of each script name in SCRIPT_NAMES."),
        u.array("WIDTH_START", width_start,
                "The first code point of each run of one width."),
        u.array("WIDTH_END", width_end, "The last code point of each run."),
        u.array("WIDTH_VAL", width_val, "The width value of each run."),
        u.string("WIDTH_NAMES",
                 pack(["Neutral", "Narrow", "Ambiguous", "Wide",
                       "Fullwidth", "Halfwidth"])[0]),
        u.array("WIDTH_NAME_OFF",
                pack(["Neutral", "Narrow", "Ambiguous", "Wide",
                      "Fullwidth", "Halfwidth"])[1],
                "The start of each width name in WIDTH_NAMES."),
        u.array("BIDI_START", bidi_start,
                "The first code point of each run of one class."),
        u.array("BIDI_END", bidi_end, "The last code point of each run."),
        u.array("BIDI_VAL", bidi_val, "The class value of each run."),
        u.string("BIDI_NAMES",
                 pack(["L", "R", "AL", "EN", "ES", "ET", "AN", "CS", "NSM",
                       "BN", "B", "S", "WS", "ON", "LRE", "LRO", "RLE", "RLO",
                       "PDF", "LRI", "RLI", "FSI", "PDI"])[0]),
        u.array("BIDI_NAME_OFF",
                pack(["L", "R", "AL", "EN", "ES", "ET", "AN", "CS", "NSM",
                      "BN", "B", "S", "WS", "ON", "LRE", "LRO", "RLE", "RLO",
                      "PDF", "LRI", "RLI", "FSI", "PDI"])[1],
                "The start of each class name in BIDI_NAMES."),
        u.array("MIRROR_START", mirror_start,
                "The first code point of each run of one mirror delta."),
        u.array("MIRROR_END", mirror_end, "The last code point of each run."),
        u.array("MIRROR_DELTA", mirror_delta,
                "The partner is the code point plus this number."),
        u.array("NUM_START", num_start,
                "The first code point of each run of one numeric value."),
        u.array("NUM_END", num_end, "The last code point of each run."),
        u.array("NUM_NUM", num_num, "The numerator of the value of each run."),
        u.array("NUM_DEN", num_den, "The denominator of the value of each run."),
        u.array("NAME_START", name_cps, "The code point of each name."),
        u.array("NAME_OFF", name_off, "The start of each name in NAME_NAMES."),
        u.string("NAME_NAMES", name_names),
        u.string("JAMO_L", jamo_l),
        u.string("JAMO_V", jamo_v),
        u.string("JAMO_T", jamo_t_p),
        u.array("JAMO_T_OFF", jamo_t_off, "The start of each trailing name."),
    ]
    u.write_goose(os.path.join(u.ROOT, "props_data.goose"),
                  "make_props_data.py", parts)

    # ---- write the name cases for the test suite ------------------------
    case_parts = [
        u.array("NAME_CASE_CP", name_cps, "A code point with a name."),
        u.array("NAME_CASE_OFF", name_off2(name_cps, names),
                "The start of the expected name in NAME_EXPECT."),
        u.string("NAME_EXPECT", name_names),
    ]
    u.write_goose(os.path.join(u.ROOT, "test", "suite", "props_name_cases.goose"),
                  "make_props_data.py", case_parts, "suite")

    num_case_cps = sorted(nums)
    num_case_parts = [
        u.array("NUM_CASE_CP", num_case_cps,
                "A code point with a numeric value, as ICU 78 holds it."),
        u.array("NUM_CASE_NUM", [nums[cp][0] for cp in num_case_cps],
                "The numerator of the value."),
        u.array("NUM_CASE_DEN", [nums[cp][1] for cp in num_case_cps],
                "The denominator of the value."),
    ]
    u.write_goose(os.path.join(u.ROOT, "test", "suite", "props_num_cases.goose"),
                  "make_props_data.py", num_case_parts, "suite")

    if py_warn:
        print("warning: %d numeric values differ from Python 16.0.0" % py_warn)
    print("props_data.goose: %d script runs, %d width runs, %d class runs,"
          " %d mirror runs, %d numeric runs, %d names"
          % (len(script_start), len(width_start), len(bidi_start),
             len(mirror_start), len(num_start), len(name_cps)))


def hexname(cp):
    return "%04X" % cp if cp < 0x10000 else "%X" % cp


def name_off2(cps, names):
    """The offsets of the expected names, one per case, plus the end."""
    off = [0]
    for cp in cps:
        off.append(off[-1] + len(names[cp]))
    return off


def pack(items):
    """Packed strings and the offsets of each item, one more at the end."""
    blob = "".join(items)
    off = [0]
    for it in items:
        off.append(off[-1] + len(it))
    return blob, off


class Oracle:
    """The Go oracle, run once per mode."""

    def __init__(self):
        self.cache = {}

    def go(self, mode):
        if mode not in self.cache:
            self.cache[mode] = u.oracle_go(mode)
        return self.cache[mode]


if __name__ == "__main__":
    main()
