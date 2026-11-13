// Tests for the restriction levels and the script confusables.
namespace suite;

import std;
import unicode from "../..";

fn rl_check(ok: bool, name: const u8[:]) -> i64 {
    if !ok { print("FAIL: restrict ", name, "\n"); return 1; }
    return 0;
}

// The level of every text of the battery, without the profile and under
// the profile of the standard. The levels come from the case file. The
// class of a text says whether the ICU library gives the same level. The
// class is 0 for the texts that agree, 1 for the texts of the Hntl rule
// and 2 for the texts of the rule of step 7.
fn rl_levels() -> i64 {
    var bad = 0;
    var text: u8[>..] = [];
    for r in 0..RL_TXT_OFF.len - 1 {
        text.clear();
        unicode::encode_all(text, RL_TXT_POOL[RL_TXT_OFF[r]..RL_TXT_OFF[r + 1]]);
        let any = unicode::restriction_level(text[..], unicode::PROFILE_ANY);
        if any != RL_LEVEL[r] {
            print("FAIL: the level of text ", r, " is ", any, " and not ", RL_LEVEL[r], "\n");
            bad += 1;
            if bad > 5 { return bad; }
        }
        let prof = unicode::restriction_level(text[..], unicode::PROFILE_ALLOWED);
        if prof != RL_LEVEL_P[r] {
            print("FAIL: the level of text ", r, " under the profile is ", prof,
                  " and not ", RL_LEVEL_P[r], "\n");
            bad += 1;
            if bad > 5 { return bad; }
        }
        // The ICU library gives the same level, unless the text sits in
        // one of the two classes of divergence.
        if RL_CLASS[r] == 0 && any != RL_ICU[r] {
            print("FAIL: the level of text ", r, " differs from ICU outside the classes\n");
            bad += 1;
            if bad > 5 { return bad; }
        }
        if RL_CLASS[r] != 0 && any == RL_ICU[r] {
            print("FAIL: the level of text ", r, " gives the same value as ICU\n");
            bad += 1;
            if bad > 5 { return bad; }
        }
        if RL_CLASS_P[r] == 0 && prof != RL_ICU_P[r] {
            print("FAIL: the level of text ", r, " under the profile differs from ICU\n");
            bad += 1;
            if bad > 5 { return bad; }
        }
        // The mixed script test of the Rust crate. The crate holds no
        // Hntl, so the two differ on the texts that mix Latin and Han.
        var mixed = 0;
        if unicode::is_mixed_script(text[..]) { mixed = 1; }
        if mixed != RL_MIXED_MINE[r] {
            print("FAIL: the mixed script test of text ", r, " differs from the rules of the standard\n");
            bad += 1;
            if bad > 5 { return bad; }
        }
        if mixed != RL_MIXED[r] && RL_MIXED_CLASS[r] == 0 {
            print("FAIL: the mixed script test of text ", r, " differs from the Rust crate outside the class\n");
            bad += 1;
            if bad > 5 { return bad; }
        }
        if mixed == RL_MIXED[r] && RL_MIXED_CLASS[r] != 0 {
            print("FAIL: the mixed script test of text ", r, " gives the same value as the Rust crate\n");
            bad += 1;
            if bad > 5 { return bad; }
        }
        // The resolved script set against the Rust crate. The crate
        // holds no Hntl, so the set of the package without Hntl must
        // give the set of the crate.
        let code, off = unicode::resolved_scripts(RL_SCRIPTS, text[..]);
        if code != unicode::OK {
            print("FAIL: the scripts of text ", r, " gave the code ", code, "\n");
            bad += 1;
            if bad > 5 { return bad; }
        }
        let first = RL_SET_OFF[r];
        let last = RL_SET_OFF[r + 1];
        if last - first == 1 && RL_SET_POOL[first] == -1 {
            // The crate writes the set of every script as the name
            // Common. The package writes every script value.
            if RL_SCRIPTS.len != 182 {
                print("FAIL: the resolved set of text ", r, " holds ", RL_SCRIPTS.len,
                      " values and not 182\n");
                bad += 1;
                if bad > 5 { return bad; }
            }
        } else {
            var mine: i64[>..] = [];
            for k in 0..RL_SCRIPTS.len {
                if RL_SCRIPTS[k] == unicode::SCRIPT_HNTL { continue; }
                mine.push(RL_SCRIPTS[k]);
            }
            if mine.len != last - first {
                print("FAIL: the resolved set of text ", r, " holds ", mine.len,
                      " values and not ", last - first, "\n");
                bad += 1;
                if bad > 5 { return bad; }
            }
            for k in 0..mine.len {
                if mine[k] != RL_SET_POOL[first + k] {
                    print("FAIL: the resolved set of text ", r, " differs from the Rust crate\n");
                    bad += 1;
                    if bad > 5 { return bad; }
                }
            }
        }
    }
    return bad;
}

