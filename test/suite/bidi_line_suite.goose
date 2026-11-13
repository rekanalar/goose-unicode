// Tests for the paragraph split and the line calls of the bidirectional
// algorithm: the paragraphs, rule L1, rule L2 and the options of the
// write call (rules L3 and L4, the removal of the controls).
namespace suite;

import std;
import os;
import unicode from "../..";
import bidi_line_cases;

fn bl_ok(ok: bool, name: const u8[:]) -> i64 {
    if !ok { print("FAIL: bidi_line ", name, "\n"); return 1; }
    return 0;
}

fn bl_text(cps: const i64[:]) -> u8[>..] {
    var s: u8[>..] = [];
    unicode::encode_all(s, cps);
    return s;
}

fn bl_same(got: const i64[:], want: const i64[:]) -> bool {
    if got.len != want.len { return false; }
    for k in 0..got.len { if got[k] != want[k] { return false; } }
    return true;
}

fn bl_show(what: const u8[:], got: const i64[:]) {
    print(what);
    for k in 0..got.len { print(" ", got[k]); }
    print("\n");
}

// The levels of the line of a text, after rule L1. A fault gives a list
// that holds -100 and the code.
fn bl_levels_of(cps: const i64[:], dir: i64, a: i64, b: i64) -> i64[>..] {
    var out: i64[>..] = [];
    let s = bl_text(cps);
    let code, _ = unicode::bidi_line_levels(out, s[..], dir, a, b);
    if code != unicode::OK { out.clear(); out.push(-100); out.push(code); }
    return out;
}

// The text of a line in visual order, as code points. A fault gives a
// list that holds -100 and the code.
fn bl_write(cps: const i64[:], dir: i64, a: i64, b: i64, flags: i64) -> i64[>..] {
    var out: u8[>..] = [];
    let s = bl_text(cps);
    let code, _ = unicode::bidi_reorder(out, s[..], dir, a, b, flags);
    var cp: i64[>..] = [];
    if code != unicode::OK { cp.push(-100); cp.push(code); return cp; }
    unicode::utf8_decode(cp, out[..]);
    return cp;
}

// ---- the cases of the oracles ---------------------------------------
// The flags of a case, in the order of the case file.
fn bl_flag(i: i64) -> i64 {
    let f = [0, 1, 2, 3, 8, 9, 10, 11];
    return f[i];
}

fn bl_cases() -> i64 {
    var bad = 0;
    let n = BL_DIR.len;
    for c in 0..n {
        let cps = BL_TXT[BL_TXT_OFF[c]..BL_TXT_OFF[c + 1]];
        let s = bl_text(cps);
        let dir = BL_DIR[c];
        let a = BL_START[c];
        let b = BL_LIMIT[c];
        var pars: i64[>..] = [];
        let pc, _ = unicode::bidi_paragraphs(pars, s[..], dir);
        let wp = BL_PAR[BL_PAR_OFF[c]..BL_PAR_OFF[c + 1]];
        if pc != unicode::OK || !bl_same(pars[..], wp) {
            print("FAIL: bidi_line paragraphs of case ", c, "\n");
            bl_show(" got", pars[..]);
            bl_show(" want", wp);
            bad += 1;
        }
        var lv: i64[>..] = [];
        let lc, _ = unicode::bidi_line_levels(lv, s[..], dir, a, b);
        if BL_KIND[c] == 1 {
            if lc != unicode::ERR_BAD_ARG || lv.len != 0 {
                print("FAIL: bidi_line case ", c, " crosses a paragraph and gave ", lc, "\n");
                bad += 1;
            }
            continue;
        }
        if lc != unicode::OK {
            print("FAIL: bidi_line levels of case ", c, " gave fault ", lc, "\n");
            bad += 1;
            continue;
        }
        if BL_HAS_LV[c] == 1 {
            let wl = BL_LV[BL_LV_OFF[c]..BL_LV_OFF[c + 1]];
            if !bl_same(lv[..], wl) {
                print("FAIL: bidi_line levels of case ", c, "\n");
                bl_show(" got", lv[..]);
                bl_show(" want", wl);
                bad += 1;
            }
        }
        var ord: i64[>..] = [];
        let oc, _ = unicode::bidi_line_order(ord, s[..], dir, a, b);
        let wo = BL_ORD[BL_ORD_OFF[c]..BL_ORD_OFF[c + 1]];
        if oc != unicode::OK || !bl_same(ord[..], wo) {
            print("FAIL: bidi_line order of case ", c, "\n");
            bl_show(" got", ord[..]);
            bl_show(" want", wo);
            bad += 1;
        }
        for fi in 0..8 {
            let k = c * 8 + fi;
            if BL_W_HAS[k] == 0 { continue; }
            let ww = BL_W[BL_W_OFF[k]..BL_W_OFF[k + 1]];
            let got = bl_write(cps, dir, a, b, bl_flag(fi));
            if !bl_same(got[..], ww) {
                print("FAIL: bidi_line text of case ", c, " with flags ", bl_flag(fi), "\n");
                bl_show(" got", got[..]);
                bl_show(" want", ww);
                bad += 1;
            }
        }
        if bad > 5 { return bad; }
    }
    return bad;
}

