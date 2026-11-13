// Tests for the dictionary word segmentation. The cases replay the
// splits of the ICU library, release 79.1, over texts of Thai, Lao,
// Burmese, Khmer, Chinese and Japanese. The scenario cases pin the
// shapes that the README states. The fault cases pin the faults of the
// other split calls.
namespace suite;

import std;
import os;
import unicode from "../..";
import dict_cases;

// The text of one case: the code points that start at the pool entry.
fn dc_text(start: i64) -> u8[>..] {
    let n = DICT_POOL[start];
    var out: u8[>..] = [];
    var cps: i64[>..] = [];
    for k in 1..n + 1 { cps.push(DICT_POOL[start + k]); }
    unicode::encode_all(out, cps[..]);
    return out;
}

// The code point size of s[a..b].
fn dc_cps(s: const u8[:], a: i64, b: i64) -> i64 {
    var cps: i64[>..] = [];
    unicode::utf8_decode(cps, s[a..b]);
    return cps.len;
}

// The starts of the segments of one case, from the sizes in the pool.
fn dc_want(text: const u8[:], start: i64, m: i64) -> i64[>..] {
    let sizes_at = start + DICT_POOL[start] + 2;
    var want: i64[>..] = [];
    var byte_at: i64 = 0;
    want.push(0);
    for k in 0..m {
        let size = DICT_POOL[sizes_at + k];
        for j in 0..size {
            let cp, w = unicode::decode_at(text[..], byte_at);
            if cp < 0 { byte_at = text.len; break; }
            byte_at += w;
        }
        if byte_at < text.len { want.push(byte_at); }
    }
    return want;
}

// Replays one case: the boundaries, the sizes and the word-like flags.
fn dc_check(start: i64, c: i64) -> i64 {
    let text = dc_text(start);
    let n = DICT_POOL[start];
    let m = DICT_POOL[start + n + 1];
    let sizes_at = start + n + 2;
    var offsets: i64[>..] = [];
    let code = unicode::word_offsets(offsets, text[..]);
    if code != unicode::OK {
        print("FAIL: dict case ", c, " gave fault ", code, "\n");
        return 1;
    }
    var want: i64[>..] = dc_want(text[..], start, m);
    var bad = 0;
    if offsets.len != want.len {
        print("FAIL: dict case ", c, " gave ", offsets.len, " starts and not ", want.len,
            " (text ", text.len, " bytes, m ", m, ")\n");
        bad += 1;
    } else {
        for k in 0..want.len {
            if offsets[k] != want[k] {
                print("FAIL: dict case ", c, " differs at start ", k, ": ",
                    offsets[k], " and not ", want[k], "\n");
                bad += 1;
                break;
            }
        }
    }
    // The sizes and the flags of the walk with the next call.
    var at: i64 = 0;
    var cache: i64[>..] = [];
    for k in 0..m {
        let code2, end = unicode::word_next(text[..], at);
        if code2 != unicode::OK || end <= at {
            print("FAIL: dict case ", c, " the next call failed at ", k, "\n");
            bad += 1;
            break;
        }
        let code4, end4 = unicode::word_next_cached(cache, text[..], at);
        if code4 != unicode::OK || end4 != end {
            print("FAIL: dict case ", c, " the cached call gave ", end4, " and not ", end, " at ", k, "\n");
            bad += 1;
            break;
        }
        if dc_cps(text[..], at, end) != DICT_POOL[sizes_at + k] {
            print("FAIL: dict case ", c, " gave a wrong size at segment ", k, "\n");
            bad += 1;
        }
        let want_flag = DICT_POOL[sizes_at + m + k];
        if unicode::is_word_like(text[..], at, end) != (want_flag == 1) {
            print("FAIL: dict case ", c, " gave a wrong word-like flag at segment ", k, "\n");
            bad += 1;
        }
        at = end;
    }
    if at != text.len {
        print("FAIL: dict case ", c, " did not reach the end\n");
        bad += 1;
    }
    let code3, count = unicode::word_count(text[..]);
    if code3 != unicode::OK || count != m {
        print("FAIL: dict case ", c, " gave a wrong count\n");
        bad += 1;
    }
    return bad;
}

fn dc_battery() -> i64 {
    var bad: i64 = 0;
    let cases = DICT_OFF.len - 1;
    for c in 0..cases {
        bad += dc_check(DICT_OFF[c], c);
        if bad > 20 { print("dict battery stopped at case ", c, "\n"); return bad; }
    }
    if bad == 0 { print("dict battery: ", cases, " cases ok\n"); }
    return bad;
}

