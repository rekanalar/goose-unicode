// Tests for the collation options.
namespace suite;

import std;
import unicode from "../..";
import util;
import collopt_cases;

fn cx_check(ok: bool, name: const u8[:]) -> i64 {
    return check("collation options", name, ok);
}

// The count of the values of one group of CO_OPT_GROUPS.
const CO_OPT_STRIDE: i64 = 8;

// The options of a group from the attributes of ICU. The strength is the
// same number. The alternate handling is 20 for shifted and 21 for
// non-ignorable. The numeric order is 16 off and 17 on. The case order
// is 16 off, 24 lower first and 25 upper first. The case level is 0
// off and 1 on.
fn cx_group_options(g: i64) -> unicode::CollOptions {
    var o = unicode::coll_options();
    o.strength = CO_OPT_GROUPS[CO_OPT_STRIDE * g];
    if CO_OPT_GROUPS[CO_OPT_STRIDE * g + 1] == 20 { o.alternate = unicode::ALT_SHIFTED; }
    if CO_OPT_GROUPS[CO_OPT_STRIDE * g + 2] == 17 { o.numeric = 1; }
    let c = CO_OPT_GROUPS[CO_OPT_STRIDE * g + 3];
    if c == 24 { o.case_first = unicode::CASE_LOWER_FIRST; }
    if c == 25 { o.case_first = unicode::CASE_UPPER_FIRST; }
    if CO_OPT_GROUPS[CO_OPT_STRIDE * g + 4] == 1 { o.case_level = unicode::CASE_LEVEL_ON; }
    return o;
}

// The text of the case c in the pool: the first text when second is
// false, the second text else. The table offs holds the start of each
// case.
fn cx_text(dst: u8[>..]&, c: i64, second: bool, offs: const u8[:]) {
    let at = pool_val(offs, c);
    let n1 = pool_val(CO_OPT_POOL, at);
    var cps: i64[>..] = [];
    if !second {
        pool_load(cps, CO_OPT_POOL, at + 1, at + 1 + n1);
    } else {
        let n2 = pool_val(CO_OPT_POOL, at + 1 + n1);
        pool_load(cps, CO_OPT_POOL, at + 2 + n1, at + 2 + n1 + n2);
    }
    dst.clear();
    unicode::encode_all(dst, cps[..]);
}

// Every group of the cases file: the sign of compare_with equals the
// sign of ICU, and the keys of sort_key_with order the texts the same
// way. Every case checks the keys.
fn cx_groups() -> i64 {
    var bad = 0;
    var out: i64[>..] = [];
    var ta: u8[>..] = [];
    var tb: u8[>..] = [];
    var k1: i64[>..] = [];
    var k2: i64[>..] = [];
    for g in 0..CO_OPT_GROUPS.len / CO_OPT_STRIDE {
        let o = cx_group_options(g);
        let first = CO_OPT_GROUPS[CO_OPT_STRIDE * g + 5];
        let count = CO_OPT_GROUPS[CO_OPT_STRIDE * g + 6];
        let sign0 = CO_OPT_GROUPS[CO_OPT_STRIDE * g + 7];
        var wrong: i64 = 0;
        for i in 0..count {
            cx_text(ta, first + i, false, CO_OPT_OFF[..]);
            cx_text(tb, first + i, true, CO_OPT_OFF[..]);
            let code, _ = unicode::compare_with(out, ta[..], tb[..], o);
            let want = (CO_OPT_EXP[sign0 + i] as i64) - 1;
            if code != unicode::OK || out.len != 1 || out[0] != want {
                wrong += 1;
                if wrong <= 3 {
                    print("FAIL: collation options group ", g, " case ", i, " code ", code, " want ", want, "\n");
                }
                continue;
            }
            {
                let c1, _ = unicode::sort_key_with(k1, ta[..], o);
                let c2, _ = unicode::sort_key_with(k2, tb[..], o);
                if c1 != unicode::OK || c2 != unicode::OK || key_sign(k1[..], k2[..]) != want {
                    wrong += 1;
                    if wrong <= 3 { print("FAIL: collation options group ", g, " key ", i, "\n"); }
                }
            }
        }
        bad += wrong;
    }
    return bad;
}

