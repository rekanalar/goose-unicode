// Sentence segments, by the sentence rules of the Unicode text
// segmentation standard. The state of one segment holds a few numbers. A
// full stop that a lower case letter may follow reads ahead. The read
// runs once for each full stop and stops at the next terminator, so the
// reads of one text never overlap.
namespace unicode;

import std;

// The state of the segment that is being read.
struct SentenceState {
    p1: i64,      // the class of the last group, -1 before the first code point
    raw: i64,     // the class of the last code point
    phase: i64,   // 1 after a terminator and closers, 2 after spaces too, else 0
    aterm: bool,  // the terminator was a full stop
    upper_lower: bool,   // a letter with case stood before the full stop
    ahead: i64,   // the read ahead after the full stop: 0 not made, 1 a lower case letter follows, 2 not
}

// The class of a code point. A bad byte gets the class SB_BAD, which
// breaks on both sides, so it forms a segment of its own.
fn sentence_class(cp: i64) -> i64 {
    if cp < 0 { return SB_BAD; }
    return SP_VAL[last_at_or_below(SP_START[..], cp)];
}

fn sentence_para(c: i64) -> bool {
    return c == SB_SEP || c == SB_CR || c == SB_LF;
}

// True when a lower case letter follows, past the code points that are no
// letter, no terminator and no separator. i is the start of the first
// code point after the terminator and c is its class.
fn sentence_lower_ahead(s: const u8[:], i0: i64, c0: i64) -> bool {
    var c = c0;
    var i = i0;
    let _, n0 = decode_at(s, i0);
    var n = n0;
    loop {
        if c == SB_LOWER { return true; }
        if c == SB_OLETTER || c == SB_UPPER || sentence_para(c) || c == SB_STERM || c == SB_ATERM { return false; }
        i += n;
        if i >= s.len { return false; }
        let cp, n1 = decode_at(s, i);
        c = sentence_class(cp);
        n = n1;
    }
}

// True when the code point with class b at byte i joins the sentence.
fn sentence_joins(s: const u8[:], i: i64, st: SentenceState&, b: i64) -> bool {
    let raw = st.raw;
    if raw == SB_CR && b == SB_LF { return true; }
    if sentence_para(raw) || raw == SB_BAD || b == SB_BAD { return false; }
    if b == SB_EXTEND || b == SB_FORMAT { return true; }
    let a = st.p1;
    if a == SB_ATERM && b == SB_NUMERIC { return true; }
    if a == SB_ATERM && st.upper_lower && b == SB_UPPER { return true; }
    if st.phase == 0 { return true; }
    if st.aterm {
        // The read from any closer or space ends at the same code point, so it runs once.
        if st.ahead == 0 { st.ahead = 2; if sentence_lower_ahead(s, i, b) { st.ahead = 1; } }
        if st.ahead == 1 { return true; }
    }
    if b == SB_SCONTINUE || b == SB_STERM || b == SB_ATERM { return true; }
    if st.phase == 1 && (b == SB_CLOSE || b == SB_SP || sentence_para(b)) { return true; }
    if st.phase == 2 && (b == SB_SP || sentence_para(b)) { return true; }
    return false;
}

// Adds a code point of class b to the state.
fn sentence_take(st: SentenceState&, b: i64) {
    st.raw = b;
    if st.p1 >= 0 && (b == SB_EXTEND || b == SB_FORMAT) { return; }
    if b == SB_ATERM { st.upper_lower = st.p1 == SB_UPPER || st.p1 == SB_LOWER; }
    if b == SB_ATERM || b == SB_STERM {
        st.phase = 1;
        st.aterm = b == SB_ATERM;
        st.ahead = 0;
    } else if st.phase == 1 && b == SB_CLOSE {
        // A closer stays in the phase of the terminator.
    } else if st.phase >= 1 && b == SB_SP {
        st.phase = 2;
    } else {
        st.phase = 0;
    }
    st.p1 = b;
}

// Finds the sentence that starts at byte at. Returns a fault code and the
// end of the sentence. The end is always above at. ERR_BAD_ARG when at is
// outside the text, ERR_TOO_LONG when s is above MAX_INPUT.
fn sentence_next(s: const u8[:], at: i64) -> i64, i64 {
    if s.len > MAX_INPUT { return ERR_TOO_LONG, at; }
    if at < 0 || at >= s.len { return ERR_BAD_ARG, at; }
    var st = SentenceState { p1: -1, raw: -1, phase: 0, aterm: false, upper_lower: false, ahead: 0 };
    let cp0, n0 = decode_at(s, at);
    sentence_take(st, sentence_class(cp0));
    var i = at + n0;
    while i < s.len {
        let cp, n = decode_at(s, i);
        let b = sentence_class(cp);
        if !sentence_joins(s, i, st, b) { break; }
        sentence_take(st, b);
        i += n;
    }
    return OK, i;
}

// Counts the sentences of s. Returns a fault code and the count.
fn sentence_count(s: const u8[:]) -> i64, i64 {
    if s.len > MAX_INPUT { return ERR_TOO_LONG, 0; }
    var count: i64 = 0;
    var at: i64 = 0;
    while at < s.len {
        let code, end = sentence_next(s, at);
        at = end;
        count += 1;
    }
    return OK, count;
}

// Writes the start offset of every sentence of s to out. out is cleared
// first.
fn sentence_offsets(out: i64[>..]&, s: const u8[:]) -> i64 {
    out.clear();
    if s.len > MAX_INPUT { return ERR_TOO_LONG; }
    var at: i64 = 0;
    while at < s.len {
        out.push(at);
        let code, end = sentence_next(s, at);
        at = end;
    }
    return OK;
}
