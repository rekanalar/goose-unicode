// The sentence segments of the Rust icu_segmenter crate. Each input line
// holds the code points of one text in hex. The output holds the
// boundaries as offsets in code points.
use icu_segmenter::options::SentenceBreakInvariantOptions;
use icu_segmenter::SentenceSegmenter;
use std::io::{self, BufRead};

fn main() {
    let seg = SentenceSegmenter::new(SentenceBreakInvariantOptions::default());
    let stdin = io::stdin();
    for line in stdin.lock().lines() {
        let line = line.unwrap();
        let text: String = line
            .split_whitespace()
            .map(|h| char::from_u32(u32::from_str_radix(h, 16).unwrap()).unwrap())
            .collect();
        let mut out: Vec<String> = Vec::new();
        for b in seg.segment_str(&text) {
            if b == 0 {
                continue;
            }
            out.push(text[..b].chars().count().to_string());
        }
        println!("{}", out.join(" "));
    }
}