// The edge cases, under the default options, under the numeric order and
// under the numeric order with the fourth level and the shifted handling.
fn cx_edges() -> i64 {
    var bad = 0;
    var out: i64[>..] = [];
    var ta: u8[>..] = [];
    var tb: u8[>..] = [];
    var o = unicode::coll_options();
    for c in 0..CO_OPT_EDGE_OFF.len / 3 {
        cx_text(ta, c, false, CO_OPT_EDGE_OFF[..]);
        cx_text(tb, c, true, CO_OPT_EDGE_OFF[..]);
        o.numeric = 0;
        let code, _ = unicode::compare_with(out, ta[..], tb[..], o);
        let want0 = (CO_OPT_EDGE_EXP[3 * c] as i64) - 1;
        if code != unicode::OK || out.len != 1 || out[0] != want0 {
            bad += 1;
            print("FAIL: collation options edge ", c, " default want ", want0, " got ", out[0], "\n");
        }
        o.numeric = 1;
        let code2, _ = unicode::compare_with(out, ta[..], tb[..], o);
        let want1 = (CO_OPT_EDGE_EXP[3 * c + 1] as i64) - 1;
        if code2 != unicode::OK || out.len != 1 || out[0] != want1 {
            bad += 1;
            print("FAIL: collation options edge ", c, " numeric want ", want1, " got ", out[0], "\n");
        }
        o.strength = unicode::STRENGTH_QUATERNARY;
        o.alternate = unicode::ALT_SHIFTED;
        let code3, _ = unicode::compare_with(out, ta[..], tb[..], o);
        let want2 = (CO_OPT_EDGE_EXP[3 * c + 2] as i64) - 1;
        if code3 != unicode::OK || out.len != 1 || out[0] != want2 {
            bad += 1;
            print("FAIL: collation options edge ", c, " fourth want ", want2, " got ", out[0], "\n");
        }
        o.strength = unicode::STRENGTH_TERTIARY;
        o.alternate = unicode::ALT_NON_IGNORABLE;
    }
    return bad;
}

// The default options give the result of compare and sort_key on the
// texts of the old collation corpus.
fn cx_default() -> i64 {
    var bad = 0;
    var o1: i64[>..] = [];
    var o2: i64[>..] = [];
    var k1: i64[>..] = [];
    var k2: i64[>..] = [];
    var ta: u8[>..] = [];
    var tb: u8[>..] = [];
    let d = unicode::coll_options();
    for p in 0..RP_SIGN.len {
        var a: i64[>..] = [];
        var b: i64[>..] = [];
        pool_load(a, RP_POOL, 2 * p, 2 * p + 1);
        pool_load(b, RP_POOL, 2 * p + 1, 2 * p + 2);
        ta.clear();
        tb.clear();
        unicode::encode_all(ta, a[..]);
        unicode::encode_all(tb, b[..]);
        let c1, _ = unicode::compare(o1, ta[..], tb[..]);
        let c2, _ = unicode::compare_with(o2, ta[..], tb[..], d);
        if c1 != c2 || o1.len != o2.len || (o1.len == 1 && o1[0] != o2[0]) {
            bad += 1;
            if bad <= 3 { print("FAIL: collation options default compare ", p, "\n"); }
        }
        let d1, _ = unicode::sort_key(k1, ta[..]);
        let d2, _ = unicode::sort_key_with(k2, ta[..], d);
        if d1 != d2 || key_sign(k1[..], k2[..]) != 0 {
            bad += 1;
            if bad <= 3 { print("FAIL: collation options default key ", p, "\n"); }
        }
    }
    return bad;
}

