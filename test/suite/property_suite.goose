// Tests for the general category and the combining class.
namespace suite;

import std;
import unicode from "../..";

// The category of every run of the table. The first and the last code
// point of the run must have the same category.
fn prop_categories() -> i64 {
    var bad = 0;
    for k in 0..PC_CAT.len / 3 {
        let first = PC_CAT[3 * k];
        let last = PC_CAT[3 * k + 1];
        let want = PC_CAT[3 * k + 2];
        if unicode::category(first) != want {
            print("FAIL: the category of ", first, " differs\n");
            bad += 1;
        }
        if unicode::category(last) != want {
            print("FAIL: the category of ", last, " differs\n");
            bad += 1;
        }
        if bad > 5 { return bad; }
    }
    return bad;
}

// The combining class of every run of the table.
fn prop_classes() -> i64 {
    var bad = 0;
    for k in 0..PC_CCC.len / 3 {
        let first = PC_CCC[3 * k];
        let last = PC_CCC[3 * k + 1];
        let want = PC_CCC[3 * k + 2];
        if unicode::combining_class(first) != want {
            print("FAIL: the class of ", first, " differs\n");
            bad += 1;
        }
        if unicode::combining_class(last) != want {
            print("FAIL: the class of ", last, " differs\n");
            bad += 1;
        }
        if bad > 5 { return bad; }
    }
    return bad;
}

// One code point of every category.
fn prop_one_of_each() -> i64 {
    var bad = 0;
    // The first code point of every category of the table.
    var seen: i64[>..] = [];
    var count: i64 = 0;
    for k in 0..PC_CAT.len / 3 {
        let cat = unicode::category(PC_CAT[3 * k]);
        if cat < 0 || cat > 29 { print("FAIL: the category is out of range\n"); bad += 1; continue; }
        var found = false;
        for j in 0..seen.len { if seen[j] == cat { found = true; } }
        if !found { seen.push(cat); }
    }
    if seen.len != 30 {
        print("FAIL: the table holds ", seen.len, " categories\n");
        bad += 1;
    }
    // The name of every category.
    for k in 0..30 {
        let name = unicode::category_name(k);
        if name.len != 2 {
            print("FAIL: the name of the category ", k, " has a wrong length\n");
            bad += 1;
        }
    }
    return bad;
}

// The code points outside the range.
fn prop_outside() -> i64 {
    var bad = 0;
    let outside: i64[6] = [-1, -1000, 0x110000, 0x200000, 0x7FFFFFFF, 0xFFFFFFFF];
    for k in 0..outside.len {
        if unicode::category(outside[k]) != unicode::CAT_CN {
            print("FAIL: a code point outside the range has a category\n");
            bad += 1;
        }
        if unicode::combining_class(outside[k]) != 0 {
            print("FAIL: a code point outside the range has a class\n");
            bad += 1;
        }
        if unicode::category_name(outside[k]) != "Cn" {
            print("FAIL: a code point outside the range has a name\n");
            bad += 1;
        }
    }
    return bad;
}

// The boundary code points of the range.
fn prop_boundary() -> i64 {
    var bad = 0;
    if unicode::category(0x10FFFF) != unicode::CAT_CN {
        print("FAIL: the last code point has a category\n");
        bad += 1;
    }
    if unicode::category(0) != unicode::CAT_CC {
        print("FAIL: the null character has a category\n");
        bad += 1;
    }
    if unicode::category(0x41) != unicode::CAT_LU {
        print("FAIL: the letter A has a category\n");
        bad += 1;
    }
    if unicode::category(0x61) != unicode::CAT_LL {
        print("FAIL: the letter a has a category\n");
        bad += 1;
    }
    if unicode::category(0x20) != unicode::CAT_ZS {
        print("FAIL: the space has a category\n");
        bad += 1;
    }
    if unicode::category(0x30) != unicode::CAT_ND {
        print("FAIL: the digit has a category\n");
        bad += 1;
    }
    if unicode::category(0x301) != unicode::CAT_MN {
        print("FAIL: the mark has a category\n");
        bad += 1;
    }
    if unicode::category(0xD800) != unicode::CAT_CS {
        print("FAIL: the surrogate has a category\n");
        bad += 1;
    }
    return bad;
}

fn run_property() -> i64 {
    var bad = 0;
    bad += prop_categories();
    bad += prop_classes();
    bad += prop_one_of_each();
    bad += prop_outside();
    bad += prop_boundary();
    return bad;
}
