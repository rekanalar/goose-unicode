// The four normalization forms.
//
// The work runs in three passes over a buffer of code points. The first
// pass decomposes every code point with the complete decompositions of
// the tables, so no pass recurses. The second pass puts the combining
// marks in canonical order. The third pass composes the pairs again for
// the composed forms.
namespace unicode;

import std;

const S_BASE: i64 = 0xAC00;
const L_BASE: i64 = 0x1100;
const V_BASE: i64 = 0x1161;
const T_BASE: i64 = 0x11A7;
const L_COUNT: i64 = 19;
const V_COUNT: i64 = 21;
const T_COUNT: i64 = 28;
const N_COUNT: i64 = 588;
const S_COUNT: i64 = 11172;

// Appends the complete decomposition of one code point to dec.
fn decompose_cp(dec: i64[>..]&, cp: i64, compat: bool) {
    if cp < 0xA0 {
        dec.push(cp);
        return;
    }
    if cp >= S_BASE && cp < S_BASE + S_COUNT {
        let s = cp - S_BASE;
        dec.push(L_BASE + s / N_COUNT);
        dec.push(V_BASE + (s % N_COUNT) / T_COUNT);
        if s % T_COUNT != 0 { dec.push(T_BASE + s % T_COUNT); }
        return;
    }
    if compat {
        let k = find_exact(KDEC_CP[..], cp);
        if k >= 0 {
            for j in KDEC_OFF[k]..KDEC_OFF[k + 1] { dec.push(KDEC_POOL[j]); }
            return;
        }
    }
    let d = find_exact(DEC_CP[..], cp);
    if d >= 0 {
        for j in DEC_OFF[d]..DEC_OFF[d + 1] { dec.push(DEC_POOL[j]); }
        return;
    }
    dec.push(cp);
}

// Sorts v[a..b] by combining class. The sort is stable. A short run uses
// insertion sort. A long run uses a counting sort, so a hostile run of
// marks cannot take quadratic time.
fn sort_run(v: i64[>..]&, a: i64, b: i64) {
    if b - a <= 32 {
        for i in a + 1..b {
            let x = v[i];
            let cx = combining_class(x);
            var j = i - 1;
            while j >= a && combining_class(v[j]) > cx {
                v[j + 1] = v[j];
                j -= 1;
            }
            v[j + 1] = x;
        }
        return;
    }
    var start: i64[>..] = [];
    for k in 0..257 { start.push(0); }
    var cls: i64[>..] = [];
    for i in a..b {
        let c = combining_class(v[i]);
        cls.push(c);
        start[c + 1] += 1;
    }
    for k in 1..257 { start[k] += start[k - 1]; }
    var tmp: i64[>..] = [];
    for i in a..b { tmp.push(0); }
    for i in a..b {
        let c = cls[i - a];
        tmp[start[c]] = v[i];
        start[c] += 1;
    }
    for i in a..b { v[i] = tmp[i - a]; }
}

// Puts the combining marks of every run in canonical order.
fn reorder(v: i64[>..]&) {
    var i: i64 = 0;
    while i < v.len {
        if combining_class(v[i]) == 0 {
            i += 1;
            continue;
        }
        var j = i;
        while j < v.len && combining_class(v[j]) != 0 { j += 1; }
        if j - i > 1 { sort_run(v, i, j); }
        i = j;
    }
}

// The composite of the pair (a, b). -1 when the pair does not compose.
fn compose_pair(a: i64, b: i64) -> i64 {
    if a >= L_BASE && a < L_BASE + L_COUNT && b >= V_BASE && b < V_BASE + V_COUNT {
        return S_BASE + ((a - L_BASE) * V_COUNT + (b - V_BASE)) * T_COUNT;
    }
    if a >= S_BASE && a < S_BASE + S_COUNT && (a - S_BASE) % T_COUNT == 0 && b > T_BASE && b < T_BASE + T_COUNT {
        return a + (b - T_BASE);
    }
    let k = find_exact(COMP_KEY[..], (a << 21) | b);
    if k < 0 { return -1; }
    return COMP_VAL[k];
}