// The faults of the calls. A bad byte gives the offset of the byte. A
// text above MAX_INPUT gives ERR_TOO_LONG.
fn rl_faults() -> i64 {
    var bad = 0;
    let code, off, level = unicode::restriction_level_checked(
        "a\xFFb", unicode::PROFILE_ANY);
    bad += rl_check(code == unicode::ERR_BAD_UTF8, "the level of a bad byte");
    bad += rl_check(off == 1, "the offset of the bad byte");
    bad += rl_check(level == 0, "the level of a bad byte");
    let code, off = unicode::resolved_scripts(RL_SCRIPTS, "a\xFFb");
    bad += rl_check(code == unicode::ERR_BAD_UTF8, "the scripts of a bad byte");
    bad += rl_check(off == 1, "the offset of the bad byte");
    bad += rl_check(RL_SCRIPTS.len == 0, "the buffer of a bad byte");
    let code, off = unicode::whole_script_twins(RL_SCRIPTS, "a\xFFb");
    bad += rl_check(code == unicode::ERR_BAD_UTF8, "the twins of a bad byte");
    bad += rl_check(off == 1, "the offset of the bad byte");
    bad += rl_check(RL_SCRIPTS.len == 0, "the buffer of a bad byte");
    // The empty text gives the level ASCII-Only.
    let level = unicode::restriction_level("", unicode::PROFILE_ANY);
    bad += rl_check(level == unicode::RESTRICT_ASCII, "the level of the empty text");
    // A text with no code point above 0x7F gives the level ASCII-Only.
    let level = unicode::restriction_level("abc123", unicode::PROFILE_ANY);
    bad += rl_check(level == unicode::RESTRICT_ASCII, "the level of an ASCII text");
    // A bad byte at the start gives the offset 0.
    let code, off, level = unicode::restriction_level_checked("\xFF", unicode::PROFILE_ANY);
    bad += rl_check(code == unicode::ERR_BAD_UTF8, "the code of a bad byte at the start");
    bad += rl_check(off == 0, "the offset of a bad byte at the start");
    bad += rl_check(level == 0, "the level of a bad byte at the start");
    // A text above MAX_INPUT bytes gives ERR_TOO_LONG.
    var long: u8[>..] = [];
    for k in 0..unicode::MAX_INPUT + 1 { long.push(0x61); }
    let code, off, level = unicode::restriction_level_checked(long[..], unicode::PROFILE_ANY);
    bad += rl_check(code == unicode::ERR_TOO_LONG, "the code of a long text");
    bad += rl_check(off == -1, "the offset of a long text");
    bad += rl_check(level == 0, "the level of a long text");
    // A fault leaves the buffer empty. The buffer holds values before
    // the call, so the check proves that the call cleared it.
    RL_SCRIPTS.push(7);
    RL_SCRIPTS.push(7);
    let code, off = unicode::resolved_scripts(RL_SCRIPTS, long[..]);
    bad += rl_check(code == unicode::ERR_TOO_LONG, "the code of the scripts of a long text");
    bad += rl_check(RL_SCRIPTS.len == 0, "the buffer of the scripts of a long text");
    RL_SCRIPTS.push(7);
    RL_SCRIPTS.push(7);
    let code, off = unicode::whole_script_twins(RL_SCRIPTS, long[..]);
    bad += rl_check(code == unicode::ERR_TOO_LONG, "the code of the twins of a long text");
    bad += rl_check(RL_SCRIPTS.len == 0, "the buffer of the twins of a long text");
    // The calls without a fault code give a safe value.
    let level = unicode::restriction_level(long[..], unicode::PROFILE_ANY);
    bad += rl_check(level == unicode::RESTRICT_UNRESTRICTED, "the level of a long text");
    let level = unicode::restriction_level("a\xFFb", unicode::PROFILE_ANY);
    bad += rl_check(level == unicode::RESTRICT_UNRESTRICTED, "the level of a bad byte");
    bad += rl_check(!unicode::is_mixed_script("a\xFFb"), "the mixed script test of a bad byte");
    bad += rl_check(!unicode::is_mixed_script(long[..]), "the mixed script test of a long text");
    bad += rl_check(!unicode::is_whole_script_confusable("a\xFFb", 5),
                    "the whole script test of a bad byte");
    bad += rl_check(!unicode::is_whole_script_confusable(long[..], 5),
                    "the whole script test of a long text");
    bad += rl_check(unicode::confusable_kinds("a\xFFb", "a") == 0,
                    "the flags of a bad byte");
    bad += rl_check(unicode::confusable_kinds(long[..], "a") == 0,
                    "the flags of a long text");
    return bad;
}