// ---- the paragraph split --------------------------------------------
fn bl_paras(cps: const i64[:], dir: i64) -> i64[>..] {
    var out: i64[>..] = [];
    let s = bl_text(cps);
    let code, _ = unicode::bidi_paragraphs(out, s[..], dir);
    if code != unicode::OK { out.clear(); out.push(-100); }
    return out;
}

fn bl_split() -> i64 {
    var bad = 0;
    // Two paragraphs: the separator stays in the first one.
    bad += bl_ok(bl_same(bl_paras([0x61, 0x0A, 0x62][..], 0)[..], [0, 2, 0, 2, 3, 0][..]), "split LF");
    // CR LF is one terminator. LF CR is two.
    bad += bl_ok(bl_same(bl_paras([0x61, 0x0D, 0x0A, 0x62][..], 0)[..], [0, 3, 0, 3, 4, 0][..]), "split CR LF");
    bad += bl_ok(bl_same(bl_paras([0x61, 0x0A, 0x0D, 0x62][..], 0)[..],
        [0, 2, 0, 2, 3, 0, 3, 4, 0][..]), "split LF CR");
    // A final separator opens no paragraph.
    bad += bl_ok(bl_same(bl_paras([0x61, 0x0A][..], 0)[..], [0, 2, 0][..]), "final LF");
    // The empty text holds no paragraph.
    let none: i64[>..] = [];
    bad += bl_ok(bl_paras(none[..], 0).len == 0, "empty text");
    // Separators only: one paragraph for each.
    bad += bl_ok(bl_same(bl_paras([0x0A, 0x0A, 0x0A][..], 0)[..], [0, 1, 0, 1, 2, 0, 2, 3, 0][..]), "LF LF LF");
    bad += bl_ok(bl_same(bl_paras([0x0A, 0x0D][..], 1)[..], [0, 1, 1, 1, 2, 1][..]), "LF CR rtl");
    // Every separator of the class B.
    let seps = [0x0A, 0x0D, 0x1C, 0x1D, 0x1E, 0x85, 0x2029];
    for k in 0..seps.len {
        let got = bl_paras([0x61, seps[k], 0x62][..], 0);
        bad += bl_ok(bl_same(got[..], [0, 2, 0, 2, 3, 0][..]), "separator class");
    }
    // The level of each paragraph with the auto direction.
    bad += bl_ok(bl_same(bl_paras([0x627, 0x0A, 0x61][..], 2)[..], [0, 2, 1, 2, 3, 0][..]), "auto levels");
    // A fixed direction gives that level to every paragraph.
    bad += bl_ok(bl_same(bl_paras([0x627, 0x0A, 0x61][..], 0)[..], [0, 2, 0, 2, 3, 0][..]), "ltr levels");
    bad += bl_ok(bl_same(bl_paras([0x627, 0x0A, 0x61][..], 1)[..], [0, 2, 1, 2, 3, 1][..]), "rtl levels");
    // An isolate that opens in one paragraph never closes in the next.
    let lv = bl_levels_of([0x2067, 0x5D0, 0x0A, 0x2069, 0x61][..], 0, 3, 5);
    bad += bl_ok(bl_same(lv[..], [0, 0][..]), "isolate across paragraphs");
    return bad;
}

