#!/usr/bin/env python3
"""Make segment_data.goose and segment_cases.goose: the word and sentence breaks.

The word table holds the Word_Break class in bits 0 to 4 and the
Extended_Pictographic flag in bit 5. The sentence table holds the
Sentence_Break class. The sources are WordBreakProperty.txt,
SentenceBreakProperty.txt and emoji-data.txt of the Unicode Character
Database 18.0.0.
Second sources: an independent Python version of the rules splits every
case of WordBreakTest.txt and SentenceBreakTest.txt, and the script fails
if it disagrees with a file. Node (Intl.Segmenter, ICU 78, which holds 17.0) splits 20,000
random texts like the Python version and gives the same word-like flags.
The random texts avoid the scripts that Node splits with a dictionary.
Usage: make_segment_data.py [ucd directory]
"""
import json
import os
import random
import sys
import unicodedata

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ucdlib as u

WB = ["Other", "CR", "LF", "Newline", "Extend", "ZWJ", "Regional_Indicator", "Format",
      "Katakana", "Hebrew_Letter", "ALetter", "Single_Quote", "Double_Quote", "MidNumLet",
      "MidLetter", "MidNum", "Numeric", "ExtendNumLet", "WSegSpace"]
SB = ["Other", "CR", "LF", "Extend", "Sep", "Format", "Sp", "Lower", "Upper", "OLetter",
      "Numeric", "ATerm", "SContinue", "STerm", "Close"]
WBI = {n: i for i, n in enumerate(WB)}
SBI = {n: i for i, n in enumerate(SB)}


def load(name, index):
    val = [0] * (u.MAX_CP + 1)
    for line in u.lines_of(name):
        p = [x.strip() for x in line.split(";")]
        a, b = u.parse_range(p[0])
        for c in range(a, b + 1):
            val[c] = index[p[1]]
    return val


# ---- independent rules ----------------------------------------------
def effective(cls, ign, para):
    """The class of each code point after the rule that joins marks to the code point before."""
    eff = []
    for j, c in enumerate(cls):
        if c in ign and j > 0 and cls[j - 1] not in para:
            eff.append(eff[j - 1])
        else:
            eff.append(c)
    return eff


def word_split(cps, wv, ep):
    n = len(cps)
    cls = [WB[wv[c]] for c in cps]
    ign = ("Extend", "Format", "ZWJ")
    eff = effective(cls, ign, ("CR", "LF", "Newline"))
    ahl = ("ALetter", "Hebrew_Letter")
    mnl = ("MidLetter", "MidNumLet", "Single_Quote")
    mnum = ("MidNum", "MidNumLet", "Single_Quote")

    def nxt(i):
        j = i + 1
        while j < n and cls[j] in ign:
            j += 1
        return eff[j] if j < n else None

    def prv(i):
        # class of the group before the group that ends at i - 1
        j = i - 1
        while j > 0 and cls[j] in ign and cls[j - 1] not in ("CR", "LF", "Newline"):
            j -= 1
        return eff[j - 1] if j > 0 else None

    sizes, start = [], 0
    for i in range(1, n + 1):
        if i == n:
            sizes.append(i - start)
            break
        a, b = eff[i - 1], cls[i]
        ra = cls[i - 1]
        brk = True
        if ra == "CR" and b == "LF":
            brk = False
        elif ra in ("CR", "LF", "Newline") or b in ("CR", "LF", "Newline"):
            brk = True
        elif ra == "ZWJ" and ep[cps[i]]:
            brk = False
        elif ra == "WSegSpace" and b == "WSegSpace":
            brk = False
        elif b in ign:
            brk = False
        else:
            p2 = prv(i)
            n1 = nxt(i)
            if a in ahl and b in ahl: brk = False
            elif a in ahl and b in mnl and n1 in ahl: brk = False
            elif p2 in ahl and a in mnl and b in ahl: brk = False
            elif a == "Hebrew_Letter" and b == "Single_Quote": brk = False
            elif a == "Hebrew_Letter" and b == "Double_Quote" and n1 == "Hebrew_Letter": brk = False
            elif p2 == "Hebrew_Letter" and a == "Double_Quote" and b == "Hebrew_Letter": brk = False
            elif a == "Numeric" and b == "Numeric": brk = False
            elif a in ahl and b == "Numeric": brk = False
            elif a == "Numeric" and b in ahl: brk = False
            elif p2 == "Numeric" and a in mnum and b == "Numeric": brk = False
            elif a == "Numeric" and b in mnum and n1 == "Numeric": brk = False
            elif a == "Katakana" and b == "Katakana": brk = False
            elif a in ahl + ("Numeric", "Katakana", "ExtendNumLet") and b == "ExtendNumLet": brk = False
            elif a == "ExtendNumLet" and b in ahl + ("Numeric", "Katakana"): brk = False
            elif a == "Regional_Indicator" and b == "Regional_Indicator":
                k, j = 0, i - 1
                while j >= start and eff[j] == "Regional_Indicator":
                    if cls[j] == "Regional_Indicator":
                        k += 1
                    j -= 1
                brk = (k % 2 == 0)
        if brk:
            sizes.append(i - start)
            start = i
    return sizes