// One split with the boundary offsets spelled out, for the scenarios.
fn dc_starts(text: const u8[:]) -> i64[>..] {
    var out: i64[>..] = [];
    unicode::word_offsets(out, text);
    return out;
}

fn dc_expect(label: const u8[:], got: const i64[:], want: const i64[:]) -> i64 {
    var bad = 0;
    if got.len != want.len {
        print("FAIL: ", label, " gave ", got.len, " starts and not ", want.len, ":");
        for k in 0..got.len { print(" ", got[k]); }
        print("\n");
        return 1;
    }
    for k in 0..want.len {
        if got[k] != want[k] {
            print("FAIL: ", label, " gave ", got[k], " at ", k, " and not ", want[k], "\n");
            bad = 1;
        }
    }
    return bad;
}

// The shapes that the README states, with the offsets of a run on this
// machine. Each one pins one rule of the engine or one join of the rules.
fn dc_scenarios() -> i64 {
    var bad: i64 = 0;
    var got: i64[>..] = [];
    // Thai: two words.
    got = dc_starts("ภาษาไทย");
    bad += dc_expect("thai phasa thai", got[..], [0, 12]);
    // Thai: one dictionary word.
    got = dc_starts("ที่มา");
    bad += dc_expect("thai thi ma", got[..], [0]);
    // Thai: a run that no word holds splits at the best partial match.
    got = dc_starts("ออออออ");
    bad += dc_expect("thai six o ang", got[..], [0, 6, 12]);
    // Chinese.
    got = dc_starts("中文测试");
    bad += dc_expect("cjk zhongwen ceshi", got[..], [0, 6]);
    // Japanese: two Han words and one Hiragana mark.
    got = dc_starts("今日は晴れ");
    bad += dc_expect("cjk kyou wa hare", got[..], [0, 6, 9]);
    // Katakana that no word holds stays one segment.
    got = dc_starts("コンニチハ");
    bad += dc_expect("katakana konnichiha", got[..], [0]);
    // Khmer.
    got = dc_starts("កាគារ");
    bad += dc_expect("khmer two words", got[..], [0, 6]);
    // Lao.
    got = dc_starts("ລາວີ");
    bad += dc_expect("lao word", got[..], [0, 6]);
    // Burmese.
    got = dc_starts("ကက်က");
    bad += dc_expect("burmese word", got[..], [0, 9]);
    // A Latin letter joins the Thai word: the rules chain them.
    got = dc_starts("aภาษา");
    bad += dc_expect("latin with thai", got[..], [0]);
    // Thai with digits: the rules give one segment, the number status.
    got = dc_starts("ภาษา12");
    bad += dc_expect("thai with digits", got[..], [0]);
    // A comma splits between the Latin letter and the Thai word.
    got = dc_starts("a,ภาษา");
    bad += dc_expect("comma then thai", got[..], [0, 1, 2]);
    // The Thai word, a full stop and Latin letters stay one segment.
    got = dc_starts("ภาษา.ABC");
    bad += dc_expect("thai dot letters", got[..], [0]);
    // The ideographic full stop splits between the two Han words.
    got = dc_starts("中文。中文");
    bad += dc_expect("han stop han", got[..], [0, 6, 9]);
    // A mark with no engine of its own, the prolonged sound mark and a
    // Katakana mark: ICU skips the whole run of their script, so the
    // Hiragana word that follows starts its own run.
    var rj: i64[>..] = [];
    var rs: u8[>..] = [];
    unicode::encode_all(rs, [0x30A6, 0x309B, 0x30A0, 0x30FC, 0x308A, 0x30B4, 0x30D3]);
    unicode::word_offsets(rj, rs[..]);
    bad += dc_expect("reject run of common marks", rj[..], [0, 15]);
    if bad == 0 { print("dict scenarios ok\n"); }
    return bad;
}

// The word-like flag of the segments of the pinned shapes.
fn dc_flags() -> i64 {
    var bad: i64 = 0;
    // Every segment of the CJK texts is word-like, the full stop is not.
    if !unicode::is_word_like("中文测试", 0, 6) { print("FAIL: flag zhong\n"); bad += 1; }
    if !unicode::is_word_like("中文测试", 6, 12) { print("FAIL: flag ceshi\n"); bad += 1; }
    if unicode::is_word_like("中文。中文", 6, 9) { print("FAIL: flag ideographic stop\n"); bad += 1; }
    if !unicode::is_word_like("中文", 0, 3) { print("FAIL: flag single han\n"); bad += 1; }
    if bad == 0 { print("dict flags ok\n"); }
    return bad;
}