// CR and LF of one pair take one level, also in a right to left text.
// The package follows ICU: a CR followed by LF is one terminator. The Rust
// crate unicode-bidi and the Go library x/text take the pair as two
// terminators, so a right to left text gives them two paragraphs.
fn bl_crlf() -> i64 {
    var bad = 0;
    let lv = bl_levels_of([0x5D0, 0x0D, 0x0A, 0x5D1][..], 1, 0, 3);
    bad += bl_ok(bl_same(lv[..], [1, 1, 1][..]), "CR LF levels rtl");
    let lv2 = bl_levels_of([0x61, 0x0D, 0x0A, 0x62][..], 1, 0, 3);
    bad += bl_ok(bl_same(lv2[..], [2, 1, 1][..]), "CR LF levels ltr text in rtl");
    // The levels of bidi_levels follow the same split.
    var out: i64[>..] = [];
    let s = bl_text([0x5D0, 0x0D, 0x0A, 0x5D1][..]);
    unicode::bidi_levels(out, s[..], 1);
    bad += bl_ok(out[1] == out[2], "bidi_levels CR LF");
    return bad;
}

// ---- rule L1 --------------------------------------------------------
fn bl_l1() -> i64 {
    var bad = 0;
    // White space at the end of the line takes the paragraph level.
    let a = bl_levels_of([0x5D0, 0x20, 0x20][..], 0, 0, 3);
    bad += bl_ok(bl_same(a[..], [1, 0, 0][..]), "trailing space");
    // White space before a separator takes the paragraph level.
    let b = bl_levels_of([0x5D0, 0x20, 0x09, 0x5D1][..], 0, 0, 4);
    bad += bl_ok(bl_same(b[..], [1, 0, 0, 1][..]), "space before tab");
    // The isolate formatting characters count as white space.
    let c = bl_levels_of([0x5D0, 0x2067, 0x2069][..], 0, 0, 3);
    bad += bl_ok(bl_same(c[..], [1, 0, 0][..]), "isolates at the end");
    // A line of white space only takes the paragraph level.
    let d = bl_levels_of([0x20, 0x20][..], 1, 0, 2);
    bad += bl_ok(bl_same(d[..], [1, 1][..]), "white space only");
    // A line may start in the middle of a paragraph. The embedding that
    // opens before the line holds in it.
    let e = bl_levels_of([0x202B, 0x61, 0x62, 0x63][..], 0, 2, 4);
    bad += bl_ok(bl_same(e[..], [2, 2][..]), "line inside an embedding");
    // A removed code point takes the level of the code point before it,
    // after rule L1. This is the value of the standard and of the Rust
    // crate: here 0 1 0 0 1 1 1. ICU gives the level of the code point
    // after it: 0 1 0 1 1 1 1.
    let f = bl_levels_of([0x20, 0x5D1, 0x09, 0xAD, 0x300, 0x5D1, 0x64B][..], 0, 0, 7);
    bad += bl_ok(bl_same(f[..], [0, 1, 0, 0, 1, 1, 1][..]), "removed after tab");
    // At the start of a paragraph a removed code point takes the paragraph
    // level.
    let g = bl_levels_of([0x202C, 0x5D0][..], 0, 0, 2);
    bad += bl_ok(g[0] == 0, "removed at the start");
    // A line that crosses a paragraph is a fault.
    let h = bl_levels_of([0x61, 0x0A, 0x62][..], 0, 1, 3);
    bad += bl_ok(h.len == 2 && h[0] == -100 && h[1] == unicode::ERR_BAD_ARG, "line across paragraphs");
    // A line that ends after the separator is valid.
    let i = bl_levels_of([0x61, 0x0A, 0x62][..], 0, 0, 2);
    bad += bl_ok(bl_same(i[..], [0, 0][..]), "line with its separator");
    // The empty line gives an empty result. ICU gives the error
    // U_ILLEGAL_ARGUMENT_ERROR for it.
    let j = bl_levels_of([0x61][..], 0, 1, 1);
    bad += bl_ok(j.len == 0, "empty line");
    return bad;
}

