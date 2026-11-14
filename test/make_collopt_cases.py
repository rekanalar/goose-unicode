#!/usr/bin/env python3
"""Make test/suite/collopt_cases.goose: the cases of the collation options.

The reference is the ICU collator of release 79.1. The oracle is
test/oracle/csrc/collopt.c. It takes the locale and the six attributes
and prints the sign of the comparison of each pair. The script builds the
pairs, asks the oracle for the sign of each pair and writes the numbers
into the suite.

Each group holds the pairs of one option. The suite reads the group and
compares the package with the signs of the oracle.

The file holds numbers only. The suite reads them and compares the
package with them.

Usage: make_collopt_cases.py [path of the collopt oracle]
"""
import os
import random
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ucdlib as u

HERE = os.path.dirname(os.path.abspath(__file__))
ORACLE = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, "oracle", "csrc", "collopt")

# The attributes of ICU that the options of the package match. The
# strength, the alternate handling, the numeric order and the case order.
STRENGTH = {"primary": 0, "secondary": 1, "tertiary": 2, "quaternary": 3, "identical": 15}
ALTERNATE = {"non_ignorable": 21, "shifted": 20}
NUMERIC = {"off": 16, "on": 17}
CASE_FIRST = {"off": 16, "lower_first": 24, "upper_first": 25}
CASE_LEVEL = {"off": 0, "on": 1}

# The letters that differ in case, in accent and in both.
LETTERS = [0x61, 0x41, 0xE4, 0xC4, 0xE0, 0xC0, 0x1EA0, 0x1EC0, 0xDF, 0x1E9E]
# The spaces, the punctuation and the symbols.
PUNCT = [0x20, 0x2C, 0x2E, 0x2D, 0x5F, 0x21, 0x3F, 0x27, 0x22, 0x2A]
# The variable characters that the table holds at the end of the variable
# band. Their primary weight is above 0x04DF, so the boundary of the band
# decides their order.
VAR_LAST = [0x1DA88, 0x1DA89, 0x1DA8A, 0x1DA8B, 0x1E5FF]
# The variable characters whose unit holds an element without a primary
# weight after the variable element.
VAR_FOLLOW = [0x2018, 0x2019, 0x201A, 0x201B, 0x201C, 0x201D]
# The digits of the ASCII, of the Arabic and of the Devanagari.
DIGITS = [0x30, 0x31, 0x32, 0x39, 0x660, 0x661, 0x966, 0x967]
# The letters with a tertiary weight of 0x0C. The case class of a
# character follows its tertiary weight, so these letters tell the upper
# case weights from the others.
CASE_TERT = [0x24B6, 0x24B7, 0x1F150, 0x1F151, 0x1F152]
# The emoji and the characters that the table holds with no row. The Han
# code points stay out: the ICU collator orders the Han by the radical
# and the stroke, while the package orders them by the implicit weights
# of UTS #10. The README names that difference.
OTHER = [0x1F600, 0x1F601, 0x2764, 0x05D0, 0x1DA88, 0xE5FF, 0x0E01]

# The code points of the table. The list holds the start and the end of
# each range of the table, so the pairs reach every shape of the table.
# The Han code points stay out: the ICU collator orders the Han by the
# radical and the stroke, while the package orders them by the implicit
# weights of UTS #10. The README names that difference.
TABLE_RANGES = [
    (0x20, 0x7E), (0xA0, 0xFF), (0x100, 0x17F), (0x180, 0x24F),
    (0x370, 0x3FF), (0x400, 0x4FF), (0x500, 0x52F), (0x531, 0x58F),
    (0x600, 0x6FF), (0x900, 0x97F), (0xE00, 0xE7F), (0x1E00, 0x1FFF),
    (0x2000, 0x206F), (0x2070, 0x209F), (0x2100, 0x218F), (0x2460, 0x24FF),
    (0x3000, 0x30FF), (0xFB00, 0xFB4F), (0xFF00, 0xFFEF),
    (0x1D400, 0x1D7FF), (0x1F300, 0x1F5FF), (0x1F600, 0x1F64F),
]