// The levels of the texts of the standard. The values come from the
// rules of the standard.
fn rl_cases() -> i64 {
    var bad = 0;
    // The Latin and the Cyrillic letters of one word.
    let level = unicode::restriction_level("pаypal", unicode::PROFILE_ANY);
    bad += rl_check(level == unicode::RESTRICT_MINIMALLY, "the level of a mixed word");
    bad += rl_check(unicode::is_mixed_script("pаypal"), "the mixed script test");
    bad += rl_check(!unicode::is_mixed_script("paypal"), "the mixed script test of one script");
    // Latin and Han give Single Script. The writing system Hntl holds
    // the resolved set.
    let level = unicode::restriction_level("a一", unicode::PROFILE_ANY);
    bad += rl_check(level == unicode::RESTRICT_SINGLE, "the level of Latin and Han");
    // Latin and Hiragana give Highly Restrictive. The writing system
    // Jpan covers the set without Latin.
    let level = unicode::restriction_level("aあ", unicode::PROFILE_ANY);
    bad += rl_check(level == unicode::RESTRICT_HIGHLY, "the level of Latin and Hiragana");
    // Latin and Hangul give Highly Restrictive.
    let level = unicode::restriction_level("a가", unicode::PROFILE_ANY);
    bad += rl_check(level == unicode::RESTRICT_HIGHLY, "the level of Latin and Hangul");
    // Latin and Devanagari give Moderately Restrictive. Devanagari is
    // a Recommended script.
    let level = unicode::restriction_level("aक", unicode::PROFILE_ANY);
    bad += rl_check(level == unicode::RESTRICT_MODERATELY, "the level of Latin and Devanagari");
    // Latin and Greek give Minimally Restrictive. Greek sits in the
    // exception of step 7.
    let level = unicode::restriction_level("aα", unicode::PROFILE_ANY);
    bad += rl_check(level == unicode::RESTRICT_MINIMALLY, "the level of Latin and Greek");
    // The code point of a script of Table 7 of UAX #31 gives Minimally
    // Restrictive under the rule of the standard.
    let level = unicode::restriction_level("a\xF1\xBA\x80\x800", unicode::PROFILE_ANY);
    bad += rl_check(level == unicode::RESTRICT_MINIMALLY, "the level of Latin and Adlam");
    // The same text gives Unrestricted under the profile of the
    // standard. The code point of Adlam sits outside the profile.
    let level = unicode::restriction_level("a\xF1\xBA\x80\x800", unicode::PROFILE_ALLOWED);
    bad += rl_check(level == unicode::RESTRICT_UNRESTRICTED, "the level of Adlam under the profile");
    return bad;
}

