// The tests of the emoji sequences. The cases of the battery replay the
// kinds of the ICU library, release 79.1, and the scan of the sequence
// files of the standard. The scenario cases pin the shapes that the
// README states. The fault cases pin the faults of the new calls. The
// hostile cases measure the time of the calls on long texts.
namespace suite;

import std;
import os;
import unicode from "../..";
import emoji_seq_cases;

// The flag of Japan. The flag of the United States.
const ES_JP: u8[] = "\xF0\x9F\x87\xAF\xF0\x9F\x87\xB5";
const ES_US: u8[] = "\xF0\x9F\x87\xBA\xF0\x9F\x87\xB8";

// The keycap of the digit 1, with and without the selector.
const ES_KEY: u8[] = "\x31\xEF\xB8\x8F\xE2\x83\xA3";
const ES_KEY2: u8[] = "\x31\xE2\x83\xA3";

// The family of three people.
const ES_FAMILY: u8[] = "\xF0\x9F\x91\xA8\xE2\x80\x8D\xF0\x9F\x91\xA9\xE2\x80\x8D\xF0\x9F\x91\xA6";

// The copyright sign, with and without the selector.
const ES_COPY: u8[] = "\xC2\xA9\xEF\xB8\x8F";
const ES_COPY2: u8[] = "\xC2\xA9";

// The flag of England, as a tag sequence.
const ES_ENGLAND: u8[] = "\xF0\x9F\x8F\xB4\xF3\xA0\x81\xA7\xF3\xA0\x81\xA2\xF3\xA0\x81\xA5\xF3\xA0\x81\xAE\xF3\xA0\x81\xA7\xF3\xA0\x81\xBF";

// The tag that ends a tag sequence.
const ES_CANCEL: u8[] = "\xF3\xA0\x81\xBF";

// The longest sequence of the standard. It holds 35 bytes.
const ES_LONGEST: u8[] = "\xF0\x9F\x91\xA8\xF0\x9F\x8F\xBB\xE2\x80\x8D\xE2\x9D\xA4\xEF\xB8\x8F\xE2\x80\x8D\xF0\x9F\x92\x8B\xE2\x80\x8D\xF0\x9F\x91\xA8\xF0\x9F\x8F\xBB";

// Appends the bytes of src to out.
fn es_push(out: u8[>..]&, src: const u8[:]) {
    for k in 0..src.len { out.push(src[k]); }
}

// The bytes of a and of b, as one text.
fn es_cat(a: const u8[:], b: const u8[:]) -> u8[>..] {
    var out: u8[>..] = [];
    es_push(out, a);
    es_push(out, b);
    return out;
}

// The six kinds of the sequence, in the order of the mask.
fn es_kinds() -> i64[6] {
    return [1, 2, 4, 8, 16, 32];
}

// True when the two lists of offsets hold the same values.
fn es_same(got: const i64[:], want: const i64[:]) -> bool {
    if got.len != want.len { return false; }
    for k in 0..got.len {
        if got[k] != want[k] { return false; }
    }
    return true;
}

