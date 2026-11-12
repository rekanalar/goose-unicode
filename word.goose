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

// The table property of a code point, without the remap of the two
// groups. The property views of the package report this value.
fn word_props_raw(cp: i64) -> i64 {
    if cp < 0 { return WB_NEWLINE; }
    return WP_VAL[last_at_or_below(WP_START[..], cp)];
}

// The packed property of a code point. A bad byte counts as a line
// break, so it forms a segment of its own.
//
// The table holds the plain classes of the standard. Two groups change:
// a letter of a script that writes without spaces between the words has
// the letter class of the rules, so it chains with the letters around
// it. A Han or Hiragana code point has the class WB_CJ, so the rules
// chain it with Hiragana and Katakana. Both groups go to the dictionary
// engines after the rules have found their segments.
fn word_props(cp: i64) -> i64 {
    if cp < 0 { return WB_NEWLINE; }
    let p = WP_VAL[last_at_or_below(WP_START[..], cp)];
    let b = p & 31;
    if b != 0 && b != WB_ALETTER { return p; }
    if b == 0 && line_break_class(cp) == LB_SA { return WB_ALETTER; }
    // The Han and the Hiragana code points start at U+2E80, so a code
    // point below that has neither script.
    if cp < 0x2E80 { return p; }
    let sc = script(cp);
    if sc == DSCRIPT_HAN || sc == DSCRIPT_HIRAGANA { return (p & ~31) | WB_CJ; }
    return p;
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
    // Han, Hiragana and Katakana chain, but the rule for them allows no
    // mark between two letters: a mark ends the chain, except between two
    // Katakana letters.
    if (a == WB_CJ || a == WB_KATAKANA) && (b == WB_CJ || b == WB_KATAKANA) && !word_ignored(raw) { return true; }
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

// The end of the rule segment that starts at byte at. The rules of the
// standard decide, before any dictionary stage runs.
fn word_rule_seg(s: const u8[:], at: i64) -> i64 {
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
    return i;
}

// True when the code point is in the dictionary set of the word rules:
// a code point that needs a complex context, a Han, Hiragana or Katakana
// code point, or a Hangul syllable. Only such a code point asks for a
// break engine.
fn dict_category(cp: i64) -> bool {
    if line_break_class(cp) == LB_SA { return true; }
    if cp >= 0xAC00 && cp <= 0xD7A3 { return true; }
    let sc = script(cp);
    if sc == DSCRIPT_HAN || sc == DSCRIPT_HIRAGANA { return true; }
    return (word_props_raw(cp) & 31) == WB_KATAKANA;
}

// Appends the break offsets that the dictionary engines put inside the
// rule segment [at, end). Every run of engine script letters goes to the
// engine of its script; the offsets come out in ascending order. A rule
// segment of one UTF-16 unit goes to no engine. A code point with no
// engine of its own ends the run that it starts.
fn word_engine_breaks(out: i64[>..]&, s: const u8[:], at: i64, end: i64) {
    // Every code point of a script with an engine starts with a byte of
    // 0xE0 or above, so a segment without such a byte needs no engine.
    var high: bool = false;
    var hb = at;
    while hb < end {
        if s[hb] >= 0xE0 { high = true; break; }
        hb += 1;
    }
    if !high { return; }
    var c: i64[>..] = [];
    var off: i64[>..] = [];
    var i = at;
    var units: i64 = 0;
    while i < end {
        off.push(i);
        let cp, n = decode_at(s, i);
        c.push(cp);
        if cp >= 0x10000 { units += 2; } else { units += 1; }
        i += n;
    }
    off.push(end);
    if units <= 1 { return; }
    var j: i64 = 0;
    while j < c.len {
        let sc = script(c[j]);
        let t = dict_plain_of(c[j]);
        if t >= 0 {
            let start = j;
            var k = j + 1;
            while k < c.len && dict_plain_of(c[k]) == t { k += 1; }
            dict_plain(t, c[start..k], off[start..k + 1], out);
            j = k;
        } else if dict_cj_own(c[j]) || c[j] == 0x30FC || c[j] == 0xFF70
            || c[j] == 0xFF9E || c[j] == 0xFF9F {
            let start = j;
            var k = j + 1;
            while k < c.len && dict_cj_set(c[k]) { k += 1; }
            dict_cj(c[start..k], off[start..k + 1], out);
            j = k;
        } else if dict_category(c[j]) {
            // The code point has no engine. The reference library hands it
            // to a reject engine that reads the whole run of the script of
            // the code point and adds no break, so the next run starts
            // after it.
            j += 1;
            while j < c.len && script(c[j]) == sc { j += 1; }
        } else {
            j += 1;
        }
    }
}

// True when the code point belongs to an engine run. kind is 0 for a
// plain run of one script and 1 for the Han, Hiragana and Katakana set.
fn dict_run_member(kind: i64, trie: i64, cp: i64) -> bool {
    if kind == 0 { return dict_plain_of(cp) == trie; }
    return dict_cj_set(cp);
}

// The byte offset of the code point that starts the engine run around
// at, and the offset of its end. An engine run is a maximal span of code
// points of one plain script trie, or of the Han, Hiragana and Katakana
// set. kind is 0 for a plain run and 1 for the CJK set, trie the plain
// trie. -1, -1 when the code point at at belongs to no engine run.
fn word_run_span(s: const u8[:], at: i64, kind: i64, trie: i64) -> i64, i64 {
    var first = at;
    while first > 0 {
        let cp, n = decode_back(s, first);
        if !dict_run_member(kind, trie, cp) { break; }
        first -= n;
    }
    var last = at;
    var ok = true;
    while ok {
        let cp, n = decode_at(s, last);
        if cp < 0 { ok = false; break; }
        last += n;
        if last >= s.len { ok = false; break; }
        let cp2, n2 = decode_at(s, last);
        if !dict_run_member(kind, trie, cp2) { ok = false; }
    }
    return first, last;
}

// The end of the first segment that starts at byte at. Returns a fault
// code and the end of the segment. The end is always above at.
// ERR_BAD_ARG when at is outside the text, ERR_TOO_LONG when s is above
// MAX_INPUT.
//
// When at points into a run of a script with a word list, the whole run
// goes through its engine and the answer is the first break of the run
// above at. This matches the cached boundaries of the reference library:
// a caller who walks a text from the start sees one split of each run.
// A call at a position inside a rule segment but outside a run restarts
// the rules there, and the splits of the run that follows can differ
// from the split of a walk from the start. The cost of a call inside a
// run grows with the part of the run before at.
fn word_next(s: const u8[:], at: i64) -> i64, i64 {
    if s.len > MAX_INPUT { return ERR_TOO_LONG, at; }
    if at < 0 || at >= s.len { return ERR_BAD_ARG, at; }
    let cp0, n0 = decode_at(s, at);
    var kind: i64 = -1;
    var trie: i64 = -1;
    if cp0 >= 0 {
        if dict_cj_set(cp0) {
            kind = 1;
        } else {
            trie = dict_plain_of(cp0);
            if trie >= 0 { kind = 0; }
        }
    }
    var base = at;
    if kind >= 0 {
        let rs, rf = word_run_span(s, at, kind, trie);
        base = rs;
        // A block of marks at the start of a run is a rule segment of its
        // own when no letter stands before it. The engine sees the
        // letters after the block as a run of their own.
        let c0, m0 = decode_at(s, rs);
        if kind == 0 && c0 >= 0 && word_ignored(word_props_raw(c0) & 31) {
            var glue = false;
            if rs > 0 {
                let pc, pw = decode_back(s, rs);
                let pcls = word_props_raw(pc) & 31;
                if pcls == WB_ALETTER || pcls == WB_HEBREW_LETTER { glue = true; }
            }
            if !glue {
                var mb = rs;
                var mk = true;
                while mk && mb < s.len {
                    let cp, n = decode_at(s, mb);
                    if cp < 0 || !word_ignored(word_props_raw(cp) & 31) {
                        mk = false;
                    } else {
                        mb += n;
                    }
                }
                if at < mb { return OK, mb; }
                base = mb;
            }
        }
    }
    // The base of the run is at or below at, so the rules start at at.
    let end = word_rule_seg(s, at);
    var br: i64[>..] = [];
    word_engine_breaks(br, s, base, end);
    for k in 0..br.len {
        if br[k] > at { return OK, br[k]; }
    }
    return OK, end;
}

// Writes the break offset after every segment to out, without the end
// of the text. out is cleared first. Every rule segment is found once
// and every engine run spans the whole text, so the splits match the
// splits of a left to right walk over the whole text.
fn word_all_breaks(out: i64[>..]&, s: const u8[:]) -> i64 {
    out.clear();
    if s.len > MAX_INPUT { return ERR_TOO_LONG; }
    var br: i64[>..] = [];
    var at: i64 = 0;
    while at < s.len {
        let end = word_rule_seg(s, at);
        br.clear();
        word_engine_breaks(br, s, at, end);
        for k in 0..br.len { out.push(br[k]); }
        if end < s.len { out.push(end); }
        at = end;
    }
    return OK;
}

// Counts the segments of s, the spaces and the punctuation too. Returns a
// fault code and the count.
fn word_count(s: const u8[:]) -> i64, i64 {
    var br: i64[>..] = [];
    let code = word_all_breaks(br, s);
    if code != OK { return code, 0; }
    if s.len == 0 { return OK, 0; }
    return OK, br.len + 1;
}

// Writes the start offset of every segment of s to out. out is cleared
// first.
fn word_offsets(out: i64[>..]&, s: const u8[:]) -> i64 {
    if s.len > MAX_INPUT { out.clear(); return ERR_TOO_LONG; }
    var br: i64[>..] = [];
    let code = word_all_breaks(br, s);
    if code != OK { out.clear(); return code; }
    out.clear();
    if br.len == 0 && s.len == 0 { return OK; }
    out.push(0);
    for k in 0..br.len { out.push(br[k]); }
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