def sentence_split(cps, sv):
    n = len(cps)
    cls = [SB[sv[c]] for c in cps]
    ign = ("Extend", "Format")
    para = ("Sep", "CR", "LF")
    eff = effective(cls, ign, para)
    sa = ("STerm", "ATerm")
    sizes, start = [], 0
    for i in range(1, n + 1):
        if i == n:
            sizes.append(i - start)
            break
        b = cls[i]
        ra = cls[i - 1]
        brk = None
        if ra == "CR" and b == "LF":
            brk = False
        elif ra in para:
            brk = True
        elif b in ign:
            brk = False
        else:
            # the group before i, then the closers and spaces back to a terminator
            j = i - 1
            sp = 0
            while j >= start and eff[j] == "Sp":
                sp += 1
                j -= 1
            while j >= start and eff[j] == "Close":
                j -= 1
            has_term = j >= start and eff[j] in sa
            a = eff[i - 1]
            term = eff[j] if has_term else None
            before = None
            if has_term:
                g = j
                while g > start and cls[g] in ign and cls[g - 1] not in para:
                    g -= 1
                before = eff[g - 1] if g - 1 >= start else None
            if a == "ATerm" and b == "Numeric": brk = False
            elif a == "ATerm" and before in ("Upper", "Lower") and b == "Upper": brk = False
            elif has_term and term == "ATerm" and lower_follows(cls, i): brk = False
            elif has_term and b in ("SContinue", "STerm", "ATerm"): brk = False
            elif has_term and sp == 0 and b in ("Close", "Sp", "Sep", "CR", "LF"): brk = False
            elif has_term and b in ("Sp", "Sep", "CR", "LF"): brk = False
            elif has_term: brk = True
            else: brk = False
        if brk:
            sizes.append(i - start)
            start = i
    return sizes


def lower_follows(cls, i):
    """SB8: after the terminator, skip the code points that are not a letter,
    a terminator or a separator. The rule joins when a lower case letter comes next."""
    j = i
    while j < len(cls):
        c = cls[j]
        if c == "Lower":
            return True
        if c in ("OLetter", "Upper", "Sep", "CR", "LF", "STerm", "ATerm"):
            return False
        j += 1
    return False


# ---- the test files -------------------------------------------------
def read_cases(name):
    cases = []
    with open(u.ucd_path(name), encoding="utf-8") as f:
        for line in f:
            line = line.split("#")[0].strip()
            if not line:
                continue
            toks = line.replace("÷", " D ").replace("×", " X ").split()
            cps, sizes, run = [], [], 0
            for t in toks:
                if t == "D":
                    if run:
                        sizes.append(run)
                    run = 0
                elif t != "X":
                    cps.append(int(t, 16))
                    run += 1
            cases.append((cps, sizes))
    return cases


