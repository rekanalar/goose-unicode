#!/usr/bin/env python3
"""Make coll_data.goose: the collation elements of every code point.

The table comes from allkeys17.txt, the allkeys_CLDR.txt of the Unicode
17.0.0 commit of the CLDR repository. The root tailoring is empty, so
the file holds no contractions: every row maps one code point to a
sequence of collation elements. A code point with no row takes the
implicit weights of UTS #10, which collate.goose computes.

The script also writes test/suite/coll_cases.goose. It holds the texts
of CollationTest_CLDR_NON_IGNORABLE.txt of the same commit: each line
of that file orders strictly above the line before it. It holds
random pairs from the whole range with the sign of the ICU collator
on the und locale as well. Usage: make_coll_data.py [ucd directory]
"""
import os
import random
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ucdlib as u


def parse_elements():
    """The rows of allkeys17.txt.

    Returns (singles, contracts): singles maps one code point to its
    element list. contracts maps a tuple of code points to its element
    list. The table holds contractions of up to three code points.
    """
    singles = {}
    contracts = {}
    for line in u.lines_of("allkeys17.txt"):
        if line.startswith("@"):
            continue
        lhs, rhs = line.split(";", 1)
        elements = re.findall(r"[.*]([0-9A-F]{4})\.([0-9A-F]{4})\.([0-9A-F]{4})", rhs)
        if not elements:
            u.fail("no elements in row " + lhs)
        if ".." in lhs:
            u.fail("range rows are not supported: " + lhs)
        seq = [int(f, 16) for f in lhs.split()]
        weights = [(int(a, 16), int(b, 16), int(c, 16)) for a, b, c in elements]
        if len(seq) == 1:
            singles[seq[0]] = weights
        elif len(seq) <= 3:
            contracts[tuple(seq)] = weights
        else:
            u.fail("contractions of more than three code points: " + lhs)
    return singles, contracts


def parse_unified_ideograph():
    """The ranges of the Unified_Ideograph property of PropList.txt."""
    ranges = []
    for line in u.lines_of("PropList.txt"):
        parts = [x.strip() for x in line.split(";")]
        if len(parts) < 2 or parts[1] != "Unified_Ideograph":
            continue
        lo, hi = u.parse_range(parts[0])
        ranges.append((lo, hi))
    return ranges


def runs_of_set(values):
    """The sorted set of code points as (start, end) runs."""
    runs = []
    for cp in sorted(values):
        if runs and cp == runs[-1][1] + 1:
            runs[-1][1] = cp
        else:
            runs.append([cp, cp])
    return [(a, b) for a, b in runs]


def implicit_tables():
    """The ranges that decide the implicit weights of UTS #10.

    Each group holds a base and a tail. The siniform scripts take the
    base of their block and the tail from the first code point of the
    block. Han takes the base from the plane of the code point. Only
    assigned code points take part, so each range holds the assigned
    code points of its block only.
    """
    rows = u.unicode_data()
    assigned = set(rows)
    ui = set()
    for lo, hi in parse_unified_ideograph():
        ui.update(range(lo, hi + 1))
    ui &= assigned
    # The core Han holds the two blocks of the standard. The rest of
    # the unified ideographs hold the other Han.
    core = {cp for cp in ui if 0x4E00 <= cp <= 0x9FFF or 0xF900 <= cp <= 0xFAFF}
    other = ui - core
    blocks = [
        (((0x17000, 0x187FF), (0x18D00, 0x18D7F)), 0xFB00, 0x17000),  # Tangut
        (((0x18800, 0x18AFF), (0x18D80, 0x18DFF)), 0xFB01, 0x18800),  # Tangut Components
        (((0x1B170, 0x1B2FF),), 0xFB02, 0x1B170),                     # Nushu
        (((0x18B00, 0x18CFF),), 0xFB03, 0x18B00),                     # Khitan Small Script
    ]
    sini_s, sini_e, sini_a, sini_b = [], [], [], []
    sini_runs = []
    for blks, aaaa, base in blocks:
        cps = set()
        for lo, hi in blks:
            cps.update(range(lo, hi + 1))
        cps &= assigned
        cps -= ui
        for lo, hi in runs_of_set(cps):
            sini_runs.append((lo, hi, aaaa, base))
    # The walk looks the runs up with a binary search, so the runs
    # must sit in code point order.
    sini_runs.sort()
    for lo, hi, aaaa, base in sini_runs:
        sini_s.append(lo)
        sini_e.append(hi)
        sini_a.append(aaaa)
        sini_b.append(base)
    return (runs_of_set(core), runs_of_set(other),
            sini_s, sini_e, sini_a, sini_b)