// The faults: a field outside its range, a long text, a bad byte.
fn cx_faults() -> i64 {
    var bad = 0;
    var out: i64[>..] = [];
    var k: i64[>..] = [];
    var o = unicode::coll_options();
    o.strength = 4;
    var code, _ = unicode::compare_with(out, "a", "b", o);
    bad += cx_check(code == unicode::ERR_BAD_ARG && out.len == 0, "strength 4");
    o = unicode::coll_options();
    o.case_level = 2;
    code, _ = unicode::compare_with(out, "a", "b", o);
    bad += cx_check(code == unicode::ERR_BAD_ARG && out.len == 0, "case level 2");
    o = unicode::coll_options();
    o.strength = -1;
    code, _ = unicode::sort_key_with(k, "a", o);
    bad += cx_check(code == unicode::ERR_BAD_ARG && k.len == 0, "strength -1");
    o = unicode::coll_options();
    o.alternate = 2;
    code, _ = unicode::compare_with(out, "a", "b", o);
    bad += cx_check(code == unicode::ERR_BAD_ARG, "alternate 2");
    o = unicode::coll_options();
    o.numeric = 2;
    code, _ = unicode::compare_with(out, "a", "b", o);
    bad += cx_check(code == unicode::ERR_BAD_ARG, "numeric 2");
    o = unicode::coll_options();
    o.case_first = 3;
    code, _ = unicode::compare_with(out, "a", "b", o);
    bad += cx_check(code == unicode::ERR_BAD_ARG, "case 3");
    // A bad option and a bad byte give the fault of the option.
    o = unicode::coll_options();
    o.strength = 4;
    code, _ = unicode::compare_with(out, "\xFF", "b", o);
    bad += cx_check(code == unicode::ERR_BAD_ARG, "option before byte");
    // A bad byte gives its offset.
    o = unicode::coll_options();
    var off: i64 = 0;
    code, off = unicode::sort_key_with(k, "ab\xFFcd", o);
    bad += cx_check(code == unicode::ERR_BAD_UTF8 && off == 2 && k.len == 0, "bad byte");
    // A text above MAX_INPUT.
    var big: u8[>..] = [];
    for i in 0..unicode::MAX_INPUT + 1 { big.push('a'); }
    code, _ = unicode::sort_key_with(k, big[..], o);
    bad += cx_check(code == unicode::ERR_TOO_LONG && k.len == 0, "long text");
    code, _ = unicode::compare_with(out, big[..], "a", o);
    bad += cx_check(code == unicode::ERR_TOO_LONG && out.len == 0, "long text compare");
    return bad;
}

// The hostile texts: a text of the input limit ends in time with each
// option, and a run of digits of the input limit does too.
fn cx_hostile() -> i64 {
    var bad = 0;
    var out: i64[>..] = [];
    var k: i64[>..] = [];
    var wall: u8[>..] = [];
    for i in 0..unicode::MAX_INPUT { wall.push('a'); }
    var digits: u8[>..] = [];
    for i in 0..unicode::MAX_INPUT { digits.push('7'); }
    var o = unicode::coll_options();
    o.alternate = unicode::ALT_SHIFTED;
    o.case_first = unicode::CASE_UPPER_FIRST;
    let t0 = clock_ns();
    let c1, _ = unicode::sort_key_with(k, wall[..], o);
    bad += cx_check(c1 == unicode::OK && k.len > 0, "wall of letters");
    let t1 = clock_ns();
    o.numeric = 1;
    let c2, _ = unicode::sort_key_with(k, digits[..], o);
    bad += cx_check(c2 == unicode::OK && k.len > 0, "wall of digits");
    let c4, _ = unicode::compare_with(out, digits[..], wall[..], o);
    bad += cx_check(c4 == unicode::OK && out.len == 1, "digits against letters");
    // A hostile text of expansions grows the key above MAX_OUTPUT. The
    // Arabic ligature U+FDFA holds the longest expansion of the table.
    // The text stays under MAX_INPUT, so the fault comes from the bound
    // of the key and not from the bound of the input.
    var many: u8[>..] = [];
    var i: i64 = 0;
    while i < 300000 {
        push_utf8(many, 0xFDFA);
        i += 3;
    }
    let c3, _ = unicode::sort_key_with(k, many[..], o);
    bad += cx_check(c3 == unicode::ERR_TOO_LONG && k.len == 0, "key above the bound");
    // Many short runs of digits grow the key faster than the text grows.
    // The run of one digit gives eight weights and the letter gives
    // three. So a text of 800,000 bytes of a digit and a letter gives
    // 4,400,000 weights. The bound holds 4,194,304.
    var runs: u8[>..] = [];
    var r: i64 = 0;
    while r < 800000 {
        runs.push('1');
        runs.push('a');
        r += 2;
    }
    let c7, _ = unicode::sort_key_with(k, runs[..], o);
    bad += cx_check(c7 == unicode::ERR_TOO_LONG && k.len == 0, "many short runs above the bound");
    let c6, _ = unicode::compare_with(out, many[..], many[..], o);
    bad += cx_check(c6 == unicode::ERR_TOO_LONG && out.len == 0, "compare above the bound");
    let t2 = clock_ns();
    // The identical strength adds the code points to the key. The key of
    // a text of the input limit then stands above the bound, and the
    // call gives the fault at once.
    o.strength = unicode::STRENGTH_IDENTICAL;
    let c5, _ = unicode::sort_key_with(k, wall[..], o);
    bad += cx_check(c5 == unicode::ERR_TOO_LONG && k.len == 0, "identical above the bound");
    bad += cx_check(t1 - t0 < 5000000000 && t2 - t1 < 5000000000, "time");
    print("collation options hostile: ", (t1 - t0) / 1000000, " ms, ", (t2 - t1) / 1000000, " ms\n");
    return bad;
}

