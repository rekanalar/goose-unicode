#!/usr/bin/env python3
"""Make linebreak_data.goose and test/suite/line_cases.goose.

The table holds, for every run of code points, the Line_Break class of
LineBreak.txt in the low six bits and the East Asian flag of rule LB30 in
bit 6. The flag is set when the East_Asian_Width of EastAsianWidth.txt is
F, W or H. Code points that the file does not list hold XX.
The script checks the classes against the Rust unicode-linebreak crate.
The crate holds an older release of the standard, so the code points that
the newest release changed may differ; the script counts them.
The suite file holds every case of LineBreakTest.txt: the code points of
the text and the boundaries that break.
Usage: make_line_data.py [ucd directory]
"""
import os
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ucdlib as u

CLASSES = ["AI", "AK", "AL", "AP", "AS", "B2", "BA", "BB", "BK", "CB", "CJ", "CL",
           "CM", "CP", "CR", "EB", "EM", "EX", "GL", "H2", "H3", "HH", "HL", "HY",
           "ID", "IN", "IS", "JL", "JT", "JV", "LF", "NL", "NS", "NU", "OP", "PO",
           "PR", "QU", "RI", "SA", "SG", "SP", "SY", "VF", "VI", "WJ", "XX", "ZW", "ZWJ"]
INDEX = {n: i for i, n in enumerate(CLASSES)}
EA_FLAG = 64


def load():
    val = [INDEX["XX"]] * (u.MAX_CP + 1)
    for line in u.lines_of("LineBreak.txt"):
        p = [x.strip() for x in line.split(";")]
        a, b = u.parse_range(p[0])
        if p[1] not in INDEX:
            u.fail("unknown class " + p[1])
        for c in range(a, b + 1):
            val[c] = INDEX[p[1]]
    for line in u.lines_of("EastAsianWidth.txt"):
        p = [x.strip() for x in line.split(";")]
        if p[1].split()[0] in ("F", "W", "H"):
            a, b = u.parse_range(p[0])
            for c in range(a, b + 1):
                val[c] |= EA_FLAG
    return val


CRATE = {"Mandatory": "BK", "CarriageReturn": "CR", "LineFeed": "LF", "CombiningMark": "CM",
         "NextLine": "NL", "Surrogate": "SG", "WordJoiner": "WJ", "ZeroWidthSpace": "ZW",
         "NonBreakingGlue": "GL", "Space": "SP", "ZeroWidthJoiner": "ZWJ",
         "BeforeAndAfter": "B2", "After": "BA", "Before": "BB", "Hyphen": "HY",
         "Contingent": "CB", "ClosePunctuation": "CL", "CloseParenthesis": "CP",
         "Exclamation": "EX", "Inseparable": "IN", "NonStarter": "NS",
         "OpenPunctuation": "OP", "Quotation": "QU", "InfixSeparator": "IS",
         "Numeric": "NU", "Postfix": "PO", "Prefix": "PR", "Symbol": "SY",
         "Ambiguous": "AI", "Alphabetic": "AL", "ConditionalJapaneseStarter": "CJ",
         "EmojiBase": "EB", "EmojiModifier": "EM", "HangulLvSyllable": "H2",
         "HangulLvtSyllable": "H3", "HebrewLetter": "HL", "Ideographic": "ID",
         "HangulLJamo": "JL", "HangulVJamo": "JV", "HangulTJamo": "JT",
         "RegionalIndicator": "RI", "ComplexContext": "SA", "Unknown": "XX"}
# The classes that the newest release added. The crate holds them as AL.
NEWER = {"AK", "AP", "AS", "VF", "VI", "HH"}


def check_crate(val):
    """Compare with the crate, which holds an older release. Code points
    that the newest release added or changed may differ; the script counts
    them and fails when more than 1,000 of the assigned ones differ."""
    binary = os.path.join(u.HERE, "oracle", "target", "release", "linebreak")
    if not os.path.exists(binary):
        subprocess.run(["cargo", "build", "--release", "--bin", "linebreak"],
                       cwd=os.path.join(u.HERE, "oracle"), check=True)
    diff = 0
    total = 0
    for line in subprocess.run([binary], capture_output=True, text=True).stdout.splitlines():
        cp, name = line.split()
        cp = int(cp, 16)
        mine = CLASSES[val[cp] & 63]
        theirs = CRATE[name]
        total += 1
        if mine == theirs or (mine in NEWER and theirs == "AL"):
            continue
        if mine == "XX" or theirs == "XX":
            continue  # a code point that the release assigned after the crate
        diff += 1
        if diff <= 5:
            print("warning: %04X is %s here and %s in the crate" % (cp, mine, theirs))
    print("the crate differs on %d of %d code points" % (diff, total))
    if diff > 1000:
        u.fail("too many differences from the crate")


def main():
    u.check_version()
    val = load()
    runs = u.runs_of(val, skip=INDEX["XX"])
    parts = [
        u.array("LB_START", [r[0] for r in runs], "The first code point of each run."),
        u.array("LB_END", [r[1] for r in runs], "The last code point of each run."),
        u.array("LB_VAL", [r[2] for r in runs], "The class of each run, with the East Asian flag in bit 6."),
    ]
    u.write_goose(os.path.join(u.ROOT, "linebreak_data.goose"), "make_line_data.py", parts)
    check_crate(val)

    cps, in_off, brk, brk_off = [], [0], [], [0]
    n = 0
    for line in open(u.ucd_path("LineBreakTest.txt"), encoding="utf-8"):
        line = line.split("#")[0].strip()
        if not line:
            continue
        toks = line.split()
        idx = 0
        for t in toks[1:]:
            if t in ("×", "÷"):
                if t == "÷" and idx > 0:
                    brk.append(idx)
                continue
            cps.append(int(t, 16))
            idx += 1
        in_off.append(len(cps))
        brk_off.append(len(brk))
        n += 1
    suite = [
        u.array("LT_CP", cps, "The code points of every case."),
        u.array("LT_OFF", in_off, "The end of each case in LT_CP."),
        u.array("LT_BRK", brk, "The boundaries that break, counted in code points."),
        u.array("LT_BRK_OFF", brk_off, "The end of each case in LT_BRK."),
    ]
    u.write_goose(os.path.join(u.ROOT, "test", "suite", "line_cases.goose"),
                  "make_line_data.py", suite, "suite")
    print("linebreak_data.goose: %d runs; line_cases.goose: %d cases" % (len(runs), n))


if __name__ == "__main__":
    main()