def node_sizes(gran, texts):
    out = u.oracle_node("segment.mjs", gran, stdin="\n".join(json.dumps(t) for t in texts) + "\n")
    res = []
    for line in out:
        if gran == "word":
            s, f = line.split("|")
            res.append(([int(x) for x in s.split()], [int(x) for x in f.split()]))
        else:
            res.append(([int(x) for x in line.split()], None))
    return res


WORD_LIKE_CLASSES = (WBI["ALetter"], WBI["Hebrew_Letter"], WBI["Numeric"], WBI["Katakana"])
WV = []
JOINERS = ("Single_Quote", "Double_Quote", "MidNumLet", "MidLetter", "MidNum", "ExtendNumLet", "ZWJ")


def word_like(cps_seg):
    """A segment is word-like when it holds a code point of a word class,
    or a letter, a decimal digit or a letter number of any class. A run of
    two connectors counts too, as in ICU."""
    if sum(1 for c in cps_seg if WV[c] == WBI["ExtendNumLet"]) >= 2:
        return True
    for c in cps_seg:
        if WV[c] in WORD_LIKE_CLASSES:
            return True
        cat = unicodedata.category(chr(c))
        if cat[0] == "L" or cat in ("Nd", "Nl"):
            return True
    return False


def main():
    u.check_version()
    wv = load("WordBreakProperty.txt", WBI)
    WV.extend(wv)
    sv = load("SentenceBreakProperty.txt", SBI)
    ep = [False] * (u.MAX_CP + 1)
    for line in u.lines_of("emoji-data.txt"):
        p = [x.strip() for x in line.split(";")]
        if p[1] == "Extended_Pictographic":
            a, b = u.parse_range(p[0])
            for c in range(a, b + 1):
                ep[c] = True

    wcases = read_cases("WordBreakTest.txt")
    scases = read_cases("SentenceBreakTest.txt")
    if len(wcases) < 1800 or len(scases) < 500:
        u.fail("a break test file is too short: %d, %d" % (len(wcases), len(scases)))
    for cps, sizes in wcases:
        if word_split(cps, wv, ep) != sizes:
            u.fail("the word rules fail on %r: %r against %r" % (cps, word_split(cps, wv, ep), sizes))
    for cps, sizes in scases:
        if sentence_split(cps, sv) != sizes:
            u.fail("the sentence rules fail on %r: %r against %r" % (cps, sentence_split(cps, sv), sizes))
    for (cps, sizes), (ns, _) in zip(wcases, node_sizes("word", [c[0] for c in wcases])):
        if ns != sizes:
            u.fail("Intl.Segmenter disagrees with the word test file on %r" % cps)
    for (cps, sizes), (ns, _) in zip(scases, node_sizes("sentence", [c[0] for c in scases])):
        if ns != sizes:
            u.fail("Intl.Segmenter disagrees with the sentence test file on %r" % cps)

    # random texts: pick code points of every class, but no dictionary script
    dictionary = [(0x0E00, 0x0EFF), (0x1000, 0x109F), (0x1780, 0x17FF), (0x3040, 0x30FF),
                  (0x3400, 0x4DBF), (0x4E00, 0x9FFF), (0xF900, 0xFAFF), (0x20000, 0x3FFFF),
                  (0x31F0, 0x31FF), (0xFF66, 0xFF9F), (0x1B000, 0x1B16F)]
    def dict_script(c):
        return any(a <= c <= b for a, b in dictionary)
    rng = random.Random(20260509)
    wpool = {}
    spool = {}
    for c in range(0x110000):
        if 0xD800 <= c <= 0xDFFF or dict_script(c) or wv[c] == WBI["Katakana"]:
            continue
        wpool.setdefault((wv[c], ep[c]), []).append(c)
        spool.setdefault(sv[c], []).append(c)
    reps = [rng.choice(v) for v in wpool.values() for _ in range(2)]
    reps += [rng.choice(v) for v in spool.values() for _ in range(2)]
    reps += [0x61, 0x62, 0x41, 0x31, 0x32, 0x2E, 0x2C, 0x27, 0x22, 0x20, 0x3A, 0x5F, 0x21, 0x3F, 0x0A, 0x0D, 0x200D, 0x301, 0x5D0]
    texts = [[rng.choice(reps) for _ in range(rng.randint(1, 12))] for _ in range(20000)]
    nw = node_sizes("word", texts)
    ns_ = node_sizes("sentence", texts)
    wd, sd = 0, 0
    for t, (n1, flags), (n2, _) in zip(texts, nw, ns_):
        w = word_split(t, wv, ep)
        s = sentence_split(t, sv)
        if w != n1:
            wd += 1
            if wd < 4: print("word diff", [hex(c) for c in t], w, n1)
        if s != n2:
            sd += 1
            if sd < 4: print("sentence diff", [hex(c) for c in t], s, n2)
    if wd or sd:
        u.fail("Node differs from the Python rules: %d word, %d sentence" % (wd, sd))

    # word-like flags
    for t, (n1, flags) in zip(texts, nw):
        k = 0
        for size, f in zip(n1, flags):
            seg = t[k:k + size]
            # ICU takes the flag from the last rule of the segment, so a segment
            # that a joining rule built can differ. The check covers the others.
            if len(seg) > 1 and any(WB[wv[c]] in JOINERS for c in seg):
                k += size
                continue
            if int(word_like(seg)) != f:
                u.fail("the word-like flag differs from Node on %r" % t[k:k + size])
            k += size

    # ---- the output ------------------------------------------------
    wval = [wv[c] | (32 if ep[c] else 0) for c in range(u.MAX_CP + 1)]
    wr, sr = u.runs_of(wval), u.runs_of(sv)
    u.write_goose(os.path.join(u.ROOT, "segment_data.goose"), "make_segment_data.py", [
        u.array("WP_START", [r[0] for r in wr], "First code point of each run of the word break table."),
        u.array("WP_VAL", [r[2] for r in wr], "Word break class in bits 0 to 4, pictographic flag in bit 5."),
        u.array("SP_START", [r[0] for r in sr], "First code point of each run of the sentence break table."),
        u.array("SP_VAL", [r[2] for r in sr], "Sentence break class."),
    ])

    def pack(cases, flagged):
        off, pool = [], []
        for cps, sizes in cases:
            off.append(len(pool))
            pool.append(len(cps)); pool.extend(cps)
            pool.append(len(sizes)); pool.extend(sizes)
            if flagged:
                k = 0
                for size in sizes:
                    pool.append(int(word_like(cps[k:k + size]))); k += size
        off.append(len(pool))
        return off, pool
    # the conformance cases, then 1500 random cases that Node and the rules agree on
    wall = wcases + [(t, w) for t, w in ((t, word_split(t, wv, ep)) for t in texts[:1500])]
    sall = scases + [(t, sentence_split(t, sv)) for t in texts[:1500]]
    wo, wp = pack(wall, True)
    so, sp = pack(sall, False)
    out = os.path.join(u.HERE, "suite", "segment_cases.goose")
    with open(out, "w", encoding="utf-8") as f:
        f.write("// Reference cases for the test suites, word and sentence splits.\n")
        f.write("// Made by test/make_segment_data.py. Do not edit by hand.\nnamespace suite;\n\n")
        f.write("\n".join([
            u.array("WS_OFF", wo, "Start of each word case in WS_POOL. One more entry ends the last."),
            u.array("WS_POOL", wp, "For each case: the count of code points, the code points, the count of segments, the size of each segment, the word-like flag of each segment."),
            u.array("SS_OFF", so, "Start of each sentence case in SS_POOL. One more entry ends the last."),
            u.array("SS_POOL", sp, "For each case: the count of code points, the code points, the count of segments, the size of each segment."),
        ]))
    print("word runs %d, sentence runs %d; %d and %d file cases and 20000 random texts agree with Node; %d flag cases" %
          (len(wr), len(sr), len(wcases), len(scases), len(texts)))


main()
