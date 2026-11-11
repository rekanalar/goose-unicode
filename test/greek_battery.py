#!/usr/bin/env python3
"""Make test/suite/greek_cases.goose: the rows of the three locale rules.

The rows come from the ICU library, release 79.1, which holds the release
of the tables. The script runs ICU over three batteries and keeps the rows
whose result differs from the root locale:

- the Greek upper case over the Greek letters and marks,
- the Greek upper case over every scalar value, so that every code point
  that the rule changes has a row,
- the Dutch title case over the digraph shapes.

The battery of one to four characters over 16 characters runs 69,904
texts. The script keeps all rows of one to three characters and samples
the rows of four characters, so that no group holds more than 1,500 rows.
The branch texts of the contract are added to the groups. The suite
replays the rows against the calls of the package.

Usage: greek_battery.py
"""
import itertools
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ucdlib as u

GREEK_CHARS = [0x3B7, 0x397, 0x3B9, 0x3A5, 0x3B1, 0x301, 0x308, 0x345,
               0x342, 0x304, 0x20, 0x3A3, 0x41, 0x31, 0x1FA7, 0x390]
DUTCH_CHARS = [0x69, 0x49, 0x6A, 0x4A, 0x301, 0xED, 0xCD, 0x308, 0x307, 0x20,
               0x27, 0x61, 0x327, 0x131, 0x3A3, 0x2E]
CAP = 1500

BRANCH_GREEK = [
    (0x3B7, 0x303), (0x41, 0x20, 0x3B7, 0x303), (0x41, 0x3B7, 0x303), (0x397, 0x345),
    (0x1FA7,), (0x3B1, 0x304), (0x3B1, 0x306), (0x1FB3,), (0x390,), (0x3B9, 0x308, 0x301),
    (0x3B9, 0x301), (0x3B9, 0x300), (0x3AA,), (0x3AA, 0x301), (0x390, 0x301), (0x3A5, 0x301),
    (0x3B9, 0x313), (0x397, 0x301, 0x3A3), (0x397, 0x301, 0x39C), (0x397, 0x301, 0x394),
    (0x397, 0x301, 0x31), (0x397, 0x301, 0x391), (0x397, 0x301, 0x345), (0x397, 0x345, 0x301),
    (0x397, 0x301, 0x345, 0x391), (0x397, 0x301, 0x20, 0x345, 0x391), (0x391, 0x342, 0x399, 0x301),
    (0x3A9, 0x3C5, 0x308), (0x3B9, 0x307, 0x300), (0x345, 0x3B1), (0x2126,), (0x3D3,), (0x3D4,),
    (0x1F60, 0x345), (0x397, 0x301, 0x20), (0x41, 0x20, 0x397, 0x301, 0x20), (0x3B1, 0x3B7, 0x301),
]
BRANCH_DUTCH = [
    (0x69, 0x6A), (0x69, 0x301, 0x6A, 0x301), (0x69, 0x301, 0x6A), (0xED, 0x6A, 0x301),
    (0xED, 0x6A), (0xCD, 0x6A), (0x69, 0x301, 0x6A, 0x308), (0x69, 0x307, 0x6A),
    (0x69, 0x6A, 0x327), (0x27, 0x69, 0x6A), (0x131, 0x6A), (0x69, 0x6A, 0x69, 0x6A),
    (0x20, 0x69, 0x6A, 0x20), (0x69, 0x6A, 0x2E), (0xC1, 0x69, 0x6A), (0x69, 0x13A, 0x6A),
]


def battery(chars):
    out = []
    for n in range(1, 5):
        out.extend(itertools.product(chars, repeat=n))
    return out


def sample(rows, extra):
    """All rows of one to three characters, a sample of the rest."""
    short = [r for r in rows if len(r[0]) <= 3]
    long_ = [r for r in rows if len(r[0]) > 3]
    room = max(CAP - len(short), 0)
    step = max(1, len(long_) // max(room, 1))
    kept = short + long_[::step][:room]
    seen = {r[0] for r in kept}
    return kept + [r for r in extra if r[0] not in seen]


def emit(prefix, rows, comment):
    pin, poff, pout, ooff = [], [0], [], [0]
    for t, res in rows:
        pin.extend(t)
        poff.append(len(pin))
        pout.extend(res)
        ooff.append(len(pout))
    return [u.array(prefix + "_IN_POOL", pin, comment + " Input code points."),
            u.array(prefix + "_IN_OFF", poff, "Start of each input text."),
            u.array(prefix + "_OUT_POOL", pout, "Result code points of ICU."),
            u.array(prefix + "_OUT_OFF", ooff, "Start of each result.")]


def main():
    u.check_version()
    # Every scalar value that the Greek upper case changes.
    scalars = [(c,) for c in range(0, 0x110000) if not 0xD800 <= c <= 0xDFFF]
    single = u.icu_rows(scalars, "el", "upper")
    print("el upper changes %d code points" % len(single))
    parts = emit("GRK_ONE", single, "Greek upper case of each single code point that changes.")
    # The Greek battery.
    gt = battery(GREEK_CHARS)
    grows = u.icu_rows(gt, "el", "upper")
    gextra = u.icu_rows(BRANCH_GREEK, "el", "upper")
    grk = sample(grows, gextra)
    print("greek battery: %d texts, %d differ, %d kept" % (len(gt), len(grows), len(grk)))
    parts += emit("GRK_UP", grk, "Greek upper case rows.")
    # The Dutch battery.
    dt = battery(DUTCH_CHARS)
    drows = u.icu_rows(dt, "nl", "title")
    dextra = u.icu_rows(BRANCH_DUTCH, "nl", "title")
    dut = sample(drows, dextra)
    print("dutch battery: %d texts, %d differ, %d kept" % (len(dt), len(drows), len(dut)))
    parts += emit("DUT_TI", dut, "Dutch title case rows.")
    u.write_goose(os.path.join(u.HERE, "suite", "greek_cases.goose"), "greek_battery.py", parts,
                  namespace="suite")


if __name__ == "__main__":
    main()
