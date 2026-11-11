#!/usr/bin/env python3
"""Compare the binary properties of the package with the Go library.

The table of flags_data.goose is the table of the package. The Go
standard library holds some of the properties in unicode.Properties. The
script compares each of them over every code point and prints the
differences. Go holds Unicode 17.0.0 as the package does.

Usage: diff_props.py
"""
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ucdlib as u
import make_flags_data as m


def table():
    text = open(os.path.join(u.ROOT, "flags_data.goose"), encoding="utf-8").read()

    def numbers(name):
        body = re.search(r"const %s: i64\[\d+\] = \[(.*?)\];" % name, text, re.S).group(1)
        return [int(x) for x in body.replace("\n", " ").split(",") if x.strip()]

    return numbers("FLAG_START"), numbers("FLAG_END"), numbers("FLAG_MASK")


def main():
    starts, ends, masks = table()
    differ = 0
    checked = 0
    for i, (_, prop) in enumerate(m.PROPS):
        lines = u.oracle_go("goprop", prop)
        if lines == ["unknown"]:
            continue
        checked += 1
        want = set()
        for line in lines:
            a, b, _ = line.split()
            want.update(range(int(a, 16), int(b, 16) + 1))
        got = set()
        for lo, hi, mask in zip(starts, ends, masks):
            if mask >> i & 1:
                got.update(range(lo, hi + 1))
        if got != want:
            differ += 1
            cps = sorted(got ^ want)
            print("%s: %d code points differ, first %04X" % (prop, len(cps), cps[0]))
    print("%d properties of the Go library compared, %d differ" % (checked, differ))


if __name__ == "__main__":
    main()
