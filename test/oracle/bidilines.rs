// Oracle for the paragraph split and the line calls of the package. Each
// input line holds "dir start limit | code points in hex". The direction
// is 0, 1 or 2 (left to right, right to left, auto). The start and the
// limit count code points.
//
// The output holds the paragraphs, then the levels of the line after
// rule L1, the visual order and the written text. The answers come from
// the Rust unicode-bidi crate 0.3.18. The crate has no L3 and no L4.

use std::io::{self, BufRead, Write};
use unicode_bidi::{BidiInfo, Level};

fn main() {
    let stdin = io::stdin();
    let stdout = io::stdout();
    let mut out = io::BufWriter::new(stdout.lock());
    for input in stdin.lock().lines() {
        let input = input.unwrap();
        let (head, body) = input.split_once('|').unwrap_or((&input, ""));
        let nums: Vec<usize> = head
            .split_whitespace()
            .map(|n| n.parse().unwrap())
            .collect();
        let (dir, start, limit) = (nums[0], nums[1], nums[2]);
        let cps: Vec<char> = body
            .split_whitespace()
            .map(|h| char::from_u32(u32::from_str_radix(h, 16).unwrap()).unwrap())
            .collect();
        let s: String = cps.iter().collect();
        // The byte offset of each code point.
        let mut off: Vec<usize> = Vec::new();
        let mut b = 0;
        for c in &cps {
            off.push(b);
            b += c.len_utf8();
        }
        off.push(b);
        let level = match dir {
            0 => Some(Level::ltr()),
            1 => Some(Level::rtl()),
            _ => None,
        };
        let info = BidiInfo::new(&s, level);
        let back = |byte: usize| off.iter().position(|o| *o == byte).unwrap();
        write!(out, "P {}", info.paragraphs.len()).unwrap();
        for p in &info.paragraphs {
            write!(out, " {} {} {}", back(p.range.start), back(p.range.end), p.level.number())
                .unwrap();
        }
        writeln!(out).unwrap();
        if start > limit || limit > cps.len() {
            writeln!(out, "E range\n.").unwrap();
            continue;
        }
        // The paragraph that holds the line.
        let para = info
            .paragraphs
            .iter()
            .find(|p| p.range.start <= off[start] && off[limit] <= p.range.end);
        let para = match para {
            Some(p) => p,
            None => {
                writeln!(out, "E cross\n.").unwrap();
                continue;
            }
        };
        let line = off[start]..off[limit];
        // The call gives one level for each character of the whole text.
        // The line is the part from start to limit.
        let all = info.reordered_levels_per_char(para, line.clone());
        let levels: Vec<Level> = all[start..limit].to_vec();
        let nums: Vec<String> = levels.iter().map(|l| l.number().to_string()).collect();
        writeln!(out, "L {}", nums.join(" ")).unwrap();
        // The levels of the paragraph, before rule L1. The crate writes the
        // line as it is when these levels hold no odd level.
        let pl: Vec<String> = (start..limit)
            .map(|i| info.levels[off[i]].number().to_string())
            .collect();
        writeln!(out, "PL {}", pl.join(" ")).unwrap();
        let map = BidiInfo::reorder_visual(&levels);
        let o: Vec<String> = map.iter().map(|i| (i + start).to_string()).collect();
        writeln!(out, "O {}", o.join(" ")).unwrap();
        let text = info.reorder_line(para, line);
        let hex: Vec<String> = text.chars().map(|c| format!("{:X}", c as u32)).collect();
        writeln!(out, "W 0 {}\n.", hex.join(" ")).unwrap();
    }
}
