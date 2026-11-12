// The language subtag of a language tag. The subtag is the first part
// of the tag: two or three ASCII letters, then the end of the tag, a
// hyphen or an underscore. The letters match without regard to case.
// The value packs the letters of the subtag, with the first letter in
// the high byte. Zero means the tag holds no language subtag.
namespace unicode;

import std;

// The language subtag of a language tag. The value packs the letters of
// the subtag, with the first letter in the high byte. Zero means the
// tag holds no language subtag.
fn lang_key(tag: const u8[:]) -> i64 {
    var n: i64 = 0;
    var l: i64 = 0;
    while n < tag.len && n < 4 {
        var c = tag[n] as i64;
        if c >= 65 && c <= 90 { c += 32; }
        if c < 97 || c > 122 { break; }
        l = (l << 8) | c;
        n += 1;
    }
    if n < 2 || n > 3 { return 0; }
    if n < tag.len && tag[n] != '-' && tag[n] != '_' { return 0; }
    return l;
}