// The weights of a key stay below 0x10000, so a caller can pack the key
// into 16 bits. The key of every code point of the range is checked,
// under the numeric order, the upper case first and the shifted
// handling. The identical strength adds the code points of the text,
// and a code point needs more than 16 bits.
fn cx_weights() -> i64 {
    var bad = 0;
    var k: i64[>..] = [];
    var s: u8[>..] = [];
    var one: i64[>..] = [];
    var o = unicode::coll_options();
    o.alternate = unicode::ALT_SHIFTED;
    o.case_first = unicode::CASE_UPPER_FIRST;
    o.numeric = 1;
    var cp: i64 = 0;
    while cp <= 0x10FFFF {
        one.clear();
        one.push(cp);
        s.clear();
        unicode::encode_all(s, one[..]);
        let code, _ = unicode::sort_key_with(k, s[..], o);
        if code == unicode::OK {
            for i in 0..k.len {
                if k[i] > 0xFFFF {
                    bad += 1;
                    if bad <= 3 { print("FAIL: weight above 16 bits at U+", cp, "\n"); }
                    break;
                }
            }
        }
        cp += 1;
    }
    // A run of digits gives the weights of the numbers.
    let code, _ = unicode::sort_key_with(k, "1234567890"[..], o);
    if code != unicode::OK {
        bad += cx_check(false, "weights of a run of digits");
    } else {
        var over = false;
        for i in 0..k.len {
            if k[i] > 0xFFFF { over = true; }
        }
        bad += cx_check(!over, "weights of a run of digits");
    }
    return bad;
}

// The key of the identical strength ends at the bound. The key holds
// the four levels, the code points, five separators and the terminator,
// so a text of n letters gives 5n + 5 numbers. A text of 838,859
// letters gives 4,194,300 numbers. One more letter gives 4,194,305
// numbers, one above the bound of 4,194,304.
fn cx_identical_bound() -> i64 {
    var bad = 0;
    var k: i64[>..] = [];
    var wall: u8[>..] = [];
    var o = unicode::coll_options();
    o.strength = unicode::STRENGTH_IDENTICAL;
    var i: i64 = 0;
    while i < 838859 {
        wall.push('a');
        i += 1;
    }
    let code, _ = unicode::sort_key_with(k, wall[..], o);
    bad += cx_check(code == unicode::OK && k.len == 4194300, "identical key at the bound");
    wall.push('a');
    let code2, _ = unicode::sort_key_with(k, wall[..], o);
    bad += cx_check(code2 == unicode::ERR_TOO_LONG && k.len == 0, "identical key above the bound");
    // A space that the shifted handling drops adds a code point and one
    // weight of the fourth level. The key of 838,859 letters and one
    // space then holds 4,194,302 numbers, which stays under the bound.
    o.alternate = unicode::ALT_SHIFTED;
    wall.clear();
    i = 0;
    while i < 838859 {
        wall.push('a');
        i += 1;
    }
    wall.push(' ');
    let code3, _ = unicode::sort_key_with(k, wall[..], o);
    bad += cx_check(code3 == unicode::OK && k.len == 4194302, "identical key with a dropped space");
    wall.push(' ');
    wall.push(' ');
    wall.push(' ');
    let code4, _ = unicode::sort_key_with(k, wall[..], o);
    bad += cx_check(code4 == unicode::ERR_TOO_LONG && k.len == 0, "identical key one above the bound");
    return bad;
}

