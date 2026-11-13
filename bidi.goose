// The Unicode bidirectional algorithm (UAX #9): the embedding level of
// each code point of a text, and the visual order of a line.
//
// The rules run in this order: the paragraph split (P1), the paragraph
// level (P2, P3), the explicit levels (X1 to X8), the removal of the
// formatting characters (X9), the isolating run sequences (X10), the
// weak types (W1 to W7), the paired brackets (N0), the neutral types (N1,
// N2), the implicit levels (I1, I2), the trailing white space (L1) and
// the reorder (L2). The rules L3 and L4 depend on the renderer, so the
// package leaves them out.
//
// Every pass reads the text once or reads each part of it a bounded
// number of times, so the time of a call is linear in the text. The
// matching isolates and the first strong class of each isolate come from
// two passes that cannot nest.
namespace unicode;

import std;

const BIDI_DIR_LTR: i64 = 0;    // the paragraph runs left to right
const BIDI_DIR_RTL: i64 = 1;    // the paragraph runs right to left
const BIDI_DIR_AUTO: i64 = 2;   // the first strong class decides

// The deepest explicit level, and the size of the bracket stack.
const BD_MAX_DEPTH: i64 = 125;
const BD_BRACKET_STACK: i64 = 63;
// The size of the status stack of the explicit levels. The deepest
// level is 125, so the stack holds the base level and every level
// above it.
const BD_STATUS_SIZE: i64 = BD_MAX_DEPTH + 6;
// The size of the stack of the open brackets of rule N0.
const BD_BRACKET_SIZE: i64 = BD_BRACKET_STACK + 1;
// The level of a code point that rule X9 removes.
const BD_REMOVED: i64 = -1;

fn bd_is_isolate_init(c: i64) -> bool {
    return c == BIDI_LRI || c == BIDI_RLI || c == BIDI_FSI;
}

// The classes that rule X9 removes from the text.
fn bd_is_removed(c: i64) -> bool {
    return c == BIDI_BN || c == BIDI_LRE || c == BIDI_RLE || c == BIDI_LRO
        || c == BIDI_RLO || c == BIDI_PDF;
}

// The direction of a class for the rules N0 to N2: L is 0, and R, EN and
// AN are 1. Any other class gives -1.
fn bd_strong_dir(c: i64) -> i64 {
    if c == BIDI_L { return BIDI_L; }
    if c == BIDI_R || c == BIDI_EN || c == BIDI_AN { return BIDI_R; }
    return -1;
}

fn bd_fill(a: i64[>..]&, n: i64, v: i64) {
    a.clear();
    for k in 0..n { a.push(v); }
}

// The direction of a level: an even level reads left to right.
fn bd_level_dir(level: i64) -> i64 {
    if level % 2 == 1 { return BIDI_R; }
    return BIDI_L;
}

// The least level above cur of the direction.
fn bd_next_level(cur: i64, rtl: bool) -> i64 {
    if rtl {
        if cur % 2 == 0 { return cur + 1; }
        return cur + 2;
    }
    if cur % 2 == 0 { return cur + 2; }
    return cur + 1;
}

// The bracket code of a code point: twice the opening bracket of its pair,
// plus 1 for an opening bracket. 0 when the code point is no bracket.
fn bd_bracket(cp: i64) -> i64 {
    let i = find_exact(BR_CP[..], cp);
    if i < 0 { return 0; }
    return BR_CODE[i];
}

// The level of the edge of a sequence: the higher of the level of the
// sequence and the level of the code point beside it.
fn bd_edge(beside: i64, level: i64) -> i64 {
    if beside > level { return beside; }
    return level;
}

// The override of the status stack changes the class of a code point.
fn bd_override(cl: i64[>..]&, i: i64, ov: i64) {
    if ov == 1 { cl[i] = BIDI_L; }
    if ov == 2 { cl[i] = BIDI_R; }
}

// The marks that follow a bracket take the type of the bracket.
fn bd_mark_after(t: i64[>..]&, cls: const i64[:], sq: const i64[:],
                 from: i64, len: i64, nd: i64) {
    var m = from + 1;
    while m < len && cls[sq[m]] == BIDI_NSM {
        t[m] = nd;
        m += 1;
    }
}

