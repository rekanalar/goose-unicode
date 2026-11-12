// The restriction levels, the mixed script test and the whole script
// test of the standard, for the defense against look alike identifiers.
//
// The restriction level grades a text by the scripts that it holds. The
// level tells a caller how far a name may drift from one script before
// a reader may mistake it for another. The six levels run from the
// strictest to the loosest. The mixed script test tells whether a text
// mixes scripts in one word. The whole script test tells whether a text
// has a twin in another script.
//
// The steps follow the standard, revision 34. The level of a text that
// mixes Latin and Han is Single Script, because the resolved script set
// holds the writing system Hntl. The ICU library and the Rust crate do
// not apply that rule. They give Highly Restrictive for such a text.
namespace unicode;

import std;

// ---- the levels of the standard ------------------------------------
// The values are the ones of the ICU library. A larger value is a
// looser level.
const RESTRICT_ASCII: i64 = 0x10000000;        // only code points below 0x80
const RESTRICT_SINGLE: i64 = 0x20000000;       // one script
const RESTRICT_HIGHLY: i64 = 0x30000000;       // one writing system
const RESTRICT_MODERATELY: i64 = 0x40000000;   // Latin and one other script
const RESTRICT_MINIMALLY: i64 = 0x50000000;   // any mixture
const RESTRICT_UNRESTRICTED: i64 = 0x60000000; // a code point outside the profile

// ---- the profiles of the standard ----------------------------------
// The profile tells which code points an identifier may hold. The
// profile of the standard is the set of the code points whose
// Identifier_Status is Allowed.
const PROFILE_ANY: i64 = 0;        // every code point
const PROFILE_ALLOWED: i64 = 1;    // the identifier profile of the standard

// ---- the confusable flags of the standard --------------------------
const CONF_SINGLE: i64 = 1;   // the two texts sit in the same scripts
const CONF_MIXED: i64 = 2;    // the two texts sit in different scripts
const CONF_WHOLE: i64 = 4;    // each text sits in one script of its own

// ---- the writing systems of the standard ---------------------------
// The writing systems hold several scripts. Their values sit above the
// scripts of the package. The scripts of the package run from 0 to 177.
const SCRIPT_HANB: i64 = 178;  // Han with Bopomofo
const SCRIPT_JPAN: i64 = 179;  // Japanese
const SCRIPT_KORE: i64 = 180;  // Korean
const SCRIPT_HNTL: i64 = 181;  // Traditional Han with Latin

// The number of the script values, the writing systems included.
const SCRIPT_COUNT: i64 = 182;

// The bound of the scripts of one code point in the whole script table.
// The largest set of that table holds 17 scripts.
const MAX_WHOLE_SCRIPTS: i64 = 17;

// ---- the set of the script values ----------------------------------
// The set holds three words. The bit of a script value is the value
// itself. The fourth field says that the set holds every script value.
// A code point whose scripts hold Common or Inherited gives that set.

// A set of the script values.
struct ScriptSet {
    w0: i64,   // the bits 0 to 63
    w1: i64,   // the bits 64 to 127
    w2: i64,   // the bits 128 to 181
    all: i64,  // 1 when the set holds every script value
}

// The set of every script value. The third word holds the bits of the
// values 128 to 181. That is 54 bits.
fn set_all() -> ScriptSet {
    return ScriptSet { w0: -1, w1: -1, w2: 0x3FFFFFFFFFFFFF, all: 1 };
}

// The empty set.
fn set_none() -> ScriptSet {
    return ScriptSet { w0: 0, w1: 0, w2: 0, all: 0 };
}

// True when the set holds every script value.
fn set_is_all(s: ScriptSet) -> bool {
    return s.all != 0;
}

// True when the set holds no script value.
fn set_is_empty(s: ScriptSet) -> bool {
    if set_is_all(s) { return false; }
    return (s.w0 | s.w1 | s.w2) == 0;
}

// Adds the script value to the set. The value must be below
// SCRIPT_COUNT.
fn set_add(s: ScriptSet&, v: i64) {
    if v < 0 || v >= SCRIPT_COUNT { return; }
    if v < 64 {
        s.w0 |= (1 as i64) << v;
    } else if v < 128 {
        s.w1 |= (1 as i64) << (v - 64);
    } else {
        s.w2 |= (1 as i64) << (v - 128);
    }
}

// True when the set holds the script value.
fn set_has(s: ScriptSet, v: i64) -> bool {
    if v < 0 || v >= SCRIPT_COUNT { return false; }
    if v < 64 { return (s.w0 & ((1 as i64) << v)) != 0; }
    if v < 128 { return (s.w1 & ((1 as i64) << (v - 64))) != 0; }
    return (s.w2 & ((1 as i64) << (v - 128))) != 0;
}

