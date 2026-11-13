// Splits one Thai text and one Burmese text with the dictionary engine
// and with the model engine. The two engines can give different breaks.
import std;
import unicode from "..";

fn show(name: const u8[:], s: const u8[:], engine: i64) {
    var br: i64[>..] = [];
    let code = unicode::word_offsets_with(br, s, engine);
    var out: u8[>..] = [];
    for k in 0..br.len {
        if k > 0 { out.push(32); }
        format_int(out, br[k], 10, 0, 32);
    }
    print(name, " code ", code, " breaks ", str(out));
}

fn main() {
    var thai: u8[>..] = [];
    unicode::encode_all(thai, [0xE04, 0xE31, 0xE48, 0xE27, 0xE2A, 0xE39, 0xE15, 0xE34,
        0xE01, 0xE23, 0xE23, 0xE21, 0xE23, 0xE31, 0xE15, 0xE19]);
    var burmese: u8[>..] = [];
    unicode::encode_all(burmese, [0x1019, 0x103C, 0x1014, 0x103A, 0x1019, 0x102C,
        0x1005, 0x102C, 0x1000, 0x103C, 0x100A, 0x103A]);
    show("thai dictionary", thai[..], unicode::SEG_DICTIONARY);
    show("thai model", thai[..], unicode::SEG_MODEL);
    show("burmese dictionary", burmese[..], unicode::SEG_DICTIONARY);
    show("burmese model", burmese[..], unicode::SEG_MODEL);
    return 0;
}
