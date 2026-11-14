#!/usr/bin/env python3
"""Compare the collation options of ICU, Node and Rust on seeded pairs.

This script is a tool of the maintainer. The user of the package never
runs it. For each option it takes 2,000 pairs from the generator of the
test cases and asks three references for the sign of each pair:

- ICU 79.1, through test/oracle/csrc/collopt.c
- Node 22, through Intl.Collator
- the Rust crate icu_collator 2.4.0, through a small program that takes
  the strength, the alternate handling, the numeric order, the case order
  and a list of pairs as arguments

It prints the count of pairs of each option and the count of pairs on
which Node or Rust differs from ICU. The package itself is checked
against ICU by the test suite.

Usage: collopt_battery.py <collopt oracle> <node program> <rust program>
The Node program reads one pair per line and takes the options of
Intl.Collator as a JSON argument. The Rust program is described above.
"""
import json
import os
import random
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import make_collopt_cases as m
import ucdlib as u

COUNT = 2000

# The options of Node that match the attributes of ICU, by group name.
# The strength 15 and the shifted handling have no exact match in Node:
# ignorePunctuation moves the variable characters to the fourth level.
# The sensitivity "case" of Node is the primary strength with the case
# level on. The secondary strength with the case level has no match, so
# the group stays out of the Node rows.
NODE = {
    "strength": {"sensitivity": "base"},
    "strength2": {"sensitivity": "accent"},
    "strength3": {"sensitivity": "variant"},
    "alternate": {},
    "alternate2": {"ignorePunctuation": True},
    "numeric": {},
    "numeric2": {"numeric": True},
    "case": {},
    "case2": {"caseFirst": "lower"},
    "case3": {"caseFirst": "upper"},
    "caselevel": {"sensitivity": "case"},
    "caselevel3": {"sensitivity": "variant"},
}
RUST_STRENGTH = {0: "primary", 1: "secondary", 2: "tertiary", 3: "quaternary",
                 15: "identical"}
RUST_CASE = {16: "off", 24: "lower", 25: "upper"}


def sgn(x):
    return (x > 0) - (x < 0)


def node_signs(node_prog, opts, pairs):
    body = "".join("%s|%s\n" % (u.hexline(a), u.hexline(b)) for a, b in pairs)
    r = subprocess.run(["node", node_prog, json.dumps(opts)], input=body,
                       capture_output=True, text=True)
    return [sgn(int(x)) for x in r.stdout.split()]


def rust_signs(rust_prog, strength, alternate, numeric, case_first, case_level, pairs):
    out = []
    for i in range(0, len(pairs), 200):
        chunk = pairs[i:i + 200]
        arg = ",".join("%s:%s" % ("-".join("%X" % c for c in a) or "0",
                                  "-".join("%X" % c for c in b) or "0") for a, b in chunk)
        # The program reads the empty text as the code point 0, so the
        # pairs with an empty text stay out of this battery.
        r = subprocess.run([rust_prog, RUST_STRENGTH[strength],
                            "shifted" if alternate == 20 else "non",
                            "true" if numeric == 17 else "false",
                            RUST_CASE[case_first],
                            "on" if case_level == 1 else "off", arg],
                           capture_output=True, text=True)
        for line in r.stdout.splitlines():
            out.append({"-": -1, "0": 0, "+": 1}[line.split()[0]])
    return out


def main():
    if len(sys.argv) < 4:
        print(__doc__)
        sys.exit(2)
    oracle = sys.argv[1]
    node_prog, rust_prog = sys.argv[2], sys.argv[3]
    rnd = random.Random(20261114)
    pairs = m.build_pairs(rnd)
    print("%-12s %6s %12s %12s" % ("group", "pairs", "node differs", "rust differs"))
    for name, base, strength, alternate, numeric, case_first, case_level in m.GROUPS:
        sample = rnd.sample(pairs[base], COUNT)
        icu = m.sign(sample, strength, alternate, numeric, case_first, case_level,
                     oracle)
        nd = "-"
        if name in NODE:
            node = node_signs(node_prog, NODE[name], sample)
            nd = str(sum(1 for a, b in zip(icu, node) if a != b))
        rust = rust_signs(rust_prog, strength, alternate, numeric, case_first,
                          case_level, sample)
        rd = str(sum(1 for a, b in zip(icu, rust) if a != b)) if len(rust) == len(icu) else "n/a"
        print("%-12s %6d %12s %12s" % (name, len(sample), nd, rd))


if __name__ == "__main__":
    main()
