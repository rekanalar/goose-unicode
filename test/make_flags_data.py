#!/usr/bin/env python3
"""Make flags_data.goose: one range table with a bit mask for the emoji
and identifier properties.

The properties come from emoji-data.txt and DerivedCoreProperties.txt.
Each property is checked against the regular expression engine of Node,
which holds Unicode 17.0, over every code point. The script exits with an
error on the first difference. It also writes the suite file: sample code
points with their masks from Node, and the runs of the group of the
general category from the Go library.
Usage: make_flags_data.py [ucd directory]
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ucdlib as u

# The bit of each property in the mask. The code of flags.goose holds the
# same numbers.
BITS = [
    ("emoji-data.txt", "Emoji", 1),
    ("emoji-data.txt", "Emoji_Presentation", 2),
    ("emoji-data.txt", "Emoji_Modifier", 4),
    ("emoji-data.txt", "Emoji_Modifier_Base", 8),
    ("emoji-data.txt", "Emoji_Component", 16),
    ("emoji-data.txt", "Extended_Pictographic", 32),
    ("DerivedCoreProperties.txt", "ID_Start", 64),
    ("DerivedCoreProperties.txt", "ID_Continue", 128),
    ("DerivedCoreProperties.txt", "XID_Start", 256),
    ("DerivedCoreProperties.txt", "XID_Continue", 512),
]
GROUPS = {"L": 0, "M": 1, "N": 2, "P": 3, "S": 4, "Z": 5, "C": 6}


def load():
    mask = [0] * (u.MAX_CP + 1)
    for name, prop, bit in BITS:
        for line in u.lines_of(name):
            parts = [x.strip() for x in line.split(";")]
            if parts[1].split()[0] != prop:
                continue
            lo, hi = u.parse_range(parts[0])
            for cp in range(lo, hi + 1):
                mask[cp] |= bit
    return mask


def node_ranges(prop):
    cps = set()
    for line in u.oracle_node("props.mjs", prop):
        if not line.strip():
            continue
        a, b = line.split()
        cps.update(range(int(a, 16), int(b, 16) + 1))
    return cps


def main():
    u.check_version()
    mask = load()
    node_mask = [0] * (u.MAX_CP + 1)
    for name, prop, bit in BITS:
        want = node_ranges(prop)
        for cp in want:
            node_mask[cp] |= bit
        got = {cp for cp in range(u.MAX_CP + 1) if mask[cp] & bit}
        if got != want:
            cp = sorted(got ^ want)[0]
            u.fail("%s differs from Node at %04X" % (prop, cp))

    runs = u.runs_of(mask, skip=0)
    parts = [
        u.array("FLAG_START", [r[0] for r in runs], "The first code point of each run."),
        u.array("FLAG_END", [r[1] for r in runs], "The last code point of each run."),
        u.array("FLAG_MASK", [r[2] for r in runs], "The mask of each run."),
    ]
    u.write_goose(os.path.join(u.ROOT, "flags_data.goose"), "make_flags_data.py", parts)

    # The suite sample: the ends of every third run and the code points
    # next to them, with the mask from Node.
    sample = set()
    for i, (lo, hi, _) in enumerate(runs):
        if i % 3 == 0:
            for cp in (lo - 1, lo, hi, hi + 1):
                if 0 <= cp <= u.MAX_CP:
                    sample.add(cp)
    sample = sorted(sample)
    groups = u.oracle_go("catgroup")
    g_start, g_end, g_val = [], [], []
    for line in groups:
        a, b, v = line.split()
        g_start.append(int(a, 16))
        g_end.append(int(b, 16))
        g_val.append(GROUPS[v])
    suite = [
        u.array("FL_CP", sample, "The code points of the sample."),
        u.array("FL_MASK", [node_mask[cp] for cp in sample], "The mask of each sample code point, from Node."),
        u.array("GP_START", g_start, "The first code point of each run of one group."),
        u.array("GP_END", g_end, "The last code point of each run."),
        u.array("GP_VAL", g_val, "The group of each run, from Go."),
    ]
    u.write_goose(os.path.join(u.ROOT, "test", "suite", "flags_cases.goose"),
                  "make_flags_data.py", suite, "suite")
    print("flags_data.goose: %d runs; flags_cases.goose: %d sample points, %d group runs"
          % (len(runs), len(sample), len(g_start)))


if __name__ == "__main__":
    main()