// The rules W1 to W7, N0 to N2 and I1, I2 on one isolating run sequence.
// sq holds the positions of the sequence, and t holds the class of each.
fn bd_run(t: i64[>..]&, pairat: i64[>..]&, bs_id: i64[>..]&, bs_pos: i64[>..]&,
          sq: const i64[:], cls: const i64[:], brk: const i64[:],
          lev: i64[>..]&, sl: i64, sos: i64, eos: i64) {
    let len = sq.len;
    // W1: a mark takes the class of the code point before it.
    var prev = sos;
    for i in 0..len {
        if t[i] == BIDI_NSM { t[i] = prev; }
        let oc = cls[sq[i]];
        if bd_is_isolate_init(oc) || oc == BIDI_PDI {
            prev = BIDI_ON;
        } else {
            prev = t[i];
        }
    }
    // W2: a European number after an Arabic letter is an Arabic number.
    var last = sos;
    for i in 0..len {
        let c = t[i];
        if c == BIDI_L || c == BIDI_R || c == BIDI_AL {
            last = c;
        } else if c == BIDI_EN && last == BIDI_AL {
            t[i] = BIDI_AN;
        }
    }
    // W3: an Arabic letter is a right to left letter.
    for i in 0..len {
        if t[i] == BIDI_AL { t[i] = BIDI_R; }
    }
    // W4: one separator between two numbers of one kind joins them.
    if len >= 3 {
        for i in 1..(len - 1) {
            let c = t[i];
            if c == BIDI_ES && t[i - 1] == BIDI_EN && t[i + 1] == BIDI_EN {
                t[i] = BIDI_EN;
            } else if c == BIDI_CS {
                let a = t[i - 1];
                if (a == BIDI_EN || a == BIDI_AN) && t[i + 1] == a {
                    t[i] = a;
                }
            }
        }
    }
    // W5: a run of terminators next to a European number joins it.
    var i5 = 0;
    while i5 < len {
        if t[i5] == BIDI_ET {
            var e = i5;
            while e < len && t[e] == BIDI_ET { e += 1; }
            if (i5 > 0 && t[i5 - 1] == BIDI_EN) || (e < len && t[e] == BIDI_EN) {
                for q in i5..e { t[q] = BIDI_EN; }
            }
            i5 = e;
        } else {
            i5 += 1;
        }
    }
    // W6: the separators and terminators that stay are neutral.
    for i in 0..len {
        let c = t[i];
        if c == BIDI_ES || c == BIDI_ET || c == BIDI_CS { t[i] = BIDI_ON; }
    }
    // W7: a European number after a left to right letter is one.
    last = sos;
    for i in 0..len {
        let c = t[i];
        if c == BIDI_L || c == BIDI_R {
            last = c;
        } else if c == BIDI_EN && last == BIDI_L {
            t[i] = BIDI_L;
        }
    }

    let ed = bd_level_dir(sl);

    // N0: the paired brackets. The pairs come from one pass with a stack
    // of at most 63 open brackets. pairat holds the close of each open.
    bd_fill(pairat, len, -1);
    bd_fill(bs_id, BD_BRACKET_SIZE, 0);
    bd_fill(bs_pos, BD_BRACKET_SIZE, 0);
    var sp = 0;
    for i in 0..len {
        let b = brk[sq[i]];
        if b == 0 || t[i] != BIDI_ON { continue; }
        if (b & 1) == 1 {
            if sp == BD_BRACKET_STACK { break; }
            bs_id[sp] = b >> 1;
            bs_pos[sp] = i;
            sp += 1;
        } else {
            let id = b >> 1;
            var k = sp;
            while k > 0 {
                k -= 1;
                if bs_id[k] == id {
                    pairat[bs_pos[k]] = i;
                    sp = k;
                    break;
                }
            }
        }
    }
    for i in 0..len {
        let ci = pairat[i];
        if ci < 0 { continue; }
        var found_e = false;
        var found_o = false;
        var q = i + 1;
        while q < ci {
            let d = bd_strong_dir(t[q]);
            if d == ed {
                found_e = true;
                break;
            }
            if d >= 0 { found_o = true; }
            q += 1;
        }
        var nd = -1;
        if found_e {
            nd = ed;
        } else if found_o {
            var ctx = sos;
            var b = i;
            while b > 0 {
                b -= 1;
                let d = bd_strong_dir(t[b]);
                if d >= 0 {
                    ctx = d;
                    break;
                }
            }
            if ctx != ed { nd = ctx; } else { nd = ed; }
        }
        if nd >= 0 {
            t[i] = nd;
            t[ci] = nd;
            // A mark after a bracket takes the type of the bracket.
            bd_mark_after(t, cls, sq, i, len, nd);
            bd_mark_after(t, cls, sq, ci, len, nd);
        }
    }

    // N1 and N2: a run of neutrals takes the direction of both ends when
    // they agree, and the direction of the level when they do not.
    var i1 = 0;
    while i1 < len {
        if bd_strong_dir(t[i1]) < 0 {
            var e = i1;
            while e < len && bd_strong_dir(t[e]) < 0 { e += 1; }
            var left = sos;
            if i1 > 0 { left = bd_strong_dir(t[i1 - 1]); }
            var right = eos;
            if e < len { right = bd_strong_dir(t[e]); }
            var nd = ed;
            if left == right { nd = left; }
            for q in i1..e { t[q] = nd; }
            i1 = e;
        } else {
            i1 += 1;
        }
    }

    // I1 and I2: the implicit levels.
    for i in 0..len {
        let c = t[i];
        var l = sl;
        if sl % 2 == 0 {
            if c == BIDI_R {
                l = sl + 1;
            } else if c == BIDI_AN || c == BIDI_EN {
                l = sl + 2;
            }
        } else if c == BIDI_L || c == BIDI_EN || c == BIDI_AN {
            l = sl + 1;
        }
        lev[sq[i]] = l;
    }
}

