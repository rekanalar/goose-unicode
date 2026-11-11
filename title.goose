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
fn push_title_locale(out: u8[>..]&, cp: i64, locale: i64) {
    if is_turkic(locale) && cp == 0x69 {
        push_utf8(out, 0x130);
        return;
    }
    push_title(out, cp);
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
    var at: i64 = 0;
    while at < s.len {
        let code, end = word_next(s, at);
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
