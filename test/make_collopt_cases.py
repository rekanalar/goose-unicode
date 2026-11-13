#!/usr/bin/env python3
"""Make test/suite/collopt_cases.goose: the cases of the collation options.

The reference is the ICU collator of release 79.1. The oracle is
test/oracle/csrc/collopt.c. It takes the locale and the five attributes
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
STRENGTH = {"primary": 0, "secondary": 1, "tertiary": 2, "identical": 15}
ALTERNATE = {"non_ignorable": 21, "shifted": 20}
NUMERIC = {"off": 16, "on": 17}
CASE_FIRST = {"off": 16, "lower_first": 24, "upper_first": 25}

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

# The names of the groups and the attributes of each group. The suite
# reads the names to pick the options.
GROUPS = [
    ("strength", STRENGTH["primary"], ALTERNATE["non_ignorable"], NUMERIC["off"], CASE_FIRST["off"]),
    ("strength2", STRENGTH["secondary"], ALTERNATE["non_ignorable"], NUMERIC["off"], CASE_FIRST["off"]),
    ("strength3", STRENGTH["tertiary"], ALTERNATE["non_ignorable"], NUMERIC["off"], CASE_FIRST["off"]),
    ("strength4", STRENGTH["identical"], ALTERNATE["non_ignorable"], NUMERIC["off"], CASE_FIRST["off"]),
    ("alternate", STRENGTH["tertiary"], ALTERNATE["non_ignorable"], NUMERIC["off"], CASE_FIRST["off"]),
    ("alternate2", STRENGTH["tertiary"], ALTERNATE["shifted"], NUMERIC["off"], CASE_FIRST["off"]),
    ("numeric", STRENGTH["tertiary"], ALTERNATE["non_ignorable"], NUMERIC["off"], CASE_FIRST["off"]),
    ("numeric2", STRENGTH["tertiary"], ALTERNATE["non_ignorable"], NUMERIC["on"], CASE_FIRST["off"]),
    ("case", STRENGTH["tertiary"], ALTERNATE["non_ignorable"], NUMERIC["off"], CASE_FIRST["off"]),
    ("case2", STRENGTH["tertiary"], ALTERNATE["non_ignorable"], NUMERIC["off"], CASE_FIRST["lower_first"]),
    ("case3", STRENGTH["tertiary"], ALTERNATE["non_ignorable"], NUMERIC["off"], CASE_FIRST["upper_first"]),
]

# The count of pairs of each group. The count is 50,000 or more.
PAIRS_PER_GROUP = 50000


def sign(pairs, strength, alternate, numeric, case_first, oracle=None):
    """The sign of each pair from the ICU collator."""
    body = "".join("%s|%s\n" % (u.hexline(a), u.hexline(b)) for a, b in pairs)
    cmd = [oracle or ORACLE, "und", str(strength), str(alternate), str(numeric), str(case_first)]
    r = subprocess.run(cmd, input=body, capture_output=True, text=True)
    if r.returncode != 0:
        u.fail("the oracle failed: " + r.stderr[:500])
    out = r.stdout.split()
    if len(out) != len(pairs):
        u.fail("the oracle gave %d signs for %d pairs" % (len(out), len(pairs)))
    return [int(x) for x in out]


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
    for base in ("strength", "alternate", "numeric", "case"):
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
    for name, strength, alternate, numeric, case_first in GROUPS:
        base = name.rstrip("234")
        table.extend([strength, alternate, numeric, case_first, base_start[base], len(pairs[base]), len(exp)])
        signs = sign(pairs[base], strength, alternate, numeric, case_first)
        exp.extend(s + 1 for s in signs)

    # The edge cases. Each edge gives the sign under the default options
    # and under the numeric order.
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
    for i in range(len(edges)):
        edge_exp.append(default[i] + 1)
        edge_exp.append(numeric[i] + 1)

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
                              "numeric order."))
        f.write("// The table of the groups. Each group holds the strength, the alternate\n")
        f.write("// handling, the numeric order, the case order, the first case in\n")
        f.write("// CO_OPT_OFF, the count of its cases and the first sign in CO_OPT_EXP.\n")
        f.write("const CO_OPT_GROUPS: i64[%d] = [\n" % len(table))
        for i in range(0, len(table), 7):
            f.write("    " + ", ".join(str(v) for v in table[i:i + 7]) + ",\n")
        f.write("];\n")
    print("collopt cases: %d signs in %d groups, %d texts, %d edge cases" % (
        len(exp), len(GROUPS), len(off), len(edges)))


if __name__ == "__main__":
    main()
