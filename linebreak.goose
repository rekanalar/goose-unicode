// Line break opportunities, by rules LB1 to LB31 of the Unicode line
// breaking standard. The call decodes the text once into one packed value
// for each unit. A unit is a base code point with the combining marks and
// joiners that follow it. One pass over the units then applies the rules.
// A rule reads at most two units ahead and a few numbers of the past, so
// the time is linear in the text.
namespace unicode;

import std;

// ---- the line break classes ------------------------------------------
const LB_AI: i64 = 0;
const LB_AK: i64 = 1;
const LB_AL: i64 = 2;
const LB_AP: i64 = 3;
const LB_AS: i64 = 4;
const LB_B2: i64 = 5;
const LB_BA: i64 = 6;
const LB_BB: i64 = 7;
const LB_BK: i64 = 8;
const LB_CB: i64 = 9;
const LB_CJ: i64 = 10;
const LB_CL: i64 = 11;
const LB_CM: i64 = 12;
const LB_CP: i64 = 13;
const LB_CR: i64 = 14;
const LB_EB: i64 = 15;
const LB_EM: i64 = 16;
const LB_EX: i64 = 17;
const LB_GL: i64 = 18;
const LB_H2: i64 = 19;
const LB_H3: i64 = 20;
const LB_HH: i64 = 21;
const LB_HL: i64 = 22;
const LB_HY: i64 = 23;
const LB_ID: i64 = 24;
const LB_IN: i64 = 25;
const LB_IS: i64 = 26;
const LB_JL: i64 = 27;
const LB_JT: i64 = 28;
const LB_JV: i64 = 29;
const LB_LF: i64 = 30;
const LB_NL: i64 = 31;
const LB_NS: i64 = 32;
const LB_NU: i64 = 33;
const LB_OP: i64 = 34;
const LB_PO: i64 = 35;
const LB_PR: i64 = 36;
const LB_QU: i64 = 37;
const LB_RI: i64 = 38;
const LB_SA: i64 = 39;
const LB_SG: i64 = 40;
const LB_SP: i64 = 41;
const LB_SY: i64 = 42;
const LB_VF: i64 = 43;
const LB_VI: i64 = 44;
const LB_WJ: i64 = 45;
const LB_XX: i64 = 46;
const LB_ZW: i64 = 47;
const LB_ZWJ: i64 = 48;

// The bits of a packed unit: the class in bits 0 to 5, then the flags.
const LBF_EA: i64 = 64;      // East_Asian_Width is F, W or H
const LBF_PI: i64 = 128;     // a quotation mark of category Pi
const LBF_PF: i64 = 256;     // a quotation mark of category Pf
const LBF_EPCN: i64 = 512;   // Extended_Pictographic and not assigned
const LBF_DC: i64 = 1024;    // U+25CC dotted circle
const LBF_ZWJ: i64 = 2048;   // the unit ends with a zero width joiner

// The kinds of a break opportunity, in the low bit of a result entry.
const BREAK_ALLOWED: i64 = 0;
const BREAK_MANDATORY: i64 = 1;

// The Line_Break class of a code point, before the resolution of rule
// LB1. A value outside the range gives LB_XX.
fn line_break_class(cp: i64) -> i64 {
    if cp < 0 || cp > 0x10FFFF { return LB_XX; }
    let r = run_at(LB_START[..], LB_END[..], cp);
    if r < 0 { return LB_XX; }
    return LB_VAL[r] & 63;
}

// The packed value of one code point after rule LB1.
fn lb_pack(cp: i64) -> i64 {
    let r = run_at(LB_START[..], LB_END[..], cp);
    var c = LB_XX;
    var v: i64 = 0;
    if r >= 0 {
        v = LB_VAL[r];
        c = v & 63;
    }
    let cat = category(cp);
    var f: i64 = v & LBF_EA;
    if c == LB_AI || c == LB_SG || c == LB_XX { c = LB_AL; }
    else if c == LB_SA {
        if cat == 6 || cat == 7 { c = LB_CM; } else { c = LB_AL; }
    }
    else if c == LB_CJ { c = LB_NS; }
    else if c == LB_QU {
        if cat == 16 { f |= LBF_PI; }
        if cat == 17 { f |= LBF_PF; }
    }
    if cat == 0 && is_extended_pictographic(cp) { f |= LBF_EPCN; }
    if cp == 0x25CC { f |= LBF_DC; }
    return c | f;
}

