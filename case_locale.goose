// Locale aware case mapping.
//
// The rows of the Unicode special casing file that name a language: the
// Turkish and Azerbaijani rules for the letter i, and the Lithuanian rules
// for the dot above. Three more rules follow the ICU library: the Greek
// upper case (greek_upper.goose), the Dutch ij title case (title.goose) and
// the Armenian ligature U+0587.
//
// Four conditions of that file read the text around a letter. Each
// condition is a scan that stops at the first character of combining class
// 0 or 230, or at a bad byte. A scan starts at a trigger. A trigger is a
// letter of class 0 or the mark U+0307 of class 230, so the scans of two
// triggers do not overlap and the time stays linear.
namespace unicode;

import std;

const LOCALE_ROOT: i64 = 0;  // no language rule
const LOCALE_TR: i64 = 1;    // Turkish
const LOCALE_AZ: i64 = 2;    // Azerbaijani
const LOCALE_LT: i64 = 3;    // Lithuanian
const LOCALE_EL: i64 = 4;    // Greek
const LOCALE_NL: i64 = 5;    // Dutch
const LOCALE_HY: i64 = 6;    // Armenian

// True when the value is one of the locale constants.
fn locale_ok(locale: i64) -> bool {
    return locale >= LOCALE_ROOT && locale <= LOCALE_HY;
}

fn is_turkic(locale: i64) -> bool {
    return locale == LOCALE_TR || locale == LOCALE_AZ;
}

// The locale of a language tag. The language is the first subtag: two or
// three ASCII letters, then the end of the tag, a hyphen or an underscore.
// The letters match without regard to case. Any other tag gives LOCALE_ROOT.
fn locale_of(tag: const u8[:]) -> i64 {
    var n: i64 = 0;
    var l: i64 = 0;
    while n < tag.len && n < 4 {
        var c = tag[n] as i64;
        if c >= 65 && c <= 90 { c += 32; }
        if c < 97 || c > 122 { break; }
        l = (l << 8) | c;
        n += 1;
    }
    if n < 2 || n > 3 { return LOCALE_ROOT; }
    if n < tag.len && tag[n] != '-' && tag[n] != '_' { return LOCALE_ROOT; }
    if l == 0x7472 || l == 0x747572 { return LOCALE_TR; }  // tr, tur
    if l == 0x617A || l == 0x617A65 { return LOCALE_AZ; }  // az, aze
    if l == 0x6C74 || l == 0x6C6974 { return LOCALE_LT; }  // lt, lit
    if l == 0x656C || l == 0x656C6C { return LOCALE_EL; }  // el, ell
    if l == 0x6E6C || l == 0x6E6C64 { return LOCALE_NL; }  // nl, nld
    if l == 0x6879 || l == 0x687965 { return LOCALE_HY; }  // hy, hye
    return LOCALE_ROOT;
}

// After_Soft_Dotted: a soft dotted letter holds before the byte offset i,
// with no character of class 0 or 230 between.
fn after_soft_dotted(s: const u8[:], i: i64) -> bool {
    var j: i64 = i;
    while j > 0 {
        let cp, len = decode_back(s, j);
        if cp < 0 { return false; }
        j -= len;
        if has_property(cp, PROP_SOFT_DOTTED) { return true; }
        let cc = combining_class(cp);
        if cc == 0 || cc == 230 { return false; }
    }
    return false;
}

// After_I: a capital I holds before the byte offset i, with no character
// of class 0 or 230 between.
fn after_capital_i(s: const u8[:], i: i64) -> bool {
    var j: i64 = i;
    while j > 0 {
        let cp, len = decode_back(s, j);
        if cp < 0 { return false; }
        j -= len;
        if cp == 0x49 { return true; }
        let cc = combining_class(cp);
        if cc == 0 || cc == 230 { return false; }
    }
    return false;
}

// Before_Dot: U+0307 holds at or after the byte offset j, with no
// character of class 0 or 230 between.
fn before_dot(s: const u8[:], j: i64) -> bool {
    var k: i64 = j;
    while k < s.len {
        let cp, len = decode_at(s, k);
        if cp < 0 { return false; }
        if cp == 0x307 { return true; }
        let cc = combining_class(cp);
        if cc == 0 || cc == 230 { return false; }
        k += len;
    }
    return false;
}

// More_Above: a character of class 230 holds at or after the byte offset j,
// with no character of class 0 between.
fn more_above(s: const u8[:], j: i64) -> bool {
    var k: i64 = j;
    while k < s.len {
        let cp, len = decode_at(s, k);
        if cp < 0 { return false; }
        let cc = combining_class(cp);
        if cc == 230 { return true; }
        if cc == 0 { return false; }
        k += len;
    }
    return false;
}

// Writes the upper case of the code point at the byte offset i when a rule
// of the locale holds. Returns false when no rule holds.
fn push_upper_rule(out: u8[>..]&, s: const u8[:], i: i64, cp: i64, locale: i64) -> bool {
    if is_turkic(locale) && cp == 0x69 {
        push_utf8(out, 0x130);
        return true;
    }
    // The Armenian ligature ech yiwn gives two capital letters.
    if locale == LOCALE_HY && cp == 0x587 {
        push_utf8(out, 0x535);
        push_utf8(out, 0x54E);
        return true;
    }
    // The dot above after a soft dotted letter drops in Lithuanian.
    return locale == LOCALE_LT && cp == 0x307 && after_soft_dotted(s, i);
}

// Writes the lower case of the code point at the byte offset i, whose
// sequence holds n bytes, when a rule of the locale holds. Returns false
// when no rule holds.
fn push_lower_rule(out: u8[>..]&, s: const u8[:], i: i64, n: i64, cp: i64, locale: i64) -> bool {
    if is_turkic(locale) {
        if cp == 0x130 {
            push_utf8(out, 0x69);
            return true;
        }
        if cp == 0x49 {
            push_utf8(out, if before_dot(s, i + n) { 0x69 } else { 0x131 });
            return true;
        }
        // The dot above after a capital I joins the letter.
        return cp == 0x307 && after_capital_i(s, i);
    }
    if locale != LOCALE_LT { return false; }
    if cp == 0x49 || cp == 0x4A || cp == 0x12E {
        if !more_above(s, i + n) { return false; }
        push_utf8(out, lower_cp(cp));
        push_utf8(out, 0x307);
        return true;
    }
    if cp == 0xCC || cp == 0xCD || cp == 0x128 {
        push_utf8(out, 0x69);
        push_utf8(out, 0x307);
        push_utf8(out, if cp == 0xCC { 0x300 } else if cp == 0xCD { 0x301 } else { 0x303 });
        return true;
    }
    return false;
}
