#!/usr/bin/env python3
"""Make test/suite/locale_cases.goose: the locale aware case mapping.

The rows come from the ICU library, release 79.1, which holds the release
of the tables. For each locale, tr, az and lt, and each case, upper, lower
and title, the script runs ICU over the battery: every text of one to four
characters over 16 characters around the rules. It keeps the rows whose
result differs from the result of the root locale. Rows of one to three
characters are all kept. Rows of four characters are sampled, so that no
group holds more than 600 rows. The suite replays the rows against the
calls of the package.

The script also checks Node: the upper and the lower case of the code
points that the release of Node holds, for the three locales. A row whose
result holds a code point that Node does not know stays out. Node gives no
locale title case. A difference from ICU is an error.

Usage: make_locale_data.py
"""
import itertools
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ucdlib as u

CHARS = [0x49, 0x69, 0x4A, 0x6A, 0x12E, 0x130, 0x131, 0xCC, 0x249, 0x307,
         0x300, 0x316, 0x327, 0x61, 0x20, 0x3A3]
LOCALES = [("tr", "TR"), ("az", "AZ"), ("lt", "LT")]
KINDS = [("upper", "UP"), ("lower", "LO"), ("title", "TI")]
CAP = 600


def battery():
    out = []
    for n in range(1, 5):
        for t in itertools.product(CHARS, repeat=n):
            out.append(t)
    return out


def icu(tag, kind, lines):
    data = "\n".join(lines) + "\n"
    return u.oracle_go("icelocale", tag, kind, stdin=data)


def main():
    u.check_version()
    held = u.held()
    texts = battery()
    lines = [" ".join("%X" % c for c in t) for t in texts]
    cps_lines = lines
    path = os.path.join(u.ROOT, "tmp")
    os.makedirs(path, exist_ok=True)
    infile = os.path.join(path, "locale_diff_in.txt")
    with open(infile, "w") as f:
        f.write("\n".join(lines) + "\n")

    root_cache = {}
    parts = []
    checked = 0
    for tag, tn in LOCALES:
        for kind, kn in KINDS:
            ice = icu(tag, kind, lines)
            root = root_cache.setdefault(kind, icu("", kind, lines))
            keep = [i for i in range(len(texts)) if ice[i] != root[i]]
            short = [i for i in keep if len(texts[i]) <= 3]
            long_ = [i for i in keep if len(texts[i]) == 4]
            step = max(1, (len(long_) + CAP - 1) // CAP)
            sel = short + long_[::step]
            sel.sort()
            in_pool, in_off, out_pool, out_off = [], [0], [], [0]
            for i in sel:
                cps = texts[i]
                got = [int(x, 16) for x in ice[i].split()]
                in_pool += cps
                in_off.append(len(in_pool))
                out_pool += got
                out_off.append(len(out_pool))
            p = "LOC_%s_%s" % (tn, kn)
            parts.append(u.array(p + "_IN_POOL", in_pool, "The code points of each input text for %s %s." % (tag, kind)))
            parts.append(u.array(p + "_IN_OFF", in_off, "The end of each input text."))
            parts.append(u.array(p + "_OUT_POOL", out_pool, "The code points of each result from ICU 79.1."))
            parts.append(u.array(p + "_OUT_OFF", out_off, "The end of each result."))
            print("%s %-5s: %d rows differ from the root, %d in the suite" % (tag, kind, len(keep), len(sel)))
            checked += len(sel)

    # Node judges the held code points for the upper and the lower case.
    # A row stays out when its result holds a code point that the release
    # of Node does not know. Four code points map to new upper case letters
    # of release 18.0, and Node gives them unchanged.
    cps = ["%X" % c for c in range(u.MAX_CP + 1) if not 0xD800 <= c <= 0xDFFF and held[c]]
    judged = 0
    for tag, _ in LOCALES:
        for kind in ("upper", "lower"):
            ice = icu(tag, kind, cps)
            keep = [i for i in range(len(cps))
                    if all(held[int(x, 16)] for x in ice[i].split())]
            node = u.oracle_node("locale.mjs", tag, kind,
                                 stdin="\n".join(cps[i] for i in keep) + "\n")
            bad = sum(1 for i, b in zip(keep, node)
                      if ice[i].upper().split() != b.upper().split())
            judged += len(keep)
            if bad:
                u.fail("node differs from icu on %d code points for %s %s" % (bad, tag, kind))
    print("node judged %d code point results" % judged)
    print("%d battery rows in the suite" % checked)
    u.write_goose(os.path.join(u.ROOT, "test", "suite", "locale_cases.goose"),
                  "make_locale_data.py", parts, "suite")


if __name__ == "__main__":
    main()