// The scenarios of the case level and the quaternary strength. Each
// pair names its expected sign, which ICU 79.1 gives.
fn cx_sign(a: const u8[:], b: const u8[:], o: unicode::CollOptions) -> i64 {
    var out: i64[>..] = [];
    let code, _ = unicode::compare_with(out, a, b, o);
    if code != unicode::OK || out.len != 1 { return 9; }
    return out[0];
}

fn cx_levels() -> i64 {
    var bad = 0;
    var o = unicode::coll_options();
    bad += cx_check(cx_sign("a", "A", o) == -1, "default a A");
    o.case_level = unicode::CASE_LEVEL_ON;
    o.strength = unicode::STRENGTH_PRIMARY;
    bad += cx_check(cx_sign("a", "A", o) == -1, "case level primary a A");
    bad += cx_check(cx_sign("a", "\xC3\xA4", o) == 0, "case level primary accent");
    o.strength = unicode::STRENGTH_SECONDARY;
    bad += cx_check(cx_sign("a", "\xC3\xA4", o) == -1, "case level secondary accent");
    o.strength = unicode::STRENGTH_TERTIARY;
    bad += cx_check(cx_sign("a", "A", o) == -1, "case level tertiary a A");
    o.case_first = unicode::CASE_UPPER_FIRST;
    bad += cx_check(cx_sign("a", "A", o) == 1, "case level upper first");
    // The key holds the case level after the secondary level.
    var k: i64[>..] = [];
    o = unicode::coll_options();
    o.case_level = unicode::CASE_LEVEL_ON;
    let c1, _ = unicode::sort_key_with(k, "a", o);
    var seps: i64 = 0;
    for i in 0..k.len { if k[i] == 1 { seps += 1; } }
    bad += cx_check(c1 == unicode::OK && seps == 3 && k[k.len - 1] == 0, "key holds the case level");
    // The case weight of a lower case letter is 2, so no weight of the
    // case level ends a level of the key.
    bad += cx_check(k[4] == 2, "case weight of a lower case letter");
    // The quaternary strength.
    o = unicode::coll_options();
    o.alternate = unicode::ALT_SHIFTED;
    bad += cx_check(cx_sign("a b", "a-b", o) == 0, "tertiary shifted equal");
    o.strength = unicode::STRENGTH_QUATERNARY;
    bad += cx_check(cx_sign("a b", "a-b", o) == -1, "quaternary shifted a b a-b");
    o.alternate = unicode::ALT_NON_IGNORABLE;
    bad += cx_check(cx_sign("a b", "a-b", o) == -1, "quaternary non-ignorable");
    var q: i64[>..] = [];
    o.alternate = unicode::ALT_SHIFTED;
    let c2, _ = unicode::sort_key_with(q, "a-b", o);
    seps = 0;
    for i in 0..q.len { if q[i] == 1 { seps += 1; } }
    bad += cx_check(c2 == unicode::OK && seps == 3, "key holds the fourth level");
    return bad;
}

fn run_collopt() -> i64 {
    var bad = 0;
    if want("collopt", "cx_groups") { bad += cx_groups(); }
    if want("collopt", "cx_edges") { bad += cx_edges(); }
    if want("collopt", "cx_default") { bad += cx_default(); }
    if want("collopt", "cx_faults") { bad += cx_faults(); }
    if want("collopt", "cx_hostile") { bad += cx_hostile(); }
    if want("collopt", "cx_weights") { bad += cx_weights(); }
    if want("collopt", "cx_identical_bound") { bad += cx_identical_bound(); }
    if want("collopt", "cx_levels") { bad += cx_levels(); }
    return bad;
}