fn lb_hard(c: i64) -> bool {
    return c == LB_BK || c == LB_CR || c == LB_LF || c == LB_NL;
}

fn lb_jamo(c: i64) -> bool {
    return c == LB_JL || c == LB_JV || c == LB_JT || c == LB_H2 || c == LB_H3;
}

// The class of unit k, or LB_XX past the ends: sot and eot hold a class
// that no rule names.
fn lb_at(u: const i64[:], k: i64) -> i64 {
    if k < 0 || k >= u.len { return LB_XX; }
    return u[k] & 63;
}

// True when unit k has the East Asian flag. The ends have none.
fn lb_ea(u: const i64[:], k: i64) -> bool {
    if k < 0 || k >= u.len { return false; }
    return (u[k] & LBF_EA) != 0;
}

// True when the unit is one that rule LB28a calls AK, dotted circle or AS.
fn lb_aksara(u: const i64[:], k: i64) -> bool {
    if k < 0 || k >= u.len { return false; }
    let c = u[k] & 63;
    return c == LB_AK || c == LB_AS || (u[k] & LBF_DC) != 0;
}

// The state that the pass carries from unit to unit.
struct LineState {
    bc: i64,       // the class of the last unit that is no space, LB_XX at the start
    q15: bool,     // that unit is an initial quotation mark that rule LB15a binds
    num: i64,      // 1 after a number and its separators, 2 after a closer too
    ri: i64,       // the count of regional indicators that end at the last unit
}

// What rule LB15b names after a final quotation mark: spaces, glue,
// closers and breaks.
fn lb_after_final(c: i64) -> bool {
    return c == LB_SP || c == LB_GL || c == LB_WJ || c == LB_CL || c == LB_QU || c == LB_CP
        || c == LB_EX || c == LB_IS || c == LB_SY || c == LB_BK || c == LB_CR || c == LB_LF
        || c == LB_NL || c == LB_ZW;
}

// True when a break is not allowed before an opening bracket and the
// number that follows it, rule LB25.
fn lb_open_number(u: const i64[:], k: i64) -> bool {
    // u[k] is the opening bracket. The number follows, with an optional
    // separator between.
    if lb_at(u, k + 1) == LB_NU { return true; }
    return lb_at(u, k + 1) == LB_IS && lb_at(u, k + 2) == LB_NU;
}

