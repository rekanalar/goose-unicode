// Tests for the bidirectional algorithm calls.
namespace suite;

import std;
import unicode from "../..";

fn bd_levels(text: const u8[:], dir: i64) -> i64[>..] {
    var lv: i64[>..] = [];
    let code, pl = unicode::bidi_levels(lv, text, dir);
    if code != unicode::OK { lv.push(-100); }
    return lv;
}

fn bd_same(got: const i64[:], want: const i64[:], name: const u8[:]) -> i64 {
    var ok = got.len == want.len;
    if ok {
        for k in 0..got.len { if got[k] != want[k] { ok = false; } }
    }
    if !ok {
        print("FAIL: bidi ", name, ", got");
        for k in 0..got.len { print(" ", got[k]); }
        print("\n");
        return 1;
    }
    return 0;
}

fn bd_samples() -> i64 {
    var bad = 0;
    // Latin letters, then Hebrew, then Latin: the Hebrew run sits at level 1.
    bad += bd_same(bd_levels("ab אב cd", 2)[..], [0, 0, 0, 1, 1, 0, 0, 0][..], "mixed");
    // The paragraph level follows the first strong letter.
    bad += bd_same(bd_levels("אב ab", 2)[..], [1, 1, 1, 2, 2][..], "hebrew first");
    // A forced direction.
    bad += bd_same(bd_levels("ab", 1)[..], [2, 2][..], "forced right to left");
    // A European number after a Hebrew letter stays at level 2.
    bad += bd_same(bd_levels("א12", 2)[..], [1, 2, 2][..], "number");
    // Brackets pair, so the parentheses follow the Hebrew inside them.
    bad += bd_same(bd_levels("a(א)b", 0)[..], [0, 0, 1, 0, 0][..], "brackets");
    // An embedding mark leaves the text and takes level -1.
    bad += bd_same(bd_levels("a‫א‬b", 0)[..], [0, -1, 1, -1, 0][..], "embedding");
    // The empty text gives an empty result and no fault.
    let empty = bd_levels("", 2);
    if empty.len != 0 {
        print("FAIL: bidi empty text holds ", empty.len, " levels\n");
        bad += 1;
    }
    // Two paragraphs take their own level.
    bad += bd_same(bd_levels("א a", 2)[..], [1, 1, 0][..], "paragraphs");
    // The visual order of a mixed line.
    var ord: i64[>..] = [];
    let lv = bd_levels("ab אב", 0);
    let c = unicode::bidi_order(ord, lv[..]);
    bad += bd_same(ord[..], [0, 1, 2, 4, 3][..], "order");
    if c != unicode::OK { bad += 1; }
    return bad;
}

fn bd_faults() -> i64 {
    var bad = 0;
    var lv: i64[>..] = [1, 2, 3];
    var bytes: u8[>..] = [0x61, 0xFF];
    let c1, p1 = unicode::bidi_levels(lv, bytes[..], 2);
    if c1 != unicode::ERR_BAD_UTF8 || lv.len != 0 { print("FAIL: bidi bad byte\n"); bad += 1; }
    lv.push(1);
    let c2, p2 = unicode::bidi_levels(lv, "a", 3);
    if c2 != unicode::ERR_BAD_ARG || lv.len != 0 { print("FAIL: bidi bad direction\n"); bad += 1; }
    var big: u8[>..] = [];
    for k in 0..1048577 { big.push(0x61); }
    let c3, p3 = unicode::bidi_levels(lv, big[..], 2);
    if c3 != unicode::ERR_TOO_LONG { print("FAIL: bidi long text\n"); bad += 1; }
    var ord: i64[>..] = [5];
    let bl: i64[>..] = [0, 127];
    if unicode::bidi_order(ord, bl[..]) != unicode::ERR_BAD_ARG || ord.len != 0 {
        print("FAIL: bidi bad level\n");
        bad += 1;
    }
    return bad;
}

// Hostile texts of the largest size. Each call runs in one pass.
fn bd_hostile() -> i64 {
    var bad = 0;
    var lv: i64[>..] = [];
    // Nested first strong isolates that never close.
    var fsi: u8[>..] = [];
    for k in 0..349525 { unicode::utf8_encode(fsi, 0x2068); }
    let c1, p1 = unicode::bidi_levels(lv, fsi[..], 2);
    if c1 != unicode::OK || lv.len != 349525 { print("FAIL: bidi nested isolates\n"); bad += 1; }
    // Open brackets and a Hebrew letter, within the input bound. The
    // bracket stack holds 63 entries, so the pairs past that depth stay
    // unpaired.
    var br: u8[>..] = [];
    for k in 0..262144 { unicode::utf8_encode(br, 0x28); unicode::utf8_encode(br, 0x5D0); }
    let c2, p2 = unicode::bidi_levels(lv, br[..], 0);
    if c2 != unicode::OK || lv.len != 524288 {
        print("FAIL: bidi bracket run\n");
        bad += 1;
    }
    var em: u8[>..] = [];
    for k in 0..349525 { unicode::utf8_encode(em, 0x202B); }
    let c3, p3 = unicode::bidi_levels(lv, em[..], 0);
    if c3 != unicode::OK || lv.len != 349525 { print("FAIL: bidi embeddings\n"); bad += 1; }
    // Nested brackets. The stack of the rule N0 holds 63 entries, so the
    // brackets past that depth stay unpaired. The call must still finish.
    var nb: u8[>..] = [];
    for k in 0..131072 { unicode::utf8_encode(nb, 0x28); }
    let c4, p4 = unicode::bidi_levels(lv, nb[..], 0);
    if c4 != unicode::OK || lv.len != 131072 {
        print("FAIL: bidi nested brackets\n");
        bad += 1;
    }
    return bad;
}