// The levels of one paragraph. cls holds the class of each code point,
// and brk holds the bracket code of each. dir is a BIDI_DIR constant.
// lev receives one level per code point, or -1 for a removed one. The
// call returns the level of the paragraph.
fn bd_core(cls: const i64[:], brk: const i64[:], dir: i64, lev: i64[>..]&) -> i64 {
    let n = cls.len;
    lev.clear();
    if n == 0 { return 0; }

    // BD9: the matching isolate initiator and PDI.
    var mt: i64[>..] = [];
    bd_fill(mt, n, -1);
    var stk: i64[>..] = [];
    bd_fill(stk, n, 0);
    var sp = 0;
    for i in 0..n {
        let c = cls[i];
        if bd_is_isolate_init(c) {
            stk[sp] = i;
            sp += 1;
        } else if c == BIDI_PDI && sp > 0 {
            sp -= 1;
            let j = stk[sp];
            mt[j] = i;
            mt[i] = j;
        }
    }

    // fs[i] is the first strong letter at or after i that no isolate
    // hides. The first strong letter of a paragraph or of an isolate
    // comes from one read of this table.
    var fs: i64[>..] = [];
    bd_fill(fs, n + 1, n);
    var k = n;
    while k > 0 {
        k -= 1;
        let c = cls[k];
        if c == BIDI_L || c == BIDI_R || c == BIDI_AL {
            fs[k] = k;
        } else if bd_is_isolate_init(c) {
            if mt[k] >= 0 { fs[k] = fs[mt[k] + 1]; } else { fs[k] = n; }
        } else {
            fs[k] = fs[k + 1];
        }
    }

    // P2 and P3.
    var para = 0;
    if dir == BIDI_DIR_RTL {
        para = 1;
    } else if dir == BIDI_DIR_AUTO {
        let r = fs[0];
        if r < n && cls[r] != BIDI_L { para = 1; }
    }

    // X1 to X8: the explicit levels, and the classes that an override
    // changes.
    var cl: i64[>..] = [];
    for i in 0..n { cl.push(cls[i]); }
    var el: i64[>..] = [];
    bd_fill(el, n, 0);
    var slv: i64[>..] = [];
    var sov: i64[>..] = [];
    var siso: i64[>..] = [];
    bd_fill(slv, BD_STATUS_SIZE, 0);
    bd_fill(sov, BD_STATUS_SIZE, 0);
    bd_fill(siso, BD_STATUS_SIZE, 0);
    var top = 0;
    slv[0] = para;
    var oi = 0;   // overflow isolates
    var oe = 0;   // overflow embeddings
    var vi = 0;   // valid isolates
    for i in 0..n {
        let c = cls[i];
        if c == BIDI_RLE || c == BIDI_LRE || c == BIDI_RLO || c == BIDI_LRO {
            el[i] = BD_REMOVED;
            let nl = bd_next_level(slv[top], c == BIDI_RLE || c == BIDI_RLO);
            if nl <= BD_MAX_DEPTH && oi == 0 && oe == 0 {
                top += 1;
                slv[top] = nl;
                siso[top] = 0;
                sov[top] = 0;
                if c == BIDI_LRO { sov[top] = 1; }
                if c == BIDI_RLO { sov[top] = 2; }
            } else if oi == 0 {
                oe += 1;
            }
        } else if bd_is_isolate_init(c) {
            el[i] = slv[top];
            bd_override(cl, i, sov[top]);
            var rtl = c == BIDI_RLI;
            if c == BIDI_FSI {
                let r = fs[i + 1];
                var lim = n;
                if mt[i] >= 0 { lim = mt[i]; }
                rtl = r < lim && cls[r] != BIDI_L;
            }
            let nl = bd_next_level(slv[top], rtl);
            if nl <= BD_MAX_DEPTH && oi == 0 && oe == 0 {
                vi += 1;
                top += 1;
                slv[top] = nl;
                siso[top] = 1;
                sov[top] = 0;
            } else {
                oi += 1;
            }
        } else if c == BIDI_PDI {
            if oi > 0 {
                oi -= 1;
            } else if vi > 0 {
                oe = 0;
                while siso[top] == 0 { top -= 1; }
                top -= 1;
                vi -= 1;
            }
            el[i] = slv[top];
            if sov[top] == 1 { cl[i] = BIDI_L; }
            if sov[top] == 2 { cl[i] = BIDI_R; }
        } else if c == BIDI_PDF {
            el[i] = BD_REMOVED;
            // Rule X7: an overflow isolate count above zero stops the
            // rule. Otherwise the overflow embedding count falls by one.
            if oi == 0 {
                if oe > 0 {
                    oe -= 1;
                } else if siso[top] == 0 && top >= 1 {
                    top -= 1;
                }
            }
        } else if c == BIDI_B {
            el[i] = para;
        } else if c == BIDI_BN {
            el[i] = BD_REMOVED;
        } else {
            el[i] = slv[top];
            bd_override(cl, i, sov[top]);
        }
    }

    // X9 and X10: the kept code points, the level runs and the isolating
    // run sequences.
    var kp: i64[>..] = [];
    var kidx: i64[>..] = [];
    bd_fill(kidx, n, -1);
    for i in 0..n {
        if el[i] != BD_REMOVED {
            kidx[i] = kp.len;
            kp.push(i);
        }
    }
    let m = kp.len;
    // The end of the level run of each code point, and the start of it.
    var ren: i64[>..] = [];
    var rst: i64[>..] = [];
    bd_fill(ren, m, 0);
    bd_fill(rst, m, 0);
    var j = 0;
    while j < m {
        var e = j + 1;
        while e < m && el[kp[e]] == el[kp[j]] { e += 1; }
        for q in j..e {
            rst[q] = j;
            ren[q] = e;
        }
        j = e;
    }

    // The levels start as the explicit ones. The rules I1 and I2 raise
    // them, one sequence at a time, and read the explicit ones only.
    for i in 0..n { lev.push(el[i]); }

    var sq: i64[>..] = [];
    var t: i64[>..] = [];
    var pairat: i64[>..] = [];
    var bs_id: i64[>..] = [];
    var bs_pos: i64[>..] = [];
    j = 0;
    while j < m {
        let next_run = ren[j];
        let first = kp[j];
        // A run that starts with the PDI of an isolate whose initiator
        // ends a run continues that run's sequence.
        var cont = false;
        if cls[first] == BIDI_PDI && mt[first] >= 0 {
            let ji = kidx[mt[first]];
            if ji >= 0 && ren[ji] == ji + 1 { cont = true; }
        }
        if !cont {
            sq.clear();
            var cj = j;
            var more = true;
            while more {
                for q in cj..ren[cj] { sq.push(kp[q]); }
                more = false;
                let lastp = kp[ren[cj] - 1];
                if bd_is_isolate_init(cls[lastp]) && mt[lastp] >= 0 {
                    let pj = kidx[mt[lastp]];
                    if pj >= 0 && rst[pj] == pj {
                        cj = pj;
                        more = true;
                    }
                }
            }
            let sl = el[sq[0]];
            // The class before the sequence and the class after it give
            // the start and the end of the sequence.
            var before = para;
            if j > 0 { before = el[kp[j - 1]]; }
            var after = para;
            let lastq = sq[sq.len - 1];
            if !bd_is_isolate_init(cls[lastq]) {
                let jl = kidx[lastq];
                if jl + 1 < m { after = el[kp[jl + 1]]; }
            }
            var sos = bd_level_dir(bd_edge(before, sl));
            var eos = bd_level_dir(bd_edge(after, sl));
            t.clear();
            for q in 0..sq.len { t.push(cl[sq[q]]); }
            bd_run(t, pairat, bs_id, bs_pos, sq[..], cls, brk, lev, sl, sos, eos);
        }
        j = next_run;
    }

    return para;
}