// ---- the write call -------------------------------------------------
fn bl_flags() -> i64 {
    var bad = 0;
    let none = 0;
    let mark = unicode::BIDI_KEEP_BASE_COMBINING;
    let mirror = unicode::BIDI_DO_MIRRORING;
    let rm = unicode::BIDI_REMOVE_CONTROLS;
    // The line in visual order, with no option.
    let a = bl_write([0x5D0, 0x5D1, 0x5D2][..], 0, 0, 3, none);
    bad += bl_ok(bl_same(a[..], [0x5D2, 0x5D1, 0x5D0][..]), "reverse run");
    // L4: a bracket in a right to left run takes its partner.
    let b = bl_write([0x5D0, 0x28, 0x5D1, 0x29][..], 1, 0, 4, mirror);
    bad += bl_ok(bl_same(b[..], [0x28, 0x5D1, 0x29, 0x5D0][..]), "mirror");
    // A bracket in a left to right run stays.
    let c = bl_write([0x61, 0x28, 0x62, 0x29][..], 0, 0, 4, mirror);
    bad += bl_ok(bl_same(c[..], [0x61, 0x28, 0x62, 0x29][..]), "no mirror in ltr");
    // The ornate parentheses are no mirrored characters.
    let d = bl_write([0x5D0, 0xFD3E, 0x5D1, 0xFD3F][..], 1, 0, 4, mirror);
    bad += bl_ok(bl_same(d[..], [0xFD3F, 0x5D1, 0xFD3E, 0x5D0][..]), "FD3E and FD3F stay");
    // Without the flag no code point changes.
    let e = bl_write([0x5D0, 0x28, 0x5D1, 0x29][..], 1, 0, 4, none);
    bad += bl_ok(bl_same(e[..], [0x29, 0x5D1, 0x28, 0x5D0][..]), "no flag, no mirror");
    // L3: a mark stays after its base.
    let f = bl_write([0x5D0, 0x5B0, 0x5D1][..], 1, 0, 3, mark);
    bad += bl_ok(bl_same(f[..], [0x5D1, 0x5D0, 0x5B0][..]), "keep base");
    let g = bl_write([0x5D0, 0x5B0, 0x5D1][..], 1, 0, 3, none);
    bad += bl_ok(bl_same(g[..], [0x5D1, 0x5B0, 0x5D0][..]), "marks reverse without the flag");
    // The removal of the controls follows the property Bidi_Control. It
    // keeps ZWJ and ZWNJ, which ICU removes, and it removes ALM, which
    // ICU keeps.
    let h = bl_write([0x5D0, 0x200F, 0x200D, 0x200C, 0x61C, 0x5D1][..], 1, 0, 6, rm);
    bad += bl_ok(bl_same(h[..], [0x5D1, 0x200C, 0x200D, 0x5D0][..]), "remove controls");
    // The three options together.
    let i = bl_write([0x5D0, 0x28, 0x5B0, 0x200F, 0x5D1, 0x29][..], 1, 0, 6, mark | mirror | rm);
    bad += bl_ok(i.len == 5, "all options");
    // An unknown bit is a fault. So is a negative value.
    let bits = [4, 16, 32, 64, -1];
    for k in 0..bits.len {
        let r = bl_write([0x61][..], 0, 0, 1, bits[k]);
        bad += bl_ok(r.len == 2 && r[0] == -100 && r[1] == unicode::ERR_BAD_ARG, "unknown flag bit");
    }
    // The empty line gives an empty text.
    let j = bl_write([0x61][..], 0, 1, 1, mirror);
    bad += bl_ok(j.len == 0, "empty write");
    return bad;
}