def check_weights(rows):
    """The key bytes hold 0000 for nothing at a level and 0001 for the
    level separator. A primary of 0001 moves to 0002: the table holds
    it for U+FFFE only, and no row holds 0002, so the order stays."""
    for elements in rows.values():
        for k, e in enumerate(elements):
            if e[0] == 0x0001:
                elements[k] = (0x0002, e[1], e[2])
                e = elements[k]
            for w in e:
                if w == 0x0001:
                    u.fail("weight 0001 collides with a level byte")


def parse_conformance():
    """The ordered texts of the conformance file with the relation of
    each line to the one before it.

    Consecutive lines may hold the same key, so the relation comes from
    the key of each line, not from the position: 1 when the line orders
    above the one before it, 0 when both hold the same weights. A line
    whose text holds a lone surrogate stays out: the package rejects a
    lone surrogate as a bad byte, so the replay cannot encode it. The
    relations of the kept lines stay correct, because the order of the
    file is strict or equal. Returns (texts, rels).
    """
    texts = []
    keys = []
    with open(u.ucd_path("CollTest17.txt"), encoding="utf-8") as f:
        for line in f:
            if line.startswith("#") or ";" not in line:
                continue
            lhs = line.split(";")[0].split("#")[0].strip()
            # The key is the bracket group at the end of the line. A
            # comment may hold a bracket of its own, as the name of "["
            # does, so the search starts at the last one.
            end = line.rfind("]")
            start = line.rfind("[", 0, end)
            if start < 0 or end < 0:
                u.fail("no key in conformance line " + lhs)
            groups = line[start + 1:end].split("|")
            if len(groups) < 3:
                u.fail("key with less than three levels: " + lhs)
            key = tuple(
                tuple(int(w, 16) for w in g.split())
                for g in groups[:3]
            )
            text = [int(x, 16) for x in lhs.split()]
            if any(0xD800 <= c <= 0xDFFF for c in text):
                continue
            texts.append(text)
            keys.append(key)
    if len(texts) < 1000:
        u.fail("only %d conformance lines" % len(texts))
    rels = []
    for k in range(len(texts)):
        if k == 0:
            rels.append(1)
        elif keys[k] == keys[k - 1]:
            rels.append(0)
        elif keys[k] > keys[k - 1]:
            rels.append(1)
        else:
            u.fail("the conformance file goes down at line %d" % (k + 1))
    return texts, rels