// Rule L1 for a whole paragraph that is one line: a separator, and the
// white space before a separator or at the end of the line, take the
// paragraph level. The levels are the levels before L1. A code point
// that rule X9 removes keeps the level -1.
fn bd_l1(cls: const i64[:], lev: i64[>..]&, para: i64) {
    var zone = true;
    var k = cls.len;
    while k > 0 {
        k -= 1;
        let c = cls[k];
        if c == BIDI_S || c == BIDI_B {
            lev[k] = para;
            zone = true;
        } else if c == BIDI_WS || bd_is_isolate_init(c) || c == BIDI_PDI {
            if zone { lev[k] = para; }
        } else if !bd_is_removed(c) {
            zone = false;
        }
    }
}

// The scan of a text. It decodes the text once. It fills the code
// points, the classes, the bracket data and the byte offset of each code
// point. The offsets hold one more value, the length of the text. The
// call returns a fault code and the offset of a bad byte.
fn bd_scan(cps: i64[>..]&, cls: i64[>..]&, brk: i64[>..]&, offs: i64[>..]&,
           s: const u8[:]) -> i64, i64 {
    cps.clear();
    cls.clear();
    brk.clear();
    offs.clear();
    var at: i64 = 0;
    while at < s.len {
        let cp, n = decode_at(s, at);
        if cp < 0 { return ERR_BAD_UTF8, at; }
        let c = bidi_class(cp);
        cps.push(cp);
        cls.push(c);
        offs.push(at);
        if c == BIDI_ON { brk.push(bd_bracket(cp)); } else { brk.push(0); }
        at += n;
    }
    offs.push(s.len);
    return OK, -1;
}

