#!/usr/bin/env python3
"""Make title_data.goose: the title case mapping of every code point.

The mapping comes from the title column of SpecialCasing.txt, with the
fallback of the standard: the titlecase field of UnicodeData.txt, then
the uppercase field. The unconditional entries only stay; the entries
with a condition or a language tag stay out. The script checks the table
against two sources and exits with an error on the first difference: the
Go library golang.org/x/text/cases and the Rust unicode-case-mapping
crate. The crate holds an older release of the standard, so the code
points that the newest release added may differ there; the script warns
about each one. Usage: make_title_data.py [ucd directory]
"""
import os
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ucdlib as u


def parse_special_casing():
    """The unconditional title mappings. Returns a dict of lists."""
    title = {}
    for line in u.lines_of("SpecialCasing.txt"):
        parts = [x.strip() for x in line.split(";")]
        if len(parts) > 4 and parts[4]:
            continue  # the entry holds a condition, so it stays out
        lo, hi = u.parse_range(parts[0])
        for cp in range(lo, hi + 1):
            if parts[2]:
                title[cp] = [int(x, 16) for x in parts[2].split()]
    return title


def derive(rows, full):
    """The table. Every code point whose mapping differs from itself."""
    table = {}
    for cp in range(0x110000):
        want = full.get(cp)
        if want is None:
            f = rows.get(cp)
            t = f[14] if f and f[14] else (f[12] if f and f[12] else None)
            want = [int(t, 16)] if t else None
        if want and want != [cp]:
            table[cp] = want
    return table


def emit(table):
    cps = sorted(table)
    off = [0]
    for cp in cps:
        off.append(off[-1] + len(table[cp]))
    pool = [c for cp in cps for c in table[cp]]
    return cps, off, pool


def hexes(cps):
    return " ".join("%04X" % c for c in cps)


def main():
    u.check_version()
    rows = u.unicode_data()
    full = parse_special_casing()
    table = derive(rows, full)

    # The first source: the Go library, over every code point.
    go = u.oracle_go("titlecp")
    if len(go) != len(table):
        u.fail("the Go oracle holds %d mappings, the tables hold %d"
               % (len(go), len(table)))
    for line in go:
        f = line.split()
        cp = int(f[0], 16)
        if hexes(table[cp]) != " ".join(f[1:]):
            u.fail("title of %04X differs from Go: %s, %s"
                   % (cp, hexes(table[cp]), " ".join(f[1:])))

    # The second source: the Rust crate. The crate holds an older
    # release of the standard, so the newest code points may differ.
    binary = os.path.join(u.HERE, "oracle", "target", "release", "title")
    if not os.path.exists(binary):
        subprocess.run(["cargo", "build", "--release", "--bin", "title"],
                       cwd=os.path.join(u.HERE, "oracle"), check=True)
    crate = subprocess.run([binary], capture_output=True,
                           text=True).stdout.splitlines()
    warn = 0
    if len(crate) > len(table):
        u.fail("the Rust crate holds more mappings than the table")
    for line in crate:
        f = line.split()
        cp = int(f[0], 16)
        if cp not in table:
            u.fail("the Rust crate maps %04X, the table maps it to itself" % cp)
        if hexes(table[cp]) != " ".join(f[1:]):
            warn += 1
            print("warning: the crate gives an older title of %04X" % cp)
    stale = len(table) - len(crate) - warn
    if stale:
        print("warning: the crate misses %d mappings of the newest code points" % stale)

    # ---- the tables -------------------------------------------------------
    cps, off, pool = emit(table)
    parts = [
        u.array("TITLE_CP", cps, "The code point of each title mapping."),
        u.array("TITLE_OFF", off, "The start of each result in TITLE_POOL."),
        u.array("TITLE_POOL", pool, "The code points of the title results."),
    ]
    u.write_goose(os.path.join(u.ROOT, "title_data.goose"),
                  "make_title_data.py", parts)

    # ---- the suite tables -------------------------------------------------
    # The same enumeration, for the suite to check every code point.
    suite = [
        u.array("TC_CP", cps, "The code point of each title mapping."),
        u.array("TC_OFF", off, "The start of each result in TC_POOL."),
        u.array("TC_POOL", pool, "The code points of the title results."),
    ]
    # The texts of the title call, with the output of the Go library.
    texts = [
        "",
        "don't stop",
        "ǳina ǲ ǳ ǲ",
        "straße STRASSE",
        "ΟΟΣ ΟΣ ος",
        "ﬁ sh ﬃ",
        "hello world",
        "abc.def GHI",
        "a_b c'd",
        "e.g. the U.S.A.",
        "x'y'z",
        "1st place",
        "abcdef",
        "ABCDEF",
        "ΑΒ ΓΔ",
        " DRV",
        "İstanbul ı",
        "á́b",
        "the ­ quick l'intérim",
        "''quoted''",
    ]
    t = u.oracle_go("title", stdin="\n".join(hexes([ord(c) for c in x])
                                             for x in texts) + "\n")
    if len(t) != len(texts):
        u.fail("the Go oracle returned %d lines for %d texts" % (len(t), len(texts)))
    in_pool, out_pool, in_off, out_off = [], [], [0], [0]
    for x in texts:
        in_pool += [ord(c) for c in x]
        in_off.append(len(in_pool))
    for line in t:
        out_pool += [int(w, 16) for w in line.split()]
        out_off.append(len(out_pool))
    suite.append(u.array("TT_IN_POOL", in_pool, "The code points of each input text."))
    suite.append(u.array("TT_OUT_POOL", out_pool, "The code points of each title text of the library."))
    suite.append(u.array("TT_IN_OFF", in_off, "The end of each input text."))
    suite.append(u.array("TT_OUT_OFF", out_off, "The end of each title text."))
    u.write_goose(os.path.join(u.ROOT, "test", "suite", "title_cases.goose"),
                  "make_title_data.py", suite, "suite")
    print("title_data.goose: %d title mappings" % len(cps))
    print("title_cases.goose: %d texts" % len(texts))


if __name__ == "__main__":
    main()
