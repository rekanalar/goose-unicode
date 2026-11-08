#!/usr/bin/env python3
"""Make normalize_data.goose: decompositions, compositions, quick checks.

The tables come from UnicodeData.txt and DerivedNormalizationProps.txt of
the Unicode Character Database 17.0.0. The decompositions are complete:
one lookup gives the final sequence, so the package needs no recursion.
Each table is checked against golang.org/x/text/unicode/norm, which holds
Unicode 17.0.0. The script exits with an error on the first difference.
Usage: make_normalize_data.py [ucd directory]
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ucdlib as u

S_BASE, L_BASE, V_BASE, T_BASE = 0xAC00, 0x1100, 0x1161, 0x11A7
L_COUNT, V_COUNT, T_COUNT = 19, 21, 28
N_COUNT = V_COUNT * T_COUNT
S_COUNT = L_COUNT * N_COUNT


def hangul_decompose(cp):
    s = cp - S_BASE
    out = [L_BASE + s // N_COUNT, V_BASE + (s % N_COUNT) // T_COUNT]
    if s % T_COUNT:
        out.append(T_BASE + s % T_COUNT)
    return out


def main():
    u.check_version()
    rows = u.unicode_data()

    canon = {}   # one step canonical mapping
    compat = {}  # one step compatibility mapping
    ccc = {}
    for cp, f in rows.items():
        ccc[cp] = int(f[3])
        d = f[5]
        if not d:
            continue
        if d.startswith("<"):
            compat[cp] = [int(x, 16) for x in d.split()[1:]]
        else:
            canon[cp] = [int(x, 16) for x in d.split()]

    def full(cp, with_compat):
        if S_BASE <= cp < S_BASE + S_COUNT:
            return hangul_decompose(cp)
        if cp in canon:
            return [y for x in canon[cp] for y in full(x, with_compat)]
        if with_compat and cp in compat:
            return [y for x in compat[cp] for y in full(x, with_compat)]
        return [cp]

    def reorder(seq):
        out = list(seq)
        i = 0
        while i < len(out):
            if ccc.get(out[i], 0) == 0:
                i += 1
                continue
            j = i
            while j < len(out) and ccc.get(out[j], 0) != 0:
                j += 1
            out[i:j] = sorted(out[i:j], key=lambda c: ccc.get(c, 0))  # stable
            i = j
        return out

    dec = {}
    kdec = {}
    for cp in range(u.MAX_CP + 1):
        if 0xD800 <= cp <= 0xDFFF or S_BASE <= cp < S_BASE + S_COUNT:
            continue
        a = full(cp, False)
        b = full(cp, True)
        if a != [cp]:
            dec[cp] = a
        if b != a:
            kdec[cp] = b

    # Full_Composition_Exclusion and the quick check properties.
    excl = set()
    qc = {"NFC": [], "NFD": [], "NFKC": [], "NFKD": []}
    for line in u.lines_of("DerivedNormalizationProps.txt"):
        p = [x.strip() for x in line.split(";")]
        a, b = u.parse_range(p[0])
        if p[1] == "Full_Composition_Exclusion":
            excl.update(range(a, b + 1))
        elif p[1].endswith("_QC") and p[1][:-3] in qc:
            qc[p[1][:-3]].append((a, b, 1 if p[2] == "N" else 2))
    for k in qc:
        qc[k].sort()

    comp = {}
    for cp, d in canon.items():
        if len(d) == 2 and cp not in excl:
            comp[(d[0] << 21) | d[1]] = cp
    comp_keys = sorted(comp)

    # ---- the second source ---------------------------------------
    for mode, table in (("nfd", dec), ("nfkd", None)):
        go = {}
        for line in u.oracle_go(mode):
            a, rest = line.split(" ", 1)
            go[int(a, 16)] = [int(x, 16) for x in rest.split()]
        want = {}
        for cp in range(u.MAX_CP + 1):
            if 0xD800 <= cp <= 0xDFFF:
                continue
            seq = reorder(kdec.get(cp, dec.get(cp, [cp])) if mode == "nfkd" else dec.get(cp, [cp]))
            if S_BASE <= cp < S_BASE + S_COUNT:
                seq = hangul_decompose(cp)
            if seq != [cp]:
                want[cp] = seq
        if go != want:
            diff = sorted(set((k, tuple(v)) for k, v in go.items()) ^ set((k, tuple(v)) for k, v in want.items()))[:3]
            u.fail("%s differs from Go: %r" % (mode, diff))

    # Compositions: Go composes each pair of the data, and it must give
    # the composite exactly when the pair is not excluded.
    pairs = []
    expect = []
    for cp, d in sorted(canon.items()):
        if len(d) == 2:
            pairs.append("%04X %04X" % (d[0], d[1]))
            expect.append(cp if cp not in excl else None)
    got = u.oracle_go("pairs", stdin="\n".join(pairs) + "\n")
    for (line, want, pair) in zip(got, expect, pairs):
        seq = [int(x, 16) for x in line.split()]
        if want is not None and seq != [want]:
            u.fail("Go composes %s to %r, the table says U+%04X" % (pair, seq, want))
        if want is None and len(seq) == 1 and seq[0] in canon:
            u.fail("Go composes the excluded pair %s" % pair)
    if len(got) != len(pairs):
        u.fail("the pair count differs from Go")

    # Quick check: a single code point is not normalized exactly when its
    # property is No.
    for form in ("nfc", "nfd", "nfkc", "nfkd"):
        go = []
        for line in u.oracle_go("qc", form):
            a, b, _ = line.split()
            go.append((int(a, 16), int(b, 16)))
        mine = [(a, b) for (a, b, v) in qc[form.upper()] if v == 1]
        merged = []
        for a, b in mine:
            if merged and merged[-1][1] + 1 == a:
                merged[-1] = (merged[-1][0], b)
            else:
                merged.append((a, b))
        go_m = [(a, b) for (a, b) in go]
        # Go skips the surrogates, and the data lists them as No for none.
        if go_m != merged:
            for x, y in zip(go_m, merged):
                if x != y:
                    u.fail("%s quick check differs: Go %r, table %r" % (form, x, y))
            u.fail("%s quick check run counts differ: Go %d, table %d" % (form, len(go_m), len(merged)))

    # ---- the output ----------------------------------------------
    def flat(table):
        cps = sorted(table)
        pool, off = [], []
        for cp in cps:
            off.append(len(pool))
            pool.extend(table[cp])
        off.append(len(pool))
        return cps, off, pool

    d_cp, d_off, d_pool = flat(dec)
    k_cp, k_off, k_pool = flat(kdec)
    parts = [
        u.array("DEC_CP", d_cp, "Code points with a canonical decomposition, sorted. Hangul syllables are not in the table."),
        u.array("DEC_OFF", d_off, "Start of each full canonical decomposition in DEC_POOL. One more entry ends the last."),
        u.array("DEC_POOL", d_pool, "The code points of all canonical decompositions."),
        u.array("KDEC_CP", k_cp, "Code points whose compatibility decomposition differs from the canonical one, sorted."),
        u.array("KDEC_OFF", k_off, "Start of each full compatibility decomposition in KDEC_POOL. One more entry ends the last."),
        u.array("KDEC_POOL", k_pool, "The code points of all compatibility decompositions."),
        u.array("COMP_KEY", comp_keys, "Primary composites: the first code point times 2097152 plus the second, sorted."),
        u.array("COMP_VAL", [comp[k] for k in comp_keys], "The composite code point of each pair."),
    ]
    for form in ("NFC", "NFD", "NFKC", "NFKD"):
        t = qc[form]
        parts.append(u.array("QC_%s_START" % form, [x[0] for x in t], "First code point of each %s quick check range." % form))
        parts.append(u.array("QC_%s_END" % form, [x[1] for x in t], "Last code point of each range."))
        parts.append(u.array("QC_%s_VAL" % form, [x[2] for x in t], "1 for No and 2 for Maybe."))
    u.write_goose(os.path.join(u.ROOT, "normalize_data.goose"), "make_normalize_data.py", parts)
    print("canonical %d (pool %d), compatibility %d (pool %d), composites %d" % (len(d_cp), len(d_pool), len(k_cp), len(k_pool), len(comp_keys)))
    print("quick check ranges: " + ", ".join("%s %d" % (k, len(qc[k])) for k in qc))
    print("checked against Go x/text")


main()