# The names of the groups and the attributes of each group. The suite
# reads the names to pick the options.
# Each group holds the name, the base of the pairs, the strength, the
# alternate handling, the numeric order, the case order and the case
# level.
GROUPS = [
    ("strength", "strength", STRENGTH["primary"], ALTERNATE["non_ignorable"], NUMERIC["off"], CASE_FIRST["off"], CASE_LEVEL["off"]),
    ("strength2", "strength", STRENGTH["secondary"], ALTERNATE["non_ignorable"], NUMERIC["off"], CASE_FIRST["off"], CASE_LEVEL["off"]),
    ("strength3", "strength", STRENGTH["tertiary"], ALTERNATE["non_ignorable"], NUMERIC["off"], CASE_FIRST["off"], CASE_LEVEL["off"]),
    ("strength4", "strength", STRENGTH["identical"], ALTERNATE["non_ignorable"], NUMERIC["off"], CASE_FIRST["off"], CASE_LEVEL["off"]),
    ("alternate", "alternate", STRENGTH["tertiary"], ALTERNATE["non_ignorable"], NUMERIC["off"], CASE_FIRST["off"], CASE_LEVEL["off"]),
    ("alternate2", "alternate", STRENGTH["tertiary"], ALTERNATE["shifted"], NUMERIC["off"], CASE_FIRST["off"], CASE_LEVEL["off"]),
    ("numeric", "numeric", STRENGTH["tertiary"], ALTERNATE["non_ignorable"], NUMERIC["off"], CASE_FIRST["off"], CASE_LEVEL["off"]),
    ("numeric2", "numeric", STRENGTH["tertiary"], ALTERNATE["non_ignorable"], NUMERIC["on"], CASE_FIRST["off"], CASE_LEVEL["off"]),
    ("case", "case", STRENGTH["tertiary"], ALTERNATE["non_ignorable"], NUMERIC["off"], CASE_FIRST["off"], CASE_LEVEL["off"]),
    ("case2", "case", STRENGTH["tertiary"], ALTERNATE["non_ignorable"], NUMERIC["off"], CASE_FIRST["lower_first"], CASE_LEVEL["off"]),
    ("case3", "case", STRENGTH["tertiary"], ALTERNATE["non_ignorable"], NUMERIC["off"], CASE_FIRST["upper_first"], CASE_LEVEL["off"]),
    ("caselevel", "caselevel", STRENGTH["primary"], ALTERNATE["non_ignorable"], NUMERIC["off"], CASE_FIRST["off"], CASE_LEVEL["on"]),
    ("caselevel2", "caselevel", STRENGTH["secondary"], ALTERNATE["non_ignorable"], NUMERIC["off"], CASE_FIRST["off"], CASE_LEVEL["on"]),
    ("caselevel3", "caselevel", STRENGTH["tertiary"], ALTERNATE["non_ignorable"], NUMERIC["off"], CASE_FIRST["off"], CASE_LEVEL["on"]),
    ("quaternary", "quaternary", STRENGTH["quaternary"], ALTERNATE["shifted"], NUMERIC["off"], CASE_FIRST["off"], CASE_LEVEL["off"]),
    ("quaternary2", "quaternary", STRENGTH["quaternary"], ALTERNATE["non_ignorable"], NUMERIC["off"], CASE_FIRST["off"], CASE_LEVEL["off"]),
    ("quaternary3", "quaternary3", STRENGTH["quaternary"], ALTERNATE["shifted"], NUMERIC["off"], CASE_FIRST["off"], CASE_LEVEL["off"]),
    ("quaternary4", "quaternary3", STRENGTH["quaternary"], ALTERNATE["non_ignorable"], NUMERIC["off"], CASE_FIRST["off"], CASE_LEVEL["off"]),
    ("caselevel4", "quaternary3", STRENGTH["primary"], ALTERNATE["shifted"], NUMERIC["off"], CASE_FIRST["off"], CASE_LEVEL["on"]),
    ("caselevel5", "quaternary3", STRENGTH["tertiary"], ALTERNATE["shifted"], NUMERIC["off"], CASE_FIRST["off"], CASE_LEVEL["on"]),
    ("table1", "table", STRENGTH["primary"], ALTERNATE["non_ignorable"], NUMERIC["off"], CASE_FIRST["off"], CASE_LEVEL["on"]),
    ("table2", "table", STRENGTH["tertiary"], ALTERNATE["non_ignorable"], NUMERIC["off"], CASE_FIRST["off"], CASE_LEVEL["on"]),
    ("table3", "table", STRENGTH["quaternary"], ALTERNATE["shifted"], NUMERIC["off"], CASE_FIRST["off"], CASE_LEVEL["off"]),
    ("table4", "table", STRENGTH["quaternary"], ALTERNATE["non_ignorable"], NUMERIC["off"], CASE_FIRST["off"], CASE_LEVEL["off"]),
    ("table5", "table", STRENGTH["tertiary"], ALTERNATE["shifted"], NUMERIC["off"], CASE_FIRST["off"], CASE_LEVEL["on"]),
    # The case level with a case order. The case order swaps the case
    # weights of the case level.
    ("caselevel6", "caselevel", STRENGTH["primary"], ALTERNATE["non_ignorable"], NUMERIC["off"], CASE_FIRST["lower_first"], CASE_LEVEL["on"]),
    ("caselevel7", "caselevel", STRENGTH["primary"], ALTERNATE["non_ignorable"], NUMERIC["off"], CASE_FIRST["upper_first"], CASE_LEVEL["on"]),
    ("caselevel8", "caselevel", STRENGTH["tertiary"], ALTERNATE["non_ignorable"], NUMERIC["off"], CASE_FIRST["lower_first"], CASE_LEVEL["on"]),
    ("caselevel9", "caselevel", STRENGTH["tertiary"], ALTERNATE["non_ignorable"], NUMERIC["off"], CASE_FIRST["upper_first"], CASE_LEVEL["on"]),
    # The fourth level with the case level. Both levels join the walk.
    ("quaternary5", "quaternary3", STRENGTH["quaternary"], ALTERNATE["shifted"], NUMERIC["off"], CASE_FIRST["off"], CASE_LEVEL["on"]),
    ("quaternary6", "quaternary3", STRENGTH["quaternary"], ALTERNATE["non_ignorable"], NUMERIC["off"], CASE_FIRST["off"], CASE_LEVEL["on"]),
    # The identical strength holds the fourth level too. The code points
    # decide the order of two texts that share every weight.
    ("identical1", "quaternary3", STRENGTH["identical"], ALTERNATE["shifted"], NUMERIC["off"], CASE_FIRST["off"], CASE_LEVEL["off"]),
    ("identical2", "quaternary3", STRENGTH["identical"], ALTERNATE["non_ignorable"], NUMERIC["off"], CASE_FIRST["off"], CASE_LEVEL["on"]),
    # The numeric order with the fourth level. A run of digits is one
    # element of the collation, so the fourth level takes one weight for
    # the run. The pairs hold the run beside a variable character, so the
    # fourth level holds both weights.
    ("numeric4", "numericquaternary", STRENGTH["quaternary"], ALTERNATE["shifted"], NUMERIC["on"], CASE_FIRST["off"], CASE_LEVEL["off"]),
    ("numeric5", "numericquaternary", STRENGTH["quaternary"], ALTERNATE["non_ignorable"], NUMERIC["on"], CASE_FIRST["off"], CASE_LEVEL["off"]),
    ("numeric6", "numericquaternary", STRENGTH["identical"], ALTERNATE["shifted"], NUMERIC["on"], CASE_FIRST["off"], CASE_LEVEL["off"]),
    ("numeric7", "numericquaternary", STRENGTH["quaternary"], ALTERNATE["shifted"], NUMERIC["on"], CASE_FIRST["off"], CASE_LEVEL["on"]),
]

