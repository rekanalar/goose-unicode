// The line break opportunities of the Rust icu_segmenter crate. Each
// input line holds the code points of one text in hex. The first
// argument names the segmenter: auto or dictionary. The output holds
// the break offsets in code points, the end of the text included.
use icu_segmenter::options::LineBreakOptions;
use icu_segmenter::LineSegmenter;
use std::io::{self, BufRead};

fn main() {
    let mode = std::env::args().nth(1).unwrap_or_else(|| "auto".to_string());
    let auto = LineSegmenter::new_auto(LineBreakOptions::default());
    let dict = LineSegmenter::new_dictionary(LineBreakOptions::default());
    let stdin = io::stdin();
    for line in stdin.lock().lines() {
        let line = line.unwrap();
        let text: String = line
            .split_whitespace()
            .map(|h| char::from_u32(u32::from_str_radix(h, 16).unwrap()).unwrap())
            .collect();
        let seg = if mode == "dictionary" { &dict } else { &auto };
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