// ---- the faults -----------------------------------------------------
fn bl_faults() -> i64 {
    var bad = 0;
    var out: i64[>..] = [];
    out.push(7);
    let s = bl_text([0x61, 0x62][..]);
    // A bad range.
    let c1, _ = unicode::bidi_line_levels(out, s[..], 0, 1, 0);
    bad += bl_ok(c1 == unicode::ERR_BAD_ARG && out.len == 0, "start above limit");
    out.push(7);
    let c2, _ = unicode::bidi_line_levels(out, s[..], 0, -1, 1);
    bad += bl_ok(c2 == unicode::ERR_BAD_ARG && out.len == 0, "negative start");
    out.push(7);
    let c3, _ = unicode::bidi_line_order(out, s[..], 0, 0, 3);
    bad += bl_ok(c3 == unicode::ERR_BAD_ARG && out.len == 0, "limit above count");
    // A bad direction.
    out.push(7);
    let c4, _ = unicode::bidi_line_order(out, s[..], 3, 0, 1);
    bad += bl_ok(c4 == unicode::ERR_BAD_ARG && out.len == 0, "bad direction");
    out.push(7);
    let c5, _ = unicode::bidi_paragraphs(out, s[..], -1);
    bad += bl_ok(c5 == unicode::ERR_BAD_ARG && out.len == 0, "bad direction paragraphs");
    // A bad byte, with its offset, also outside the line.
    var bytes: u8[>..] = [0x61, 0x62, 0xFF, 0x63];
    out.push(7);
    let c6, off = unicode::bidi_line_levels(out, bytes[..], 0, 0, 1);
    bad += bl_ok(c6 == unicode::ERR_BAD_UTF8 && off == 2 && out.len == 0, "bad byte");
    out.push(7);
    let c7, off7 = unicode::bidi_paragraphs(out, bytes[..], 0);
    bad += bl_ok(c7 == unicode::ERR_BAD_UTF8 && off7 == 2 && out.len == 0, "bad byte paragraphs");
    // A text above the bound.
    var big: u8[>..] = [];
    for k in 0..unicode::MAX_INPUT + 1 { big.push(0x61); }
    out.push(7);
    let c8, _ = unicode::bidi_line_levels(out, big[..], 0, 0, 1);
    bad += bl_ok(c8 == unicode::ERR_TOO_LONG && out.len == 0, "text too long");
    var wb: u8[>..] = [1];
    let c9, _ = unicode::bidi_reorder(wb, big[..], 0, 0, 1, 0);
    bad += bl_ok(c9 == unicode::ERR_TOO_LONG && wb.len == 0, "write too long");
    // The paragraph split and the resolution give the same faults and
    // clear their buffers.
    var pars: i64[>..] = [1];
    let c11, _ = unicode::bidi_paragraphs(pars, big[..], 0);
    bad += bl_ok(c11 == unicode::ERR_TOO_LONG && pars.len == 0, "paragraphs too long");
    var res: i64[>..] = [1];
    var offs: i64[>..] = [1];
    let c12, _ = unicode::bidi_resolve(res, offs, big[..], 0);
    bad += bl_ok(c12 == unicode::ERR_TOO_LONG && res.len == 0 && offs.len == 0, "resolve too long");
    res.push(1);
    offs.push(1);
    let c13, off13 = unicode::bidi_resolve(res, offs, bytes[..], 0);
    bad += bl_ok(c13 == unicode::ERR_BAD_UTF8 && off13 == 2 && res.len == 0 && offs.len == 0, "resolve bad byte");
    res.push(1);
    offs.push(1);
    let c14, _ = unicode::bidi_resolve(res, offs, s[..], 5);
    bad += bl_ok(c14 == unicode::ERR_BAD_ARG && res.len == 0 && offs.len == 0, "resolve bad direction");
    // A fault of the write call clears the buffer.
    wb.push(1);
    let c10, _ = unicode::bidi_reorder(wb, s[..], 0, 0, 5, 0);
    bad += bl_ok(c10 == unicode::ERR_BAD_ARG && wb.len == 0, "write bad range");
    return bad;
}

// ---- the calls on a resolved text -----------------------------------
fn bl_pack_for_test(level: i64, kind: i64, para: i64) -> i64 {
    return level | (kind << 8) | (para << 16);
}