// Replays the cases of the battery. Each case holds the code points of
// a text, the mask of its kinds, the flag of the RGI property and the
// byte pairs of the scan.
fn es_battery() -> i64 {
    var bad: i64 = 0;
    var pos: i64 = 0;
    var text: u8[>..] = [];
    var cps: i64[>..] = [];
    var pairs: i64[>..] = [];
    var out: i64[>..] = [];
    let kinds = es_kinds();
    for c in 0..EMOJI_SEQ_CASES_COUNT[0] {
        let n = pool_val(EMOJI_SEQ_CASES_POOL, pos);
        cps.clear();
        for k in 0..n { cps.push(pool_val(EMOJI_SEQ_CASES_POOL, pos + 1 + k)); }
        let mask = pool_val(EMOJI_SEQ_CASES_POOL, pos + 1 + n);
        let rgi = pool_val(EMOJI_SEQ_CASES_POOL, pos + 2 + n);
        let np = pool_val(EMOJI_SEQ_CASES_POOL, pos + 3 + n);
        pairs.clear();
        for k in 0..np * 2 { pairs.push(pool_val(EMOJI_SEQ_CASES_POOL, pos + 4 + n + k)); }
        pos += 4 + n + np * 2;
        unicode::encode_all(text, cps[..]);
        let got = unicode::emoji_sequence_kinds(text[..]);
        if got != mask {
            print("FAIL: emoji case ", c, " gave the mask ", got, " and not ", mask, "\n");
            bad += 1;
        }
        if unicode::is_rgi_emoji(text[..]) != (rgi == 1) {
            print("FAIL: emoji case ", c, " gave the wrong flag of the RGI property\n");
            bad += 1;
        }
        for ki in 0..kinds.len {
            let kind = kinds[ki];
            if unicode::is_emoji_sequence(text[..], kind) != ((mask & kind) != 0) {
                print("FAIL: emoji case ", c, " gave the wrong answer for the kind ", kind, "\n");
                bad += 1;
            }
        }
        if unicode::is_emoji_sequence(text[..], unicode::EMOJI_SEQ_RGI) != (mask != 0) {
            print("FAIL: emoji case ", c, " gave the wrong answer for the RGI mask\n");
            bad += 1;
        }
        let code, offset, cmask = unicode::emoji_sequence_kinds_checked(text[..]);
        if code != unicode::OK || offset != 0 || cmask != mask {
            print("FAIL: emoji case ", c, " gave the code ", code, " the offset ", offset,
                " and the mask ", cmask, "\n");
            bad += 1;
        }
        let scode = unicode::emoji_sequences(out, text[..]);
        if scode != unicode::OK {
            print("FAIL: emoji case ", c, " gave the fault ", scode, " in the scan\n");
            bad += 1;
        } else {
            if !es_same(out[..], pairs[..]) {
                print("FAIL: emoji case ", c, " gave the wrong pairs\n");
                bad += 1;
            }
        }
        if bad > 20 { break; }
    }
    if bad == 0 {
        print("emoji battery: ", EMOJI_SEQ_CASES_COUNT[0], " cases ok\n");
    }
    return bad;
}

