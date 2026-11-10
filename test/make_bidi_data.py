#!/usr/bin/env python3
"""Make bidi_data.goose: the paired brackets of the bidirectional algorithm.

The table comes from BidiBrackets.txt of the Unicode Character Database
17.0.0. Each bracket gets one number: twice the code point of the opening
bracket of its pair, plus 1 for an opening bracket. The angle brackets
U+2329 and U+232A count as U+3008 and U+3009, as UAX #9 asks. The script
exits with an error when the opening and closing brackets do not pair.
The conformance test checks the table through the results of the bidi
calls.

Usage: make_bidi_data.py [ucd directory]
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ucdlib as u

CANON = {0x2329: 0x3008, 0x232A: 0x3009}


def main():
    rows = {}
    for line in u.lines_of("BidiBrackets.txt"):
        f = [x.strip() for x in line.split(";")]
        cp = int(f[0], 16)
        pair = int(f[1], 16)
        kind = f[2]
        if kind == "o":
            code = CANON.get(cp, cp) * 2 + 1
        elif kind == "c":
            code = CANON.get(pair, pair) * 2
        else:
            continue
        rows[cp] = code
    cps = sorted(rows)
    # Every opening bracket has a closing partner with the same pair.
    opens = {c >> 1 for c in rows.values() if c & 1}
    closes = {c >> 1 for c in rows.values() if not c & 1}
    if opens != closes:
        u.fail("the opening and closing brackets do not pair up")
    parts = []
    for name, vals in (("BR_CP", cps), ("BR_CODE", [rows[c] for c in cps])):
        parts.append(u.array(name, vals))
    u.write_goose(os.path.join(u.ROOT, "bidi_data.goose"), "make_bidi_data.py", parts)
    print("brackets: %d code points, %d pairs" % (len(cps), len(opens)))


main()
