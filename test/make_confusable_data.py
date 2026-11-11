#!/usr/bin/env python3
"""Make confusable_data.goose: the confusable table of the standard.

The table comes from confusables.txt of the security data of the
Unicode standard. Every row holds one source code point and its
target. The target holds one or more code points. The script writes
the table as a sorted list of sources with a pool of targets.

The script also writes the suite tables. The skeleton of a text is
the text in the canonical form, then the default ignorables dropped,
then every code point mapped through the table, then the canonical
form again. The script computes that result for every source and for
a set of texts. It asks the ICU 78 library for the same skeletons.
The ICU library ships an older revision of the table, so the two
differ on the sources whose rows changed. The script counts them.

Usage: make_confusable_data.py [ucd directory]
"""
import os
import random
import sys
import unicodedata

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ucdlib as u

CONF = "confusables.txt"


def parse_rows():
    """The rows of confusables.txt: source code point -> target tuple."""
    rows = {}
    path = os.path.join(u.ucd_dir(), CONF)
    with open(path, encoding="utf-8") as f:
        for line in f:
            line = line.split("#")[0].strip()
            if not line:
                continue
            parts = [x.strip() for x in line.split(";")]
            if len(parts) < 2:
                continue
            src = parts[0].split()
            tgt = parts[1].split()
            if len(src) != 1 or not tgt:
                continue
            rows[int(src[0], 16)] = tuple(int(x, 16) for x in tgt)
    if len(rows) < 1000:
        u.fail("only %d confusable rows" % len(rows))
    return rows


def ignorable(cp):
    """True for a code point of Default_Ignorable_Code_Point. The set
    comes from the ICU library, through the property table of the
    package."""
    return cp in IGNORABLE


def skeleton(cps, rows):
    """The skeleton of a text: the canonical form, the default
    ignorables dropped, every code point mapped, then the canonical
    form again."""
    text = "".join(chr(c) for c in cps)
    text = unicodedata.normalize("NFD", text)
    out = []
    for ch in text:
        cp = ord(ch)
        if ignorable(cp):
            continue
        out.extend(rows.get(cp, (cp,)))
    return [ord(c) for c in unicodedata.normalize("NFD", "".join(chr(c) for c in out))]


def load_ignorable():
    """The code points of Default_Ignorable_Code_Point, from the ICU
    library."""
    cps = set()
    for line in u.oracle_go("icebin", "Default_Ignorable_Code_Point"):
        a, b, _ = line.split()
        cps.update(range(int(a, 16), int(b, 16) + 1))
    if len(cps) < 100:
        u.fail("only %d default ignorable code points" % len(cps))
    return cps


def main():
    u.check_version()
    global IGNORABLE
    IGNORABLE = load_ignorable()
    rows = parse_rows()

    # The table: the sources in order, and the targets in a pool.
    srcs = sorted(rows)
    off = [0]
    pool = []
    for s in srcs:
        pool += list(rows[s])
        off.append(len(pool))
    data = [
        u.array("CONF_CP", srcs, "The source code point of each row, sorted."),
        u.array("CONF_OFF", off, "The end of the target of each row in CONF_POOL."),
        u.array("CONF_POOL", pool, "The code points of all targets."),
    ]
    u.write_goose(os.path.join(u.ROOT, "confusable_data.goose"),
                  "make_confusable_data.py", data)

    # ---- the suite tables -----------------------------------------
    # The skeleton of every source, by the rule of the standard and by
    # the ICU library.
    lines = ["%X" % s for s in srcs]
    icu = u.oracle_go("iceskel", stdin="\n".join(lines) + "\n")
    if len(icu) != len(lines):
        u.fail("the ICU oracle returned %d skeletons for %d sources"
               % (len(icu), len(lines)))
    want_pool = []
    want_off = [0]
    icu_pool = []
    icu_off = [0]
    differ = 0
    for s, sk in zip(srcs, icu):
        mine = skeleton([s], rows)
        theirs = [int(x, 16) for x in sk.split()]
        if mine != theirs:
            differ += 1
        want_pool += mine
        want_off.append(len(want_pool))
        icu_pool += theirs
        icu_off.append(len(icu_pool))

    # The texts of several code points.
    rng = random.Random(20261112)
    texts = [
        [0x0430, 0x0062, 0x0063],
        [0x0430, 0x0435, 0x0441],
        [0x006D, 0x006E],
        [0x2167, 0x0041],
        [0xFF21, 0xFF22],
        [0x0061, 0x0301, 0x0062],
        [0x212A, 0x004B],
        [0x00E9, 0x0065],
        [0x037A],
        [0x00AD, 0x0041],
    ]
    for _ in range(300):
        n = rng.randrange(2, 5)
        texts.append([rng.choice(srcs) for _ in range(n)])
    tlines = [" ".join("%X" % c for c in t) for t in texts]
    ticu = u.oracle_go("iceskel", stdin="\n".join(tlines) + "\n")
    if len(ticu) != len(tlines):
        u.fail("the ICU oracle returned %d skeletons for %d texts"
               % (len(ticu), len(tlines)))
    twant_pool = []
    twant_off = [0]
    ticu_pool = []
    ticu_off = [0]
    for t, sk in zip(texts, ticu):
        mine = skeleton(t, rows)
        theirs = [int(x, 16) for x in sk.split()]
        twant_pool += mine
        twant_off.append(len(twant_pool))
        ticu_pool += theirs
        ticu_off.append(len(ticu_pool))

    suite = [
        u.array("CS_SRC_OFF", list(range(len(srcs) + 1)), "The end of each source in CS_SRC_POOL."),
        u.array("CS_SRC_POOL", srcs, "The source code point of each row."),
        u.array("CS_WANT_OFF", want_off, "The end of each skeleton in CS_WANT_POOL."),
        u.array("CS_WANT_POOL", want_pool, "The code points of each skeleton by the rule of the standard."),
        u.array("CS_ICU_OFF", icu_off, "The end of each skeleton in CS_ICU_POOL."),
        u.array("CS_ICU_POOL", icu_pool, "The code points of each skeleton from ICU."),
        u.array("CS_TXT_OFF", list(__import__("itertools").accumulate([len(t) for t in texts], initial=0)),
                "The end of each text in CS_TXT_POOL."),
        u.array("CS_TXT_POOL", [c for t in texts for c in t], "The code points of each text."),
        u.array("CS_TXT_WANT_OFF", twant_off, "The end of each text skeleton in CS_TXT_WANT_POOL."),
        u.array("CS_TXT_WANT_POOL", twant_pool, "The code points of each text skeleton by the rule of the standard."),
        u.array("CS_TXT_ICU_OFF", ticu_off, "The end of each text skeleton in CS_TXT_ICU_POOL."),
        u.array("CS_TXT_ICU_POOL", ticu_pool, "The code points of each text skeleton from ICU."),
    ]
    u.write_goose(os.path.join(u.ROOT, "test", "suite", "confusable_cases.goose"),
                  "make_confusable_data.py", suite, "suite")
    print("confusable_data.goose: %d rows" % len(srcs))
    print("confusable_cases.goose: %d sources, %d texts, %d differ from ICU"
          % (len(srcs), len(texts), differ))


if __name__ == "__main__":
    main()