// The edge cases of the standard. Each case gives the level that the
// rules of the standard give.
fn rl_edges() -> i64 {
    var bad = 0;
    // A combining mark alone sits in the script Inherited. Its resolved
    // set holds every script, so the text is Single Script and does not
    // mix scripts.
    let level = unicode::restriction_level("\xCC\x81", unicode::PROFILE_ANY);
    bad += rl_check(level == unicode::RESTRICT_SINGLE, "the level of an Inherited mark");
    bad += rl_check(!unicode::is_mixed_script("\xCC\x81"), "the mixed script test of an Inherited mark");
    // The identifier profile. The first range is the apostrophe, U+0027.
    // The last range is the single code point U+29D98. The code points
    // next to them, the ends of the code space and the values outside it
    // are not in the profile.
    bad += rl_check(unicode::identifier_allowed(39), "the profile holds U+0027");
    bad += rl_check(!unicode::identifier_allowed(38), "the profile holds no U+0026");
    bad += rl_check(!unicode::identifier_allowed(40), "the profile holds no U+0028");
    bad += rl_check(unicode::identifier_allowed(171416), "the profile holds the last range");
    bad += rl_check(!unicode::identifier_allowed(171417), "the profile ends after the last range");
    bad += rl_check(!unicode::identifier_allowed(0x10FFFF), "the profile holds no U+10FFFF");
    bad += rl_check(!unicode::identifier_allowed(0), "the profile holds no U+0000");
    bad += rl_check(!unicode::identifier_allowed(-1), "the profile holds no negative value");
    bad += rl_check(!unicode::identifier_allowed(0x110000), "the profile holds no value above U+10FFFF");
    // The empty text gives ASCII-Only.
    let level = unicode::restriction_level("", unicode::PROFILE_ANY);
    bad += rl_check(level == unicode::RESTRICT_ASCII, "the level of the empty text");
    // The euro sign is not ASCII. Its resolved set is every script, so
    // the level is Single Script.
    let level = unicode::restriction_level("\xE2\x82\xAC", unicode::PROFILE_ANY);
    bad += rl_check(level == unicode::RESTRICT_SINGLE, "the level of the euro sign");
    // A Han code point with Hiragana gives Single Script.
    let level = unicode::restriction_level("\xE4\xB8\x80\xE3\x81\x82", unicode::PROFILE_ANY);
    bad += rl_check(level == unicode::RESTRICT_SINGLE, "the level of Han and Hiragana");
    // A Han code point with Hangul gives Single Script.
    let level = unicode::restriction_level("\xE4\xB8\x80\xEA\xB0\x80", unicode::PROFILE_ANY);
    bad += rl_check(level == unicode::RESTRICT_SINGLE, "the level of Han and Hangul");
    // Han with Bopomofo gives Single Script.
    let level = unicode::restriction_level("\xE4\xB8\x80\xE3\x8A\x80", unicode::PROFILE_ANY);
    bad += rl_check(level == unicode::RESTRICT_SINGLE, "the level of Han and Bopomofo");
    // Latin with Han and Hangul gives Highly Restrictive. The set
    // without Latin holds Kore.
    let level = unicode::restriction_level("a\xE4\xB8\x80\xEA\xB0\x80", unicode::PROFILE_ANY);
    bad += rl_check(level == unicode::RESTRICT_HIGHLY, "the level of Latin, Han and Hangul");
    // Latin with Han and Hiragana gives Highly Restrictive. The set
    // without Latin holds Jpan.
    let level = unicode::restriction_level("a\xE4\xB8\x80\xE3\x81\x82", unicode::PROFILE_ANY);
    bad += rl_check(level == unicode::RESTRICT_HIGHLY, "the level of Latin, Han and Hiragana");
    // Han with Hiragana and Hangul gives Minimally Restrictive. No one
    // writing system covers all three.
    let level = unicode::restriction_level("\xE4\xB8\x80\xE3\x81\x82\xEA\xB0\x80", unicode::PROFILE_ANY);
    bad += rl_check(level == unicode::RESTRICT_MINIMALLY, "the level of Han, Hiragana and Hangul");
    // Greek with Latin gives Minimally Restrictive.
    let level = unicode::restriction_level("\xCE\xB1a", unicode::PROFILE_ANY);
    bad += rl_check(level == unicode::RESTRICT_MINIMALLY, "the level of Greek and Latin");
    // Cyrillic with Latin gives Minimally Restrictive too.
    let level = unicode::restriction_level("\xD0\xB0a", unicode::PROFILE_ANY);
    bad += rl_check(level == unicode::RESTRICT_MINIMALLY, "the level of Cyrillic and Latin");
    // Armenian with Devanagari gives Minimally Restrictive, because
    // their intersection is empty.
    let level = unicode::restriction_level("\xD5\x81\xE0\xA4\x95", unicode::PROFILE_ANY);
    bad += rl_check(level == unicode::RESTRICT_MINIMALLY, "the level of Armenian and Devanagari");
    // Latin with Hebrew gives Moderately Restrictive.
    let level = unicode::restriction_level("a\xD7\x90", unicode::PROFILE_ANY);
    bad += rl_check(level == unicode::RESTRICT_MODERATELY, "the level of Latin and Hebrew");
    // The Arabic tatweel has a list of several scripts. It widens the
    // set of a text of Arabic and Syriac.
    let level = unicode::restriction_level("\xD8\xA7\xD9\x80\xD8\xB9", unicode::PROFILE_ANY);
    bad += rl_check(level == unicode::RESTRICT_SINGLE, "the level of Arabic and Syriac");
    // The names of the six levels.
    bad += rl_check(unicode::restriction_level_name(unicode::RESTRICT_ASCII) == "ASCII-Only",
                    "the name of ASCII-Only");
    bad += rl_check(unicode::restriction_level_name(unicode::RESTRICT_SINGLE) == "Single Script",
                    "the name of Single Script");
    bad += rl_check(unicode::restriction_level_name(unicode::RESTRICT_HIGHLY) == "Highly Restrictive",
                    "the name of Highly Restrictive");
    bad += rl_check(unicode::restriction_level_name(unicode::RESTRICT_MODERATELY) == "Moderately Restrictive",
                    "the name of Moderately Restrictive");
    bad += rl_check(unicode::restriction_level_name(unicode::RESTRICT_MINIMALLY) == "Minimally Restrictive",
                    "the name of Minimally Restrictive");
    bad += rl_check(unicode::restriction_level_name(unicode::RESTRICT_UNRESTRICTED) == "Unrestricted",
                    "the name of Unrestricted");
    return bad;
}

