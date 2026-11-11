#!/usr/bin/env python3
"""Make flags_data.goose: one range table with a bit mask for the binary
properties, and the names of the properties.

The properties come from emoji-data.txt, DerivedCoreProperties.txt,
PropList.txt and DerivedNormalizationProps.txt. Each property is checked
against the ICU library over every code point, and against the regular
expression engine of Node, which holds Unicode 17.0, where Node has a
class for it. Node judges only the code points that 18.0 did not add.
The script exits with an error on the first difference. It also writes
the suite file: sample code points with their masks, and the runs of
the group of the general category from the ICU library.
Usage: make_flags_data.py [ucd directory]
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ucdlib as u

# The properties, in the order of their numbers. The number of a property
# is its bit in the mask. The code of flags.goose holds the same numbers.
# Node holds no regular expression class for the last five.
CORE = "DerivedCoreProperties.txt"
LIST = "PropList.txt"
NORM = "DerivedNormalizationProps.txt"
EMOJI = "emoji-data.txt"
PROPS = [
    (EMOJI, "Emoji"), (EMOJI, "Emoji_Presentation"), (EMOJI, "Emoji_Modifier"),
    (EMOJI, "Emoji_Modifier_Base"), (EMOJI, "Emoji_Component"),
    (EMOJI, "Extended_Pictographic"),
    (CORE, "ID_Start"), (CORE, "ID_Continue"), (CORE, "XID_Start"), (CORE, "XID_Continue"),
    (CORE, "Alphabetic"), (CORE, "Case_Ignorable"), (CORE, "Cased"),
    (CORE, "Changes_When_Casefolded"), (CORE, "Changes_When_Casemapped"),
    (CORE, "Changes_When_Lowercased"), (CORE, "Changes_When_Titlecased"),
    (CORE, "Changes_When_Uppercased"), (CORE, "Default_Ignorable_Code_Point"),
    (CORE, "Grapheme_Base"), (CORE, "Grapheme_Extend"), (CORE, "Lowercase"),
    (CORE, "Math"), (CORE, "Uppercase"),
    (LIST, "ASCII_Hex_Digit"), (LIST, "Bidi_Control"), (LIST, "Dash"),
    (LIST, "Deprecated"), (LIST, "Diacritic"), (LIST, "Extender"),
    (LIST, "Hex_Digit"), (LIST, "IDS_Binary_Operator"),
    (LIST, "IDS_Trinary_Operator"), (LIST, "Ideographic"), (LIST, "Join_Control"),
    (LIST, "Logical_Order_Exception"), (LIST, "Noncharacter_Code_Point"),
    (LIST, "Pattern_Syntax"), (LIST, "Pattern_White_Space"),
    (LIST, "Quotation_Mark"), (LIST, "Radical"), (LIST, "Sentence_Terminal"),
    (LIST, "Soft_Dotted"), (LIST, "Terminal_Punctuation"),
    (LIST, "Unified_Ideograph"), (LIST, "Variation_Selector"), (LIST, "White_Space"),
    (NORM, "Changes_When_NFKC_Casefolded"),
    (LIST, "IDS_Unary_Operator"), (LIST, "Prepended_Concatenation_Mark"),
    (LIST, "Modifier_Combining_Mark"), (LIST, "ID_Compat_Math_Start"),
    (LIST, "ID_Compat_Math_Continue"),
]
NO_NODE = {"IDS_Unary_Operator", "Prepended_Concatenation_Mark",
           "Modifier_Combining_Mark", "ID_Compat_Math_Start",
           "ID_Compat_Math_Continue"}
BITS = [(f, p, 1 << i) for i, (f, p) in enumerate(PROPS)]
GROUPS = {"L": 0, "M": 1, "N": 2, "P": 3, "S": 4, "Z": 5, "C": 6}


# The code points that 18.0.0 changed although they are old. Node holds
# 17.0 and disagrees on exactly these. Four letters gained an upper case
# mapping to a new letter, and three marks became Diacritic. The check
# against Node requires this set exactly, so any other difference fails.
CHANGED_IN_18 = {
    "Changes_When_Casemapped": {0x277, 0x27C, 0xAB4B, 0xAB4C},
    "Changes_When_Titlecased": {0x277, 0x27C, 0xAB4B, 0xAB4C},
    "Changes_When_Uppercased": {0x277, 0x27C, 0xAB4B, 0xAB4C},
    "Diacritic": {0x656, 0x6E2, 0x8D3},
}


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


def ice_ranges(prop):
    cps = set()
    lines = u.oracle_go("icebin", prop)
    if lines == ["unknown"]:
        u.fail("the ICU library does not know " + prop)
    for line in lines:
        a, b, _ = line.split()
        cps.update(range(int(a, 16), int(b, 16) + 1))
    return cps


def main():
    u.check_version()
    mask = load()
    held = u.held()
    for name, prop, bit in BITS:
        got = {cp for cp in range(u.MAX_CP + 1) if mask[cp] & bit}
        if got != ice_ranges(prop):
            cp = sorted(got ^ ice_ranges(prop))[0]
            u.fail("%s differs from ICU at %04X" % (prop, cp))
        if prop not in NO_NODE:
            want = node_ranges(prop)
            diff = {cp for cp in got ^ want if held[cp]}
            if diff != CHANGED_IN_18.get(prop, set()):
                u.fail("%s differs from Node at %s" % (
                    prop, " ".join("%04X" % c for c in sorted(diff ^ CHANGED_IN_18.get(prop, set()))[:5])))

    runs = u.runs_of(mask, skip=0)
    offs = [0]
    for _, p in PROPS:
        offs.append(offs[-1] + len(p))
    parts = [
        u.array("FLAG_START", [r[0] for r in runs], "The first code point of each run."),
        u.array("FLAG_END", [r[1] for r in runs], "The last code point of each run."),
        u.array("FLAG_MASK", [r[2] for r in runs], "The mask of each run."),
        u.array("PROP_OFF", offs, "The start of each property name in PROP_NAMES."),
        u.string("PROP_NAMES", "".join(p for _, p in PROPS)),
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
    # The group is the first letter of the ICU category. Cs, Co and Cn
    # fall in the group C, as they do in the table of the package.
    g_start, g_end, g_val = [], [], []
    for line in u.oracle_go("icucat"):
        a, b, v = line.split()
        g = GROUPS[v[0]]
        if g_val and g_val[-1] == g:
            g_end[-1] = int(b, 16)
            continue
        g_start.append(int(a, 16))
        g_end.append(int(b, 16))
        g_val.append(g)
    suite = [
        u.array("FL_CP", sample, "The code points of the sample."),
        u.array("FL_MASK", [mask[cp] for cp in sample], "The mask of each sample code point, checked against ICU."),
        u.array("GP_START", g_start, "The first code point of each run of one group."),
        u.array("GP_END", g_end, "The last code point of each run."),
        u.array("GP_VAL", g_val, "The group of each run, from ICU."),
    ]
    u.write_goose(os.path.join(u.ROOT, "test", "suite", "flags_cases.goose"),
                  "make_flags_data.py", suite, "suite")
    print("flags_data.goose: %d runs; flags_cases.goose: %d sample points, %d group runs"
          % (len(runs), len(sample), len(g_start)))


if __name__ == "__main__":
    main()