// The shapes that the README states. The texts hold the flag of Japan,
// the keycap of the digit 1, the family of three people, the copyright
// sign and the tag sequence of the flag of England.
fn es_scenarios() -> i64 {
    var bad: i64 = 0;
    let kinds = es_kinds();
    // The flag of Japan holds the flag kind. It holds no other kind.
    if !unicode::is_emoji_sequence(ES_JP, unicode::EMOJI_SEQ_FLAG) {
        print("FAIL: the flag of Japan holds no flag kind\n");
        bad += 1;
    }
    for ki in 0..kinds.len {
        if kinds[ki] == unicode::EMOJI_SEQ_FLAG { continue; }
        if unicode::is_emoji_sequence(ES_JP, kinds[ki]) {
            print("FAIL: the flag of Japan holds the kind ", kinds[ki], "\n");
            bad += 1;
        }
    }
    // The mask of the flag of Japan holds the flag bit. The RGI mask
    // holds it too.
    if unicode::emoji_sequence_kinds(ES_JP) != unicode::EMOJI_SEQ_FLAG {
        print("FAIL: the flag of Japan gave the wrong mask\n");
        bad += 1;
    }
    if !unicode::is_rgi_emoji(ES_JP) {
        print("FAIL: the flag of Japan holds no RGI property\n");
        bad += 1;
    }
    // The keycap holds the keycap kind. It holds none without the
    // selector.
    if !unicode::is_emoji_sequence(ES_KEY, unicode::EMOJI_SEQ_KEYCAP) {
        print("FAIL: the keycap holds no keycap kind\n");
        bad += 1;
    }
    if unicode::is_emoji_sequence(ES_KEY2, unicode::EMOJI_SEQ_KEYCAP) {
        print("FAIL: the keycap without the selector holds the keycap kind\n");
        bad += 1;
    }
    // The family holds the ZWJ kind.
    if !unicode::is_emoji_sequence(ES_FAMILY, unicode::EMOJI_SEQ_ZWJ) {
        print("FAIL: the family holds no ZWJ kind\n");
        bad += 1;
    }
    // Two flags in a row hold no kind.
    if unicode::emoji_sequence_kinds(es_cat(ES_JP, ES_US)) != 0 {
        print("FAIL: two flags in a row hold a kind\n");
        bad += 1;
    }
    // The copyright sign holds the basic kind with the selector. It
    // holds none without it.
    if !unicode::is_emoji_sequence(ES_COPY, unicode::EMOJI_SEQ_BASIC) {
        print("FAIL: the copyright sign holds no basic kind\n");
        bad += 1;
    }
    if unicode::is_emoji_sequence(ES_COPY2, unicode::EMOJI_SEQ_BASIC) {
        print("FAIL: the copyright sign without the selector holds the basic kind\n");
        bad += 1;
    }
    // The empty text and the letter hold no kind.
    for ki in 0..kinds.len {
        if unicode::is_emoji_sequence("", kinds[ki]) {
            print("FAIL: the empty text holds the kind ", kinds[ki], "\n");
            bad += 1;
        }
        if unicode::is_emoji_sequence("a", kinds[ki]) {
            print("FAIL: the letter holds the kind ", kinds[ki], "\n");
            bad += 1;
        }
    }
    // The selector and the keycap mark alone hold no kind.
    if unicode::emoji_sequence_kinds("\xEF\xB8\x8F") != 0 {
        print("FAIL: the selector alone holds a kind\n");
        bad += 1;
    }
    if unicode::emoji_sequence_kinds("\xE2\x83\xA3") != 0 {
        print("FAIL: the keycap mark alone holds a kind\n");
        bad += 1;
    }
    // A tag sequence with one tag character missing holds no kind. The
    // full tag sequence holds the tag kind.
    var short: u8[>..] = [];
    // The copy holds the flag, four tag characters and the cancel tag.
    for k in 0..ES_ENGLAND.len - 8 { short.push(ES_ENGLAND[k]); }
    es_push(short, ES_CANCEL);
    if unicode::emoji_sequence_kinds(short[..]) != 0 {
        print("FAIL: the short tag sequence holds a kind\n");
        bad += 1;
    }
    if !unicode::is_emoji_sequence(ES_ENGLAND, unicode::EMOJI_SEQ_TAG) {
        print("FAIL: the tag sequence holds no tag kind\n");
        bad += 1;
    }
    // A text with a sequence and trailing bytes holds no kind.
    if unicode::emoji_sequence_kinds(es_cat(ES_JP, "a")) != 0 {
        print("FAIL: the flag of Japan with a letter holds a kind\n");
        bad += 1;
    }
    // A kind mask of 0 holds nothing. A mask with an unknown bit holds
    // nothing.
    if unicode::is_emoji_sequence(ES_JP, 0) {
        print("FAIL: the mask 0 holds the flag of Japan\n");
        bad += 1;
    }
    if unicode::is_emoji_sequence(ES_JP, 64) {
        print("FAIL: the mask 64 holds the flag of Japan\n");
        bad += 1;
    }
    if bad == 0 { print("emoji scenarios ok\n"); }
    return bad;
}

// The scan of the texts that the README states. The sample holds a
// letter, two flags, a letter, an emoji, a letter and a copyright sign.
fn es_scan() -> i64 {
    var bad: i64 = 0;
    let sample = es_cat(es_cat(es_cat(es_cat("a", ES_JP), ES_US), "b\xF0\x9F\x98\x80x"), "\xC2\xA9\xEF\xB8\x8F");
    var out: i64[>..] = [];
    let code = unicode::emoji_sequences(out, sample);
    if code != unicode::OK {
        print("FAIL: the scan of the sample gave the fault ", code, "\n");
        bad += 1;
    }
    let want = [1, 9, 9, 17, 18, 22, 23, 28];
    if !es_same(out[..], want[..]) {
        print("FAIL: the scan of the sample gave the wrong pairs\n");
        bad += 1;
    }
    // The copyright sign without the selector gives no pair.
    out.clear();
    unicode::emoji_sequences(out, "a\xC2\xA9");
    if out.len != 0 {
        print("FAIL: the scan gave a pair for the copyright sign\n");
        bad += 1;
    }
    // A lone regional indicator gives no pair. A lone heart gives no
    // pair.
    out.clear();
    unicode::emoji_sequences(out, "\xF0\x9F\x87\xAF");
    if out.len != 0 {
        print("FAIL: the scan gave a pair for a lone regional indicator\n");
        bad += 1;
    }
    out.clear();
    unicode::emoji_sequences(out, "\xE2\x9D\xA4");
    if out.len != 0 {
        print("FAIL: the scan gave a pair for a lone heart\n");
        bad += 1;
    }
    // Two flags in a row give two pairs.
    out.clear();
    unicode::emoji_sequences(out, es_cat(ES_JP, ES_US));
    if out.len != 4 || out[0] != 0 || out[1] != 8 || out[2] != 8 || out[3] != 16 {
        print("FAIL: the scan gave the wrong pairs for two flags\n");
        bad += 1;
    }
    if bad == 0 { print("emoji scan ok\n"); }
    return bad;
}