# The count of pairs of each group. The count is 50,000 or more.
PAIRS_PER_GROUP = 50000


def sign(pairs, strength, alternate, numeric, case_first, case_level=0, oracle=None):
    """The sign of each pair from the ICU collator."""
    body = "".join("%s|%s\n" % (u.hexline(a), u.hexline(b)) for a, b in pairs)
    cmd = [oracle or ORACLE, "und", str(strength), str(alternate), str(numeric),
           str(case_first), str(case_level)]
    r = subprocess.run(cmd, input=body, capture_output=True, text=True)
    if r.returncode != 0:
        u.fail("the oracle failed: " + r.stderr[:500])
    out = r.stdout.split()
    if len(out) != len(pairs):
        u.fail("the oracle gave %d signs for %d pairs" % (len(out), len(pairs)))
    return [int(x) for x in out]


def table_points(rnd):
    """One code point of the table, at random."""
    lo, hi = rnd.choice(TABLE_RANGES)
    return rnd.randint(lo, hi)


def build_pairs(rnd):
    """The pairs of each option, 50,000 for each. A third of the pairs of
    an option come from each of its pair shapes. The alternate set has
    four shapes, so it holds 66,664 pairs."""
    third = PAIRS_PER_GROUP // 3
    pairs = {}
    # The strength: the pairs differ in case, in accent and in both.
    p = []
    for _ in range(PAIRS_PER_GROUP):
        n = rnd.randint(1, 3)
        p.append(([rnd.choice(LETTERS) for _ in range(n)],
                  [rnd.choice(LETTERS) for _ in range(rnd.randint(1, 3))]))
    pairs["strength"] = p
    # The alternate handling: the pairs hold the spaces, the punctuation
    # and the symbols, beside the letters and alone.
    p = []
    for _ in range(third):
        p.append(([rnd.choice(LETTERS), rnd.choice(PUNCT)],
                  [rnd.choice(LETTERS), rnd.choice(PUNCT)]))
    for _ in range(third):
        p.append(([rnd.choice(PUNCT) for _ in range(rnd.randint(1, 3))],
                  [rnd.choice(PUNCT) for _ in range(rnd.randint(1, 3))]))
    for _ in range(third):
        # The band of the variable characters. The last five code points
        # of the band decide the order of these pairs.
        p.append(([rnd.choice(VAR_LAST)], [rnd.choice(VAR_LAST)]))
    for _ in range(third):
        # The variable characters whose unit holds an element without a
        # primary weight after the variable element.
        p.append(([rnd.choice(VAR_FOLLOW)], [rnd.choice(VAR_FOLLOW)]))
    pairs["alternate"] = p
    # The numeric order: the pairs hold runs of digits with a different
    # count of digits, with leading zeros and of other scripts.
    p = []
    for _ in range(third):
        p.append(([rnd.choice(DIGITS) for _ in range(rnd.randint(1, 6))],
                  [rnd.choice(DIGITS) for _ in range(rnd.randint(1, 6))]))
    for _ in range(third):
        p.append(([0x30] * rnd.randint(0, 3) + [rnd.choice(DIGITS) for _ in range(rnd.randint(1, 4))],
                  [rnd.choice(DIGITS) for _ in range(rnd.randint(1, 4))]))
    for _ in range(third):
        # The runs of a different count of digits. The count of the
        # digits comes first, so a run of twelve digits and a run of
        # three digits order by their count.
        p.append(([rnd.choice(DIGITS) for _ in range(rnd.randint(9, 13))],
                  [rnd.choice(DIGITS) for _ in range(rnd.randint(1, 4))]))
    while len(p) < PAIRS_PER_GROUP:
        p.append(([rnd.choice(LETTERS)] + [rnd.choice(DIGITS) for _ in range(rnd.randint(1, 3))],
                  [rnd.choice(LETTERS)] + [rnd.choice(DIGITS) for _ in range(rnd.randint(1, 3))]))
    pairs["numeric"] = p
    # The numeric order with the fourth level. The pairs hold a run of
    # digits beside a variable character, so the fourth level holds the
    # weight of the dropped element and the weight of the run.
    p = []
    for _ in range(third):
        p.append(([rnd.choice(PUNCT)] + [rnd.choice(DIGITS) for _ in range(rnd.randint(1, 3))],
                  [rnd.choice(DIGITS) for _ in range(rnd.randint(1, 3))]))
    for _ in range(third):
        p.append(([rnd.choice(DIGITS) for _ in range(rnd.randint(1, 3))] + [rnd.choice(PUNCT)],
                  [rnd.choice(DIGITS) for _ in range(rnd.randint(1, 3))] + [rnd.choice(PUNCT)]))
    for _ in range(third):
        p.append(([rnd.choice(LETTERS)] + [rnd.choice(DIGITS) for _ in range(rnd.randint(1, 4))],
                  [rnd.choice(LETTERS)] + [rnd.choice(DIGITS) for _ in range(rnd.randint(1, 4))]))
    while len(p) < PAIRS_PER_GROUP:
        p.append(([rnd.choice(PUNCT), rnd.choice(PUNCT)] + [rnd.choice(DIGITS) for _ in range(rnd.randint(1, 3))],
                  [rnd.choice(DIGITS) for _ in range(rnd.randint(1, 3))]))
    pairs["numericquaternary"] = p
    # The case order: the pairs hold the upper case and the lower case
    # of one letter, and the compatibility forms.
    p = []
    for _ in range(third):
        p.append(([rnd.choice(LETTERS)], [rnd.choice(LETTERS)]))
    for _ in range(third):
        p.append(([rnd.choice(LETTERS) for _ in range(rnd.randint(1, 3))],
                  [rnd.choice(LETTERS) for _ in range(rnd.randint(1, 3))]))
    while len(p) < PAIRS_PER_GROUP:
        p.append(([rnd.choice(OTHER)], [rnd.choice(OTHER)]))
    pairs["case"] = p
    # The case level: the pairs hold the upper case and the lower case
    # of one letter, with an accent and without one.
    p = []
    for _ in range(third):
        p.append(([rnd.choice(LETTERS)], [rnd.choice(LETTERS)]))
    for _ in range(third):
        p.append(([rnd.choice(LETTERS) for _ in range(rnd.randint(1, 3))],
                  [rnd.choice(LETTERS) for _ in range(rnd.randint(1, 3))]))
    while len(p) < PAIRS_PER_GROUP:
        p.append(([rnd.choice(LETTERS), 0x0301], [rnd.choice(LETTERS)]))
    pairs["caselevel"] = p
    # The quaternary strength: the pairs hold the variable characters
    # beside the letters, so the fourth level decides.
    p = []
    for _ in range(third):
        p.append(([rnd.choice(LETTERS), rnd.choice(PUNCT)],
                  [rnd.choice(LETTERS), rnd.choice(PUNCT)]))
    for _ in range(third):
        p.append(([rnd.choice(PUNCT), rnd.choice(LETTERS)],
                  [rnd.choice(LETTERS), rnd.choice(PUNCT)]))
    for _ in range(third):
        p.append(([rnd.choice(LETTERS), rnd.choice(PUNCT), rnd.choice(LETTERS)],
                  [rnd.choice(LETTERS), rnd.choice(LETTERS)]))
    while len(p) < PAIRS_PER_GROUP:
        p.append(([rnd.choice(LETTERS), rnd.choice(PUNCT)],
                  [rnd.choice(LETTERS), rnd.choice(LETTERS)]))
    pairs["quaternary"] = p
    # The quaternary strength over the pairs of the alternate set. They
    # hold the variable characters and the marks that follow them.
    p = []
    for _ in range(third):
        p.append(([rnd.choice(LETTERS), rnd.choice(PUNCT)],
                  [rnd.choice(LETTERS), rnd.choice(PUNCT)]))
    for _ in range(third):
        p.append(([rnd.choice(VAR_FOLLOW)], [rnd.choice(VAR_FOLLOW)]))
    for _ in range(third):
        p.append(([rnd.choice(VAR_LAST)], [rnd.choice(VAR_LAST)]))
    while len(p) < PAIRS_PER_GROUP:
        p.append(([rnd.choice(LETTERS), rnd.choice(PUNCT), rnd.choice(LETTERS)],
                  [rnd.choice(LETTERS), rnd.choice(LETTERS)]))
    pairs["quaternary3"] = p
    # The whole table: the code points of every range of the table. The
    # pairs hold them beside the letters and beside each other, so the
    # new levels meet the shapes of the table.
    p = []
    for _ in range(third):
        p.append(([table_points(rnd)], [table_points(rnd)]))
    for _ in range(third):
        p.append(([table_points(rnd), rnd.choice(LETTERS)],
                  [table_points(rnd), rnd.choice(LETTERS)]))
    for _ in range(third):
        p.append(([table_points(rnd), rnd.choice(PUNCT)],
                  [table_points(rnd), rnd.choice(LETTERS)]))
    while len(p) < PAIRS_PER_GROUP:
        p.append(([table_points(rnd), table_points(rnd), table_points(rnd)],
                  [table_points(rnd), table_points(rnd)]))
    pairs["table"] = p
    return pairs


