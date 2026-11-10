#!/usr/bin/env python3
"""Make the conformance case files of the unicode package.

The two test files of the Unicode Character Database hold many cases and
many megabytes, so the package cannot ship them. This script takes a
sample of the cases of BidiCharacterTest.txt and of the class sequences
of BidiTest.txt, and writes them into the package, so the test suite
checks the algorithm against the cases of the standard without the files
of the standard.

The sample takes the cases in a fixed stride, so a change of the
standard shows up in the package.

Usage: make_bidi_cases.py [ucd directory]
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ucdlib as u

STRIDE = 97
LIMIT = 2000

# One code point of each class, for the class sequences.
CLASS_CP = {
    "L": 0x61, "R": 0x5D0, "AL": 0x627, "EN": 0x31, "ES": 0x2B,
    "ET": 0x24, "AN": 0x661, "CS": 0x2C, "NSM": 0x300, "BN": 0xAD,
    "B": 0x2029, "S": 0x09, "WS": 0x20, "ON": 0x21, "LRE": 0x202A,
    "LRO": 0x202D, "RLE": 0x202B, "RLO": 0x202E, "PDF": 0x202C,
    "LRI": 0x2066, "RLI": 0x2067, "FSI": 0x2068, "PDI": 0x2069,
}


def parse_levels(text):
    """The levels of a case. A level of x marks a removed code point."""
    return [-1 if x == "x" else int(x) for x in text.split()]


def char_cases():
    """The cases of BidiCharacterTest.txt with their expected results."""
    out = []
    for line in u.lines_of("BidiCharacterTest.txt"):
        f = line.split(";")
        if len(f) < 5:
            continue
        out.append(([int(x, 16) for x in f[0].split()], int(f[1]),
                    parse_levels(f[3]), [int(x) for x in f[4].split()]))
    return out


def class_cases():
    """The class sequences of BidiTest.txt with their expected results."""
    out = []
    levels = []
    order = []
    for line in u.lines_of("BidiTest.txt"):
        if line.startswith("@Levels:"):
            levels = parse_levels(line[len("@Levels:"):])
            continue
        if line.startswith("@Reorder:"):
            order = [int(x) for x in line[len("@Reorder:"):].split()]
            continue
        if ";" not in line:
            continue
        seq, bits = line.split(";")
        cps = []
        for name in seq.split():
            if name not in CLASS_CP:
                u.fail("the class %s is unknown" % name)
            cps.append(CLASS_CP[name])
        out.append((cps, int(bits), levels, order))
    return out


def offsets(lens):
    """The start of each case and the length of each case."""
    off = []
    total = 0
    for n in lens:
        off.append(total)
        total += n
    return off


def flat(name, rows):
    """A growable table of the rows, one row per line."""
    out = ["const %s: i64[>..] = [" % name]
    for row in rows:
        out.append("    " + ", ".join(str(v) for v in row) + ",")
    out.append("];")
    out.append("")
    return "\n".join(out)


def emit(path, prefix, picked, comment, dir_name, dir_index):
    """Write the case tables of one file of cases.

    The tables are flat. The offsets give the start of each case in the
    code point table and in the order table.
    """
    parts = [comment]
    parts.append("const %s_COUNT: i64 = %d;" % (prefix, len(picked)))
    for name, index in ((prefix + "_CP", 0), (prefix + "_LV", 2),
                        (prefix + "_OD", 3)):
        rows = []
        for case in picked:
            vals = case[index]
            if not vals:
                continue
            rows.append(vals)
        parts.append(flat(name, rows))
    parts.append(flat(dir_name, [[c[dir_index]] for c in picked]))
    parts.append(flat(prefix + "_LEN", [[len(c[0])] for c in picked]))
    parts.append(flat(prefix + "_OFF",
                      [[n] for n in offsets([len(c[0]) for c in picked])]))
    parts.append(flat(prefix + "_OD_LEN", [[len(c[3])] for c in picked]))
    parts.append(flat(prefix + "_OD_OFF",
                      [[n] for n in offsets([len(c[3]) for c in picked])]))
    u.write_goose(path, "make_bidi_cases.py", parts, namespace="suite")


def main():
    chars = char_cases()
    if not chars:
        u.fail("the test file holds no case")
    picked = chars[::STRIDE][:LIMIT]
    emit(os.path.join(u.ROOT, "test", "suite", "bidi_cases.goose"), "BD",
         picked,
         "// A sample of the conformance cases of the Unicode Character\n"
         "// Database. BD_CP holds the code points of each case, BD_LV the\n"
         "// level of each code point and BD_OD the visual order. A level of\n"
         "// -1 marks a code point that the algorithm removes.",
         "BD_DIR", 1)

    cls = class_cases()
    if not cls:
        u.fail("the test file holds no class sequence")
    picked2 = cls[::STRIDE][:LIMIT]
    emit(os.path.join(u.ROOT, "test", "suite", "bidi_class_cases.goose"), "BC",
         picked2,
         "// A sample of the class sequences of the Unicode Character\n"
         "// Database. BC_CP holds the code point of each class, BC_LV the\n"
         "// level of each code point and BC_OD the visual order. A level of\n"
         "// -1 marks a code point that the algorithm removes.",
         "BC_BITS", 1)
    print("cases: %d of %d, class sequences: %d of %d"
          % (len(picked), len(chars), len(picked2), len(cls)))


main()
