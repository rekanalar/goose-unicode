// The paragraphs and the lines of the bidirectional algorithm (UAX #9).
//
// bidi_paragraphs cuts a text into paragraphs (rule P1). bidi_resolve
// resolves the levels of every paragraph once. A caller then cuts lines
// from the result. Each line gets rule L1 (the levels), rule L2 (the
// visual order) and, as options of the write call, rule L3 (a mark stays
// after its base) and rule L4 (the mirror of a code point in a right to
// left run).
//
// Each call reads each code point of its line a bounded number of times,
// so the time of a call is linear in the text.
namespace unicode;

import std;

// The options of bidi_reorder and bidi_reorder_from. The values are the
// values of the ICU library.
const BIDI_KEEP_BASE_COMBINING: i64 = 1;  // rule L3
const BIDI_DO_MIRRORING: i64 = 2;         // rule L4
const BIDI_REMOVE_CONTROLS: i64 = 8;      // drop the code points of Bidi_Control

// The kind of a code point for rule L1. The kind comes from the original
// class of the code point.
const BL_STOP: i64 = 0;       // every other class: stops a sequence
const BL_SPACE: i64 = 1;      // white space, isolate formatting
const BL_SEPARATOR: i64 = 2;  // a segment separator, or the CR of a CR LF pair
const BL_END: i64 = 3;        // the separator that ends a paragraph
const BL_REMOVED: i64 = 4;    // a code point that rule X9 removes

// The packed value of a code point holds the level in the bits 0 to 7,
// the kind in the bits 8 to 10 and the paragraph level in the bits 16
// to 23.
fn bl_pack(level: i64, kind: i64, para: i64) -> i64 {
    return level | (kind << 8) | (para << 16);
}

fn bl_level(v: i64) -> i64 { return v & 0xFF; }
fn bl_kind(v: i64) -> i64 { return (v >> 8) & 7; }
fn bl_para(v: i64) -> i64 { return (v >> 16) & 0xFF; }

// The paragraphs of the UTF-8 text s. out is cleared first and receives
// three values for each paragraph: the start, the limit and the level.
// The unit is the code point. The separator of a paragraph is inside it.
// A CR followed by LF is one terminator. dir is BIDI_DIR_LTR,
// BIDI_DIR_RTL or BIDI_DIR_AUTO. The call returns a fault code and the
// offset of a bad byte, or -1. A fault leaves out empty.
fn bidi_paragraphs(out: i64[>..]&, s: const u8[:], dir: i64) -> i64, i64 {
    out.clear();
    if dir < 0 || dir > 2 { return ERR_BAD_ARG, -1; }
    if s.len > MAX_INPUT { return ERR_TOO_LONG, -1; }
    var cps: i64[>..] = [];
    var cls: i64[>..] = [];
    var brk: i64[>..] = [];
    var offs: i64[>..] = [];
    let code, off = bd_scan(cps, cls, brk, offs, s);
    if code != OK { return code, off; }
    var cuts: i64[>..] = [];
    bd_split(cuts, cps[..], cls[..]);
    var plev: i64[>..] = [];
    var p = 0;
    while p < cuts.len {
        let a = cuts[p];
        let b = cuts[p + 1];
        let pl = bd_para_levels(plev, cls[..], brk[..], a, b, dir);
        out.push(a);
        out.push(b);
        out.push(pl);
        p += 2;
    }
    return OK, -1;
}

// Resolves the levels of every paragraph of the text once. res is
// cleared first and receives one packed value for each code point. offs
// is cleared first and receives the byte offset of each code point, then
// the length of the text. A code point that rule X9 removes takes the
// level of the code point before it, and the paragraph level at the
// start of a paragraph. The levels are the levels before rule L1. The
// call returns a fault code and the offset of a bad byte, or -1. A fault
// leaves both buffers empty.
fn bidi_resolve(res: i64[>..]&, offs: i64[>..]&, s: const u8[:], dir: i64) -> i64, i64 {
    res.clear();
    offs.clear();
    if dir < 0 || dir > 2 { return ERR_BAD_ARG, -1; }
    if s.len > MAX_INPUT { return ERR_TOO_LONG, -1; }
    var cps: i64[>..] = [];
    var cls: i64[>..] = [];
    var brk: i64[>..] = [];
    let code, off = bd_scan(cps, cls, brk, offs, s);
    if code != OK {
        offs.clear();
        return code, off;
    }
    var cuts: i64[>..] = [];
    bd_split(cuts, cps[..], cls[..]);
    var plev: i64[>..] = [];
    var p = 0;
    while p < cuts.len {
        let a = cuts[p];
        let b = cuts[p + 1];
        let pl = bd_para_levels(plev, cls[..], brk[..], a, b, dir);
        var prev = pl;
        for k in a..b {
            let c = cls[k];
            var l = plev[k - a];
            if l == BD_REMOVED { l = prev; }
            prev = l;
            var kind = BL_STOP;
            if c == BIDI_B {
                if k + 1 == b { kind = BL_END; } else { kind = BL_SEPARATOR; }
            } else if c == BIDI_S {
                kind = BL_SEPARATOR;
            } else if bd_is_removed(c) {
                kind = BL_REMOVED;
            } else if c == BIDI_WS || c == BIDI_PDI || bd_is_isolate_init(c) {
                kind = BL_SPACE;
            }
            res.push(bl_pack(l, kind, pl));
        }
        p += 2;
    }
    return OK, -1;
}

