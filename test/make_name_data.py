#!/usr/bin/env python3
"""Make name_data.goose and test/suite/name_cases.goose: the name lookup.

The lookup inverts the table of names in props_data.goose. The script
reads that table, sorts the names, and writes the sorted order as indexes
into the table. It writes the formal name aliases of NameAliases.txt in
the same way: the sorted text, the code point of each alias.
The script checks that no two names are equal and that no two aliases
are equal. It then checks the lookup against the ICU library for every
name and every alias, and against Python unicodedata.lookup for every
name that the Python release holds. The suite file holds sample names,
near misses and the answer of ICU for each.
Usage: make_name_data.py [ucd directory]
"""
import os
import re
import sys
import unicodedata

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ucdlib as u


def read_table():
    text = open(os.path.join(u.ROOT, "props_data.goose"), encoding="utf-8").read()

    def numbers(name):
        m = re.search(r"const %s: i64\[\d+\] = \[(.*?)\];" % name, text, re.S)
        return [int(x) for x in m.group(1).replace("\n", " ").split(",") if x.strip()]
    chars = re.search(r'const NAME_NAMES: u8\[\] = "(.*?)";\n', text, re.S).group(1)
    start, off = numbers("NAME_START"), numbers("NAME_OFF")
    return start, [chars[off[i]:off[i + 1]] for i in range(len(start))]


def read_aliases():
    out, kinds = {}, {}
    for line in u.lines_of("NameAliases.txt"):
        cp, alias, kind = [x.strip() for x in line.split(";")]
        if alias in out:
            u.fail("alias twice: " + alias)
        out[alias] = int(cp, 16)
        kinds[alias] = kind
    return out, kinds


def main():
    start, names = read_table()
    aliases, kinds = read_aliases()
    order = sorted(range(len(names)), key=lambda i: names[i])
    for a, b in zip(order, order[1:]):
        if names[a] == names[b]:
            u.fail("name twice: " + names[a])
    by_name = {n: start[i] for i, n in enumerate(names)}
    akeys = sorted(aliases)
    # A name wins over an alias of the same text, so the alias table
    # keeps only the aliases that no name has.
    shadow = [a for a in akeys if a in by_name]
    akeys = [a for a in akeys if a not in by_name]

    # The second source: ICU, for every name and for the aliases of the
    # type correction. ICU holds no other alias.
    corrections = [a for a in akeys if kinds[a] == "correction"]
    lines = [n for n in names] + corrections
    icu = u.oracle_go("fromname", stdin="\n".join(lines) + "\n")
    if len(icu) != len(lines):
        u.fail("the ICU oracle gave %d lines for %d names" % (len(icu), len(lines)))
    for i, n in enumerate(names):
        if int(icu[i], 16) != start[i]:
            u.fail("ICU gives %s for %s" % (icu[i], n))
    for j, a in enumerate(corrections):
        if int(icu[len(names) + j], 16) != aliases[a]:
            u.fail("ICU gives %s for the alias %s" % (icu[len(names) + j], a))

    # The third source: Python, for the names and the aliases of its
    # release. Python holds the aliases of every type.
    held = 0
    for n, cp in list(by_name.items()) + [(a, aliases[a]) for a in akeys]:
        try:
            got = unicodedata.lookup(n)
        except KeyError:
            continue
        if len(got) != 1 or ord(got) != cp:
            u.fail("Python gives another code point for " + n)
        held += 1
    print("Python holds %d of %d names and aliases; names shadow %d aliases"
          % (held, len(names) + len(akeys), len(shadow)))

    achars = "".join(akeys)
    aoff = [0]
    for a in akeys:
        aoff.append(aoff[-1] + len(a))
    parts = [
        u.array("NAME_ORDER", order, "The index in NAME_START of each name, in the sorted order of the names."),
        u.string("ALIAS_NAMES", achars, "The aliases in sorted order, joined."),
        u.array("ALIAS_OFF", aoff, "The start of each alias in ALIAS_NAMES."),
        u.array("ALIAS_CP", [aliases[a] for a in akeys], "The code point of each alias."),
    ]
    u.write_goose(os.path.join(u.ROOT, "name_data.goose"), "make_name_data.py", parts)

    # The suite sample: names, aliases and near misses, with the ICU answer.
    near = []
    for i in range(0, len(names), 997):
        n = names[i]
        near += [n, n.lower(), n[:-1], n + "X", " " + n, n + " ", n.replace(" ", "-", 1)]
    near += ["", "A", "ZZZZ", "HANGUL SYLLABLE GAX", "CJK UNIFIED IDEOGRAPH-4E0",
             "CJK UNIFIED IDEOGRAPH-4e00", "LINE FEED (LF)", "nbsp", "Lf", "BELL"]
    answers = u.oracle_go("fromname", stdin="\n".join(near) + "\n")
    cps, want = [], []
    pool, off = [], [0]
    for q, a in zip(near, answers):
        pool += [ord(c) for c in q]
        off.append(len(pool))
        if a == "-1":
            want.append(aliases.get(q.upper(), -1) if q.upper() in akeys else -1)
        else:
            want.append(int(a, 16))
    suite = [
        u.array("NQ_POOL", pool, "The code points of each query."),
        u.array("NQ_OFF", off, "The end of each query in NQ_POOL."),
        u.array("NQ_WANT", want, "The code point of each query from ICU, or -1."),
        u.array("NAL_CP", [aliases[a] for a in akeys], "The code point of each alias."),
        u.string("NAL_NAMES", achars),
        u.array("NAL_OFF", aoff, "The end of each alias in NAL_NAMES."),
    ]
    u.write_goose(os.path.join(u.ROOT, "test", "suite", "name_cases.goose"),
                  "make_name_data.py", suite, "suite")
    print("name_data.goose: %d names, %d aliases; name_cases.goose: %d queries"
          % (len(names), len(akeys), len(near)))


if __name__ == "__main__":
    main()
