// Title case, by the algorithm of the Unicode standard. The text splits
// into words at the word boundaries of the text segmentation standard.
// The first cased character of a word takes the title case mapping. The
// rest of the word takes the full lower case, with the final sigma rule.
// A word with no cased character stays as it is. One pass over the text
// reads each code point once, so the time is linear. A code point grows
// to three code points at most, so the result of a text of MAX_INPUT
// bytes stays below MAX_OUTPUT and needs no check.
namespace unicode;

import std;

// Writes the title case mapping of the code point under the locale. A code
// point with no entry maps to itself. Turkish and Azerbaijani map i to U+0130.
// Armenian maps the ligature U+0587 to U+0535 U+057E.
fn push_title_locale(out: u8[>..]&, cp: i64, locale: i64) {
    if is_turkic(locale) && cp == 0x69 {
        push_utf8(out, 0x130);
        return;
    }
    if locale == LOCALE_HY && cp == 0x587 {
        push_utf8(out, 0x535);
        push_utf8(out, 0x57E);
        return;
    }
    push_title(out, cp);
}

// The Dutch ij rule. The first cased character of a word titled to I or to
// an I with acute, and the byte offset at is just after it. When the digraph
// ij follows, in one of the forms of the ICU library, the j takes the title
// case too. The forms are i j, i acute j acute, and i-acute j acute with
// the precomposed letter. The j needs its own acute when the i had one. A
// combining mark after the digraph blocks the rule. Writes the rest of the
// digraph and returns the offset after it, or returns -1 and writes nothing.
fn dutch_ij(out: u8[>..]&, s: const u8[:], at: i64, end: i64, first: i64) -> i64 {
    if !is_dutch_i(first) { return -1; }
    if at >= end { return -1; }
    let c2, n2 = decode_at(s, at);
    if c2 < 0 { return -1; }
    var acute = first == 0xED || first == 0xCD;
    var acute_first = false;
    var j = c2;
    var p = at + n2;
    if !acute && c2 == 0x301 {
        acute = true;
        acute_first = true;
        if p >= end { return -1; }
        let c3, n3 = decode_at(s, p);
        if c3 < 0 { return -1; }
        j = c3;
        p += n3;
    }
    if j != 0x6A && j != 0x4A { return -1; }
    if acute {
        if p >= end { return -1; }
        let c4, n4 = decode_at(s, p);
        if c4 != 0x301 { return -1; }
        p += n4;
    }
    if p < end {
        let c5, _ = decode_at(s, p);
        if c5 >= 0 && category_group(c5) == GROUP_MARK { return -1; }
    }
    if acute_first { push_utf8(out, 0x301); }
    push_utf8(out, 0x4A);
    if acute { push_utf8(out, 0x301); }
    return p;
}

// True when the code point starts the Dutch digraph: a plain i in its three
// forms, or an i with an acute in its two forms.
fn is_dutch_i(cp: i64) -> bool {
    return cp == 0x49 || cp == 0x69 || cp == 0x131 || cp == 0xCD || cp == 0xED;
}

// Writes the title case mapping of the code point. A code point with no
// entry maps to itself.
fn push_title(out: u8[>..]&, cp: i64) {
    let k = find_exact(TITLE_CP[..], cp);
    if k < 0 {
        push_utf8(out, cp);
        return;
    }
    for j in TITLE_OFF[k]..TITLE_OFF[k + 1] { push_utf8(out, TITLE_POOL[j]); }
}

// Writes the title case mapping of one code point into the buffer of the
// caller, in UTF-8. A surrogate, a negative value or a value above
// U+10FFFF gives ERR_BAD_CODEPOINT and leaves the buffer empty.
fn titlecase_cp(out: u8[>..]&, cp: i64) -> i64 {
    out.clear();
    if !scalar_ok(cp) { return ERR_BAD_CODEPOINT; }
    push_title(out, cp);
    return OK;
}

// Writes the title case of the text s to out. Returns a fault code and
// the offset of the first bad byte, or OK and -1.
fn to_title(out: u8[>..]&, s: const u8[:]) -> i64, i64 {
    return to_title_locale(out, s, LOCALE_ROOT);
}

// Writes the title case of the text s under the rules of the locale. The
// word rules do not change with the locale. The faults are those of
// to_upper_locale.
fn to_title_locale(out: u8[>..]&, s: const u8[:], locale: i64) -> i64, i64 {
    out.clear();
    if !locale_ok(locale) { return ERR_BAD_ARG, -1; }
    if s.len > MAX_INPUT { return ERR_TOO_LONG, -1; }
    var br: i64[>..] = [];
    let bcode = word_all_breaks(br, s, SEG_DICTIONARY);
    if bcode != OK { return bcode, -1; }
    var at: i64 = 0;
    var k: i64 = 0;
    while at < s.len {
        var end = s.len;
        if k < br.len { end = br[k]; }
        k += 1;
        var seen = false;
        var i = at;
        while i < end {
            let cp, n = decode_at(s, i);
            if cp < 0 {
                out.clear();
                return ERR_BAD_UTF8, i;
            }
            if !seen && is_cased(cp) {
                seen = true;
                push_title_locale(out, cp, locale);
                if locale == LOCALE_NL && is_dutch_i(cp) {
                    let q = dutch_ij(out, s, i + n, end, cp);
                    if q >= 0 {
                        i = q;
                        continue;
                    }
                }
            } else if seen {
                push_lower_full(out, s, i, n, cp, locale);
            } else {
                push_utf8(out, cp);
            }
            i += n;
        }
        at = end;
    }
    return OK, -1;
}
