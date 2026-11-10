// Word segments, by the word rules of the Unicode text segmentation
// standard. The state of one segment holds a few numbers, so the split
// needs no stack and no recursion. A rule that needs the code point
// after the next one reads ahead past the marks that join to it. Each
// read belongs to one code point, so the split of a text is linear.
namespace unicode;

import std;

// The state of the segment that is being read.
struct WordState {
    p1: i64,    // the class of the last group, -1 before the first code point
    p2: i64,    // the class of the group before it
    raw: i64,   // the class of the last code point
    ri: i64,    // regional indicators in a row
}

// The packed property of a code point. A bad byte counts as a line
// break, so it forms a segment of its own.
fn word_props(cp: i64) -> i64 {
    if cp < 0 { return WB_NEWLINE; }
    return WP_VAL[last_at_or_below(WP_START[..], cp)];
}

fn word_ignored(c: i64) -> bool {
    return c == WB_EXTEND || c == WB_FORMAT || c == WB_ZWJ;
}

fn word_letter(c: i64) -> bool {
    return c == WB_ALETTER || c == WB_HEBREW_LETTER;
}

fn word_mid_letter(c: i64) -> bool {
    return c == WB_MIDLETTER || c == WB_MIDNUMLET || c == WB_SINGLE_QUOTE;
}

fn word_mid_num(c: i64) -> bool {
    return c == WB_MIDNUM || c == WB_MIDNUMLET || c == WB_SINGLE_QUOTE;
}

// The class of the first code point at or after byte i that no earlier
// mark joins to. -1 at the end of the text.
fn word_ahead(s: const u8[:], i0: i64) -> i64 {
    var i = i0;
    while i < s.len {
        let cp, n = decode_at(s, i);
        let c = word_props(cp) & 31;
        if !word_ignored(c) { return c; }
        i += n;
    }
    return -1;
}

// True when the code point with the packed property p joins the segment.
// after is the byte after that code point.
fn word_joins(s: const u8[:], after: i64, st: WordState&, p: i64) -> bool {
    let b = p & 31;
    let raw = st.raw;
    if raw == WB_CR && b == WB_LF { return true; }
    if raw == WB_CR || raw == WB_LF || raw == WB_NEWLINE { return false; }
    if b == WB_CR || b == WB_LF || b == WB_NEWLINE { return false; }
    if raw == WB_ZWJ && ((p >> 5) & 1) == 1 { return true; }
    if raw == WB_WSEGSPACE && b == WB_WSEGSPACE { return true; }
    if word_ignored(b) { return true; }
    let a = st.p1;
    let p2 = st.p2;
    if word_letter(a) && word_letter(b) { return true; }
    if word_letter(a) && word_mid_letter(b) && word_letter(word_ahead(s, after)) { return true; }
    if word_letter(p2) && word_mid_letter(a) && word_letter(b) { return true; }
    if a == WB_HEBREW_LETTER && b == WB_SINGLE_QUOTE { return true; }
    if a == WB_HEBREW_LETTER && b == WB_DOUBLE_QUOTE && word_ahead(s, after) == WB_HEBREW_LETTER { return true; }
    if p2 == WB_HEBREW_LETTER && a == WB_DOUBLE_QUOTE && b == WB_HEBREW_LETTER { return true; }
    if a == WB_NUMERIC && b == WB_NUMERIC { return true; }
    if word_letter(a) && b == WB_NUMERIC { return true; }
    if a == WB_NUMERIC && word_letter(b) { return true; }
    if p2 == WB_NUMERIC && word_mid_num(a) && b == WB_NUMERIC { return true; }
    if a == WB_NUMERIC && word_mid_num(b) && word_ahead(s, after) == WB_NUMERIC { return true; }
    if a == WB_KATAKANA && b == WB_KATAKANA { return true; }
    if b == WB_EXTENDNUMLET && (word_letter(a) || a == WB_NUMERIC || a == WB_KATAKANA || a == WB_EXTENDNUMLET) { return true; }
    if a == WB_EXTENDNUMLET && (word_letter(b) || b == WB_NUMERIC || b == WB_KATAKANA) { return true; }
    if a == WB_REGIONAL_INDICATOR && b == WB_REGIONAL_INDICATOR && st.ri % 2 == 1 { return true; }
    return false;
}

// Adds the code point with the packed property p to the state. A mark
// that joins to the group before it leaves the group classes alone.
fn word_take(st: WordState&, p: i64) {
    let b = p & 31;
    st.raw = b;
    if st.p1 >= 0 && word_ignored(b) { return; }
    st.p2 = st.p1;
    st.p1 = b;
    if b == WB_REGIONAL_INDICATOR { st.ri += 1; } else { st.ri = 0; }
}

// Finds the segment that starts at byte at. Returns a fault code and the
// end of the segment. The end is always above at. ERR_BAD_ARG when at is
// outside the text, ERR_TOO_LONG when s is above MAX_INPUT.
fn word_next(s: const u8[:], at: i64) -> i64, i64 {
    if s.len > MAX_INPUT { return ERR_TOO_LONG, at; }
    if at < 0 || at >= s.len { return ERR_BAD_ARG, at; }
    var st = WordState { p1: -1, p2: -1, raw: -1, ri: 0 };
    let cp0, n0 = decode_at(s, at);
    word_take(st, word_props(cp0));
    var i = at + n0;
    while i < s.len {
        let cp, n = decode_at(s, i);
        let p = word_props(cp);
        if !word_joins(s, i + n, st, p) { break; }
        word_take(st, p);
        i += n;
    }
    return OK, i;
}

// Counts the segments of s, the spaces and the punctuation too. Returns a
// fault code and the count.
fn word_count(s: const u8[:]) -> i64, i64 {
    if s.len > MAX_INPUT { return ERR_TOO_LONG, 0; }
    var count: i64 = 0;
    var at: i64 = 0;
    while at < s.len {
        let code, end = word_next(s, at);
        at = end;
        count += 1;
    }
    return OK, count;
}

// Writes the start offset of every segment of s to out. out is cleared
// first.
fn word_offsets(out: i64[>..]&, s: const u8[:]) -> i64 {
    out.clear();
    if s.len > MAX_INPUT { return ERR_TOO_LONG; }
    var at: i64 = 0;
    while at < s.len {
        out.push(at);
        let code, end = word_next(s, at);
        at = end;
    }
    return OK;
}

// True when the segment s[start..end] is a word: it holds a letter, a
// number or an ideograph. A run of spaces or punctuation gives false. The
// flag follows the isWordLike flag of Node for a segment of one code
// point. A segment of two connectors, such as "__", counts as a word.
fn is_word_like(s: const u8[:], start: i64, end: i64) -> bool {
    if s.len > MAX_INPUT || start < 0 || end > s.len || start >= end { return false; }
    var connectors: i64 = 0;
    var i = start;
    while i < end {
        let cp, n = decode_at(s, i);
        i += n;
        if cp < 0 { continue; }
        let c = word_props(cp) & 31;
        if c == WB_ALETTER || c == WB_HEBREW_LETTER || c == WB_NUMERIC || c == WB_KATAKANA { return true; }
        if c == WB_EXTENDNUMLET { connectors += 1; }
        let cat = category(cp);
        if (cat >= CAT_LU && cat <= CAT_LO) || cat == CAT_ND || cat == CAT_NL { return true; }
    }
    return connectors >= 2;
}