// The level of the code point i in a resolved text, before rule L1. An
// index outside res gives -1.
fn bidi_resolved_level(res: const i64[:], i: i64) -> i64 {
    if i < 0 || i >= res.len { return -1; }
    return bl_level(res[i]);
}

// Checks the line start to limit of a resolved text. The line must sit
// inside the text and inside one paragraph. A value of res that no call
// of the package gives is a fault too.
fn bl_check(res: const i64[:], start: i64, limit: i64) -> i64 {
    if res.len > MAX_INPUT { return ERR_TOO_LONG; }
    if start < 0 || limit > res.len || start > limit { return ERR_BAD_ARG; }
    for k in start..limit {
        let v = res[k];
        if v < 0 || bl_level(v) > BD_MAX_DEPTH + 1 || bl_para(v) > BD_MAX_DEPTH + 1
            || bl_kind(v) > BL_REMOVED || (v >> 24) != 0 { return ERR_BAD_ARG; }
        if bl_kind(v) == BL_END && k + 1 < limit { return ERR_BAD_ARG; }
    }
    return OK;
}

// The levels of the line after rule L1. out is cleared first and receives
// one level for each code point of the line. The white space at the end
// of the line, and before a separator, takes the paragraph level. A code
// point that rule X9 removes takes the level of the code point before it,
// after rule L1. The call returns a fault code. A line that crosses a
// paragraph, and a line outside the text, give ERR_BAD_ARG. A fault leaves
// out empty.
fn bidi_line_levels_from(out: i64[>..]&, res: const i64[:], start: i64, limit: i64) -> i64 {
    out.clear();
    let code = bl_check(res, start, limit);
    if code != OK { return code; }
    for k in start..limit { out.push(bl_level(res[k])); }
    // The start of the run of white space that a separator or the end of
    // the line resets to the paragraph level.
    var from = -1;
    for k in start..limit {
        let kind = bl_kind(res[k]);
        if kind == BL_SEPARATOR || kind == BL_END {
            if from < 0 { from = k; }
            for j in from..k + 1 { out[j - start] = bl_para(res[j]); }
            from = -1;
        } else if kind == BL_SPACE || kind == BL_REMOVED {
            if from < 0 { from = k; }
            if kind == BL_REMOVED {
                // The level of the code point before it, after rule L1. At
                // the start of a line the paragraph level stands, as in the
                // Rust crate.
                if k == start { out[k - start] = bl_para(res[k]); }
                else { out[k - start] = out[k - start - 1]; }
            }
        } else {
            from = -1;
        }
    }
    if from >= 0 {
        for j in from..limit { out[j - start] = bl_para(res[j]); }
    }
    return OK;
}

// The levels of the line and the visual order of its code points. ord
// holds the index of each code point, counted from the start of the text.
fn bl_order(ord: i64[>..]&, lv: i64[>..]&, res: const i64[:], start: i64, limit: i64) -> i64 {
    ord.clear();
    let code = bidi_line_levels_from(lv, res, start, limit);
    if code != OK { return code; }
    var maxl = 0;
    var min_odd = BD_MAX_DEPTH + 2;
    for i in 0..lv.len {
        let l = lv[i];
        if l > maxl { maxl = l; }
        if l % 2 == 1 && l < min_odd { min_odd = l; }
        ord.push(i);
    }
    bd_reverse(ord, lv[..], maxl, min_odd);
    for i in 0..ord.len { ord[i] += start; }
    return OK;
}

// The visual order of the line, after rules L1 and L2. out is cleared
// first and receives the index of each code point of the line, in the
// order that a reader sees them from left to right. The indexes count
// from the start of the text. The call returns a fault code. A fault
// leaves out empty.
fn bidi_line_order_from(out: i64[>..]&, res: const i64[:], start: i64, limit: i64) -> i64 {
    var lv: i64[>..] = [];
    return bl_order(out, lv, res, start, limit);
}

// True when the code point is a combining mark: Mn, Mc or Me.
fn bl_is_mark(cp: i64) -> bool {
    return category_group(cp) == GROUP_MARK;
}