fn bl_from() -> i64 {
    var bad = 0;
    let cps = [0x5D0, 0x20, 0x61, 0x0A, 0x28, 0x5D1, 0x5B0, 0x29, 0x20, 0x0D, 0x0A, 0x62];
    let s = bl_text(cps[..]);
    var res: i64[>..] = [];
    var offs: i64[>..] = [];
    let code, _ = unicode::bidi_resolve(res, offs, s[..], 2);
    bad += bl_ok(code == unicode::OK && res.len == cps.len && offs.len == cps.len + 1, "resolve sizes");
    bad += bl_ok(unicode::bidi_resolved_level(res[..], 0) == 1, "resolved level");
    bad += bl_ok(unicode::bidi_resolved_level(res[..], -1) == -1, "resolved level below");
    // A removed code point takes the level of the code point before it,
    // and the paragraph level at the start of a paragraph.
    var r2: i64[>..] = [];
    var o2: i64[>..] = [];
    let t2 = bl_text([0x202C, 0x5D0, 0xAD, 0x61][..]);
    unicode::bidi_resolve(r2, o2, t2[..], 0);
    bad += bl_ok(unicode::bidi_resolved_level(r2[..], 0) == 0, "removed level at the start");
    bad += bl_ok(unicode::bidi_resolved_level(r2[..], 2) == 1, "removed level after a letter");
    bad += bl_ok(unicode::bidi_resolved_level(res[..], cps.len) == -1, "resolved level above");
    // Every line of the text, from the resolved levels and from the text.
    for a in 0..cps.len {
        for b in a..cps.len + 1 {
            var l1: i64[>..] = [];
            var l2: i64[>..] = [];
            let c1 = unicode::bidi_line_levels_from(l1, res[..], a, b);
            let c2, _ = unicode::bidi_line_levels(l2, s[..], 2, a, b);
            bad += bl_ok(c1 == c2 && bl_same(l1[..], l2[..]), "levels from and direct");
            var o1: i64[>..] = [];
            var o2: i64[>..] = [];
            let c3 = unicode::bidi_line_order_from(o1, res[..], a, b);
            let c4, _ = unicode::bidi_line_order(o2, s[..], 2, a, b);
            bad += bl_ok(c3 == c4 && bl_same(o1[..], o2[..]), "order from and direct");
            var w1: u8[>..] = [];
            var w2: u8[>..] = [];
            let c5 = unicode::bidi_reorder_from(w1, s[..], res[..], offs[..], a, b, 3);
            let c6, _ = unicode::bidi_reorder(w2, s[..], 2, a, b, 3);
            bad += bl_ok(c5 == c6 && w1.len == w2.len, "write from and direct");
            if bad > 5 { return bad; }
        }
    }
    // The order holds the indexes of the text, not of the line.
    var o: i64[>..] = [];
    unicode::bidi_line_order_from(o, res[..], 4, 8);
    bad += bl_ok(o.len == 4 && o[0] >= 4 && o[3] <= 7, "order counts from the text");
    // A value that no call gives is a fault, and a short offset list too.
    var bogus: i64[>..] = [];
    for k in 0..3 { bogus.push(-5); }
    var out: i64[>..] = [1];
    bad += bl_ok(unicode::bidi_line_levels_from(out, bogus[..], 0, 3) == unicode::ERR_BAD_ARG
        && out.len == 0, "bogus resolved value");
    // A paragraph level, a kind or a high bit that no call gives is a fault.
    var odd: i64[>..] = [bl_pack_for_test(0, 0, 255), bl_pack_for_test(0, 7, 0), 1 << 30];
    for k in 0..odd.len {
        var one: i64[>..] = [odd[k]];
        out.push(1);
        bad += bl_ok(unicode::bidi_line_levels_from(out, one[..], 0, 1) == unicode::ERR_BAD_ARG
            && out.len == 0, "bogus paragraph level, kind or bit");
    }
    var w: u8[>..] = [1];
    var shortoffs: i64[>..] = [0, 1];
    bad += bl_ok(unicode::bidi_reorder_from(w, s[..], res[..], shortoffs[..], 0, 2, 0) == unicode::ERR_BAD_ARG
        && w.len == 0, "short offsets");
    // The offsets may not point out of the text.
    var wild: i64[>..] = [];
    for k in 0..offs.len { wild.push(offs[k] + 1000); }
    bad += bl_ok(unicode::bidi_reorder_from(w, s[..], res[..], wild[..], 0, 2, 0) == unicode::ERR_BAD_ARG
        && w.len == 0, "wild offsets");
    return bad;
}

