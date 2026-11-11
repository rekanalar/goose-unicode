#!/usr/bin/env python3
"""Make char_data.goose and test/suite/char_cases.goose.

The tables hold the numeric type with the decimal and digit values, the
decomposition type with the one level mappings, the joining type, the
joining group and the paired brackets. The sources are UnicodeData.txt,
DerivedNumericType.txt, DerivedDecompositionType.txt,
DerivedJoiningType.txt, DerivedJoiningGroup.txt and BidiBrackets.txt of
the Unicode Character Database 18.0.0.
Second sources: the ICU library gives every property over the whole range,
and Python unicodedata gives the decimal value, the digit value and the
mapping for the code points of its own release. The script fails on the
first difference. The suite file holds the runs of ICU.
Usage: make_char_data.py [ucd directory]
"""
import os
import sys
import unicodedata

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ucdlib as u

NUMTYPES = ["None", "Decimal", "Digit", "Numeric"]
DECOMPS = ["None", "Canonical", "Compat", "Circle", "Final", "Font", "Fraction", "Initial",
           "Isolated", "Medial", "Narrow", "Nobreak", "Small", "Square", "Sub", "Super",
           "Vertical", "Wide"]
JOINTYPES = {"U": "Non_Joining", "C": "Join_Causing", "D": "Dual_Joining",
             "L": "Left_Joining", "R": "Right_Joining", "T": "Transparent"}
JTORDER = ["U", "C", "D", "L", "R", "T"]
PROP_DT, PROP_JT, PROP_JG, PROP_NT = 4099, 4103, 4102, 4105


def derived(name, names):
    """The value index of every code point from a derived file."""
    val = [0] * (u.MAX_CP + 1)
    for line in u.lines_of(name):
        p = [x.strip() for x in line.split(";")]
        a, b = u.parse_range(p[0])
        for c in range(a, b + 1):
            val[c] = names.index(p[1])
    return val


def icu_runs(prop, names, norm=lambda s: s.lower().replace("_", "")):
    """The ICU runs as (start, end, index). The names map through norm."""
    table = {norm(n): i for i, n in enumerate(names)}
    out = []
    for line in u.oracle_go("icuprop", str(prop)):
        a, b, name = line.split()
        if norm(name) not in table:
            u.fail("ICU holds the value %s that the table lacks" % name)
        out.append((int(a, 16), int(b, 16), table[norm(name)]))
    return out


