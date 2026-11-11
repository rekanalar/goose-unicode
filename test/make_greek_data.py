#!/usr/bin/env python3
"""Make greek_upper_data.goose: the letter data of the Greek upper case.

The Greek upper case of the ICU library needs one value for each Greek
letter: the upper case letter in the low ten bits, and the flags vowel,
iota subscript, accent and dialytika. The script derives the value from
UnicodeData.txt and Scripts.txt of the Unicode Character Database
18.0.0: the first character of the canonical decomposition gives the upper
case and the vowel flag, and the other characters give the flags of the
marks. The phonetic letters U+1D00 to U+1DBF and U+AB65 stay out.

The script then checks the table against ICU 79.1: it runs ICU over every
scalar value under the Greek locale and holds the code points whose result
differs from the root locale. Every one of them must have a nonzero value
in the table. It also checks that Node 22 agrees with ICU for the upper and
the lower case of the code points that Node holds, for the three new
locales. A difference from ICU is an error.

Usage: make_greek_data.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ucdlib as u

HAS_VOWEL = 0x1000
HAS_YPOG = 0x2000
HAS_ACCENT = 0x4000
HAS_DIAL = 0x8000
UPPER_MASK = 0x3FF
VOWELS = {0x3B1, 0x391, 0x3B5, 0x395, 0x3B7, 0x397, 0x3B9, 0x399, 0x3BF, 0x39F,
          0x3C9, 0x3A9, 0x3C5, 0x3A5, 0x3F5}
ACCENTS = {0x300, 0x301, 0x342, 0x302, 0x303, 0x311}
LOCALES = [("el", "EL"), ("nl", "NL"), ("hy", "HY")]


def greek_scripts():
    out = set()
    for line in u.lines_of("Scripts.txt"):
        p = [x.strip() for x in line.split(";")]
        if p[1] != "Greek":
            continue
        a, b = u.parse_range(p[0])
        out.update(range(a, b + 1))
    return out


def derive_table(greek):
    names = {}
    for line in u.lines_of("UnicodeData.txt"):
        f = line.split(";")
        names[int(f[0], 16)] = f

    def decomp(cp):
        f = names.get(cp)
        if f is None or f[5] == "" or f[5].startswith("<"):
            return [cp]
        out = []
        for x in f[5].split():
            out.extend(decomp(int(x, 16)))
        return out

    def upper(cp):
        f = names.get(cp)
        return int(f[12], 16) if f is not None and f[12] else cp

    def value(cp):
        f = names.get(cp)
        if f is None or cp not in greek or 0x1D00 <= cp <= 0x1DBF or cp == 0xAB65:
            return 0
        if f[2] not in ("Lu", "Ll", "Lt", "Lm", "Lo"):
            return 0
        d = decomp(cp)
        v = upper(d[0]) & UPPER_MASK
        if d[0] in VOWELS:
            v |= HAS_VOWEL
        for c in d[1:]:
            if c in ACCENTS:
                v |= HAS_ACCENT
            elif c == 0x308:
                v |= HAS_DIAL
            elif c == 0x344:
                v |= HAS_DIAL | HAS_ACCENT
            elif c == 0x345:
                v |= HAS_YPOG
        return v
    return value


def main():
    u.check_version()
    greek = greek_scripts()
    value = derive_table(greek)
    d0370 = [value(c) for c in range(0x370, 0x400)]
    d1f00 = [value(c) for c in range(0x1F00, 0x2000)]
    if value(0x2126) != (0x3A9 | HAS_VOWEL):
        u.fail("U+2126 does not derive to the capital omega")
    parts = [
        u.array("GREEK_D0370", d0370, "Letter data of U+0370..U+03FF: upper case, flags."),
        u.array("GREEK_D1F00", d1f00, "Letter data of U+1F00..U+1FFF: upper case, flags."),
    ]
    # Every scalar value: the single code point result of ICU in Greek.
    scalars = [(c,) for c in range(0, 0x110000) if not 0xD800 <= c <= 0xDFFF]
    lines = [u.hexline(t) for t in scalars]
    loc = u.icu_case("el", "upper", lines)
    root = u.icu_case("und", "upper", lines)
    changed = [t[0] for t, a, b in zip(scalars, loc, root) if a != b]
    print("el upper changes %d code points" % len(changed))
    for c in changed:
        if value(c) == 0:
            u.fail("U+%04X changes under el but the table holds no value" % c)
    # Node: the upper and the lower case of the held code points, per locale.
    held = u.held()
    cps = [c for c in range(0x110000) if not 0xD800 <= c <= 0xDFFF and held[c]]
    for tag, name in LOCALES:
        for kind in ("upper", "lower"):
            lines = [u.hexline((c,)) for c in cps]
            a = u.icu_case(tag, kind, lines)
            b = u.oracle_node("locale.mjs", tag, kind, stdin="\n".join(lines) + "\n")
            diff = []
            for c, x, y in zip(cps, a, b):
                if any(not held[int(h, 16)] for h in x.split()):
                    continue  # the result holds a code point that Node does not know
                if x != y:
                    diff.append((c, x, y))
            print("node %s %s: %d differences over %d code points" % (
                name, kind, len(diff), len(cps)))
            for c, x, y in diff[:3]:
                print("  U+%04X: icu %s node %s" % (c, x, y))
            if tag == "hy" and kind == "upper":
                # The Armenian ligature: ICU and the package give two
                # letters, Node gives the root mapping.
                one = [(c, x, y) for c, x, y in diff if c == 0x587]
                if one != [(0x587, "0535 054E", "0535 0552")]:
                    u.fail("the Armenian ligature differs from the measured value")
                diff = [(c, x, y) for c, x, y in diff if c != 0x587]
            if diff:
                u.fail("node differs from icu")
    u.write_goose(os.path.join(u.ROOT, "greek_upper_data.goose"), "make_greek_data.py", parts)


if __name__ == "__main__":
    main()