// The scripts of the resolved set of the texts of the standard.
fn rl_scripts() -> i64 {
    var bad = 0;
    let code, off = unicode::resolved_scripts(RL_SCRIPTS, "pаypal");
    bad += rl_check(code == unicode::OK, "the scripts of a mixed word");
    bad += rl_check(RL_SCRIPTS.len == 0, "the resolved set of a mixed word");
    // The text of Han and a mark holds five scripts.
    let code, off = unicode::resolved_scripts(RL_SCRIPTS, "〆切");
    bad += rl_check(code == unicode::OK, "the scripts of Han");
    bad += rl_check(RL_SCRIPTS.len == 5, "the resolved set of Han");
    // The text of Latin and Han holds Hntl.
    let code, off = unicode::resolved_scripts(RL_SCRIPTS, "a一");
    bad += rl_check(code == unicode::OK, "the scripts of Latin and Han");
    bad += rl_check(RL_SCRIPTS.len == 1, "the resolved set of Latin and Han");
    bad += rl_check(RL_SCRIPTS[0] == unicode::SCRIPT_HNTL, "the script of Latin and Han");
    // The name of a script value gives the name of the writing systems.
    bad += rl_check(unicode::script_value_name(unicode::SCRIPT_HNTL) == "Hntl",
                    "the name of Hntl");
    bad += rl_check(unicode::script_value_name(unicode::SCRIPT_JPAN) == "Jpan",
                    "the name of Jpan");
    bad += rl_check(unicode::script_value_name(unicode::SCRIPT_KORE) == "Kore",
                    "the name of Kore");
    bad += rl_check(unicode::script_value_name(unicode::SCRIPT_HANB) == "Hanb",
                    "the name of Hanb");
    return bad;
}