def edge_pairs():
    """The pairs that check the edges. Each entry holds a name and the
    two texts."""
    return [
        ("empty and empty", [], []),
        ("empty and a", [], [0x61]),
        ("a and empty", [0x61], []),
        ("one digit", [0x31], [0x32]),
        ("only zeros", [0x30, 0x30], [0x30, 0x30, 0x30]),
        ("zeros and one zero", [0x30, 0x30], [0x30]),
        ("one zero and zeros", [0x30], [0x30, 0x30]),
        ("zeros and a digit", [0x30, 0x30, 0x31], [0x31]),
        ("run at the end", [0x61, 0x31], [0x61, 0x31, 0x32]),
        ("digit beside a mark", [0x31, 0x0301, 0x32], [0x31, 0x32]),
        ("digit of another script", [0x661], [0x31]),
        ("no table row", [0x0378], [0x0379]),
        ("no table row and a digit", [0x0378, 0x31], [0x31]),
        ("emoji", [0x1F600], [0x1F601]),
        ("emoji and a digit", [0x1F600, 0x31], [0x1F600, 0x32]),
        ("a mark alone", [0x0301], [0x0302]),
        ("a contraction", [0x01C4, 0x01C5], [0x01C6]),
        ("a contraction with a mark", [0x01C4, 0x0301], [0x01C4]),
        ("two variable marks", [0x2018, 0x2019], [0x2018]),
        ("a variable mark and a digit", [0x2018, 0x31], [0x31]),
        ("nine and ten", [0x39], [0x31, 0x30]),
        ("twelve and nine", [0x31, 0x32], [0x39]),
        ("twenty one and one hundred", [0x32, 0x31], [0x31, 0x30, 0x30]),
        ("a long run", [0x31] * 12, [0x31] * 13),
        ("a dropped element and a number", [0x2C, 0x32], [0x30, 0x32]),
        ("a number and a dropped element", [0x32], [0x2C, 0x32]),
        ("a number and two dropped elements", [0x32], [0x5F, 0x32, 0x2E, 0x2E]),
    ]