// One case of the standard: the code points, the levels and the order.
fn bd_check(text: const u8[:], dir: i64, want_lv: const i64[:],
            want_od: const i64[:], name: const u8[:], c: i64) -> i64 {
    var lv: i64[>..] = [];
    let code, pl = unicode::bidi_levels(lv, text, dir);
    if code != unicode::OK {
        print("FAIL: bidi ", name, " ", c, " gave fault ", code, "\n");
        return 1;
    }
    if lv.len != want_lv.len {
        print("FAIL: bidi ", name, " ", c, " holds ", lv.len, " levels, want ", want_lv.len, "\n");
        return 1;
    }
    for k in 0..lv.len {
        if lv[k] != want_lv[k] {
            print("FAIL: bidi ", name, " ", c, " level ", lv[k], ", want ", want_lv[k], "\n");
            return 1;
        }
    }
    var ord: i64[>..] = [];
    let c2 = unicode::bidi_order(ord, lv[..]);
    if c2 != unicode::OK {
        print("FAIL: bidi ", name, " ", c, " gave fault ", c2, "\n");
        return 1;
    }
    if ord.len != want_od.len {
        print("FAIL: bidi ", name, " ", c, " order holds ", ord.len, ", want ", want_od.len, "\n");
        return 1;
    }
    for k in 0..ord.len {
        if ord[k] != want_od[k] {
            print("FAIL: bidi ", name, " ", c, " order ", ord[k], ", want ", want_od[k], "\n");
            return 1;
        }
    }
    return 0;
}

// The bytes of the code points of a case.
fn bd_bytes(cp: const i64[:], start: i64, len: i64) -> u8[>..] {
    var text: u8[>..] = [];
    for k in start..start + len {
        unicode::utf8_encode(text, cp[k]);
    }
    return text;
}

// The conformance cases of the standard. The file holds a sample of the
// cases of the Unicode Character Database.
fn bd_cases() -> i64 {
    var bad = 0;
    for c in 0..BD_COUNT {
        let start = BD_OFF[c];
        let text = bd_bytes(BD_CP[..], start, BD_LEN[c]);
        let ostart = BD_OD_OFF[c];
        bad += bd_check(text[..], BD_DIR[c],
            BD_LV[start..start + BD_LEN[c]],
            BD_OD[ostart..ostart + BD_OD_LEN[c]], "case", c);
        if bad > 5 { return bad; }
    }
    return bad;
}

// The class sequences of the standard. The file holds a sample of the
// sequences of the Unicode Character Database.
fn bd_class_cases() -> i64 {
    var bad = 0;
    for c in 0..BC_COUNT {
        let start = BC_OFF[c];
        let text = bd_bytes(BC_CP[..], start, BC_LEN[c]);
        let ostart = BC_OD_OFF[c];
        // The bits name the paragraph levels to test: 1 is auto, 2 is
        // left to right and 4 is right to left.
        let bits = BC_BITS[c];
        var dirs: i64[>..] = [];
        if (bits & 1) != 0 { dirs.push(unicode::BIDI_DIR_AUTO); }
        if (bits & 2) != 0 { dirs.push(unicode::BIDI_DIR_LTR); }
        if (bits & 4) != 0 { dirs.push(unicode::BIDI_DIR_RTL); }
        for d in 0..dirs.len {
            bad += bd_check(text[..], dirs[d],
                BC_LV[start..start + BC_LEN[c]],
                BC_OD[ostart..ostart + BC_OD_LEN[c]], "class case", c);
            if bad > 5 { return bad; }
        }
    }
    return bad;
}

fn run_bidi() -> i64 {
    var bad = 0;
    if want("bidi", "bd_samples") { bad += bd_samples(); }
    if want("bidi", "bd_faults") { bad += bd_faults(); }
    if want("bidi", "bd_cases") { bad += bd_cases(); }
    if want("bidi", "bd_class_cases") { bad += bd_class_cases(); }
    if want("bidi", "bd_hostile") { bad += bd_hostile(); }
    return bad;
}