def main():
    u.check_version()
    singles, contracts = parse_elements()
    check_weights(singles)
    check_weights(contracts)

    # The units hold the element lists. The single code point rows come
    # first, in code point order, then the contraction rows.
    units = [singles[cp] for cp in sorted(singles)]
    units += [contracts[seq] for seq in sorted(contracts)]
    unit_off = [0]
    for elements in units:
        unit_off.append(unit_off[-1] + len(elements))
    pool_p = [e[0] for elements in units for e in elements]
    pool_s = [e[1] for elements in units for e in elements]
    pool_t = [e[2] for elements in units for e in elements]

    # The contractions sit under their first code point. Each record
    # holds the tail length, the tail code points and the unit index.
    # Within one group the longer tails come first, so the walk takes
    # the first match.
    seqs = sorted(contracts)
    unit_of = {seq: len(singles) + i for i, seq in enumerate(seqs)}
    firsts = sorted(set(seq[0] for seq in contracts))
    recs = []
    first_off = []
    for first in firsts:
        first_off.append(len(recs))
        group = sorted((seq for seq in seqs if seq[0] == first),
                       key=lambda s: -len(s))
        for seq in group:
            recs += [len(seq) - 1] + list(seq[1:]) + [unit_of[seq]]
    first_off.append(len(recs))

    cps = sorted(singles)
    # Every jamo of the Hangul syllables must hold a row, because the
    # package decomposes the syllables into their jamos.
    for s in range(0, 0xD7A4 - 0xAC00):
        for jamo in (0x1100 + s // 588, 0x1161 + (s % 588) // 28):
            if jamo not in singles:
                u.fail("no row for the Hangul jamo %04X" % jamo)
        t = s % 28
        if t > 0 and (0x11A7 + t) not in singles:
            u.fail("no row for the Hangul jamo %04X" % (0x11A7 + t))

    core, other, sini_s, sini_e, sini_a, sini_b = implicit_tables()
    core_s = [a for a, b in core]
    core_e = [b for a, b in core]
    hano_s = [a for a, b in other]
    hano_e = [b for a, b in other]
    data = [
        u.array("COLL_CP", cps, "The code point of each single row. Its index is the unit index."),
        u.array("COLL_FIRST", firsts, "The first code point of each contraction group."),
        u.array("COLL_FOFF", first_off, "The start of each contraction group in COLL_REC."),
        u.array("COLL_REC", recs, "Each record holds the tail length, the tail code points and the unit."),
        u.array("COLL_EOFF", unit_off, "The start of each unit in the element pools."),
        u.array("COLL_P", pool_p, "The primary weight of each element."),
        u.array("COLL_S", pool_s, "The secondary weight of each element."),
        u.array("COLL_T", pool_t, "The tertiary weight of each element."),
        u.array("COLL_SINI_S", sini_s, "The start of each siniform run."),
        u.array("COLL_SINI_E", sini_e, "The end of each siniform run."),
        u.array("COLL_SINI_A", sini_a, "The base weight of each siniform run."),
        u.array("COLL_SINI_B", sini_b, "The first code point of each siniform tail."),
        u.array("COLL_HAN_S", core_s, "The start of each core Han run."),
        u.array("COLL_HAN_E", core_e, "The end of each core Han run."),
        u.array("COLL_HANO_S", hano_s, "The start of each other Han run."),
        u.array("COLL_HANO_E", hano_e, "The end of each other Han run."),
    ]
    u.write_goose(os.path.join(u.ROOT, "coll_data.goose"),
                  "make_coll_data.py", data)

    # ---- the suite tables --------------------------------------------------
    texts, rels = parse_conformance()
    case_pool, case_off = [], [0]
    for text in texts:
        case_pool += text
        case_off.append(len(case_pool))
    case_rel = rels

    # The random pairs come from the ICU oracle on the und locale. The
    # pairs cover the whole range, the unassigned code points and the
    # expansions. A pair of two Han code points stays out: the ICU 78
    # collator orders the Han by the Unihan radical stroke, while the
    # conformance file and the Go and Rust references order it by the
    # implicit weights of UTS #10. The README names the difference.
    rng = random.Random(20261110)
    han = set()
    for a, b in core + other:
        han.update(range(a, b + 1))
    pair_cps = []
    while len(pair_cps) < 10000:
        cp = rng.randrange(0x110000)
        if 0xD800 <= cp <= 0xDFFF:
            continue  # the package rejects a lone surrogate, so the pairs hold none
        pair_cps.append(cp)
    out_cps = []
    k = 0
    while k + 1 < len(pair_cps) and len(out_cps) < 10000:
        if pair_cps[k] in han and pair_cps[k + 1] in han:
            k += 2
            continue
        out_cps += [pair_cps[k], pair_cps[k + 1]]
        k += 2
    pair_cps = out_cps
    lines = ["%X|%X" % (pair_cps[k], pair_cps[k + 1])
             for k in range(0, len(pair_cps), 2)]
    signs = u.oracle_go("icecoll", stdin="\n".join(lines) + "\n")
    if len(signs) != len(lines):
        u.fail("the ICU oracle returned %d lines for %d pairs"
               % (len(signs), len(lines)))
    pair_sign = []
    for s in signs:
        v = int(s)
        if v not in (-1, 0, 1):
            u.fail("the ICU oracle returned the sign %d" % v)
        pair_sign.append(v)

    suite = [
        u.array("CC_POOL", case_pool, "The code points of each conformance text."),
        u.array("CC_OFF", case_off, "The end of each conformance text."),
        u.array("CC_REL", case_rel, "Each line holds 1: it orders above the line before it, or 0: both lines hold the same weights."),
        u.array("RP_POOL", pair_cps, "The two code points of each random pair."),
        u.array("RP_SIGN", pair_sign, "The sign of each random pair."),
    ]
    u.write_goose(os.path.join(u.ROOT, "test", "suite", "coll_cases.goose"),
                  "make_coll_data.py", suite, "suite")
    print("coll_data.goose: %d rows, %d elements" % (len(cps), len(pool_p)))
    print("coll_cases.goose: %d conformance lines, %d random pairs"
          % (len(texts), len(pair_sign)))


if __name__ == "__main__":
    main()