// The decision of the boundary before unit k, where k is at least 1:
// 0 no break, 1 a break that the text allows, 2 a mandatory break.
fn lb_decide(u: const i64[:], k: i64, st: LineState&) -> i64 {
    let a = lb_at(u, k - 1);
    let b = lb_at(u, k);
    let pa = u[k - 1];
    let pb = u[k];
    // LB4, LB5, LB6
    if a == LB_BK { return 2; }
    if a == LB_CR { if b == LB_LF { return 0; } return 2; }
    if a == LB_LF || a == LB_NL { return 2; }
    if lb_hard(b) { return 0; }
    // LB7, LB8
    if b == LB_SP || b == LB_ZW { return 0; }
    if st.bc == LB_ZW { return 1; }
    // LB8a
    if (pa & LBF_ZWJ) != 0 { return 0; }
    // LB11, LB12, LB12a
    if b == LB_WJ || a == LB_WJ { return 0; }
    if a == LB_GL { return 0; }
    if b == LB_GL && a != LB_SP && a != LB_HY && a != LB_HH { return 0; }
    // LB13, LB14
    if b == LB_CL || b == LB_CP || b == LB_EX || b == LB_SY { return 0; }
    if st.bc == LB_OP { return 0; }
    // LB15a, LB15b
    if st.q15 { return 0; }
    if b == LB_QU && (pb & LBF_PF) != 0 {
        let n = lb_at(u, k + 1);
        if k + 1 >= u.len || lb_after_final(n) { return 0; }
    }
    // LB15c, LB15d
    if a == LB_SP && b == LB_IS && lb_at(u, k + 1) == LB_NU { return 1; }
    if b == LB_IS { return 0; }
    // LB16, LB17
    if (st.bc == LB_CL || st.bc == LB_CP) && b == LB_NS { return 0; }
    if st.bc == LB_B2 && b == LB_B2 { return 0; }
    // LB18
    if a == LB_SP { return 1; }
    // LB19, LB19a
    if b == LB_QU && (pb & LBF_PI) == 0 { return 0; }
    if a == LB_QU && (pa & LBF_PF) == 0 { return 0; }
    if b == LB_QU && !lb_ea(u, k - 1) { return 0; }
    if b == LB_QU && (k + 1 >= u.len || !lb_ea(u, k + 1)) { return 0; }
    if a == LB_QU && !lb_ea(u, k) { return 0; }
    if a == LB_QU && (k < 2 || !lb_ea(u, k - 2)) { return 0; }
    // LB20, LB20a
    if b == LB_CB || a == LB_CB { return 1; }
    if (a == LB_HY || a == LB_HH) && (b == LB_AL || b == LB_HL) {
        let p = lb_at(u, k - 2);
        if k < 2 || p == LB_BK || p == LB_CR || p == LB_LF || p == LB_NL || p == LB_SP
            || p == LB_ZW || p == LB_CB || p == LB_GL { return 0; }
    }
    // LB21, LB21a, LB21b, LB22
    if b == LB_BA || b == LB_HH || b == LB_HY || b == LB_NS || a == LB_BB { return 0; }
    if (a == LB_HY || a == LB_HH) && lb_at(u, k - 2) == LB_HL && b != LB_HL { return 0; }
    if a == LB_SY && b == LB_HL { return 0; }
    if b == LB_IN { return 0; }
    // LB23, LB23a, LB24
    let a_al = a == LB_AL || a == LB_HL;
    let b_al = b == LB_AL || b == LB_HL;
    if a_al && b == LB_NU { return 0; }
    if a == LB_NU && b_al { return 0; }
    if a == LB_PR && (b == LB_ID || b == LB_EB || b == LB_EM) { return 0; }
    if (a == LB_ID || a == LB_EB || a == LB_EM) && b == LB_PO { return 0; }
    if (a == LB_PR || a == LB_PO) && b_al { return 0; }
    if a_al && (b == LB_PR || b == LB_PO) { return 0; }
    // LB25
    if st.num == 2 && (b == LB_PO || b == LB_PR) { return 0; }
    if st.num == 1 && (b == LB_PO || b == LB_PR) { return 0; }
    if (a == LB_PO || a == LB_PR) && b == LB_OP && lb_open_number(u, k) { return 0; }
    if (a == LB_PO || a == LB_PR) && b == LB_NU { return 0; }
    if (a == LB_HY || a == LB_IS) && b == LB_NU { return 0; }
    if st.num == 1 && b == LB_NU { return 0; }
    // LB26, LB27
    if a == LB_JL && (b == LB_JL || b == LB_JV || b == LB_H2 || b == LB_H3) { return 0; }
    if (a == LB_JV || a == LB_H2) && (b == LB_JV || b == LB_JT) { return 0; }
    if (a == LB_JT || a == LB_H3) && b == LB_JT { return 0; }
    if lb_jamo(a) && b == LB_PO { return 0; }
    if a == LB_PR && lb_jamo(b) { return 0; }
    // LB28, LB28a
    if a_al && b_al { return 0; }
    if a == LB_AP && lb_aksara(u, k) { return 0; }
    if lb_aksara(u, k - 1) && (b == LB_VF || b == LB_VI) { return 0; }
    if a == LB_VI && lb_aksara(u, k - 2) && lb_aksara(u, k) { return 0; }
    if lb_aksara(u, k - 1) && lb_aksara(u, k) && lb_at(u, k + 1) == LB_VF { return 0; }
    // LB29, LB30
    if a == LB_IS && b_al { return 0; }
    if (a_al || a == LB_NU) && b == LB_OP && !lb_ea(u, k) { return 0; }
    if a == LB_CP && !lb_ea(u, k - 1) && (b_al || b == LB_NU) { return 0; }
    // LB30a, LB30b
    if a == LB_RI && b == LB_RI && (st.ri % 2) == 1 { return 0; }
    if b == LB_EM && (a == LB_EB || (pa & LBF_EPCN) != 0) { return 0; }
    // LB31
    return 1;
}