// The faults and the hostile texts. A bad byte is a fault with its
// offset, a text above the input bound is a fault, a fault clears the
// buffer, and a hostile text of one script returns in bounded time.
fn dc_faults() -> i64 {
    var bad: i64 = 0;
    var out: i64[>..] = [];
    // A bad byte forms a segment of one byte, like in the other split
    // calls. The bytes are the Thai letter, the space and one bad byte.
    var s: u8[>..] = [];
    var cps: i64[>..] = [];
    cps.push(0x0E20); cps.push(0x20);
    unicode::encode_all(s, cps[..]);
    s.push(0xFF);
    let code, end = unicode::word_next(s[..], 0);
    if code != unicode::OK || end != 3 {
        print("FAIL: dict bad byte walk gave ", code, " end ", end, "\n");
        bad += 1;
    }
    let code2 = unicode::word_offsets(out, s[..]);
    if code2 != unicode::OK || out.len != 3 || out[0] != 0 || out[1] != 3 || out[2] != 4 {
        print("FAIL: dict bad byte offsets gave ", code2, ":\n");
        for k in 0..out.len { print(" ", out[k]); }
        print("\n");
        bad += 1;
    }
    // The too long fault.
    var big: u8[>..] = [];
    for k in 0..unicode::MAX_INPUT + 1 { big.push(0x20); }
    let wc, _count = unicode::word_count(big[..]);
    if wc != unicode::ERR_TOO_LONG {
        print("FAIL: dict too long\n");
        bad += 1;
    }
    // A fault clears the buffer.
    out.push(1);
    let code3 = unicode::word_offsets(out, big[..]);
    if code3 != unicode::ERR_TOO_LONG || out.len != 0 {
        print("FAIL: dict fault left the buffer filled\n");
        bad += 1;
    }
    // One mebibyte of one Thai letter.
    var thai: u8[>..] = [];
    for k in 0..unicode::MAX_INPUT / 3 { thai.push(0xE0); thai.push(0xB8); thai.push(0xA0); }
    let t0 = clock_ns();
    let code4 = unicode::word_offsets(out, thai[..]);
    let t1 = clock_ns();
    if code4 != unicode::OK {
        print("FAIL: dict hostile thai gave fault ", code4, "\n");
        bad += 1;
    }
    if (t1 - t0) / 1000000 > 5000 {
        print("FAIL: dict hostile thai took ", (t1 - t0) / 1000000, " ms\n");
        bad += 1;
    }
    // One mebibyte of Thai words, the shape with many breaks: the split
    // stays linear. The text repeats a word of seven code points.
    var words: u8[>..] = [];
    let unit = [0x0E20, 0x0E32, 0x0E29, 0x0E32, 0x0E44, 0x0E17, 0x0E22];
    var rep: i64 = 0;
    while words.len + 21 <= unicode::MAX_INPUT {
        for k in 0..unit.len { unicode::utf8_encode(words, unit[k]); }
        rep += 1;
    }
    let w0 = clock_ns();
    var wo: i64[>..] = [];
    let code5 = unicode::word_offsets(wo, words[..]);
    let w1 = clock_ns();
    if code5 != unicode::OK || (w1 - w0) / 1000000 > 5000 {
        print("FAIL: dict hostile thai words gave ", code5, " in ", (w1 - w0) / 1000000, " ms\n");
        bad += 1;
    }
    // Every boundary sits on a code point boundary.
    for k in 0..out.len {
        if out[k] % 3 != 0 {
            print("FAIL: dict hostile thai boundary at ", out[k], "\n");
            bad += 1;
            break;
        }
    }
    // One mebibyte of one Han code point.
    var han: u8[>..] = [];
    for k in 0..unicode::MAX_INPUT / 3 { han.push(0xE4); han.push(0xB8); han.push(0xAD); }
    let t2 = clock_ns();
    let code5 = unicode::word_offsets(out, han[..]);
    let t3 = clock_ns();
    if code5 != unicode::OK {
        print("FAIL: dict hostile han gave fault ", code5, "\n");
        bad += 1;
    }
    if (t3 - t2) / 1000000 > 5000 {
        print("FAIL: dict hostile han took ", (t3 - t2) / 1000000, " ms\n");
        bad += 1;
    }
    if bad == 0 {
        print("dict faults ok: thai ", (t1 - t0) / 1000000, " ms, han ", (t3 - t2) / 1000000, " ms\n");
    }
    return bad;
}

fn run_dict() -> i64 {
    var bad: i64 = 0;
    if want("dict", "dc_battery") { bad += dc_battery(); }
    if want("dict", "dc_scenarios") { bad += dc_scenarios(); }
    if want("dict", "dc_flags") { bad += dc_flags(); }
    if want("dict", "dc_faults") { bad += dc_faults(); }
    return bad;
}
