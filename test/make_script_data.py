#!/usr/bin/env python3
"""Make script_data.goose and test/suite/script_cases.goose.

The tables hold the script extensions, the blocks and the age of every
code point. The sources are ScriptExtensions.txt, Blocks.txt,
DerivedAge.txt and PropertyValueAliases.txt of the Unicode Character
Database 17.0.0. The script numbers are those of props_data.goose, so the
script of a code point without an extension list comes from the table of
`script`.
The ICU library gives the three properties over the whole range. The
script fails on the first difference. The suite file holds the runs of ICU.
Usage: make_script_data.py [ucd directory]
"""
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ucdlib as u


def read_props():
    text = open(os.path.join(u.ROOT, "props_data.goose"), encoding="utf-8").read()

    def numbers(name):
        m = re.search(r"const %s: i64\[\d+\] = \[(.*?)\];" % name, text, re.S)
        return [int(x) for x in m.group(1).replace("\n", " ").split(",") if x.strip()]
    chars = re.search(r'const SCRIPT_NAMES: u8\[\] = "(.*?)";\n', text, re.S).group(1)
    off = numbers("SCRIPT_OFF")
    names = [chars[off[i]:off[i + 1]] for i in range(len(off) - 1)]
    return names, numbers("SCRIPT_START"), numbers("SCRIPT_INDEX")


def norm(s):
    return re.sub(r"[^a-z0-9]", "", s.lower())


def main():
    u.check_version()
    names, sstart, sindex = read_props()
    index = {n: i for i, n in enumerate(names)}
    script = [0] * (u.MAX_CP + 1)
    for k, a in enumerate(sstart):
        b = sstart[k + 1] - 1 if k + 1 < len(sstart) else u.MAX_CP
        for c in range(a, b + 1):
            script[c] = sindex[k]
    short = {}
    for line in u.lines_of("PropertyValueAliases.txt"):
        p = [x.strip() for x in line.split(";")]
        if p[0] == "sc":
            short[p[1]] = p[2]
    ext = {}
    for line in u.lines_of("ScriptExtensions.txt"):
        p = [x.strip() for x in line.split(";")]
        a, b = u.parse_range(p[0])
        lst = sorted(index[short[x]] for x in p[1].split())
        for c in range(a, b + 1):
            ext[c] = lst

    # ---- the extensions: runs of equal lists ---------------------------------
    runs = []
    for c in sorted(ext):
        if runs and runs[-1][1] == c - 1 and runs[-1][2] == ext[c]:
            runs[-1][1] = c
        else:
            runs.append([c, c, ext[c]])
    pool, off = [], [0]
    for r in runs:
        pool += r[2]
        off.append(len(pool))

    def mine(c):
        return ext.get(c, [script[c]])
    icu = []
    for line in u.oracle_go("icescriptext"):
        a, b, v = line.split()
        icu.append((int(a, 16), int(b, 16), sorted(index[x] for x in v.split(","))))
    for a, b, lst in icu:
        for c in range(a, b + 1):
            if mine(c) != lst:
                u.fail("script extensions of %04X differ from ICU: %s, %s" % (c, mine(c), lst))

    # ---- the blocks -----------------------------------------------------------
    blocks = []
    for line in u.lines_of("Blocks.txt"):
        p = [x.strip() for x in line.split(";")]
        a, b = u.parse_range(p[0])
        blocks.append((a, b, p[1]))
    blocks.sort()
    bmap = {}
    for a, b, n in blocks:
        for c in range(a, b + 1):
            bmap[c] = norm(n)
    for line in u.oracle_go("icuprop", "4097"):
        a, b, v = line.split()
        for c in range(int(a, 16), int(b, 16) + 1):
            if bmap.get(c, "noblock") != norm(v):
                u.fail("block of %04X differs from ICU: %s" % (c, v))

    # ---- the age ---------------------------------------------------------------
    age = [0] * (u.MAX_CP + 1)
    for line in u.lines_of("DerivedAge.txt"):
        p = [x.strip() for x in line.split(";")]
        a, b = u.parse_range(p[0])
        major, minor = p[1].split(".")
        for c in range(a, b + 1):
            age[c] = int(major) * 100 + int(minor)
    icu_age = []
    for line in u.oracle_go("iceage"):
        a, b, v = line.split()
        major, minor = v.split(".")
        val = int(major) * 100 + int(minor)
        icu_age.append((int(a, 16), int(b, 16), val))
        for c in range(int(a, 16), int(b, 16) + 1):
            if age[c] != val:
                u.fail("age of %04X differs from ICU: %d, %d" % (c, age[c], val))

    # ---- the tables ---------------------------------------------------------------
    bnames = "".join(n for _, _, n in blocks)
    boff = [0]
    for _, _, n in blocks:
        boff.append(boff[-1] + len(n))
    ar = u.runs_of(age, skip=0)
    parts = [
        u.array("ES_START", [r[0] for r in runs], "The first code point of each run that shares a list of scripts."),
        u.array("ES_END", [r[1] for r in runs], "The last code point of each run."),
        u.array("ES_OFF", off, "The start of the list of each run in ES_POOL."),
        u.array("ES_POOL", pool, "The script numbers of the lists."),
        u.array("BK_START", [b[0] for b in blocks], "The first code point of each block."),
        u.array("BK_END", [b[1] for b in blocks], "The last code point of each block."),
        u.string("BK_NAMES", bnames),
        u.array("BK_NAME_OFF", boff, "The start of each block name in BK_NAMES."),
        u.array("AG_START", [r[0] for r in ar], "The first code point of each run of one age."),
        u.array("AG_END", [r[1] for r in ar], "The last code point of each run."),
        u.array("AG_VAL", [r[2] for r in ar], "The age of each run: the major number times 100 plus the minor number."),
    ]
    u.write_goose(os.path.join(u.ROOT, "script_data.goose"), "make_script_data.py", parts)

    suite = [
        u.array("SX_START", [r[0] for r in icu], "The first code point of each ICU run of script lists."),
        u.array("SX_END", [r[1] for r in icu], "The last code point of each run."),
        u.array("SX_OFF", [0] + [sum(len(x[2]) for x in icu[:k + 1]) for k in range(len(icu))], "The start of each list in SX_POOL."),
        u.array("SX_POOL", [v for r in icu for v in r[2]], "The script numbers of the lists."),
        u.array("SA_START", [r[0] for r in icu_age], "The first code point of each ICU run of one age."),
        u.array("SA_END", [r[1] for r in icu_age], "The last code point of each run."),
        u.array("SA_VAL", [r[2] for r in icu_age], "The age of each run."),
    ]
    u.write_goose(os.path.join(u.ROOT, "test", "suite", "script_cases.goose"),
                  "make_script_data.py", suite, "suite")
    print("script_data.goose: %d extension runs, %d blocks, %d age runs" % (len(runs), len(blocks), len(ar)))


if __name__ == "__main__":
    main()