// The intersection of two sets. The set of all script values meets any
// set to give that set.
fn set_and(a: ScriptSet, b: ScriptSet) -> ScriptSet {
    if set_is_all(a) { return b; }
    if set_is_all(b) { return a; }
    return ScriptSet {
        w0: a.w0 & b.w0,
        w1: a.w1 & b.w1,
        w2: a.w2 & b.w2,
        all: 0,
    };
}

// The scripts of the set, in ascending order.
fn set_values(s: ScriptSet, out: i64[>..]&) {
    out.clear();
    if set_is_all(s) {
        // The set of every script value gives every script.
        for k in 0..SCRIPT_COUNT { out.push(k); }
        return;
    }
    for k in 0..SCRIPT_COUNT {
        if set_has(s, k) { out.push(k); }
    }
}

// ---- the identifier profile ----------------------------------------
// True when the code point is in the identifier profile of the standard,
// that is, when its Identifier_Status is Allowed.
fn identifier_allowed(cp: i64) -> bool {
    if cp < 0 || cp > 0x10FFFF { return false; }
    let i = run_at(IDP_START[..], IDP_END[..], cp);
    return i >= 0;
}

// The script value of a code point that the profile allows, or -1.
fn profile_allows(cp: i64, profile: i64) -> bool {
    if profile == PROFILE_ANY { return true; }
    if profile != PROFILE_ALLOWED { return false; }
    return identifier_allowed(cp);
}

// ---- the augmented script set --------------------------------------
// The augmented script set of a code point is its Script_Extensions plus
// the writing systems that those scripts imply. A code point whose
// scripts hold Common or Inherited gives the set of every script value.
fn augmented_set(out: ScriptSet&, cp: i64) {
    var ext: i64[>..] = [];
    script_extensions(ext, cp);
    var s: ScriptSet = set_none();
    for k in 0..ext.len {
        let v = ext[k];
        // A code point of the scripts Common or Inherited gives the set
        // of every script value.
        if v == SCRIPT_COMMON || v == SCRIPT_INHERITED {
            out = set_all();
            return;
        }
        set_add(s, v);
    }
    // The writing systems of the standard.
    if set_has(s, SCRIPT_HAN) {
        set_add(s, SCRIPT_HANB);
        set_add(s, SCRIPT_HNTL);
        set_add(s, SCRIPT_JPAN);
        set_add(s, SCRIPT_KORE);
    }
    if set_has(s, SCRIPT_HIRAGANA) || set_has(s, SCRIPT_KATAKANA) {
        set_add(s, SCRIPT_JPAN);
    }
    if set_has(s, SCRIPT_HANGUL) {
        set_add(s, SCRIPT_KORE);
    }
    if set_has(s, SCRIPT_BOPOMOFO) {
        set_add(s, SCRIPT_HANB);
    }
    if set_has(s, SCRIPT_LATIN) {
        set_add(s, SCRIPT_HNTL);
    }
    out = s;
}

// ---- the recommended scripts of the standard -----------------------
// The scripts of Table 5 of UAX #31. The step 7 of the level asks for
// one of them.
fn is_recommended(v: i64) -> bool {
    // The values of the scripts of Table 5 of UAX #31.
    if v == 1 || v == 2 { return true; }    // Common and Inherited
    if v == 3 { return true; }             // Latin
    if v == 4 { return true; }             // Greek
    if v == 5 { return true; }             // Cyrillic
    if v == 6 { return true; }             // Armenian
    if v == 7 { return true; }             // Hebrew
    if v == 8 { return true; }             // Arabic
    if v == 10 { return true; }            // Thaana
    if v == 11 { return true; }            // Devanagari
    if v == 12 { return true; }            // Bengali
    if v == 13 { return true; }            // Gurmukhi
    if v == 14 { return true; }            // Gujarati
    if v == 15 { return true; }            // Oriya
    if v == 16 { return true; }            // Tamil
    if v == 17 { return true; }            // Telugu
    if v == 18 { return true; }            // Kannada
    if v == 19 { return true; }            // Malayalam
    if v == 20 { return true; }            // Sinhala
    if v == 21 { return true; }            // Thai
    if v == 22 { return true; }            // Lao
    if v == 23 { return true; }            // Tibetan
    if v == 24 { return true; }            // Myanmar
    if v == 25 { return true; }            // Georgian
    if v == 26 { return true; }            // Hangul
    if v == 27 { return true; }            // Ethiopic
    if v == 32 { return true; }            // Khmer
    if v == 34 { return true; }            // Hiragana
    if v == 35 { return true; }            // Katakana
    if v == 37 { return true; }            // Han
    return false;
}

