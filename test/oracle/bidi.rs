// Oracle for the bidirectional algorithm of the package. It reads one
// text per line, as hex code points separated by spaces, and prints the
// level of each code point and the visual order.
//
// The answers come from the Rust unicode-bidi crate 0.3.x.

use std::io::{self, BufRead, Write};
use unicode_bidi::{BidiInfo, Level, ParagraphInfo};

fn main() {
    let stdin = io::stdin();
    let stdout = io::stdout();
    let mut out = io::BufWriter::new(stdout.lock());
    for line in stdin.lock().lines() {
        let line = line.unwrap();
        let line = line.trim();
        if line.is_empty() {
            continue;
        }
        let cps: Vec<u32> = line
            .split_whitespace()
            .map(|h| u32::from_str_radix(h, 16).unwrap())
            .collect();
        let s: String = cps.iter().filter_map(|c| char::from_u32(*c)).collect();
        let bidi = BidiInfo::new(&s, None);
        let para: &ParagraphInfo = bidi.paragraphs.first().unwrap();
        let levels = bidi.reordered_levels_per_char(para, 0..s.len());
        let mut parts: Vec<String> = levels
            .iter()
            .map(|l| l.number().to_string())
            .collect();
        writeln!(out, "{}", parts.join(" ")).unwrap();
        let map = BidiInfo::reorder_visual(&levels);
        let mut o: Vec<String> = map.iter().map(|i| i.to_string()).collect();
        writeln!(out, "{}", o.join(" ")).unwrap();
    }
}