// The flags of the confusable pairs of the standard. The pairs come
// from the battery. The flags come from the ICU library 79.1.
fn rl_kinds() -> i64 {
    var bad = 0;
    var a: u8[>..] = [];
    var b: u8[>..] = [];
    for p in 0..RL_PAIR_OFF.len - 1 {
        a.clear();
        b.clear();
        unicode::encode_all(a, RL_PAIR_POOL[RL_PAIR_OFF[p]..RL_PAIR_OFF[p] + RL_PAIR_SPLIT[p]]);
        unicode::encode_all(b, RL_PAIR_POOL[RL_PAIR_OFF[p] + RL_PAIR_SPLIT[p]..RL_PAIR_OFF[p + 1]]);
        let mask = unicode::confusable_kinds(a[..], b[..]);
        if RL_PAIR_CLASS[p] == 0 && mask != RL_FLAGS[p] {
            print("FAIL: the flags of pair ", p, " are ", mask, " and not ",
                  RL_FLAGS[p], "\n");
            bad += 1;
            if bad > 5 { return bad; }
        }
        // A pair of Latin and Han gives the single script flag. The
        // ICU library gives the mixed script flag and the whole script
        // flag, because it holds no Hntl.
        if RL_PAIR_CLASS[p] != 0 {
            if mask != unicode::CONF_SINGLE {
                print("FAIL: the flags of pair ", p, " are ", mask, " and not 1\n");
                bad += 1;
                if bad > 5 { return bad; }
            }
            if RL_FLAGS[p] != (unicode::CONF_MIXED | unicode::CONF_WHOLE) {
                print("FAIL: the flags of pair ", p, " differ from ICU outside the class\n");
                bad += 1;
                if bad > 5 { return bad; }
            }
        }
    }
    // The Latin and the Cyrillic letters are mixed script, and each
    // text sits in one script of its own.
    let mask = unicode::confusable_kinds("a", "а");
    bad += rl_check(mask == (unicode::CONF_MIXED | unicode::CONF_WHOLE),
                    "the flags of Latin and Cyrillic");
    // The two texts of one script are single script.
    let mask = unicode::confusable_kinds("a", "a");
    bad += rl_check(mask == unicode::CONF_SINGLE, "the flags of two Latin letters");
    // The two texts of different scripts are no confusable.
    let mask = unicode::confusable_kinds("а", "б");
    bad += rl_check(mask == 0, "the flags of two different letters");
    // The letter of Cherokee and the Latin letter are no confusable.
    let mask = unicode::confusable_kinds("a", "Ꭰ");
    bad += rl_check(mask == 0, "the flags of Latin and Cherokee");
    return bad;
}

