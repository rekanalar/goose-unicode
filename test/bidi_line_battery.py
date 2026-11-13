#!/usr/bin/env python3
"""Compare the paragraph and line calls of the package with ICU 79.1 and
the Rust crate unicode-bidi.

Usage: bidi_line_battery.py [cases] [seed] [goose binary]

The script builds the cases of bidi_line_lib, asks the oracles, works out
the expected answer and runs the package on the same lines. It prints the
count of cases and the count of differences for each class of text. It
exits nonzero when the package gives another answer than the expected
one, or when the oracles differ in a way that no class explains.
"""
import os
import sys
from collections import Counter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bidi_line_lib as lib
import ucdlib as u


def compare(case, exp, got):
    """The first difference between the expected answer and the package
    answer, or None."""
    if got.get("P") != exp["P"]:
        return "paragraphs: expected %s, got %s" % (exp["P"], got.get("P"))
    if "E" in exp:
        if "E" not in got:
            return "expected a fault, got %s" % got
        return None
    if "E" in got:
        return "fault %s" % got["E"]
    if exp.get("L") is not None and got.get("L") != exp["L"]:
        return "levels: expected %s, got %s" % (exp["L"], got.get("L"))
    if got.get("O") != exp["O"]:
        return "order: expected %s, got %s" % (exp["O"], got.get("O"))
    for f, want in exp["W"].items():
        if got.get("W", {}).get(f) != want:
            return "text with flags %d: expected %s, got %s" % (
                f, ["%X" % c for c in want], got.get("W", {}).get(f))
    return None


def check_controls():
    """The code points of Bidi_Control in ICU 79.1 equal the list of the
    standard that the package reads. Flag 8 removes exactly these."""
    want = set()
    path = os.path.join(u.ROOT, "..", "..", "tmp", "ucd18", "PropList.txt")
    for row in open(path, encoding="utf-8"):
        row = row.split("#")[0]
        if ";" not in row:
            continue
        rng, prop = [x.strip() for x in row.split(";")]
        if prop == "Bidi_Control":
            a, b = u.parse_range(rng)
            want.update(range(a, b + 1))
    got = {int(x, 16) for x in u.oracle_go("icubidicontrol") if x.strip()}
    if got != want:
        print("FAIL: Bidi_Control differs: only ICU %s, only the list %s"
              % (sorted(got - want), sorted(want - got)))
        return 1
    print("Bidi_Control: %d code points equal in ICU and in the list" % len(got))
    return 0


def check_go_paragraphs(cases, goose):
    """The paragraph split equals the split of Go x/text for the texts that
    hold no CR LF. Go takes one paragraph for each call and reports the
    bytes of each one."""
    texts = []
    for c in cases:
        if not lib.has_crlf(c[4]) and c[4] not in texts:
            texts.append(c[4])
        if len(texts) == 100:
            break
    lines = [" ".join("%X" % x for x in t) for t in texts]
    go = u.oracle_go("gobidi", stdin="\n".join(lines) + "\n")
    mine = lib.run_package(["0 0 0 | " + l for l in lines], goose)
    bad = 0
    for t, g, m in zip(texts, go, mine):
        sizes = []
        par = m["P"]
        for k in range(0, len(par), 3):
            sizes.append(sum(len(chr(x).encode("utf-8", "surrogatepass"))
                             for x in t[par[k]:par[k + 1]]))
        if [int(x) for x in g.split()] != sizes:
            bad += 1
            print("FAIL: Go splits %s as %s, the package as %s" % (lines[texts.index(t)], g, sizes))
    print("Go paragraph split: %d texts, %d differences" % (len(texts), bad))
    return 1 if bad else 0


def main():
    count = int(sys.argv[1]) if len(sys.argv) > 1 else 3000
    seed = int(sys.argv[2]) if len(sys.argv) > 2 else 1
    goose = sys.argv[3] if len(sys.argv) > 3 else "goose"
    cases = lib.build(seed, count)
    extra = check_controls() + check_go_paragraphs(cases, goose)
    lines = [lib.line_of(c) for c in cases]
    icu = lib.run_icu(lines)
    rust = lib.run_rust(lines)
    pkg = lib.run_package(lines, goose)
    if not (len(icu) == len(rust) == len(pkg) == len(cases)):
        print("FAIL: the outputs hold %d, %d, %d lines for %d cases"
              % (len(icu), len(rust), len(pkg), len(cases)))
        return 1
    seen = Counter()
    bad = Counter()
    shown = 0
    unexplained = 0
    for case, i, r, p in zip(cases, icu, rust, pkg):
        seen[case[0]] += 1
        try:
            exp, diffs = lib.expected(case, i, r)
        except lib.Unexplained as e:
            unexplained += 1
            print("UNEXPLAINED", lib.line_of(case), "\n   ", e)
            continue
        for d in diffs:
            seen["note:" + d] += 1
        why = compare(case, exp, p)
        if why:
            bad[case[0]] += 1
            if shown < 8:
                shown += 1
                print("DIFF", lib.line_of(case), "\n   ", why)
    for name in sorted(seen):
        print("%-16s %6d cases  %d differences" % (name, seen[name], bad.get(name, 0)))
    total = sum(bad.values())
    print("%d cases, %d differences, %d unexplained" % (len(cases), total, unexplained))
    return 1 if total or unexplained or extra else 0


if __name__ == "__main__":
    sys.exit(main())