// ---- hostile texts --------------------------------------------------
// The time of a text of one mebibyte, in milliseconds, for the paragraph
// split, the resolution and the line calls of the first paragraph.
fn bl_time(text: const u8[:], dir: i64, name: const u8[:]) -> i64 {
    let t0 = clock_ns();
    var pars: i64[>..] = [];
    let c1, _ = unicode::bidi_paragraphs(pars, text, dir);
    var res: i64[>..] = [];
    var offs: i64[>..] = [];
    let c2, _ = unicode::bidi_resolve(res, offs, text, dir);
    if c1 != unicode::OK || c2 != unicode::OK || pars.len == 0 {
        print("FAIL: bidi_line hostile ", name, " gave ", c1, " and ", c2, "\n");
        return 1;
    }
    // The first paragraph is the line, and so are slices of 100 code
    // points of it, up to 10,000 calls: the cost of each call is its own length.
    let limit = pars[1];
    var lv: i64[>..] = [];
    var ord: i64[>..] = [];
    var w: u8[>..] = [];
    var bad = 0;
    var a = 0;
    var calls = 0;
    while a < limit && calls < 10000 {
        var b = a + 100;
        if b > limit { b = limit; }
        if unicode::bidi_line_levels_from(lv, res[..], a, b) != unicode::OK { bad += 1; }
        if unicode::bidi_line_order_from(ord, res[..], a, b) != unicode::OK { bad += 1; }
        if unicode::bidi_reorder_from(w, text, res[..], offs[..], a, b, 11) != unicode::OK { bad += 1; }
        a = b;
        calls += 1;
    }
    // The first paragraph as one line.
    if limit <= 200000 {
        if unicode::bidi_line_order_from(ord, res[..], 0, limit) != unicode::OK { bad += 1; }
    }
    let ms = (clock_ns() - t0) / 1000000;
    print("bidi_line hostile ", name, ": ", ms, " ms\n");
    if bad > 0 || ms > 5000 {
        print("FAIL: bidi_line hostile ", name, " took ", ms, " ms, faults ", bad, "\n");
        return 1;
    }
    return 0;
}

fn bl_filled(unit: const i64[:], tail: const i64[:]) -> u8[>..] {
    var s: u8[>..] = [];
    var u: u8[>..] = [];
    for k in 0..unit.len { unicode::utf8_encode(u, unit[k]); }
    while s.len + u.len + 8 <= unicode::MAX_INPUT {
        for k in 0..u.len { s.push(u[k]); }
    }
    for k in 0..tail.len { unicode::utf8_encode(s, tail[k]); }
    return s;
}

fn bl_hostile() -> i64 {
    var bad = 0;
    let nothing: i64[>..] = [];
    // One mebibyte of paragraph separators.
    let a = bl_filled([0x0A][..], nothing[..]);
    bad += bl_time(a[..], 2, "LF");
    // One mebibyte of CR LF pairs.
    let b = bl_filled([0x0D, 0x0A][..], nothing[..]);
    bad += bl_time(b[..], 1, "CR LF");
    // One mebibyte of isolate initiators.
    let c = bl_filled([0x2067][..], [0x5D0]);
    bad += bl_time(c[..], 2, "isolates");
    // One mebibyte of embedding initiators.
    let d = bl_filled([0x202B][..], [0x5D0]);
    bad += bl_time(d[..], 0, "embeddings");
    // One mebibyte of white space after a right to left letter.
    let e = bl_filled([0x20][..], nothing[..]);
    var e2: u8[>..] = [];
    unicode::utf8_encode(e2, 0x5D0);
    for k in 0..e.len { e2.push(e[k]); }
    bad += bl_time(e2[..], 0, "trailing white space");
    // Isolates that never close, then a separator, then more text.
    let f = bl_filled([0x2068, 0x5D0, 0x0A][..], nothing[..]);
    bad += bl_time(f[..], 2, "isolates with separators");
    return bad;
}