// The paragraph split (rule P1). out receives the start and the limit of
// each paragraph. A code point of class B ends a paragraph and stays in
// it. A CR followed by LF is one terminator. A final separator opens no
// paragraph.
fn bd_split(out: i64[>..]&, cps: const i64[:], cls: const i64[:]) {
    out.clear();
    let n = cls.len;
    var a = 0;
    while a < n {
        var b = a;
        while b < n && cls[b] != BIDI_B { b += 1; }
        if b < n {
            if cps[b] == 0x0D && b + 1 < n && cps[b + 1] == 0x0A { b += 1; }
            b += 1;
        }
        out.push(a);
        out.push(b);
        a = b;
    }
}

// The levels of one paragraph before rule L1, and the paragraph level.
// A paragraph that holds only separators needs no run of the core. Its
// code points take the paragraph level.
fn bd_para_levels(lev: i64[>..]&, cls: const i64[:],
                  brk: const i64[:], a: i64, b: i64, dir: i64) -> i64 {
    if b - a <= 2 {
        var only = true;
        for k in a..b {
            if cls[k] != BIDI_B { only = false; }
        }
        if only {
            var para = 0;
            if dir == BIDI_DIR_RTL { para = 1; }
            lev.clear();
            for k in a..b { lev.push(para); }
            return para;
        }
    }
    return bd_core(cls[a..b], brk[a..b], dir, lev);
}