// The faults of the calls. A bad byte gives the code and the offset of
// the byte. A fault clears the buffer of the scan.
fn es_faults() -> i64 {
    var bad: i64 = 0;
    // The checked call gives the mask of the flag of Japan.
    let code, offset, mask = unicode::emoji_sequence_kinds_checked(ES_JP);
    if code != unicode::OK || offset != 0 || mask != unicode::EMOJI_SEQ_FLAG {
        print("FAIL: the checked call gave the code ", code, " the offset ", offset,
            " and the mask ", mask, "\n");
        bad += 1;
    }
    // A text that is no sequence gives the mask 0.
    let code2, offset2, mask2 = unicode::emoji_sequence_kinds_checked("a");
    if code2 != unicode::OK || offset2 != 0 || mask2 != 0 {
        print("FAIL: the checked call gave the wrong answer for a letter\n");
        bad += 1;
    }
    // A bad byte at the start gives the offset 0.
    let code3, offset3, mask3 = unicode::emoji_sequence_kinds_checked("\xFFa");
    if code3 != unicode::ERR_BAD_UTF8 || offset3 != 0 || mask3 != 0 {
        print("FAIL: the checked call gave the code ", code3, " and the offset ", offset3,
            " for a bad byte at the start\n");
        bad += 1;
    }
    // A bad byte in the middle gives its offset.
    let code4, offset4, mask4 = unicode::emoji_sequence_kinds_checked(es_cat(es_cat(ES_JP, "\xFF"), "a"));
    if code4 != unicode::ERR_BAD_UTF8 || offset4 != 8 || mask4 != 0 {
        print("FAIL: the checked call gave the code ", code4, " and the offset ", offset4,
            " for a bad byte in the middle\n");
        bad += 1;
    }
    // The plain calls give no fault for a bad byte.
    if unicode::emoji_sequence_kinds("\xFFa") != 0 {
        print("FAIL: the plain call gave a mask for a bad byte\n");
        bad += 1;
    }
    if unicode::is_rgi_emoji("\xFFa") {
        print("FAIL: the plain call gave the RGI property for a bad byte\n");
        bad += 1;
    }
    // A text above the bound of the longest sequence gives 0 and no
    // fault.
    var long: u8[>..] = [];
    for k in 0..36 { long.push(0x61); }
    if unicode::emoji_sequence_kinds(long[..]) != 0 {
        print("FAIL: the plain call gave a mask for a long text\n");
        bad += 1;
    }
    let code5, offset5, mask5 = unicode::emoji_sequence_kinds_checked(long[..]);
    if code5 != unicode::OK || offset5 != 0 || mask5 != 0 {
        print("FAIL: the checked call gave the wrong answer for a long text\n");
        bad += 1;
    }
    // A text above the bound of the input gives the fault.
    var huge: u8[>..] = [];
    for k in 0..unicode::MAX_INPUT + 1 { huge.push(0x61); }
    let code6, offset6, mask6 = unicode::emoji_sequence_kinds_checked(huge[..]);
    if code6 != unicode::ERR_TOO_LONG || offset6 != 0 || mask6 != 0 {
        print("FAIL: the checked call gave the code ", code6, " for a huge text\n");
        bad += 1;
    }
    // The scan of a bad byte gives the fault and the offset. The buffer
    // stays empty.
    var out: i64[>..] = [];
    out.push(1);
    let scode, soffset = unicode::emoji_sequences(out, es_cat(es_cat(ES_JP, "\xFF"), "a"));
    if scode != unicode::ERR_BAD_UTF8 || soffset != 8 || out.len != 0 {
        print("FAIL: the scan gave the code ", scode, " the offset ", soffset,
            " and ", out.len, " values for a bad byte\n");
        bad += 1;
    }
    // The scan of a huge text gives the fault. The buffer stays empty.
    out.push(1);
    let scode2, soffset2 = unicode::emoji_sequences(out, huge[..]);
    if scode2 != unicode::ERR_TOO_LONG || soffset2 != 0 || out.len != 0 {
        print("FAIL: the scan gave the code ", scode2, " and ", out.len,
            " values for a huge text\n");
        bad += 1;
    }
    if bad == 0 { print("emoji faults ok\n"); }
    return bad;
}

