// Grapheme clusters, by the rules of the Unicode text segmentation
// standard. The state of one cluster has four numbers, so the split
// needs no stack and no recursion.
namespace unicode;

import std;

// The state of the cluster that is being read.
struct Cluster {
    prev: i64,   // the break class of the last code point
    ri: i64,     // regional indicators in a row
    ep: i64,     // 1 after a pictographic and marks, 2 after the joiner that follows
    incb: i64,   // 1 after a consonant, 2 after a linker that follows it
}

// The packed property of a code point. A bad byte counts as a control,
// so it forms a cluster of its own.
fn grapheme_props(cp: i64) -> i64 {
    if cp < 0 { return GB_CONTROL; }
    return GP_VAL[last_at_or_below(GP_START[..], cp)];
}

// True when the code point with the packed property p joins the cluster.
fn cluster_joins(st: Cluster&, p: i64) -> bool {
    let cur = p & 15;
    let prev = st.prev;
    if prev == GB_CR && cur == GB_LF { return true; }
    if prev == GB_CR || prev == GB_LF || prev == GB_CONTROL { return false; }
    if cur == GB_CR || cur == GB_LF || cur == GB_CONTROL { return false; }
    if prev == GB_L && (cur == GB_L || cur == GB_V || cur == GB_LV || cur == GB_LVT) { return true; }
    if (prev == GB_LV || prev == GB_V) && (cur == GB_V || cur == GB_T) { return true; }
    if (prev == GB_LVT || prev == GB_T) && cur == GB_T { return true; }
    if cur == GB_EXTEND || cur == GB_ZWJ || cur == GB_SPACINGMARK { return true; }
    if prev == GB_PREPEND { return true; }
    if ((p >> 5) & 3) == 1 && st.incb == 2 { return true; }
    if prev == GB_ZWJ && st.ep == 2 && ((p >> 4) & 1) == 1 { return true; }
    if prev == GB_REGIONAL_INDICATOR && cur == GB_REGIONAL_INDICATOR && st.ri % 2 == 1 { return true; }
    return false;
}

// Adds the code point with the packed property p to the state.
fn cluster_take(st: Cluster&, p: i64) {
    let cur = p & 15;
    let is_ep = ((p >> 4) & 1) == 1;
    let incb = (p >> 5) & 3;
    if is_ep {
        st.ep = 1;
    } else if st.ep == 1 && cur == GB_EXTEND {
        st.ep = 1;
    } else if st.ep == 1 && cur == GB_ZWJ {
        st.ep = 2;
    } else {
        st.ep = 0;
    }
    if cur == GB_REGIONAL_INDICATOR { st.ri += 1; } else { st.ri = 0; }
    if incb == 1 {
        st.incb = 1;
    } else if st.incb >= 1 && incb == 2 {
        st.incb = 2;
    } else if st.incb == 0 || incb != 3 {
        st.incb = 0;
    }
    st.prev = cur;
}

// Finds the cluster that starts at byte at. Returns a fault code and
// the end of the cluster. The end is always above at. ERR_BAD_ARG when
// at is outside the text, ERR_TOO_LONG when s is above MAX_INPUT.
fn grapheme_next(s: const u8[:], at: i64) -> i64, i64 {
    if s.len > MAX_INPUT { return ERR_TOO_LONG, at; }
    if at < 0 || at >= s.len { return ERR_BAD_ARG, at; }
    var st = Cluster { .. };
    let cp0, n0 = decode_at(s, at);
    let p0 = grapheme_props(cp0);
    cluster_take(st, p0);
    var i = at + n0;
    while i < s.len {
        let cp, n = decode_at(s, i);
        let p = grapheme_props(cp);
        if !cluster_joins(st, p) { break; }
        cluster_take(st, p);
        i += n;
    }
    return OK, i;
}

// Counts the clusters of s. Returns a fault code and the count.
fn grapheme_count(s: const u8[:]) -> i64, i64 {
    if s.len > MAX_INPUT { return ERR_TOO_LONG, 0; }
    var count: i64 = 0;
    var at: i64 = 0;
    while at < s.len {
        let code, end = grapheme_next(s, at);
        at = end;
        count += 1;
    }
    return OK, count;
}

// Writes the start offset of every cluster of s to out. out is cleared
// first.
fn grapheme_offsets(out: i64[>..]&, s: const u8[:]) -> i64 {
    out.clear();
    if s.len > MAX_INPUT { return ERR_TOO_LONG; }
    var at: i64 = 0;
    while at < s.len {
        out.push(at);
        let code, end = grapheme_next(s, at);
        at = end;
    }
    return OK;
}
