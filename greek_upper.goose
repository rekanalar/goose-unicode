// The Greek upper case, by the rules of the ICU library.
//
// Greek text in capitals loses the accents of its letters. A vowel keeps
// its dialytika, an iota subscript becomes a spacing capital iota, and an
// iota or ypsilon that follows an accented vowel gains a dialytika. The
// word "or", a capital eta with an accent that stands alone, keeps its
// tonos. The walk holds a small state: whether a cased letter came before,
// and whether the vowel before held an accent. Each code point is read
// once. The scan for a cased letter after an eta runs only for an eta that
// does not follow a cased letter, so the time stays linear.
namespace unicode;

import std;

const GREEK_HAS_VOWEL: i64 = 0x1000;
const GREEK_HAS_YPOG: i64 = 0x2000;
const GREEK_HAS_ACCENT: i64 = 0x4000;
const GREEK_HAS_DIALYTIKA: i64 = 0x8000;
const GREEK_HAS_COMB_DIALYTIKA: i64 = 0x10000;
const GREEK_EITHER_DIALYTIKA: i64 = 0x18000;
const GREEK_HAS_DROP: i64 = 0x20000;

const GREEK_AFTER_CASED: i64 = 1;
const GREEK_AFTER_COMB_ACCENT: i64 = 2;
const GREEK_AFTER_TABLE_ACCENT: i64 = 4;
const GREEK_AFTER_ACCENT: i64 = GREEK_AFTER_COMB_ACCENT | GREEK_AFTER_TABLE_ACCENT;

// The letter data of a code point: the upper case in the low ten bits and
// the flags above. A code point that no Greek rule covers gives 0.
fn greek_letter_data(cp: i64) -> i64 {
    if cp < 0x370 || (cp > 0x3FF && cp < 0x1F00) { return 0; }
    if cp <= 0x3FF { return GREEK_D0370[cp - 0x370]; }
    if cp <= 0x1FFF { return GREEK_D1F00[cp - 0x1F00]; }
    if cp == 0x2126 { return 0x3A9 | GREEK_HAS_VOWEL; }
    return 0;
}

// The flags of a combining mark that follows a Greek letter. A mark that
// is no Greek diacritic gives 0.
fn greek_mark_data(cp: i64) -> i64 {
    if cp == 0x300 || cp == 0x301 || cp == 0x342 || cp == 0x302 || cp == 0x303 || cp == 0x311 {
        return GREEK_HAS_ACCENT;
    }
    if cp == 0x308 { return GREEK_HAS_COMB_DIALYTIKA; }
    if cp == 0x344 { return GREEK_HAS_COMB_DIALYTIKA | GREEK_HAS_ACCENT; }
    if cp == 0x345 { return GREEK_HAS_YPOG; }
    // Macron, breve, the two commas above and the koronis: dropped, no flag.
    if cp == 0x304 || cp == 0x306 || cp == 0x313 || cp == 0x314 || cp == 0x343 { return GREEK_HAS_DROP; }
    return 0;
}

// The Greek upper case of the text. Returns a fault code and the offset of
// the first bad byte, or OK and -1. The function checks the length of the
// text itself, so a caller that reaches it directly gets the same bound.
fn greek_upper(out: u8[>..]&, s: const u8[:]) -> i64, i64 {
    out.clear();
    if s.len > MAX_INPUT { return ERR_TOO_LONG, -1; }
    var state: i64 = 0;
    var i: i64 = 0;
    while i < s.len {
        let cp, n = decode_at(s, i);
        if cp < 0 {
            out.clear();
            return ERR_BAD_UTF8, i;
        }
        var next = i + n;
        var next_state: i64 = 0;
        if is_ignorable(cp) {
            next_state = state & GREEK_AFTER_CASED;
        } else if is_cased(cp) {
            next_state = GREEK_AFTER_CASED;
        }
        var data = greek_letter_data(cp);
        if data > 0 {
            var upper = data & 0x3FF;
            // A vowel after an accented vowel gains the dialytika of the
            // form that the accent had.
            if (data & GREEK_HAS_VOWEL) != 0 && (state & GREEK_AFTER_ACCENT) != 0 && (upper == 0x399 || upper == 0x3A5) {
                data |= if (state & GREEK_AFTER_TABLE_ACCENT) != 0 { GREEK_HAS_DIALYTIKA } else { GREEK_HAS_COMB_DIALYTIKA };
            }
            var ypog: i64 = if (data & GREEK_HAS_YPOG) != 0 { 1 } else { 0 };
            let table_accent = (data & GREEK_HAS_ACCENT) != 0;
            while next < s.len {
                let mc, mn = decode_at(s, next);
                if mc < 0 { break; }
                let md = greek_mark_data(mc);
                if md == 0 { break; }
                data |= md;
                if (md & GREEK_HAS_YPOG) != 0 { ypog += 1; }
                next += mn;
            }
            let va = GREEK_HAS_VOWEL | GREEK_HAS_ACCENT;
            if (data & (va | GREEK_HAS_DIALYTIKA)) == va {
                next_state |= if table_accent { GREEK_AFTER_TABLE_ACCENT } else { GREEK_AFTER_COMB_ACCENT };
            }
            var add_tonos = false;
            if upper == 0x397 && (data & GREEK_HAS_ACCENT) != 0 && ypog == 0
                && (state & GREEK_AFTER_CASED) == 0 && !cased_follows(s, next) {
                // The word "or" keeps its tonos.
                if table_accent { upper = 0x389; } else { add_tonos = true; }
            } else if (data & GREEK_HAS_DIALYTIKA) != 0 {
                let precomposed = if upper == 0x399 { 0x3AA } else if upper == 0x3A5 { 0x3AB } else { 0 };
                if precomposed != 0 {
                    upper = precomposed;
                    data &= ~GREEK_EITHER_DIALYTIKA;
                }
            }
            push_utf8(out, upper);
            if (data & GREEK_EITHER_DIALYTIKA) != 0 { push_utf8(out, 0x308); }
            if add_tonos { push_utf8(out, 0x301); }
            while ypog > 0 {
                push_utf8(out, 0x399);
                ypog -= 1;
            }
        } else {
            push_upper_full(out, cp);
        }
        // The guard for a future table. A Greek letter grows the text by at
        // most two bytes, so the check cannot fail today.
        if out.len > MAX_OUTPUT {
            out.clear();
            return ERR_TOO_LONG, -1;
        }
        i = next;
        state = next_state;
    }
    return OK, -1;
}
