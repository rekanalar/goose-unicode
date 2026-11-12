// The word segments of the Rust icu_segmenter crate. Each input line
// holds the code points of one text in hex. The first argument names the
// segmenter: auto, dictionary or invariant. The output holds the
// boundaries as offsets in code points.
use icu_segmenter::options::WordBreakInvariantOptions;
use icu_segmenter::WordSegmenter;
use std::io::{self, BufRead};

fn main() {
    let mode = std::env::args().nth(1).unwrap_or_else(|| "auto".to_string());
    let auto = WordSegmenter::new_auto(WordBreakInvariantOptions::default());
    let dict = WordSegmenter::new_dictionary(WordBreakInvariantOptions::default());
    let stdin = io::stdin();
    for line in stdin.lock().lines() {
        let line = line.unwrap();
        let text: String = line
            .split_whitespace()
            .map(|h| char::from_u32(u32::from_str_radix(h, 16).unwrap()).unwrap())
            .collect();
        let seg = if mode == "dictionary" { dict } else { auto };
        let mut out: Vec<String> = Vec::new();
        for b in seg.segment_str(&text) {
            let cps = text[..b].chars().count();
            out.push(cps.to_string());
        }
        println!("{}", out.join(" "));
    }
}