// ---- the restriction level ------------------------------------------
// The level of the text under the profile. The steps follow section 5.2
// of the standard.
//
// A text with a bad byte gives RESTRICT_UNRESTRICTED. A text above
// MAX_INPUT bytes gives RESTRICT_UNRESTRICTED. The call has no fault
// code. The checked call gives the fault.
fn restriction_level(s: const u8[:], profile: i64) -> i64 {
    let code, _, level = restriction_level_checked(s, profile);
    if code != OK { return RESTRICT_UNRESTRICTED; }
    return level;
}

// The level of the text under the profile, with the fault. The three
// values are the code, the offset and the level.
//
// A good text gives OK, -1 and the level. A bad byte gives
// ERR_BAD_UTF8, the offset of the byte and 0. A text above MAX_INPUT
// bytes gives ERR_TOO_LONG, -1 and 0.
fn restriction_level_checked(s: const u8[:], profile: i64) -> i64, i64, i64 {
    if s.len > MAX_INPUT { return ERR_TOO_LONG, -1, 0; }
    var src: i64[>..] = [];
    let code, off = utf8_decode(src, s);
    if code != OK { return code, off, 0; }
    return OK, -1, level_of(src[..], profile);
}

// The level of the code points of the text under the profile.
fn level_of(cps: const i64[:], profile: i64) -> i64 {
    // Step 1: a code point outside the profile gives Unrestricted.
    var ascii_only = true;
    for k in 0..cps.len {
        if !profile_allows(cps[k], profile) { return RESTRICT_UNRESTRICTED; }
        if cps[k] > 0x7F { ascii_only = false; }
    }
    // Step 2: no code point above 0x7F gives ASCII-Only.
    if ascii_only { return RESTRICT_ASCII; }
    // Steps 3 and 4: the resolved script set. An empty set gives
    // Single Script, because the standard returns Single Script for a
    // text whose SOSS is empty.
    var all: ScriptSet = set_all();
    var no_latin: ScriptSet = set_all();
    var has_no_latin = false;
    for k in 0..cps.len {
        var a: ScriptSet = ScriptSet { w0: 0, w1: 0, w2: 0, all: 0 };
        augmented_set(a, cps[k]);
        if set_is_all(a) { continue; }
        all = set_and(all, a);
        if !set_has(a, SCRIPT_LATIN) {
            no_latin = set_and(no_latin, a);
            has_no_latin = true;
        }
    }
    if !set_is_empty(all) { return RESTRICT_SINGLE; }
    // Step 5: the entries that hold Latin drop out.
    if !has_no_latin { return RESTRICT_MINIMALLY; }
    // Step 6: a writing system covers the set.
    if set_has(no_latin, SCRIPT_KORE) || set_has(no_latin, SCRIPT_HANB)
        || set_has(no_latin, SCRIPT_JPAN) {
        return RESTRICT_HIGHLY;
    }
    // Step 7: a Recommended script that is not Cyrillic or Greek.
    for k in 0..SCRIPT_COUNT {
        if k == SCRIPT_CYRILLIC || k == SCRIPT_GREEK { continue; }
        if set_has(no_latin, k) && is_recommended(k) {
            return RESTRICT_MODERATELY;
        }
    }
    // Step 8: the other texts.
    return RESTRICT_MINIMALLY;
}

// ---- the mixed script test -----------------------------------------
// The resolved script set of the text. The set holds every script value
// when the text holds a code point of the scripts Common or Inherited.
fn resolved_set(cps: const i64[:]) -> ScriptSet {
    var all: ScriptSet = set_all();
    for k in 0..cps.len {
        var a: ScriptSet = ScriptSet { w0: 0, w1: 0, w2: 0, all: 0 };
        augmented_set(a, cps[k]);
        if set_is_all(a) { continue; }
        all = set_and(all, a);
    }
    return all;
}

// True when the text mixes scripts in one word. A text with a bad byte
// gives false. The call has no fault code.
fn is_mixed_script(s: const u8[:]) -> bool {
    if s.len > MAX_INPUT { return false; }
    var src: i64[>..] = [];
    let code, off = utf8_decode(src, s);
    if code != OK { return false; }
    return set_is_empty(resolved_set(src[..]));
}

// The script values of the resolved script set of the text, in ascending
// order. The two values are the code and the offset.
//
// A good text gives OK and -1. A bad byte gives ERR_BAD_UTF8 and the
// offset. A text above MAX_INPUT bytes gives ERR_TOO_LONG. A fault
// leaves out empty.
fn resolved_scripts(out: i64[>..]&, s: const u8[:]) -> i64, i64 {
    out.clear();
    if s.len > MAX_INPUT { return ERR_TOO_LONG, -1; }
    var src: i64[>..] = [];
    let code, off = utf8_decode(src, s);
    if code != OK { return code, off; }
    set_values(resolved_set(src[..]), out);
    return OK, -1;
}