// Rule L3 on the visual order. A base character and the marks that
// follow it keep the order of the text. The base comes first and the
// marks follow. A group of marks without a base keeps the order of the
// text too. Only a run at an odd level changes.
fn bl_keep_base(ord: i64[>..]&, lv: const i64[:], lcp: const i64[:], start: i64) {
    let n = ord.len;
    var odd = false;
    for k in 0..n { if lv[k] % 2 == 1 { odd = true; } }
    if !odd { return; }
    // The visual position of each code point of the line.
    var pos: i64[>..] = [];
    for k in 0..n { pos.push(0); }
    for k in 0..n { pos[ord[k] - start] = k; }
    var i = 0;
    while i < n {
        // A base character takes the marks that follow it. A mark takes
        // the marks that follow it.
        var j = i;
        if !bl_is_mark(lcp[i]) { j = i + 1; }
        while j < n && bl_is_mark(lcp[j]) && lv[j] == lv[i] { j += 1; }
        if lv[i] % 2 == 1 {
            var lo = pos[j - 1];
            var hi = pos[i];
            while lo < hi {
                let tmp = ord[lo];
                ord[lo] = ord[hi];
                ord[hi] = tmp;
                lo += 1;
                hi -= 1;
            }
        }
        i = j;
    }
}

// The UTF-8 bytes of the line in visual order. out is cleared first.
// offs holds the byte offsets that bidi_resolve gives. flags is the sum of
// BIDI_KEEP_BASE_COMBINING (rule L3), BIDI_DO_MIRRORING (rule L4) and
// BIDI_REMOVE_CONTROLS. With no flag the call writes the code points of
// rule L2 as they are. A bit of flags that is no option gives
// ERR_BAD_ARG. A result above MAX_OUTPUT bytes gives ERR_TOO_LONG. A
// fault leaves out empty.
fn bidi_reorder_from(out: u8[>..]&, s: const u8[:], res: const i64[:], offs: const i64[:],
                     start: i64, limit: i64, flags: i64) -> i64 {
    out.clear();
    if flags < 0 || (flags & ~(BIDI_KEEP_BASE_COMBINING | BIDI_DO_MIRRORING
        | BIDI_REMOVE_CONTROLS)) != 0 { return ERR_BAD_ARG; }
    if offs.len != res.len + 1 { return ERR_BAD_ARG; }
    var ord: i64[>..] = [];
    var lv: i64[>..] = [];
    let code = bl_order(ord, lv, res, start, limit);
    if code != OK { return code; }
    // The code points of the line.
    var lcp: i64[>..] = [];
    for k in start..limit {
        let at = offs[k];
        if at < 0 || at >= s.len { out.clear(); return ERR_BAD_ARG; }
        let cp, n = decode_at(s, at);
        if cp < 0 { out.clear(); return ERR_BAD_ARG; }
        lcp.push(cp);
    }
    if (flags & BIDI_KEEP_BASE_COMBINING) != 0 { bl_keep_base(ord, lv[..], lcp[..], start); }
    for i in 0..ord.len {
        var cp = lcp[ord[i] - start];
        if (flags & BIDI_REMOVE_CONTROLS) != 0 && has_property(cp, PROP_BIDI_CONTROL) { continue; }
        if (flags & BIDI_DO_MIRRORING) != 0 && lv[ord[i] - start] % 2 == 1 { cp = mirror_of(cp); }
        push_utf8(out, cp);
        if out.len > MAX_OUTPUT { out.clear(); return ERR_TOO_LONG; }
    }
    return OK;
}

// The levels of the line, after rule L1. The call resolves the text and
// then calls bidi_line_levels_from. It returns a fault code and the
// offset of a bad byte, or -1. A caller that cuts many lines of one text
// resolves it once with bidi_resolve.
fn bidi_line_levels(out: i64[>..]&, s: const u8[:], dir: i64, start: i64, limit: i64) -> i64, i64 {
    out.clear();
    var res: i64[>..] = [];
    var offs: i64[>..] = [];
    let code, off = bidi_resolve(res, offs, s, dir);
    if code != OK { return code, off; }
    return bidi_line_levels_from(out, res[..], start, limit), -1;
}

// The visual order of the line. The call resolves the text and then
// calls bidi_line_order_from. It returns a fault code and the offset of
// a bad byte, or -1.
fn bidi_line_order(out: i64[>..]&, s: const u8[:], dir: i64, start: i64, limit: i64) -> i64, i64 {
    out.clear();
    var res: i64[>..] = [];
    var offs: i64[>..] = [];
    let code, off = bidi_resolve(res, offs, s, dir);
    if code != OK { return code, off; }
    return bidi_line_order_from(out, res[..], start, limit), -1;
}

// The line in visual order, as UTF-8 bytes. The call resolves the text
// and then calls bidi_reorder_from. It returns a fault code and the
// offset of a bad byte, or -1.
fn bidi_reorder(out: u8[>..]&, s: const u8[:], dir: i64, start: i64, limit: i64,
                flags: i64) -> i64, i64 {
    out.clear();
    var res: i64[>..] = [];
    var offs: i64[>..] = [];
    let code, off = bidi_resolve(res, offs, s, dir);
    if code != OK { return code, off; }
    return bidi_reorder_from(out, s, res[..], offs[..], start, limit, flags), -1;
}