// The long texts. Each text holds one mebibyte of one code point that
// starts no sequence. The scan reads each text in a short time.
fn es_hostile() -> i64 {
    var bad: i64 = 0;
    var out: i64[>..] = [];
    // The joiners, the regional indicators, the keycap bases, the tag
    // characters and the skin tone modifiers.
    let units = [
        "\xE2\x80\x8D",
        "\xF0\x9F\x87\xA6",
        "\x30",
        "\xF3\xA0\x81\xA1",
        "\xF0\x9F\x8F\xBB",
    ];
    let names = ["joiners", "regional indicators", "keycap bases",
        "tag characters", "skin tone modifiers"];
    // The number of the values of the buffer for each unit of the text.
    // The skin tone modifier is a code point of the basic kind, so it
    // gives a pair of its own. The other units give no pair.
    let per_unit = [0, 0, 0, 0, 2];
    for u in 0..units.len {
        let unit = units[u];
        var text: u8[>..] = [];
        while text.len + unit.len <= unicode::MAX_INPUT {
            es_push(text, unit);
        }
        if text.len < unicode::MAX_INPUT { text.push(0x61); }
        let t0 = clock_ns();
        let code, offset, mask = unicode::emoji_sequence_kinds_checked(text[..]);
        let t1 = clock_ns();
        if code != unicode::OK || mask != 0 {
            print("FAIL: the hostile text of ", names[u], " gave the code ", code,
                " and the mask ", mask, "\n");
            bad += 1;
        }
        if unicode::emoji_sequence_kinds(text[..]) != 0 {
            print("FAIL: the hostile text of ", names[u], " gave a mask\n");
            bad += 1;
        }
        if unicode::is_rgi_emoji(text[..]) {
            print("FAIL: the hostile text of ", names[u], " gave the RGI property\n");
            bad += 1;
        }
        let t2 = clock_ns();
        let scode = unicode::emoji_sequences(out, text[..]);
        let t3 = clock_ns();
        let want = per_unit[u] * (text.len / unit.len);
        if scode != unicode::OK || out.len != want {
            print("FAIL: the scan of the hostile text of ", names[u], " gave the code ",
                scode, " and ", out.len, " values and not ", want, "\n");
            bad += 1;
        }
        let ms = (t3 - t2) / 1000000;
        if ms > 5000 {
            print("FAIL: the scan of the hostile text of ", names[u], " took ", ms, " ms\n");
            bad += 1;
        }
        let ms2 = (t1 - t0) / 1000000;
        if ms2 > 5000 {
            print("FAIL: the checked call on the hostile text of ", names[u], " took ",
                ms2, " ms\n");
            bad += 1;
        }
        if bad == 0 {
            print("emoji hostile ", names[u], ": scan ", ms, " ms, checked ", ms2, " ms\n");
        }
    }
    // The longest sequence of the standard holds 35 bytes. It holds the
    // ZWJ kind. A text of 36 bytes holds no kind.
    let longest = ES_LONGEST;
    if longest.len != unicode::MAX_EMOJI_SEQ {
        print("FAIL: the longest sequence holds ", longest.len, " bytes\n");
        bad += 1;
    }
    if unicode::emoji_sequence_kinds(longest) != unicode::EMOJI_SEQ_ZWJ {
        print("FAIL: the longest sequence gave the wrong mask\n");
        bad += 1;
    }
    var text36: u8[>..] = [];
    es_push(text36, longest);
    text36.push(0x61);
    if unicode::emoji_sequence_kinds(text36[..]) != 0 {
        print("FAIL: the text of 36 bytes gave a mask\n");
        bad += 1;
    }
    if bad == 0 { print("emoji hostile ok\n"); }
    return bad;
}

fn run_emoji_seq() -> i64 {
    var bad: i64 = 0;
    bad += es_battery();
    bad += es_scenarios();
    bad += es_scan();
    bad += es_faults();
    bad += es_hostile();
    return bad;
}