// ---- the whole script test -----------------------------------------
// The scripts that hold a character confusable with the code point. The
// set comes from the table of the standard.
fn whole_script_set(out: ScriptSet&, cp: i64) {
    out = set_none();
    let i = find_exact(WS_CP[..], cp);
    if i < 0 { return; }
    for k in WS_OFF[i]..WS_OFF[i + 1] { set_add(out, WS_POOL[k]); }
}

// The scripts that hold a whole script confusable of the text. The set
// is the intersection of the sets of the code points of the text. A
// code point with no row of the table gives an empty set, so the text
// has no whole script confusable at all. The call stops at such a code
// point, so a long text costs no more than the part before it.
fn whole_script_set_of(cps: const i64[:]) -> ScriptSet {
    if cps.len == 0 { return set_none(); }
    var all: ScriptSet = set_all();
    for k in 0..cps.len {
        var a: ScriptSet = ScriptSet { w0: 0, w1: 0, w2: 0, all: 0 };
        whole_script_set(a, cps[k]);
        if set_is_empty(a) { return set_none(); }
        all = set_and(all, a);
    }
    return all;
}

// True when the script holds a whole script confusable of the text. A
// text with a bad byte gives false. The call has no fault code.
//
// The test holds a text that sits in one script. A text that mixes
// scripts has no whole script confusable, because the standard gives
// the test on the texts of one script.
fn is_whole_script_confusable(s: const u8[:], script: i64) -> bool {
    if s.len > MAX_INPUT { return false; }
    var src: i64[>..] = [];
    let code, off = utf8_decode(src, s);
    if code != OK { return false; }
    let mine = resolved_set(src[..]);
    // A text that mixes scripts has no whole script confusable.
    if set_is_empty(mine) { return false; }
    let twins = whole_script_set_of(src[..]);
    if !set_has(twins, script) { return false; }
    // The script of the text itself holds no whole script confusable.
    if set_has(mine, script) { return false; }
    return true;
}

// The script values that hold a whole script confusable of the text, in
// ascending order. The two values are the code and the offset.
//
// A good text gives OK and -1. A bad byte gives ERR_BAD_UTF8 and the
// offset. A text above MAX_INPUT bytes gives ERR_TOO_LONG. A fault
// leaves out empty.
fn whole_script_twins(out: i64[>..]&, s: const u8[:]) -> i64, i64 {
    out.clear();
    if s.len > MAX_INPUT { return ERR_TOO_LONG, -1; }
    var src: i64[>..] = [];
    let code, off = utf8_decode(src, s);
    if code != OK { return code, off; }
    // The script of the text itself holds no whole script confusable.
    let mine = resolved_set(src[..]);
    // A text that mixes scripts has no whole script confusable.
    if set_is_empty(mine) { return OK, -1; }
    var twins = whole_script_set_of(src[..]);
    for k in 0..SCRIPT_COUNT {
        if set_has(twins, k) && !set_has(mine, k) { out.push(k); }
    }
    return OK, -1;
}

// ---- the confusable flags ------------------------------------------
// The mask of the confusable flags of the two texts. The mask holds
// CONF_SINGLE, CONF_MIXED and CONF_WHOLE.
//
// A pair that is not confusable gives 0. A pair with a bad byte gives 0.
// The call has no fault code.
fn confusable_kinds(a: const u8[:], b: const u8[:]) -> i64 {
    if !confusable(a, b) { return 0; }
    var src_a: i64[>..] = [];
    var src_b: i64[>..] = [];
    if utf8_decode(src_a, a) != OK { return 0; }
    if utf8_decode(src_b, b) != OK { return 0; }
    let set_a = resolved_set(src_a[..]);
    let set_b = resolved_set(src_b[..]);
    var mask = 0;
    // The set of every script meets any set that holds a script. It does
    // not meet the empty set of a text that mixes scripts.
    if !set_is_empty(set_and(set_a, set_b)) {
        mask |= CONF_SINGLE;
    } else {
        mask |= CONF_MIXED;
        if !set_is_empty(set_a) && !set_is_empty(set_b) {
            mask |= CONF_WHOLE;
        }
    }
    return mask;
}

// ---- the names of the values ---------------------------------------
// The name of a restriction level.
fn restriction_level_name(level: i64) -> const u8[:] {
    if level == RESTRICT_ASCII { return "ASCII-Only"; }
    if level == RESTRICT_SINGLE { return "Single Script"; }
    if level == RESTRICT_HIGHLY { return "Highly Restrictive"; }
    if level == RESTRICT_MODERATELY { return "Moderately Restrictive"; }
    if level == RESTRICT_MINIMALLY { return "Minimally Restrictive"; }
    if level == RESTRICT_UNRESTRICTED { return "Unrestricted"; }
    return "Unknown";
}