def same(mine, runs, what):
    for a, b, v in runs:
        for c in (a, b, (a + b) // 2):
            if mine[c] != v:
                u.fail("%s of %04X: %s here, %s in ICU" % (what, c, mine[c], v))
    # The runs cover the range, so equal run counts prove equal values.
    if len(u.runs_of(mine)) != len(runs):
        # A run of ICU can split where the values are equal for us.
        for a, b, v in runs:
            for c in range(a, b + 1):
                if mine[c] != v:
                    u.fail("%s of %04X: %s here, %s in ICU" % (what, c, mine[c], v))


def hangul(cp):
    """The decomposition of a Hangul syllable into jamo, as Python gives it."""
    s = cp - 0xAC00
    out = [0x1100 + s // 588, 0x1161 + (s % 588) // 28]
    if s % 28:
        out.append(0x11A7 + s % 28)
    return out


def main():
    u.check_version()
    rows = u.unicode_data()

    # ---- the numeric type, the decimal value and the digit value -------
    nt = derived("extracted/DerivedNumericType.txt", NUMTYPES)
    num = [0] * (u.MAX_CP + 1)
    dec = [-1] * (u.MAX_CP + 1)
    dig = [-1] * (u.MAX_CP + 1)
    for cp, f in rows.items():
        if f[6]:
            dec[cp] = int(f[6])
        if f[7]:
            dig[cp] = int(f[7])
    for cp in range(u.MAX_CP + 1):
        if nt[cp] == 1 and (dec[cp] < 0 or dig[cp] < 0):
            u.fail("a decimal digit with no value at %04X" % cp)
        if nt[cp] != 1 and dec[cp] >= 0:
            u.fail("a decimal value on a code point of another type at %04X" % cp)
        num[cp] = nt[cp] | ((dec[cp] + 1) << 2) | ((dig[cp] + 1) << 6)
    same(nt, icu_runs(PROP_NT, NUMTYPES), "numeric type")
    icu_dec = {}
    for line in u.oracle_go("icudigit"):
        a, b = line.split()
        icu_dec[int(a, 16)] = int(b)
    for cp in range(u.MAX_CP + 1):
        if icu_dec.get(cp, -1) != dec[cp]:
            u.fail("decimal value of %04X differs from ICU" % cp)
    held = 0
    for cp in range(u.MAX_CP + 1):
        if 0xD800 <= cp <= 0xDFFF:
            continue
        ch = chr(cp)
        if unicodedata.category(ch) == "Cn":
            continue
        held += 1
        if unicodedata.decimal(ch, -1) != dec[cp] or unicodedata.digit(ch, -1) != dig[cp]:
            u.fail("Python gives other digit values for %04X" % cp)

    # ---- the decomposition ----------------------------------------------
    dt = derived("extracted/DerivedDecompositionType.txt", DECOMPS)
    mapping = {}
    for cp, f in rows.items():
        if not f[5]:
            continue
        parts = f[5].split()
        if parts[0].startswith("<"):
            tag = parts[0][1:-1]
            parts = parts[1:]
        else:
            tag = "canonical"
        if DECOMPS[dt[cp]].lower() != tag.lower():
            u.fail("decomposition type of %04X differs from the mapping" % cp)
        mapping[cp] = [int(x, 16) for x in parts]
    for cp in range(u.MAX_CP + 1):
        if dt[cp] and cp not in mapping and not (0xAC00 <= cp <= 0xD7A3):
            u.fail("a decomposition type with no mapping at %04X" % cp)
    same(dt, icu_runs(PROP_DT, DECOMPS), "decomposition type")
    for cp in range(u.MAX_CP + 1):
        if 0xD800 <= cp <= 0xDFFF or unicodedata.category(chr(cp)) == "Cn":
            continue
        want = unicodedata.decomposition(chr(cp))
        f = rows.get(cp)
        have = f[5] if f else ""
        if 0xAC00 <= cp <= 0xD7A3:
            # Python gives the full decomposition of a syllable; the table
            # holds none and the code computes it.
            have = " ".join("%04X" % c for c in hangul(cp))
        if want != have:
            u.fail("Python gives another mapping for %04X" % cp)

    # ---- the joining type and group --------------------------------------
    jt = derived("DerivedJoiningType.txt", JTORDER)
    groups = ["No_Joining_Group"]
    for line in u.lines_of("DerivedJoiningGroup.txt"):
        g = line.split(";")[1].strip()
        if g not in groups:
            groups.append(g)
    groups = ["No_Joining_Group"] + sorted(g for g in groups if g != "No_Joining_Group")
    jg = derived("DerivedJoiningGroup.txt", groups)
    jt_icu = icu_runs(PROP_JT, [JOINTYPES[k] for k in JTORDER])
    same(jt, jt_icu, "joining type")
    jg_icu = icu_runs(PROP_JG, groups)
    same(jg, jg_icu, "joining group")

    # ---- the paired brackets ---------------------------------------------
    br = []
    for line in u.lines_of("BidiBrackets.txt"):
        p = [x.strip() for x in line.split(";")]
        br.append((int(p[0], 16), int(p[1], 16), 1 if p[2] == "o" else 2))
    br.sort()
    icu_pairs = {}
    for line in u.oracle_go("icubracket"):
        a, b = line.split()
        icu_pairs[int(a, 16)] = int(b, 16)
    if icu_pairs != {c: p for c, p, _ in br}:
        u.fail("the paired brackets differ from ICU")
    bpt_icu = icu_runs(4117, ["None", "Open", "Close"])
    bt = [0] * (u.MAX_CP + 1)
    for c, _, t in br:
        bt[c] = t
    same(bt, bpt_icu, "bracket type")

    # ---- the tables ----------------------------------------------------------
    mcp = sorted(mapping)
    moff = [0]
    pool = []
    for cp in mcp:
        pool += mapping[cp]
        moff.append(len(pool))
    gnames = "".join(groups)
    goff = [0]
    for g in groups:
        goff.append(goff[-1] + len(g))
    def runs3(prefix, values, doc):
        r = u.runs_of(values, skip=0)
        return [u.array(prefix + "_START", [x[0] for x in r], "The first code point of each run of %s." % doc),
                u.array(prefix + "_END", [x[1] for x in r], "The last code point of each run."),
                u.array(prefix + "_VAL", [x[2] for x in r], "The value of each run.")]
    parts = []
    parts += runs3("NT", num, "the numeric type with the decimal and digit values")
    parts += runs3("DT", dt, "the decomposition type")
    parts += [u.array("DM_CP", mcp, "The code points that have a mapping."),
              u.array("DM_OFF", moff, "The start of each mapping in DM_POOL."),
              u.array("DM_POOL", pool, "The code points of the mappings.")]
    parts += runs3("JT", jt, "the joining type")
    parts += runs3("JG", jg, "the joining group")
    parts += [u.string("JG_NAMES", gnames),
              u.array("JG_NAME_OFF", goff, "The start of each group name in JG_NAMES.")]
    parts += [u.array("BP_CP", [b[0] for b in br], "The brackets, sorted."),
              u.array("BP_PAIR", [b[1] for b in br], "The partner of each bracket."),
              u.array("BP_TYPE", [b[2] for b in br], "1 for an opening bracket and 2 for a closing one.")]
    u.write_goose(os.path.join(u.ROOT, "char_data.goose"), "make_char_data.py", parts)

    suite = []
    for prefix, runs in (("CT", [(a, b, v) for a, b, v in icu_runs(PROP_NT, NUMTYPES)]),
                         ("CD", icu_runs(PROP_DT, DECOMPS)),
                         ("CJ", jt_icu), ("CG", jg_icu)):
        suite += [u.array(prefix + "_START", [r[0] for r in runs], "The first code point of each ICU run."),
                  u.array(prefix + "_END", [r[1] for r in runs], "The last code point of each ICU run."),
                  u.array(prefix + "_VAL", [r[2] for r in runs], "The value of each ICU run.")]
    suite += [u.array("CV_CP", [c for c in range(u.MAX_CP + 1) if dec[c] >= 0 or dig[c] >= 0],
                      "The code points that have a decimal or digit value."),
              u.array("CV_DEC", [dec[c] for c in range(u.MAX_CP + 1) if dec[c] >= 0 or dig[c] >= 0],
                      "The decimal value of each."),
              u.array("CV_DIG", [dig[c] for c in range(u.MAX_CP + 1) if dec[c] >= 0 or dig[c] >= 0],
                      "The digit value of each.")]
    u.write_goose(os.path.join(u.ROOT, "test", "suite", "char_cases.goose"),
                  "make_char_data.py", suite, "suite")
    print("char_data.goose: %d mappings, %d groups, %d brackets; Python checked %d code points"
          % (len(mcp), len(groups), len(br), held))


if __name__ == "__main__":
    main()
