#!/usr/bin/env python3
"""Make the reference cases of the test suites.

The cases hold numbers only. They come from three sources:
  NormalizationTest.txt   the conformance cases of the normalization standard
  GraphemeBreakTest.txt   the conformance cases of the cluster split
  the Go oracle           the simple case mappings and the categories
The script checks the normalization cases against Node (ICU 78) and Go
(Unicode 17.0.0) before it writes them, and it fails on a difference.
Usage: make_vectors.py [ucd directory]
"""
import os
import sys
import unicodedata

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ucdlib as u

OUT = os.path.join(u.HERE, "suite")


def write(name, script_note, parts):
    path = os.path.join(OUT, name)
    with open(path, "w", encoding="utf-8") as f:
        f.write("// Reference cases for the test suites, %s.\n" % script_note)
        f.write("// Made by test/make_vectors.py. Do not edit by hand.\n")
        f.write("namespace suite;\n\n")
        f.write("\n".join(parts))


def hexlist(text):
    return [int(x, 16) for x in text.split()]


def normalization():
    cases = []
    for line in u.lines_of("NormalizationTest.txt"):
        if line.startswith("@"):
            continue
        cols = line.split(";")[:5]
        cases.append([hexlist(c) for c in cols])
    # Check the file against Node and Go.
    text = "\n".join("|".join(" ".join("%04X" % c for c in col) for col in case) for case in cases) + "\n"
    node = u.oracle_node("normalize.mjs", stdin=text)
    go = u.oracle_go("nt", stdin=text)
    if len(node) != len(cases) or len(go) != len(cases):
        u.fail("the oracle line counts differ")
    for case, nl, gl in zip(cases, node, go):
        if nl != gl:
            u.fail("Node and Go differ on %r" % case)
        outs = [o.split() for o in nl.split("|")]
        # outs[col*4 + form] with forms NFC, NFD, NFKC, NFKD
        def form(col, k):
            return [int(x, 16) for x in outs[col * 4 + k]]
        c1, c2, c3, c4, c5 = case
        for col in range(5):
            if form(col, 0) != (c2 if col < 3 else c4):
                u.fail("NFC differs from the file on %r" % case)
            if form(col, 1) != (c3 if col < 3 else c5):
                u.fail("NFD differs from the file on %r" % case)
            if form(col, 2) != c4 or form(col, 3) != c5:
                u.fail("a compatibility form differs from the file on %r" % case)
    off, pool = [], []
    for case in cases:
        for col in case:
            off.append(len(pool))
            pool.extend(col)
    off.append(len(pool))
    write("norm_cases.goose", "normalization conformance", [
        "// Five columns for each case, as in the file NormalizationTest.txt of Unicode 17.0.0.\n"
        + u.array("NT_OFF", off, "Start of each column in NT_POOL. Five columns for each case. One more entry ends the last."),
        u.array("NT_POOL", pool, "The code points of all columns."),
    ])
    print("normalization cases %d, pool %d, checked against Node and Go" % (len(cases), len(pool)))


def grapheme():
    pool, off = [], []
    n = 0
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
            elif t != "X":
                cps.append(int(t, 16))
                run += 1
        off.append(len(pool))
        pool.append(len(cps))
        pool.extend(cps)
        pool.append(len(sizes))
        pool.extend(sizes)
        n += 1
    off.append(len(pool))
    write("grapheme_cases.goose", "cluster split conformance", [
        u.array("GB_OFF", off, "Start of each case in GB_POOL. One more entry ends the last."),
        u.array("GB_POOL", pool, "For each case: the count of code points, the code points, the count of clusters, the size of each cluster in code points."),
    ])
    print("grapheme cases %d" % n)