// The whole script test of the standard. The text of Latin has a twin
// in the Cyrillic script.
fn rl_whole_script() -> i64 {
    var bad = 0;
    // The twins of every text of the battery. The values come from the
    // table of Unicode 8.0.0.
    var text: u8[>..] = [];
    for r in 0..RL_TXT_OFF.len - 1 {
        text.clear();
        unicode::encode_all(text, RL_TXT_POOL[RL_TXT_OFF[r]..RL_TXT_OFF[r + 1]]);
        let code, off = unicode::whole_script_twins(RL_SCRIPTS, text[..]);
        if code != unicode::OK {
            print("FAIL: the twins of text ", r, " gave the code ", code, "\n");
            bad += 1;
            if bad > 5 { return bad; }
        }
        let first = RL_TWIN_OFF[r];
        let last = RL_TWIN_OFF[r + 1];
        if RL_SCRIPTS.len != last - first {
            print("FAIL: the twins of text ", r, " hold ", RL_SCRIPTS.len,
                  " values and not ", last - first, "\n");
            bad += 1;
            if bad > 5 { return bad; }
        }
        for k in 0..RL_SCRIPTS.len {
            if RL_SCRIPTS[k] != RL_TWIN_POOL[first + k] {
                print("FAIL: the twins of text ", r, " differ from the table of Unicode 8.0.0\n");
                bad += 1;
                if bad > 5 { return bad; }
            }
        }
    }
    let code, off = unicode::whole_script_twins(RL_SCRIPTS, "scope");
    bad += rl_check(code == unicode::OK, "the twins of a Latin word");
    bad += rl_check(RL_SCRIPTS.len == 1, "the count of the twins");
    if RL_SCRIPTS.len == 1 {
        bad += rl_check(RL_SCRIPTS[0] == 5, "the script of the twins");
    }
    // The script of the text itself holds no whole script confusable.
    bad += rl_check(!unicode::is_whole_script_confusable("scope", 3),
                    "the whole script test of the script of the text");
    // The Cyrillic script holds a twin of the Latin word.
    bad += rl_check(unicode::is_whole_script_confusable("scope", 5),
                    "the whole script test of the Cyrillic script");
    // A text with no row in the table holds no twin.
    let code, off = unicode::whole_script_twins(RL_SCRIPTS, "Ꭰ");
    bad += rl_check(code == unicode::OK, "the twins of a Cherokee letter");
    bad += rl_check(RL_SCRIPTS.len == 0, "the count of the twins of Cherokee");
    // The letter z has no row in the table of Unicode 8.0.0. A word
    // with that letter holds no twin.
    let code, off = unicode::whole_script_twins(RL_SCRIPTS, "sz");
    bad += rl_check(code == unicode::OK, "the twins of a word with a z");
    bad += rl_check(RL_SCRIPTS.len == 0, "the count of the twins of a word with a z");
    bad += rl_check(!unicode::is_whole_script_confusable("sz", 5),
                    "the whole script test of a word with a z");
    // A text that mixes scripts holds no twin. The standard gives the
    // whole script test on the texts of one script.
    let code, off = unicode::whole_script_twins(RL_SCRIPTS, "pаypal");
    bad += rl_check(code == unicode::OK, "the twins of a mixed word");
    bad += rl_check(RL_SCRIPTS.len == 0, "the count of the twins of a mixed word");
    bad += rl_check(!unicode::is_whole_script_confusable("pаypal", 5),
                    "the whole script test of a mixed word");
    return bad;
}