// ---- the bound of the result ----------------------------------------
// A line of code points of four bytes writes at most four bytes for each
// code point, so a text at MAX_INPUT never reaches MAX_OUTPUT.
fn bl_bound() -> i64 {
    var s: u8[>..] = [];
    var n = 0;
    while s.len + 4 <= unicode::MAX_INPUT {
        unicode::utf8_encode(s, 0x1F600 + n % 64);
        n += 1;
    }
    var out: u8[>..] = [];
    let code, _ = unicode::bidi_reorder(out, s[..], 1, 0, n, 11);
    var bad = bl_ok(code == unicode::OK, "bound: no fault");
    bad += bl_ok(out.len <= 4 * n && out.len <= unicode::MAX_OUTPUT, "bound: result size");
    return bad;
}

// ---- the shortcut of a paragraph of separators ----------------------
// A paragraph of separators needs no run of the core. Its levels equal
// the levels that the core gives to the same separators after white
// space, which rule L1 resets to the paragraph level.
fn bl_shortcut() -> i64 {
    var bad = 0;
    let seps = [0x0A, 0x0D, 0x1C, 0x1D, 0x1E, 0x85, 0x2029];
    for d in 0..3 {
        for k in 0..seps.len {
            let a = bl_levels_of([seps[k]][..], d, 0, 1);
            let b = bl_levels_of([0x20, seps[k]][..], d, 1, 2);
            bad += bl_ok(bl_same(a[..], b[..]), "shortcut one separator");
        }
        let c = bl_levels_of([0x0D, 0x0A][..], d, 0, 2);
        let e = bl_levels_of([0x20, 0x0D, 0x0A][..], d, 1, 3);
        bad += bl_ok(bl_same(c[..], e[..]), "shortcut CR LF");
        let f = bl_levels_of([0x0A, 0x0A][..], d, 0, 1);
        bad += bl_ok(f.len == 1, "shortcut LF LF line");
    }
    return bad;
}

// ---- cover and order on the case file --------------------------------
// The paragraphs cover the text with no gap and no overlap. The order of
// a line holds each index of the line once.
fn bl_cover() -> i64 {
    var bad = 0;
    var n = BL_DIR.len;
    if n > 200 { n = 200; }
    for c in 0..n {
        let cps = BL_TXT[BL_TXT_OFF[c]..BL_TXT_OFF[c + 1]];
        let pars = bl_paras(cps, BL_DIR[c]);
        var at = 0;
        var k = 0;
        while k < pars.len {
            if pars[k] != at || pars[k + 1] <= pars[k] { bad += 1; }
            at = pars[k + 1];
            k += 3;
        }
        if at != cps.len { bad += 1; }
        if BL_KIND[c] == 1 { continue; }
        let s = bl_text(cps);
        var ord: i64[>..] = [];
        let code, _ = unicode::bidi_line_order(ord, s[..], BL_DIR[c], BL_START[c], BL_LIMIT[c]);
        if code != unicode::OK || ord.len != BL_LIMIT[c] - BL_START[c] { bad += 1; continue; }
        var seen: i64[>..] = [];
        for j in 0..cps.len { seen.push(0); }
        for j in 0..ord.len {
            if ord[j] < BL_START[c] || ord[j] >= BL_LIMIT[c] { bad += 1; continue; }
            seen[ord[j]] += 1;
        }
        for j in BL_START[c]..BL_LIMIT[c] { if seen[j] != 1 { bad += 1; } }
    }
    return bl_ok(bad == 0, "cover and order of the case file");
}

fn run_bidi_line() -> i64 {
    var bad = 0;
    if want("bidi_line", "bl_split") { bad += bl_split(); }
    if want("bidi_line", "bl_crlf") { bad += bl_crlf(); }
    if want("bidi_line", "bl_l1") { bad += bl_l1(); }
    if want("bidi_line", "bl_flags") { bad += bl_flags(); }
    if want("bidi_line", "bl_faults") { bad += bl_faults(); }
    if want("bidi_line", "bl_from") { bad += bl_from(); }
    if want("bidi_line", "bl_cases") { bad += bl_cases(); }
    if want("bidi_line", "bl_shortcut") { bad += bl_shortcut(); }
    if want("bidi_line", "bl_cover") { bad += bl_cover(); }
    if want("bidi_line", "bl_bound") { bad += bl_bound(); }
    if want("bidi_line", "bl_hostile") { bad += bl_hostile(); }
    return bad;
}
