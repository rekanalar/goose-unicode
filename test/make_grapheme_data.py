#!/usr/bin/env python3
"""Make grapheme_data.goose: the cluster break properties.

One table holds, for every run of code points, the Grapheme_Cluster_Break
class, the Extended_Pictographic flag and the Indic_Conjunct_Break class,
packed in one number: the class in the low four bits, the flag in bit 4
and the conjunct class in bits 5 and 6 (1 consonant, 2 linker, 3 extend).
The sources are GraphemeBreakProperty.txt, emoji-data.txt and
DerivedCoreProperties.txt of the Unicode Character Database 18.0.0.
Second sources: Node (ICU 78, which holds 17.0) gives Extended_Pictographic and
Regional_Indicator by regular expression. Intl.Segmenter of Node and an
independent Python version of the rules both split every case of
GraphemeBreakTest.txt, and the script fails if either disagrees with the
file. Usage: make_grapheme_data.py [ucd directory]
"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ucdlib as u

GB = {"Other": 0, "CR": 1, "LF": 2, "Control": 3, "Extend": 4, "ZWJ": 5,
      "Regional_Indicator": 6, "Prepend": 7, "SpacingMark": 8, "L": 9, "V": 10,
      "T": 11, "LV": 12, "LVT": 13}
INCB = {"Consonant": 1, "Linker": 2, "Extend": 3}


def reference_split(cps, val, legacy=False):
    """An independent version of the rules of UAX 29, for the check only.
    The legacy form holds the rule GB9c of 17.0.0, which needs a consonant
    before the linker. Node still follows that form."""
    def gb(c): return val[c] & 15
    def ep(c): return (val[c] >> 4) & 1
    def incb(c): return (val[c] >> 5) & 3
    sizes = []
    start = 0
    for i in range(1, len(cps) + 1):
        if i == len(cps):
            sizes.append(i - start)
            break
        a, b = gb(cps[i - 1]), gb(cps[i])
        brk = True
        if a == GB["CR"] and b == GB["LF"]:
            brk = False
        elif a in (1, 2, 3) or b in (1, 2, 3):
            brk = True
        elif a == 9 and b in (9, 10, 12, 13):
            brk = False
        elif a in (12, 10) and b in (10, 11):
            brk = False
        elif a in (13, 11) and b == 11:
            brk = False
        elif b in (4, 5, 8) or a == 7:
            brk = False
        else:
            # GB9c: a linker, marks of the Extend class, then a consonant.
            # The legacy form wants a consonant, then linkers and marks
            # with at least one linker, then the consonant.
            if incb(cps[i]) == 1:
                j = i - 1
                seen_linker = False
                while j >= start and incb(cps[j]) in ((2, 3) if legacy else (3,)):
                    if incb(cps[j]) == 2:
                        seen_linker = True
                    j -= 1
                if legacy:
                    if seen_linker and j >= start and incb(cps[j]) == 1:
                        brk = False
                elif j >= start and incb(cps[j]) == 2:
                    brk = False
            # GB11: pictographic, extends, joiner, pictographic
            if brk and a == 5 and ep(cps[i]):
                j = i - 2
                while j >= start and gb(cps[j]) == 4:
                    j -= 1
                if j >= start and ep(cps[j]):
                    brk = False
            # GB12 and GB13: pairs of regional indicators
            if brk and a == 6 and b == 6:
                j = i - 1
                n = 0
                while j >= start and gb(cps[j]) == 6:
                    n += 1
                    j -= 1
                if n % 2 == 1:
                    brk = False
        if brk:
            sizes.append(i - start)
            start = i
    return sizes


def main():
    u.check_version()
    n = u.MAX_CP + 1
    val = [0] * n
    ri = set()
    for line in u.lines_of("GraphemeBreakProperty.txt"):
        p = [x.strip() for x in line.split(";")]
        a, b = u.parse_range(p[0])
        for c in range(a, b + 1):
            val[c] |= GB[p[1]]
            if p[1] == "Regional_Indicator":
                ri.add(c)
    ep = set()
    for line in u.lines_of("emoji-data.txt"):
        p = [x.strip() for x in line.split(";")]
        if p[1] == "Extended_Pictographic":
            a, b = u.parse_range(p[0])
            for c in range(a, b + 1):
                val[c] |= 16
                ep.add(c)
    for line in u.lines_of("DerivedCoreProperties.txt"):
        p = [x.strip() for x in line.split(";")]
        if len(p) > 2 and p[1] == "InCB":
            a, b = u.parse_range(p[0])
            for c in range(a, b + 1):
                val[c] |= INCB[p[2]] << 5

    # ---- the second sources --------------------------------------
    def node_set(name):
        s = set()
        for line in u.oracle_node("props.mjs", name):
            if line.strip():
                a, b = line.split()
                s.update(range(int(a, 16), int(b, 16) + 1))
        return s
    def icu_set(name):
        s = set()
        for line in u.oracle_go("icebin", name):
            a, b, _ = line.split()
            s.update(range(int(a, 16), int(b, 16) + 1))
        return s
    # ICU holds the release of the tables and judges every code point.
    # Node holds 17.0, so it judges the code points that 18.0 did not add.
    held = u.held()
    for name, mine in (("Extended_Pictographic", ep), ("Regional_Indicator", ri)):
        if icu_set(name) != mine:
            u.fail("%s differs from ICU" % name)
        if {c for c in node_set(name) if held[c]} != {c for c in mine if held[c]}:
            u.fail("%s differs from Node" % name)

    moved = 0
    cases = []
    for line in open(u.ucd_path("GraphemeBreakTest.txt"), encoding="utf-8"):
        line = line.split("#")[0].strip()
        if not line:
            continue
        toks = line.replace("÷", " D ").replace("×", " X ").split()
        cps, sizes, run = [], [], 0
        for t in toks:
            if t == "D":
                if run:
                    sizes.append(run)
                run = 0
            elif t == "X":
                pass
            else:
                cps.append(int(t, 16))
                run += 1
        cases.append((cps, sizes))
    if len(cases) < 700:
        u.fail("the break test file holds only %d cases" % len(cases))
    for cps, sizes in cases:
        if reference_split(cps, val) != sizes:
            u.fail("the reference rules fail on %r: %r against %r" % (cps, reference_split(cps, val), sizes))
    # Node follows the legacy GB9c, so it must equal the legacy form of
    # the rules on every case that holds no code point of the new release.
    old_cases = [c for c in cases if all(held[x] for x in c[0])]
    node = u.oracle_node("segment.mjs", stdin="\n".join(json.dumps(c[0]) for c in old_cases) + "\n")
    for (cps, sizes), line in zip(old_cases, node):
        want = reference_split(cps, val, legacy=True)
        if [int(x) for x in line.split()] != want:
            u.fail("Intl.Segmenter disagrees with the legacy rules on %r" % cps)
        if want != sizes:
            moved += 1
    if moved == 0:
        u.fail("no case of the test file depends on the changed rule GB9c")

    # ---- the output ----------------------------------------------
    runs = u.runs_of(val)
    parts = [
        u.array("GP_START", [r[0] for r in runs], "First code point of each run. The runs cover all code points."),
        u.array("GP_VAL", [r[2] for r in runs], "Break class in bits 0 to 3, pictographic flag in bit 4, conjunct class in bits 5 and 6."),
    ]
    u.write_goose(os.path.join(u.ROOT, "grapheme_data.goose"), "make_grapheme_data.py", parts)
    print("grapheme runs %d; %d cases of the break test file agree with the reference rules; Node agrees with the legacy rules on %d cases, %d of them split differently now" % (len(runs), len(cases), len(old_cases), moved))


main()
