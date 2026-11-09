#!/usr/bin/env python3
"""Make case_full_data.goose: the full case mappings and the tables of the
final sigma rule.

The mappings come from SpecialCasing.txt. The unconditional entries that
differ from the simple mappings go into the package. The language tagged
entries stay out. The final sigma is a rule of the code, so its tables
come from DerivedCoreProperties.txt. Each table is checked against a
second source: the case calls of Python, of Node and of the Go package
golang.org/x/text/cases. The script exits with an error on the first
difference. Usage: make_case_full_data.py [ucd directory]
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ucdlib as u


def simple_maps(rows):
    upper = {}
    lower = {}
    for cp, f in rows.items():
        if f[12]:
            upper[cp] = int(f[12], 16)
        if f[13]:
            lower[cp] = int(f[13], 16)
    return upper, lower


def parse_special_casing():
    """The unconditional mappings. Returns upper and lower dicts of lists."""
    upper = {}
    lower = {}
    for line in u.lines_of("SpecialCasing.txt"):
        parts = [x.strip() for x in line.split(";")]
        lo, hi = u.parse_range(parts[0])
        if len(parts) > 4 and parts[4]:
            continue  # the entry holds a condition, so it stays out
        for cp in range(lo, hi + 1):
            if parts[1]:
                lower[cp] = [int(x, 16) for x in parts[1].split()]
            if parts[3]:
                upper[cp] = [int(x, 16) for x in parts[3].split()]
    return upper, lower


def prop_ranges(name, prop):
    runs = []
    for line in u.lines_of(name):
        parts = [x.strip() for x in line.split(";")]
        if prop not in parts[1].split():
            continue
        lo, hi = u.parse_range(parts[0])
        runs.append((lo, hi))
    runs.sort()
    merged = []
    for lo, hi in runs:
        if merged and merged[-1][1] + 1 >= lo:
            merged[-1][1] = max(merged[-1][1], hi)
        else:
            merged.append([lo, hi])
    return merged


def hexes(cps):
    return " ".join("%04X" % c for c in cps)


def main():
    u.check_version()
    rows = u.unicode_data()
    simple_upper, simple_lower = simple_maps(rows)
    full_upper, full_lower = parse_special_casing()

    # The entry stays only when the full mapping differs from the simple
    # one. The sigma has its own rule in the code.
    for cp in list(full_upper):
        want = chr(cp).upper()
        if hexes(full_upper[cp]) == hexes([simple_upper.get(cp, cp)]):
            del full_upper[cp]
    for cp in list(full_lower):
        if cp == 0x3A3:
            del full_lower[cp]
            continue
        want = chr(cp).lower()
        if want == chr(0x3C2):
            del full_lower[cp]
            continue
        if hexes(full_lower[cp]) == hexes([simple_lower.get(cp, cp)]):
            del full_lower[cp]

    # ---- the second sources ---------------------------------------------
    # Python, over every code point. Python holds Unicode 16.0.0, so it
    # misses the letters that 17.0.0 added. A difference warns.
    py_warn = 0
    for cp in range(0x110000):
        if 0xD800 <= cp <= 0xDFFF or cp == 0x3A3:
            continue
        want = full_upper.get(cp)
        text = chr(cp).upper()
        if want is None:
            up = simple_upper.get(cp, cp)
            if text != chr(up):
                py_warn += 1
        elif text != "".join(chr(c) for c in want):
            py_warn += 1
        want = full_lower.get(cp)
        text = chr(cp).lower()
        if want is None:
            lo = simple_lower.get(cp, cp)
            if text != chr(lo):
                py_warn += 1
        elif text != "".join(chr(c) for c in want):
            py_warn += 1

    # Node, over every code point in one batch.
    cps = [cp for cp in range(0x110000) if not 0xD800 <= cp <= 0xDFFF]
    node = u.oracle_node("casefull.mjs", stdin="\n".join(hexes([cp]) for cp in cps) + "\n")
    if len(node) != len(cps):
        u.fail("the Node oracle returned %d lines for %d code points" % (len(node), len(cps)))
    for cp, line in zip(cps, node):
        out_up, out_lo = line.split("\t")
        want_up = full_upper.get(cp)
        if want_up is None:
            want_up = [simple_upper.get(cp, cp)]
        if out_up != hexes(want_up):
            u.fail("upper of %04X differs from Node: %s, %s" % (cp, out_up, hexes(want_up)))
        want_lo = full_lower.get(cp)
        if want_lo is None:
            want_lo = [simple_lower.get(cp, cp)]
        if out_lo != hexes(want_lo):
            u.fail("lower of %04X differs from Node: %s, %s" % (cp, out_lo, hexes(want_lo)))

    # Go, over every code point in one batch.
    go = u.oracle_go("fullcase", stdin="\n".join("%X" % cp for cp in cps) + "\n")
    if len(go) != len(cps):
        u.fail("the Go oracle returned %d lines for %d code points" % (len(go), len(cps)))
    for cp, line in zip(cps, go):
        out_up, out_lo = line.split("\t")
        want_up = full_upper.get(cp)
        if want_up is None:
            want_up = [simple_upper.get(cp, cp)]
        if out_up != hexes(want_up):
            u.fail("upper of %04X differs from Go: %s, %s" % (cp, out_up, hexes(want_up)))
        want_lo = full_lower.get(cp)
        if want_lo is None:
            want_lo = [simple_lower.get(cp, cp)]
        if out_lo != hexes(want_lo):
            u.fail("lower of %04X differs from Go: %s, %s" % (cp, out_lo, hexes(want_lo)))

    # ---- the tables -------------------------------------------------------
    cased = prop_ranges("DerivedCoreProperties.txt", "Cased")
    ignorable = prop_ranges("DerivedCoreProperties.txt", "Case_Ignorable")

    def emit(foot):
        cps = sorted(foot)
        off = [0]
        for cp in cps:
            off.append(off[-1] + len(foot[cp]))
        pool = [c for cp in cps for c in foot[cp]]
        return cps, off, pool

    upper_cps, upper_off, upper_pool = emit(full_upper)
    lower_cps, lower_off, lower_pool = emit(full_lower)

    # The texts of the test suite. Each mapping code point stands alone
    # and inside a word. The last group holds the sigma contexts.
    texts = []
    for cp in sorted(full_upper) + sorted(full_lower):
        texts.append(chr(cp))
        texts.append("x" + chr(cp) + "x")
    texts += ["\u03A3", "\u039F\u03A3", "\u039F\u03A3\u03A3",
              "\u03A3\u03A3", "\u039F\u03A3.\u03A3", "\u039F\u03A3\u0307\u03A3",
              "\u03A3\u03A3\u03A3", "\u039F\u03A3'\u03A3", "\u039F\u039F\u03A3",
              "\u03A3 \u03A3"]
    in_pool, up_pool, lo_pool = [], [], []
    in_off, up_off, lo_off = [0], [0], [0]
    for t in texts:
        in_pool += [ord(c) for c in t]
        in_off.append(len(in_pool))
        u_out = t.upper()
        up_pool += [ord(c) for c in u_out]
        up_off.append(len(up_pool))
        l_out = t.lower()
        lo_pool += [ord(c) for c in l_out]
        lo_off.append(len(lo_pool))
    suite_parts = [
        u.array("FC_IN_POOL", in_pool, "The code points of each input text."),
        u.array("FC_UP_POOL", up_pool, "The code points of each upper text."),
        u.array("FC_LO_POOL", lo_pool, "The code points of each lower text."),
        u.array("FC_IN_OFF", in_off, "The end of each input text."),
        u.array("FC_UP_OFF", up_off, "The end of each upper text."),
        u.array("FC_LO_OFF", lo_off, "The end of each lower text."),
    ]
    u.write_goose(os.path.join(u.ROOT, "test", "suite", "case_full_cases.goose"),
                  "make_case_full_data.py", suite_parts, "suite")

    parts = [
        u.array("UFULL_CP", upper_cps, "The code point of each upper mapping."),
        u.array("UFULL_OFF", upper_off, "The start of each result in UFULL_POOL."),
        u.array("UFULL_POOL", upper_pool, "The code points of the upper results."),
        u.array("LFULL_CP", lower_cps, "The code point of each lower mapping."),
        u.array("LFULL_OFF", lower_off, "The start of each result in LFULL_POOL."),
        u.array("LFULL_POOL", lower_pool, "The code points of the lower results."),
        u.array("SIGMA_CP", [0x3A3], "The capital sigma."),
        u.array("SIGMA_FINAL", [0x3C2], "The final sigma."),
        u.array("CASED_START", [r[0] for r in cased], "The first code point of each run of cased letters."),
        u.array("CASED_END", [r[1] for r in cased], "The last code point of each run."),
        u.array("IGNORABLE_START", [r[0] for r in ignorable], "The first code point of each run of case ignorable characters."),
        u.array("IGNORABLE_END", [r[1] for r in ignorable], "The last code point of each run."),
    ]
    u.write_goose(os.path.join(u.ROOT, "case_full_data.goose"),
                  "make_case_full_data.py", parts)
    if py_warn:
        print("warning: %d values differ from Python" % py_warn)
    print("case_full_data.goose: %d upper mappings, %d lower mappings,"
          " %d cased runs, %d ignorable runs"
          % (len(upper_cps), len(lower_cps), len(cased), len(ignorable)))


if __name__ == "__main__":
    main()