// Composes the pairs of v in place. A mark blocks a pair when a mark
// with a class at or above its own stands between it and the starter.
fn compose(v: i64[>..]&) {
    var w: i64 = 0;
    var starter: i64 = -1;
    var last: i64 = 0;
    for r in 0..v.len {
        let c = v[r];
        let cc = combining_class(c);
        if starter >= 0 && (last < cc || w - 1 == starter) {
            let comp = compose_pair(v[starter], c);
            if comp >= 0 {
                v[starter] = comp;
                continue;
            }
        }
        if cc == 0 { starter = w; }
        last = cc;
        v[w] = c;
        w += 1;
    }
    v.resize(w);
}

// Converts the code points of src to a form. work receives the result.
fn normalize_cps(work: i64[>..]&, src: const i64[:], form: i64) -> i64 {
    work.clear();
    let compat = form == FORM_NFKC || form == FORM_NFKD;
    for k in 0..src.len {
        decompose_cp(work, src[k], compat);
        if work.len > MAX_OUTPUT {
            work.clear();
            return ERR_TOO_LONG;
        }
    }
    reorder(work);
    if form == FORM_NFC || form == FORM_NFKC { compose(work); }
    return OK;
}

// True when every byte of s is ASCII. ASCII text is in all four forms.
fn all_ascii(s: const u8[:]) -> bool {
    for i in 0..s.len { if s[i] >= 0x80 { return false; } }
    return true;
}

// Converts s to a form. out is cleared first. A bad byte gives
// ERR_BAD_UTF8 and the offset of the first bad byte. A result above
// MAX_OUTPUT gives ERR_TOO_LONG. Either fault leaves out empty.
fn normalize(out: u8[>..]&, form: i64, s: const u8[:]) -> i64, i64 {
    out.clear();
    if s.len > MAX_INPUT { return ERR_TOO_LONG, -1; }
    if form < FORM_NFC || form > FORM_NFKD { return ERR_BAD_FORM, -1; }
    if all_ascii(s) {
        out.append(s);
        return OK, -1;
    }
    var src: i64[>..] = [];
    let code, off = utf8_decode(src, s);
    if code != OK { return code, off; }
    var work: i64[>..] = [];
    let c2 = normalize_cps(work, src[..], form);
    if c2 != OK { return c2, -1; }
    let c3 = encode_all(out, work[..]);
    return c3, -1;
}

// The quick check value of a code point: 0 yes, 1 no, 2 maybe.
fn quick_check(form: i64, cp: i64) -> i64 {
    if form == FORM_NFC { return qc_range(QC_NFC_START[..], QC_NFC_END[..], QC_NFC_VAL[..], cp); }
    if form == FORM_NFD { return qc_range(QC_NFD_START[..], QC_NFD_END[..], QC_NFD_VAL[..], cp); }
    if form == FORM_NFKC { return qc_range(QC_NFKC_START[..], QC_NFKC_END[..], QC_NFKC_VAL[..], cp); }
    return qc_range(QC_NFKD_START[..], QC_NFKD_END[..], QC_NFKD_VAL[..], cp);
}

fn qc_range(starts: const i64[:], ends: const i64[:], vals: const i64[:], cp: i64) -> i64 {
    let i = last_at_or_below(starts, cp);
    if i >= 0 && cp <= ends[i] { return vals[i]; }
    return 0;
}

// True when s is already in the form. The answer equals the answer of a
// full conversion: the quick check decides when it can, and the full
// conversion decides the rest. Text that is not well formed UTF-8, text
// above MAX_INPUT and an unknown form give false.
fn is_normalized(form: i64, s: const u8[:]) -> bool {
    if s.len > MAX_INPUT { return false; }
    if form < FORM_NFC || form > FORM_NFKD { return false; }
    var last: i64 = 0;
    var maybe = false;
    var i: i64 = 0;
    while i < s.len {
        let cp, n = decode_at(s, i);
        if cp < 0 { return false; }
        let cc = combining_class(cp);
        if cc != 0 && last > cc { return false; }
        let q = quick_check(form, cp);
        if q == 1 { return false; }
        if q == 2 { maybe = true; }
        last = cc;
        i += n;
    }
    if !maybe { return true; }
    var out: u8[>..] = [];
    let code, off = normalize(out, form, s);
    return code == OK && out == s;
}
