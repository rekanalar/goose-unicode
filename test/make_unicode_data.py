#!/usr/bin/env python3
"""Make unicode_data.goose: categories, combining classes and case tables.

The tables come from UnicodeData.txt and CaseFolding.txt of the Unicode
Character Database 17.0.0. Each table is checked against a second source:
Go (Unicode 17.0.0) for the categories, the combining classes and the
simple case mappings, and Python str.casefold for the full case folding of
the code points that Python 16.0.0 knows. The script exits with an error
on the first difference. Usage: make_unicode_data.py [ucd directory]
"""
import os
import sys
import unicodedata

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ucdlib as u


def main():
    u.check_version()
    rows = u.unicode_data()
    n = u.MAX_CP + 1

    cat = [0] * n
    ccc = [0] * n
    for cp, f in rows.items():
        cat[cp] = u.CATS.index(f[2])
        ccc[cp] = int(f[3])

    cat_runs = u.runs_of(cat)
    cat_start = [r[0] for r in cat_runs]
    cat_val = [r[2] for r in cat_runs]
    ccc_runs = u.runs_of(ccc, skip=0)

    upper = {}
    lower = {}
    for cp, f in rows.items():
        if f[12]:
            upper[cp] = int(f[12], 16)
        if f[13]:
            lower[cp] = int(f[13], 16)

    # The full case folding: the common and the full entries.
    fold = {}
    for line in u.lines_of("CaseFolding.txt"):
        p = [x.strip() for x in line.split(";")]
        if p[1] in ("C", "F"):
            fold[int(p[0], 16)] = [int(x, 16) for x in p[2].split()]

    # ---- the second sources --------------------------------------
    go_cat = []
    for line in u.oracle_go("cat"):
        a, b, name = line.split()
        go_cat.append((int(a, 16), int(b, 16), u.CATS.index(name)))
    if go_cat != cat_runs:
        for x, y in zip(go_cat, cat_runs):
            if x != y:
                u.fail("category runs differ: Go %r, table %r" % (x, y))
        u.fail("category run counts differ: Go %d, table %d" % (len(go_cat), len(cat_runs)))

    go_ccc = []
    for line in u.oracle_go("ccc"):
        a, b, v = line.split()
        go_ccc.append((int(a, 16), int(b, 16), int(v)))
    if go_ccc != ccc_runs:
        for x, y in zip(go_ccc, ccc_runs):
            if x != y:
                u.fail("combining class runs differ: Go %r, table %r" % (x, y))
        u.fail("combining class run counts differ")

    for mode, table in (("upper", upper), ("lower", lower)):
        go = {}
        for line in u.oracle_go(mode):
            a, b = line.split()
            go[int(a, 16)] = int(b, 16)
        if go != table:
            diff = sorted(set(go.items()) ^ set(table.items()))[:3]
            u.fail("the %s mapping differs from Go: %r" % (mode, diff))

    # Python 16.0.0 folds the code points that it knows.
    checked = 0
    for cp in range(n):
        if 0xD800 <= cp <= 0xDFFF or unicodedata.category(chr(cp)) == "Cn":
            continue
        want = [ord(c) for c in chr(cp).casefold()]
        have = fold.get(cp, [cp])
        if want != have:
            u.fail("the fold of U+%04X differs from Python: %r against %r" % (cp, have, want))
        checked += 1

    # ---- the output ----------------------------------------------
    up_cp = sorted(upper)
    lo_cp = sorted(lower)
    fold_cp = sorted(fold)
    pool = []
    off = []
    for cp in fold_cp:
        off.append(len(pool))
        pool.extend(fold[cp])
    off.append(len(pool))

    parts = [
        u.array("CAT_START", cat_start, "First code point of each category run. The runs cover all code points."),
        u.array("CAT_VAL", cat_val, "The category of each run, as the CAT_ constants."),
        u.array("CCC_START", [r[0] for r in ccc_runs], "First code point of each run with a combining class above zero."),
        u.array("CCC_END", [r[1] for r in ccc_runs], "Last code point of each run."),
        u.array("CCC_VAL", [r[2] for r in ccc_runs], "The combining class of each run."),
        u.array("UP_CP", up_cp, "Code points with a simple upper case mapping, sorted."),
        u.array("UP_TO", [upper[c] for c in up_cp], "The upper case code point of each."),
        u.array("LO_CP", lo_cp, "Code points with a simple lower case mapping, sorted."),
        u.array("LO_TO", [lower[c] for c in lo_cp], "The lower case code point of each."),
        u.array("FOLD_CP", fold_cp, "Code points with a full case folding, sorted."),
        u.array("FOLD_OFF", off, "Start of the fold of each code point in FOLD_POOL. One more entry ends the last."),
        u.array("FOLD_POOL", pool, "The code points of all folds."),
    ]
    u.write_goose(os.path.join(u.ROOT, "unicode_data.goose"), "make_unicode_data.py", parts)
    print("categories %d runs, combining classes %d runs, upper %d, lower %d, fold %d (%d code points of the pool)"
          % (len(cat_start), len(ccc_runs), len(up_cp), len(lo_cp), len(fold_cp), len(pool)))
    print("checked against Go; fold checked against Python for %d code points" % checked)


main()