// The embedding level of each code point of the UTF-8 text s. out is
// cleared first and receives one level per code point. A code point that
// rule X9 removes gets the level -1. dir is BIDI_DIR_LTR, BIDI_DIR_RTL or
// BIDI_DIR_AUTO. The text splits into paragraphs, and each paragraph
// takes its own level. A CR followed by LF is one terminator. The call
// returns a fault code and the level of the first paragraph. A fault
// leaves out empty.
fn bidi_levels(out: i64[>..]&, s: const u8[:], dir: i64) -> i64, i64 {
    out.clear();
    if dir < 0 || dir > 2 { return ERR_BAD_ARG, 0; }
    if s.len > MAX_INPUT { return ERR_TOO_LONG, 0; }
    var cps: i64[>..] = [];
    var cls: i64[>..] = [];
    var brk: i64[>..] = [];
    var offs: i64[>..] = [];
    let code, _ = bd_scan(cps, cls, brk, offs, s);
    if code != OK { return code, 0; }
    var cuts: i64[>..] = [];
    bd_split(cuts, cps[..], cls[..]);
    var first = 0;
    var plev: i64[>..] = [];
    var p = 0;
    while p < cuts.len {
        let a = cuts[p];
        let b = cuts[p + 1];
        let pl = bd_para_levels(plev, cls[..], brk[..], a, b, dir);
        bd_l1(cls[a..b], plev, pl);
        if a == 0 { first = pl; }
        for q in 0..plev.len { out.push(plev[q]); }
        p += 2;
    }
    return OK, first;
}

// Rule L2: reverses the runs of out. out holds indexes into levels.
// A run is a stretch of indexes with levels at or above one level. The
// loop runs from the highest level down to the lowest odd level, so it
// makes at most 126 passes.
fn bd_reverse(out: i64[>..]&, levels: const i64[:], maxl: i64, min_odd: i64) {
    var lvl = maxl;
    while lvl >= min_odd {
        var i = 0;
        while i < out.len {
            if levels[out[i]] >= lvl {
                var e = i;
                while e < out.len && levels[out[e]] >= lvl { e += 1; }
                var lo = i;
                var hi = e - 1;
                while lo < hi {
                    let tmp = out[lo];
                    out[lo] = out[hi];
                    out[hi] = tmp;
                    lo += 1;
                    hi -= 1;
                }
                i = e;
            } else {
                i += 1;
            }
        }
        lvl -= 1;
    }
}

// The visual order of a line (rule L2). levels holds the level of each
// code point of the line, as bidi_levels gives them. out is cleared first
// and receives the index of each code point, in the order that a reader
// sees them from left to right. A code point of level -1 stays out. A
// level below -1 or above 126 gives ERR_BAD_ARG.
fn bidi_order(out: i64[>..]&, levels: const i64[:]) -> i64 {
    out.clear();
    if levels.len > MAX_INPUT { return ERR_TOO_LONG; }
    var maxl = 0;
    var min_odd = BD_MAX_DEPTH + 2;
    // The levels are read before anything is written, so a fault leaves
    // the buffer of the caller empty.
    for i in 0..levels.len {
        let l = levels[i];
        if l < BD_REMOVED || l > BD_MAX_DEPTH + 1 { return ERR_BAD_ARG; }
        if l == BD_REMOVED { continue; }
        if l > maxl { maxl = l; }
        if l % 2 == 1 && l < min_odd { min_odd = l; }
    }
    for i in 0..levels.len {
        if levels[i] != BD_REMOVED { out.push(i); }
    }
    bd_reverse(out, levels, maxl, min_odd);
    return OK;
}