def main():
    if not os.path.exists(ORACLE):
        u.fail("the oracle is missing; build test/oracle/csrc/collopt.c against ICU 79.1")

    rnd = random.Random(20261113)
    pairs = build_pairs(rnd)
    edges = edge_pairs()

    # The pool holds the code points of every text of the four pair
    # sets. The offsets give the start of each case. A case holds the
    # count of the code points of the first text, the code points, the
    # count of the second text and its code points.
    pool = []
    off = []
    base_start = {}
    for base in ("strength", "alternate", "numeric", "numericquaternary",
                 "case", "caselevel", "quaternary", "quaternary3", "table"):
        base_start[base] = len(off)
        for a, b in pairs[base]:
            off.append(len(pool))
            pool.append(len(a))
            pool.extend(a)
            pool.append(len(b))
            pool.extend(b)
    # The signs: one byte for each case of each group, plus one.
    exp = bytearray()
    table = []
    for name, base, strength, alternate, numeric, case_first, case_level in GROUPS:
        table.extend([strength, alternate, numeric, case_first, case_level,
                      base_start[base], len(pairs[base]), len(exp)])
        signs = sign(pairs[base], strength, alternate, numeric, case_first, case_level)
        exp.extend(s + 1 for s in signs)

    # The edge cases. Each edge gives the sign under the default options,
    # under the numeric order and under the numeric order with the fourth
    # level and the shifted handling.
    edge_off = []
    edge_exp = []
    for _, a, b in edges:
        edge_off.append(len(pool))
        pool.append(len(a))
        pool.extend(a)
        pool.append(len(b))
        pool.extend(b)
    default = sign([(a, b) for _, a, b in edges], STRENGTH["tertiary"],
                   ALTERNATE["non_ignorable"], NUMERIC["off"], CASE_FIRST["off"])
    numeric = sign([(a, b) for _, a, b in edges], STRENGTH["tertiary"],
                   ALTERNATE["non_ignorable"], NUMERIC["on"], CASE_FIRST["off"])
    fourth = sign([(a, b) for _, a, b in edges], STRENGTH["quaternary"],
                  ALTERNATE["shifted"], NUMERIC["on"], CASE_FIRST["off"])
    for i in range(len(edges)):
        edge_exp.append(default[i] + 1)
        edge_exp.append(numeric[i] + 1)
        edge_exp.append(fourth[i] + 1)

    with open(os.path.join(HERE, "suite", "collopt_cases.goose"), "w", encoding="utf-8") as f:
        f.write("// Generated by test/make_collopt_cases.py. Do not edit by hand.\n")
        f.write("// The cases of the collation options. The expected signs come\n")
        f.write("// from the ICU collator of release 79.1.\n")
        f.write("namespace suite;\n\n")
        f.write(u.bytes_array("CO_OPT_POOL", u.pool_bytes(pool),
                              "For each case: the count of the code points of the first text, "
                              "the code points, the count of the code points of the second text, "
                              "the code points."))
        f.write(u.bytes_array("CO_OPT_OFF", u.pool_bytes(off),
                              "Start of each case in CO_OPT_POOL."))
        f.write(u.bytes_array("CO_OPT_EXP", bytes(exp),
                              "The expected sign of each case of each group, plus one. "
                              "The groups follow each other in the order of CO_OPT_GROUPS."))
        f.write(u.bytes_array("CO_OPT_EDGE_OFF", u.pool_bytes(edge_off),
                              "Start of each edge case in CO_OPT_POOL."))
        f.write(u.bytes_array("CO_OPT_EDGE_EXP", bytes(edge_exp),
                              "The expected sign of each edge case, plus one. The first sign of an "
                              "edge case comes from the default options, the second from the "
                              "numeric order, the third from the numeric order with the fourth "
                              "level and the shifted handling."))
        f.write("// The table of the groups. Each group holds the strength, the alternate\n")
        f.write("// handling, the numeric order, the case order, the case level, the first\n")
        f.write("// case in CO_OPT_OFF, the count of its cases and the first sign in\n")
        f.write("// CO_OPT_EXP.\n")
        f.write("const CO_OPT_GROUPS: i64[%d] = [\n" % len(table))
        for i in range(0, len(table), 8):
            f.write("    " + ", ".join(str(v) for v in table[i:i + 8]) + ",\n")
        f.write("];\n")
    print("collopt cases: %d signs in %d groups, %d texts, %d edge cases" % (
        len(exp), len(GROUPS), len(off), len(edges)))


if __name__ == "__main__":
    main()
