#!/usr/bin/env python3
"""Make suite/bidi_line_cases.goose: the cases of the paragraph and line
calls.

The cases come from bidi_line_lib. The script asks ICU 79.1 and the Rust
crate unicode-bidi for each case and writes the answer that the package
must give. A case holds a text, a direction, a line, the paragraphs, the
levels, the order and the written text for each flag. A value that the
two oracles cannot settle is left out, and the suite skips it.

Usage: make_bidi_line_cases.py [cases] [seed]
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bidi_line_lib as lib
import ucdlib as u


def main():
    count = int(sys.argv[1]) if len(sys.argv) > 1 else 480
    seed = int(sys.argv[2]) if len(sys.argv) > 2 else 5
    cases = lib.build(seed, count)
    lines = [lib.line_of(c) for c in cases]
    icu = lib.run_icu(lines)
    rust = lib.run_rust(lines)
    if not (len(icu) == len(rust) == len(cases)):
        u.fail("the oracles gave %d and %d answers for %d cases"
               % (len(icu), len(rust), len(cases)))
    txt_off, txt = [0], []
    par_off, par = [0], []
    lv_off, lv = [0], []
    ord_off, order = [0], []
    w_off, w = [0], []
    dirs, starts, limits, kinds, has_lv = [], [], [], [], []
    w_has = []
    for case, i, r in zip(cases, icu, rust):
        exp, _ = lib.expected(case, i, r)
        _, d, a, b, cps = case
        txt += cps
        txt_off.append(len(txt))
        dirs.append(d)
        starts.append(a)
        limits.append(b)
        par += exp["P"]
        par_off.append(len(par))
        if "E" in exp:
            # A line that crosses a paragraph.
            kinds.append(1)
            has_lv.append(0)
            lv_off.append(len(lv))
            ord_off.append(len(order))
            for _f in lib.FLAGS:
                w_has.append(0)
                w_off.append(len(w))
            continue
        kinds.append(0)
        if exp.get("L") is None:
            has_lv.append(0)
        else:
            has_lv.append(1)
            lv += exp["L"]
        lv_off.append(len(lv))
        order += exp["O"]
        ord_off.append(len(order))
        for f in lib.FLAGS:
            if f in exp["W"]:
                w_has.append(1)
                w += exp["W"][f]
            else:
                w_has.append(0)
            w_off.append(len(w))
    data = [
        u.array("BL_TXT_OFF", txt_off, "The end of each text in BL_TXT."),
        u.array("BL_TXT", txt, "The code points of the texts."),
        u.array("BL_DIR", dirs, "The direction of each case."),
        u.array("BL_START", starts, "The start of the line of each case."),
        u.array("BL_LIMIT", limits, "The limit of the line of each case."),
        u.array("BL_KIND", kinds, "0 for a line, 1 for a line that crosses a paragraph."),
        u.array("BL_PAR_OFF", par_off, "The end of the paragraphs of each case in BL_PAR."),
        u.array("BL_PAR", par, "The start, the limit and the level of each paragraph."),
        u.array("BL_HAS_LV", has_lv, "1 when the levels of the case are known."),
        u.array("BL_LV_OFF", lv_off, "The end of the levels of each case in BL_LV."),
        u.array("BL_LV", lv, "The levels of the lines after rule L1."),
        u.array("BL_ORD_OFF", ord_off, "The end of the order of each case in BL_ORD."),
        u.array("BL_ORD", order, "The visual order of each line."),
        u.array("BL_W_HAS", w_has, "1 when the written text of a case and flag is known."),
        u.array("BL_W_OFF", w_off, "The end of each written text in BL_W."),
        u.array("BL_W", w, "The code points of the written texts, eight flags for each case."),
    ]
    u.write_goose(os.path.join(u.HERE, "suite", "bidi_line_cases.goose"),
                  "make_bidi_line_cases.py", data, namespace="suite")
    print("bidi_line_cases.goose: %d cases" % len(cases))


if __name__ == "__main__":
    main()