// Advances the state past unit k.
fn lb_advance(u: const i64[:], k: i64, st: LineState&) {
    let c = u[k] & 63;
    if c != LB_SP {
        // LB15a: an initial quotation mark that stands at the start, after
        // a space, after an opener, a quotation mark, glue, a break or a
        // zero width space.
        var ok = k == 0;
        if k > 0 {
            let p = lb_at(u, k - 1);
            ok = lb_hard(p) || p == LB_OP || p == LB_QU || p == LB_GL || p == LB_SP || p == LB_ZW;
        }
        st.q15 = c == LB_QU && (u[k] & LBF_PI) != 0 && ok;
        st.bc = c;
    }
    if c == LB_NU { st.num = 1; }
    else if st.num == 1 && (c == LB_SY || c == LB_IS) { st.num = 1; }
    else if st.num == 1 && (c == LB_CL || c == LB_CP) { st.num = 2; }
    else { st.num = 0; }
    if c == LB_RI { st.ri += 1; } else { st.ri = 0; }
}

// Writes the break opportunities of s to out. out is cleared first. An
// entry holds the byte offset of the break times two, plus BREAK_MANDATORY
// for a mandatory break. The end of a text that is not empty is the last
// break, and it is mandatory. Returns a fault code and the offset of the
// first bad byte. A fault clears out.
fn line_breaks(out: i64[>..]&, s: const u8[:]) -> i64, i64 {
    out.clear();
    if s.len > MAX_INPUT { return ERR_TOO_LONG, 0; }
    var units: i64[>..] = [];
    var starts: i64[>..] = [];
    var i: i64 = 0;
    while i < s.len {
        let cp, n = decode_at(s, i);
        if cp < 0 { return ERR_BAD_UTF8, i; }
        let p = lb_pack(cp);
        let c = p & 63;
        let m = units.len;
        // LB9 and LB10: a mark or joiner joins the unit before it, unless
        // that unit is a break, a space or a zero width space.
        if c == LB_CM || c == LB_ZWJ {
            var joins = m > 0;
            if m > 0 {
                let b = units[m - 1] & 63;
                if lb_hard(b) || b == LB_SP || b == LB_ZW { joins = false; }
            }
            if joins {
                if c == LB_ZWJ { units[m - 1] = units[m - 1] | LBF_ZWJ; }
                else { units[m - 1] = units[m - 1] & ~LBF_ZWJ; }
                i += n;
                continue;
            }
            // A mark with no unit to join acts as the letter A.
            var q = LB_AL;
            if c == LB_ZWJ { q = LB_AL | LBF_ZWJ; }
            units.push(q);
        } else {
            units.push(p);
        }
        starts.push(i);
        i += n;
    }
    var st = LineState { bc: LB_XX, q15: false, num: 0, ri: 0 };
    for k in 0..units.len {
        if k > 0 {
            let d = lb_decide(units[..], k, st);
            if d > 0 { out.push(starts[k] * 2 + (d - 1)); }
        }
        lb_advance(units[..], k, st);
    }
    if units.len > 0 { out.push(s.len * 2 + BREAK_MANDATORY); }
    return OK, 0;
}