TRICKY = [
    [0x61, 0x301], [0x61, 0x301, 0x62], [0x61, 0x328, 0x301],
    [0x61, 0x301, 0x328], [0x44, 0x307, 0x301], [0x61, 0x300, 0x301],
    [0x61, 0x301, 0x300], [0x61, 0x308, 0x301], [0x61, 0x301, 0x308],
    [0x61, 0x327, 0x301], [0x61, 0x334, 0x301], [0x61, 0x301, 0x301],
    [0x41, 0x308, 0x301], [0x61, 0x344], [0x61, 0x334, 0x301, 0x308],
    [0x44, 0x307, 0x301, 0x323], [0x1E0A, 0x323], [0x1E0C, 0x307],
    [0x44, 0x307, 0x323], [0x1E0A, 0x31B], [0x1E0A, 0x31B, 0x323],
    [0x45, 0x304, 0x300], [0x1E14], [0x45, 0x300, 0x304],
    [0x1100, 0x1161, 0x11A8], [0xAC01], [0xAC00, 0x11A8],
    [0xAC00, 0x0323], [0x212B], [0x2126], [0x1E9B, 0x323],
    [0x0F77, 0x0F81], [0x0F71, 0x0F72], [0x0F73], [0x0F74, 0x0F75],
    [0x09DC], [0x0958], [0x0A33], [0x0B5C], [0xFB2C], [0x1D15E],
    [0x2ADC], [0x1F82, 0x1F83], [0x0344], [0x0958, 0x093C],
    [0x0041, 0x0316, 0x0307], [0x0061, 0x05AE, 0x05C1],
    [0x0F43, 0x0FB7], [0x1D160, 0x1D16E], [0x1D1BB, 0x1D165],
    [0x0A33, 0x0A3C], [0x0F71, 0x0F72, 0x0F73],
]


def tricky():
    """Cases of combining marks, with the four forms from Node."""
    lines = []
    for seq in TRICKY:
        lines.append(" ".join("%04X" % c for c in seq))
    node = u.oracle_node("normalize.mjs", stdin="\n".join(lines) + "\n")
    if len(node) != len(TRICKY):
        u.fail("the oracle line count differs")
    pool, off = [], []
    for seq, line in zip(TRICKY, node):
        parts = line.split("|")
        if len(parts) != 4:
            u.fail("the oracle gave %d columns" % len(parts))
        cols = [list(seq)] + [[int(x, 16) for x in part.split()] for part in parts]
        for col in cols:
            off.append(len(pool))
            pool.extend(col)
    off.append(len(pool))
    write("tricky_cases.goose", "combining mark cases", [
        u.array("TR_OFF", off, "Start of each column in TR_POOL. Five columns for each case."),
        u.array("TR_POOL", pool, "The code points of the input and of the four forms."),
    ])
    print("tricky cases %d" % len(TRICKY))


def exclusions():
    """The composition exclusions: each pair stays apart from its composite."""
    data = u.unicode_data()
    triples = []
    for line in u.lines_of("CompositionExclusions.txt"):
        cp = int(line.split(";")[0], 16)
        a, b = data[cp][5].split()
        triples.extend([int(a, 16), int(b, 16), cp])
    write("exclusion_cases.goose", "composition exclusions", [
        u.array("EXCL_CASE", triples, "For each excluded composite: the two code points of its decomposition, then the composite."),
    ])
    print("exclusion cases %d" % (len(triples) // 3))


def properties():
    cat = []
    for line in u.oracle_go("cat"):
        a, b, name = line.split()
        cat.extend([int(a, 16), int(b, 16), u.CATS.index(name)])
    ccc = []
    for line in u.oracle_go("ccc"):
        a, b, v = line.split()
        ccc.extend([int(a, 16), int(b, 16), int(v)])
    up, lo = [], []
    for line in u.oracle_go("upper"):
        a, b = line.split()
        up.extend([int(a, 16), int(b, 16)])
    for line in u.oracle_go("lower"):
        a, b = line.split()
        lo.extend([int(a, 16), int(b, 16)])
    fold = []
    for line in u.lines_of("CaseFolding.txt"):
        p = [x.strip() for x in line.split(";")]
        if p[1] in ("C", "F"):
            seq = [int(x, 16) for x in p[2].split()]
            fold.extend([int(p[0], 16), len(seq)] + seq)
    write("property_cases.goose", "categories, classes and case", [
        u.array("PC_CAT", cat, "Runs of equal category from the Go standard library: first, last, category."),
        u.array("PC_CCC", ccc, "Runs of a combining class above zero from x/text: first, last, class."),
        u.array("PC_UP", up, "Simple upper case from the Go standard library: code point, result."),
        u.array("PC_LO", lo, "Simple lower case from the Go standard library: code point, result."),
        u.array("PC_FOLD", fold, "Full case folding from the Unicode data: code point, length, result."),
    ])
    print("property cases: categories %d runs, classes %d runs, upper %d, lower %d" % (len(cat) // 3, len(ccc) // 3, len(up) // 2, len(lo) // 2))


def main():
    u.check_version()
    os.makedirs(OUT, exist_ok=True)
    normalization()
    tricky()
    grapheme()
    properties()
    exclusions()


main()
