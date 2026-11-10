// The oracle of the title case mapping. Prints one line per code point
// whose title case differs from the code point: the code point and the
// mapping in hex, separated by a space. The table comes from the
// unicode-case-mapping crate.
use std::io::Write;

fn main() {
    let out = std::io::stdout();
    let mut w = std::io::BufWriter::new(out.lock());
    for cp in 0u32..=0x10FFFF {
        if (0xD800..=0xDFFF).contains(&cp) {
            continue;
        }
        let c = char::from_u32(cp).unwrap();
        let t = unicode_case_mapping::to_titlecase(c);
        if t == [0, 0, 0] {
            continue;
        }
        let mapped: Vec<String> = t
            .iter()
            .take_while(|&&x| x != 0)
            .map(|&x| format!("{:04X}", x))
            .collect();
        let _ = writeln!(w, "{:04X} {}", cp, mapped.join(" "));
    }
}