// The hostile texts of the package. Each one must finish in time.
fn rl_hostile() -> i64 {
    var bad = 0;
    // A text of one mebibyte of Latin letters.
    var text: u8[>..] = [];
    for k in 0..1048576 { text.push(0x61); }
    let t0 = clock_ns();
    let level = unicode::restriction_level(text[..], unicode::PROFILE_ANY);
    let t1 = clock_ns();
    bad += rl_check(level == unicode::RESTRICT_ASCII, "the level of a long text");
    let code, off = unicode::resolved_scripts(RL_SCRIPTS, text[..]);
    bad += rl_check(code == unicode::OK, "the scripts of a long text");
    let ms = (t1 - t0) / 1000000;
    bad += rl_check(ms < 5000, "the level of a long text took too long");
    // The other calls read the same text. Each one must finish in time.
    let t0 = clock_ns();
    let code, off = unicode::resolved_scripts(RL_SCRIPTS, text[..]);
    let t1 = clock_ns();
    bad += rl_check(code == unicode::OK, "the scripts of a long text");
    bad += rl_check((t1 - t0) / 1000000 < 5000, "the scripts of a long text took too long");
    let t0 = clock_ns();
    let mixed = unicode::is_mixed_script(text[..]);
    let t1 = clock_ns();
    bad += rl_check(!mixed, "the mixed script test of a long text");
    bad += rl_check((t1 - t0) / 1000000 < 5000, "the mixed script test of a long text took too long");
    let t0 = clock_ns();
    let code, off = unicode::whole_script_twins(RL_SCRIPTS, text[..]);
    let t1 = clock_ns();
    bad += rl_check(code == unicode::OK, "the twins of a long text");
    bad += rl_check((t1 - t0) / 1000000 < 5000, "the twins of a long text took too long");
    let t0 = clock_ns();
    let whole = unicode::is_whole_script_confusable(text[..], 5);
    let t1 = clock_ns();
    // The text sits in one script, so it has a twin in Cyrillic.
    bad += rl_check(whole, "the whole script test of a long text");
    bad += rl_check((t1 - t0) / 1000000 < 5000, "the whole script test of a long text took too long");
    print("restrict hostile Latin: ", ms, " ms\n");
    // A text of one mebibyte of Han letters.
    text.clear();
    for k in 0..349525 { text.push(0xE4); text.push(0xB8); text.push(0x80); }
    let t0 = clock_ns();
    let level = unicode::restriction_level(text[..], unicode::PROFILE_ANY);
    let t1 = clock_ns();
    bad += rl_check(level == unicode::RESTRICT_SINGLE, "the level of a long Han text");
    let ms = (t1 - t0) / 1000000;
    bad += rl_check(ms < 5000, "the level of a long Han text took too long");
    print("restrict hostile Han: ", ms, " ms\n");
    // A text of one mebibyte of the Common script. The euro sign sits
    // in that script, so the resolved set holds every script.
    text.clear();
    for k in 0..349525 { text.push(0xE2); text.push(0x82); text.push(0xAC); }
    let t0 = clock_ns();
    let level = unicode::restriction_level(text[..], unicode::PROFILE_ANY);
    let t1 = clock_ns();
    bad += rl_check(level == unicode::RESTRICT_SINGLE, "the level of a long Common text");
    let ms = (t1 - t0) / 1000000;
    bad += rl_check(ms < 5000, "the level of a long Common text took too long");
    print("restrict hostile Common: ", ms, " ms\n");
    // A text of one mebibyte of a mix of twenty scripts.
    let cps: i64[20] = [
        0x61, 0x3B1, 0x430, 0x5D0, 0x628, 0x915, 0x995, 0xB95, 0xC15, 0xC95,
        0xD15, 0xDD9, 0xE01, 0xEA5, 0xF40, 0x1000, 0x10D0, 0xAC00, 0x3042, 0x30AB,
    ];
    text.clear();
    var k = 0;
    while text.len + 4 <= 1048576 {
        push_utf8(text, cps[k]);
        k = (k + 1) % cps.len;
    }
    let t0 = clock_ns();
    let level = unicode::restriction_level(text[..], unicode::PROFILE_ANY);
    let t1 = clock_ns();
    bad += rl_check(level != unicode::RESTRICT_UNRESTRICTED,
                    "the level of a long mixed text");
    bad += rl_check(unicode::is_mixed_script(text[..]),
                    "the mixed script test of a long mixed text");
    let ms = (t1 - t0) / 1000000;
    bad += rl_check(ms < 5000, "the level of a long mixed text took too long");
    print("restrict hostile mixed: ", ms, " ms\n");
    return bad;
}

// The buffer of the scripts of the tests.
var RL_SCRIPTS: i64[>..] = [];

// Runs the tests of the restriction levels.
fn run_restrict() -> i64 {
    var bad = 0;
    if want("restrict", "rl_levels") { bad += rl_levels(); }
    if want("restrict", "rl_faults") { bad += rl_faults(); }
    if want("restrict", "rl_cases") { bad += rl_cases(); }
    if want("restrict", "rl_edges") { bad += rl_edges(); }
    if want("restrict", "rl_scripts") { bad += rl_scripts(); }
    if want("restrict", "rl_kinds") { bad += rl_kinds(); }
    if want("restrict", "rl_whole_script") { bad += rl_whole_script(); }
    if want("restrict", "rl_hostile") { bad += rl_hostile(); }
    return bad;
}
